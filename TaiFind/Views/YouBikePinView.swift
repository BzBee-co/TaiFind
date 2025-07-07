//
//  YouBikePinView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/6/30.
//

import SwiftUI

struct YouBikePinView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	var count: Int? = nil
	
    var body: some View {
		VStack {
			ZStack {
				Image(systemName: "bubble.middle.bottom.fill")
					.resizable()
					.scaledToFit()
					.frame(width: 32, height: 32)
					.foregroundStyle(.indigo.gradient)
					.padding(6)
				if let count = count, count > 1 {
					Text("\(count)")
						.foregroundStyle(.white)
						.font(.caption)
						.fontWeight(.heavy)
						.fontDesign(.rounded)
						.offset(y: -2)
				} else {
					Image(systemName: "bicycle")
						.foregroundStyle(.white)
						.font(.caption)
						.fontWeight(.heavy)
						.fontDesign(.rounded)
						.offset(y: -3)
				}
			}
		}
    }
}

#Preview {
    YouBikePinView()
}
