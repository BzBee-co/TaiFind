# TaiFind

**TaiFind** is an iPhone app that puts Taiwan’s official air quality on a map—along with optional layers for YouBike availability and public trash can locations—so you can see conditions where you actually are, not just in a generic weather widget.

The project started from a simple observation: the stock iOS weather experience does not surface Taiwan AQI the way many residents and visitors expect. TaiFind closes that gap using government open data and a map-first interface.

## What it does

- **Air quality map** — Plots monitoring stations across Taiwan with live-style readings aligned with Taiwan’s Ministry of Environment standards (AQI scale 0–500). Pick **AQI** or individual pollutants (**SO₂**, **CO**, **O₃**, **PM₁₀**, **PM₂.₅**, **NO₂**), switch between **pin** and **heatmap** views, and open any station for a detail sheet with pollutant breakdown, status, and last update time.
- **YouBike (Taipei & Taichung)** — Optional map layers show **YouBike 2.0** stations with availability (bikes to rent and empty docks). Data comes from Taipei’s public feed and Taichung’s open data API. Selecting a layer recenters the map on the chosen city.
- **Public trash cans (Taipei)** — Optional layer to help locate **public trash cans** in Taipei; pins are clustered for clarity and filtered by proximity to the current map view for performance.

The app uses **MapKit** (standard, satellite, or hybrid), **location when in use** to recenter on you, and includes an **Information** screen that explains AQI tiers, pollutants, data licenses, and disclaimers.

**Languages:** English and Traditional Chinese (`Localizable.xcstrings`), including locale-aware labels for air quality content where the backend supports it.

## How it is built

| Area | Details |
|------|---------|
| UI | SwiftUI; main surface is `MapView` with overlays (`LegendView`, floating controls). |
| State | `AQIViewModel` holds AQI records, optional trash/YouBike datasets, map region, and loading flags. |
| Location | `LocationManager` wraps `CLLocationManager` (when-in-use authorization, movement threshold before updating). |
| Networking | `APIService` uses `URLSession` for AQI (via a small proxy service), YouBike JSON endpoints, trash cans (worker first, Taipei open data fallback). |
| Models | `AQIRecord` for stations; decoding helpers for Taipei trash cans and both YouBike formats live alongside `APIService`. |

**Requirements:** Xcode project targets **iOS 17.6** (see `TaiFind.xcodeproj`). Product name / display name: **TaiFind** (`INFOPLIST_KEY_CFBundleDisplayName`).

## Repository layout

- `TaiFind/` — Swift sources (`Views/`, `ViewModels/`, `API/`, `Models/`, `Helpers/`), assets, `Localizable.xcstrings`, entitlements.
- `TaiFind.xcodeproj/` — Xcode project and shared scheme.
- `worker.js` — Backend/proxy logic for deployed services (not required to read the app shell).

## Building

1. Open `TaiFind.xcodeproj` in Xcode.
2. Select the **TaiFind** scheme and a simulator or device.
3. Build and run (**⌘R**).

Location features require a simulator or device with location services enabled; grant **When In Use** permission when prompted.

## Data & attribution

TaiFind aggregates **public datasets** (Taiwan EPA / Ministry of Environment air quality, Taipei and Taichung open data, YouBike feeds). The in-app Information screen links to official portals and states the **Open Government Data License** context. Data is provided as-is; the app disclaims guarantees of accuracy or timeliness.

## Credits

Developed by **BzBee** (Taipei). Contact and branding appear in the app’s Information section (`bzbee.co`).

---

*Internal note: some source filenames and the app entry file still use legacy “Taiwan AQI” naming; the shipped product name is TaiFind.*
