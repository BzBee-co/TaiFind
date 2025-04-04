//
//  AQILegend.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/4.
//

import SwiftUI

struct AQILegend: View {
	let colors: [Color] = [.blue, .green, .yellow, .orange, .red, .crimson]
	let values: [Int] = [25, 50, 75, 100, 150, 200]

	var body: some View {
		ZStack {
			// Colored blocks
			HStack(spacing: 0) {
				ForEach(colors, id: \.self) { color in
					Rectangle()
						.fill(color)
						.frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
				}
			}
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.frame(height: 20)

			// AQI Threshold Labels
			HStack {
				ForEach(values.indices, id: \.self) { index in
					Text("\(values[index])") // Use values[index]
						.font(.caption)
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity, alignment: .bottomTrailing)
						.padding(.trailing, index == values.count - 1 ? 5 : 0)
				}
			}
		}
		.padding(.horizontal, 20)
	}
}
#Preview {
    AQILegend()
}
