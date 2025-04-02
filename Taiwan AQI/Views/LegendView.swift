//
//  LegendView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/1.
//

import SwiftUI

struct LegendView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .frame(width: 200, height: 20)
    }
}

#Preview {
    LegendView()
}


//case 0..<25: return Color.blue
//case 25..<50: return Color.green
//case 50..<75: return Color.yellow
//case 75..<100: return Color.orange
//case 100..<150: return Color.red
//case 150..<200: return Color.purple
