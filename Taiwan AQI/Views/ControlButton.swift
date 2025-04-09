//
//  ControlButtonView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/9.
//

import SwiftUI

struct ControlButton: View {
	var iconName: String
	var fontSize: CGFloat
	var padding: CGFloat
	
    var body: some View {
        Image(systemName: iconName)
			.font(.system(size: fontSize))
			.padding(padding)
			.background(Circle().fill(Color(.secondarySystemBackground).opacity(0.6)))
			.frame(width: 44, height: 44)
    }
}

#Preview {
	ControlButton(iconName: "arrow.clockwise", fontSize: 12, padding: 12)
}
