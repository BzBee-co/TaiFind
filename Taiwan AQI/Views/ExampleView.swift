//
//  ExampleView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI

struct ExampleView: View {
	var body: some View {
		VStack(spacing: 20) {
			LegendView(type: .no2)
		}
		.padding()
	}
}

#Preview {
    ExampleView()
}
