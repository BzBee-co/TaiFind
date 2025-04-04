//
//  make.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/4.
//

import SwiftUI

struct make: View {
	let values = [10, 20, 30, 40, 50]

	var body: some View {
		VStack {
			ForEach(values.indices, id: \.self) { index in
				Text("\(values[index])")
					.font(.caption)
					.foregroundStyle(Color("AccentColor"))
					.frame(maxWidth: .infinity, alignment: .bottomTrailing)
					.padding(.trailing, index == values.count - 1 ? 10 : 0) // Conditional padding
			}
		}
		.background(Color.gray) // Added background color for visual clarity
	}
}

#Preview {
    make()
}
