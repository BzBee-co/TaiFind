//
//  make.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.
//

import SwiftUI

struct make: View {
    
    
    
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [.green, .green.opacity(0)]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 80 // Adjust this value to control how far the fade reaches
                )
            )
            .frame(width: 200 * 1, height: 200 * 1)
            .opacity(0.6)
    }
}

#Preview {
    make()
}
