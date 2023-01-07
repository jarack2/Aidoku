//
//  TrackerAddView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 7/20/22.
//

import SwiftUI

struct TrackerAddView: View {

    let tracker: Tracker
    let manga: Manga
    @Binding var refresh: Bool

    @State var isLoading = false
    @State var showSearchController = false
    
  

    var body: some View {

        HStack {
            ZStack {
                HStack {
                Image(uiImage: tracker.icon ?? UIImage(named: "MangaPlaceholder")!)
                    .resizable()
                    .frame(width: 44, height: 44, alignment: .leading)
                    .cornerRadius(10)
                    Spacer()
                }
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                else {
                    Button(NSLocalizedString("START_TRACKING", comment: "")) {
                        Task {
                            let sources = await tracker.search(for: manga)
                            if sources.count == 1 {
                                TrackerManager.shared.track(result: sources[0], manga: manga, tracker: tracker)
                            }
                            else {
                                showSearchController.toggle()
                            }
                        }
                        
                    }
                }
            }
        }
        .padding([.top, .horizontal])
        .sheet(isPresented: $showSearchController, content: {
            TrackerSearchNavigationController(tracker: tracker, manga: manga)
        })
    }
}
