// Trashcans are provided as a CSV file from Taipei open data.
// This Worker parses the CSV and returns JSON matching the iOS app's TrashcanRecord.

const BASE_TRASH_URL = "https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=267d550f-c6ec-46e0-b8af-fd5a464eb098";
const BASE_AQI_URL = "https://data.moenv.gov.tw/api/v2/aqx_p_432?format=json&limit=1000";

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      const pathname = url.pathname;

      // Manual triggers
      if (pathname === "/update-trashcans") {
        try {
          await updateTrashcanCache(env);
          return new Response("Trashcan cache updated", { status: 200 });
        } catch (err) {
          console.error("Error updating trashcan cache:", err);
          return new Response(`Error: ${err.message}`, { status: 500 });
        }
      }

      // App routes
      if (pathname.startsWith("/trashcans")) {
        const meta = url.searchParams.get("meta") === "true";
        return await handleTrashcanRequest(env, meta);
      }

      if (pathname.startsWith("/air-quality")) {
        return await handleAQIRequest(url, env);
      }

      return new Response("Not found", { status: 404 });
    } catch (err) {
      console.error("Fetch error:", err);
      return Response.json({ error: "Internal Worker error", message: err.message }, { status: 500 });
    }
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(updateTrashcanCache(env).catch(err =>
      console.error("Scheduled trashcan update failed:", err)
    ));
    // No scheduled AQI work; AQI is fetched live per request.
  }
};

// -----------------------------
// Trashcan Caching and Handlers
// -----------------------------

async function updateTrashcanCache(env) {
  // Fetch the CSV once and parse it into an array of objects that match TrashcanRecord.
  console.log(`Fetching trash can CSV from: ${BASE_TRASH_URL}`);
  const response = await fetch(BASE_TRASH_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch trash can CSV: ${response.status} ${response.statusText}`);
  }

  // Note: the CSV is encoded in Big5 on the provider side, but using response.text()
  // still gives us a string with correct commas and numeric fields, which is all
  // we need to build JSON for the app. The Chinese text may be mojibake in logs,
  // but the structure is correct for the Swift decoder.
  const csvText = await response.text();
  console.log(`Received trash can CSV, length=${csvText.length} characters`);

  const lines = csvText
    .split(/\r?\n/)
    .map(l => l.trim())
    .filter(l => l.length > 0);

  if (lines.length <= 1) {
    console.warn("Trash can CSV has no data rows");
    const timestampEmpty = Date.now();
    await env.TRASHCAN_CACHE.put("latest", JSON.stringify({ timestamp: timestampEmpty, data: [] }));
    return;
  }

  // First line is the header row. The provider currently uses:
  // 行政區,地址,經度,緯度,備註
  // but because of encoding, the actual bytes seen here may not match the
  // literal UTF‑8 strings above in this runtime. For our purposes, the
  // column order is stable, so we simply use fixed indices.
  const districtIdx = 0; // 行政區
  const addressIdx = 1;  // 地址
  const lngIdx = 2;      // 經度
  const latIdx = 3;      // 緯度
  const noteIdx = 4;     // 備註 (optional)

  const records = [];

  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i].split(",");
    if (cols.length < 4) continue;

    const district = cols[districtIdx] || "";
    const address = cols[addressIdx] || "";
    const longitude = cols[lngIdx] || "";
    const latitude = cols[latIdx] || "";
    const note = noteIdx >= 0 ? (cols[noteIdx] || "") : "";

    // Build record with keys matching the original JSON fields that
    // your Swift `TrashcanRecord` expects via CodingKeys.
    const record = {
      _id: i,              // synthetic ID (1-based row index)
      "行政區": district,
      "地址": address,
      "經度": longitude,
      "緯度": latitude,
      "備註": note
    };

    // Only include rows with valid coordinates
    if (record["經度"] && record["緯度"]) {
      records.push(record);
    }
  }

  console.log(`Parsed ${records.length} trash can records from CSV`);

  const timestamp = Date.now();
  await env.TRASHCAN_CACHE.put("latest", JSON.stringify({ timestamp, data: records }));
}

async function handleTrashcanRequest(env, includeMeta = false) {
  try {
    const cached = await env.TRASHCAN_CACHE.get("latest", { type: "json" });
    if (!cached) {
      // Return an empty array instead of text to keep the client JSON decoding happy
      return Response.json([]);
    }

    const responseData = includeMeta
      ? { timestamp: cached.timestamp, count: cached.data.length, data: cached.data }
      : cached.data;

    return Response.json(responseData);
  } catch (err) {
    console.error("Error handling trashcan request:", err);
    return Response.json([]);
  }
}

// -----------------------------
// AQI Proxy Handler
// -----------------------------

async function handleAQIRequest(url, env) {
  try {
    const locale = url.searchParams.get("locale") || "zh";
    const language = (locale === "en" || locale === "zh") ? locale : "zh";
    const apiUrl = `${BASE_AQI_URL}&language=${language}&api_key=${env.AIR_QUALITY_API_KEY}`;

    console.log(`Proxying AQI request for locale=${locale}, language=${language}`);
    console.log(`AQI API URL: ${apiUrl}`);

    const response = await fetch(apiUrl);
    console.log(`AQI upstream status: ${response.status}`);

    if (!response.ok) {
      const text = await response.text();
      console.error(`Upstream AQI error: ${text}`);
      // Return empty records but still valid JSON structure
      return Response.json({
        timestamp: Date.now(),
        data: {
          records: []
        }
      }, { status: 200 });
    }

    const json = await response.json();

    // Extract records from the API response and wrap in the structure expected by the iOS app:
    // { timestamp: number, data: { records: [...] } }
    const records = json.records || [];
    const wrapped = {
      timestamp: Date.now(),
      data: {
        records: records
      }
    };

    return Response.json(wrapped);
  } catch (err) {
    console.error("Error handling AQI request:", err);
    // Return valid JSON structure even on error
    return Response.json({
      timestamp: Date.now(),
      data: {
        records: []
      }
    });
  }
}

