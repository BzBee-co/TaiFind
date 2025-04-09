//
//  PinView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/9.
//

import SwiftUI

struct PinView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	let color: Color
	let value: String // Display the AQI or pollutant value

	var body: some View {
		VStack {
			ZStack {
				Image(systemName: "circle.fill")
					.resizable()
					.scaledToFit()
					.frame(width: 30, height: 30)
					.foregroundStyle(color)
					.padding(6)
				Text(value)
					.foregroundStyle(.white)
					.font(.caption)
					.fontWeight(.heavy)
					.fontDesign(.rounded)
			}
			
			Image(systemName: "triangle.fill")
				.resizable()
				.scaledToFit()
				.foregroundStyle(color)
				.frame(width: 10, height: 10)
				.rotationEffect(.degrees(180))
				.offset(y: -18)
				.padding(.bottom, 40)
		}
		.frame(width: 40, height: 40)
		.offset(y: 10)
	}
}

#Preview {
	PinView(color: .green, value: "35")
}
