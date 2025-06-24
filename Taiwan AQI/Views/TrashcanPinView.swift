//
//  TrashcanPinView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/6/22.
//

import SwiftUI

struct TrashcanPinView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	var count: Int? = nil

	var body: some View {
		VStack {
			ZStack {
				Image(systemName: "circle.fill")
					.resizable()
					.scaledToFit()
					.frame(width: 30, height: 30)
					.foregroundStyle(.gray)
					.padding(6)
				if let count = count, count > 1 {
					Text("\(count)")
						.foregroundStyle(.white)
						.font(.caption)
						.fontWeight(.heavy)
						.fontDesign(.rounded)
				} else {
				Image(systemName: "trash")
					.foregroundStyle(.white)
					.font(.caption)
					.fontWeight(.heavy)
					.fontDesign(.rounded)
			}
			}
			let triangleOffset: CGFloat = (count ?? 1) > 1 ? -18 : -14
			Image(systemName: "triangle.fill")
				.resizable()
				.scaledToFit()
				.foregroundStyle(.gray)
				.frame(width: 10, height: 10)
				.rotationEffect(.degrees(180))
				.offset(y: triangleOffset)
				.padding(.bottom, 40)
		}
		.frame(width: 40, height: 40)
		.offset(y: 10)
	}
}

#Preview {
    TrashcanPinView(count: 2)
}
