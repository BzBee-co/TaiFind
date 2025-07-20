//
//  TrashCanListView.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2025/7/20.
//

import SwiftUI

struct TrashCanListView: View {
	@State var service = TrashCanService()

	var body: some View {
		List(service.trashCans) { can in
			VStack(alignment: .leading) {
				Text(can.name).bold()
				Text(can.address).font(.subheadline)
			}
		}
	}
}


#Preview {
    TrashCanListView()
}
