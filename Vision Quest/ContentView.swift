//
//  Depth Map.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI

enum AppPage {
    case home
    case depthMap
    case objectDetection
    case directions
}

struct ContentView: View {
    @State private var currentPage: AppPage = .home
    
    var body: some View {
        ZStack {
            currentScreen
        }
        .animation(.easeInOut, value: currentPage)
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    handleSwipe(value)
                }
        )
    }
    
    @ViewBuilder
    private var currentScreen: some View {
        switch currentPage {
        case .home:
            HomeView()
        case .depthMap:
            Depth_Map()
        case .objectDetection:
            Object_Detection()
        case .directions:
            Directions()
        }
    }
    
    private func handleSwipe(_ value: DragGesture.Value) {
        // get vectors
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        // amount needed to swipe
        let horizontalThreshold: CGFloat = 50
        let verticalThreshold: CGFloat = 30
        
        // determine where to go based off currentPage and swipe
        if abs(horizontalAmount) > abs(verticalAmount) {
            if horizontalAmount < -horizontalThreshold {
                if currentPage == .home { currentPage = .objectDetection }
                else if currentPage == .depthMap { currentPage = .home }
            } else if horizontalAmount > horizontalThreshold {
                if currentPage == .home { currentPage = .depthMap }
                else if currentPage == .objectDetection { currentPage = .home }
            }
        } else {
            if verticalAmount < -verticalThreshold {
                if currentPage == .home { currentPage = .directions }
            } else if verticalAmount > verticalThreshold {
                if currentPage == .directions { currentPage = .home }
            }
        }
    }
    
    struct HomeView: View {
        var body: some View {
            VStack(spacing: 20) {
                Text("This is the Home Page!")
                    .font(.title)
                
                Text("Swipe right for Depth Map")
                Text("Swipe left for Object Detection")
                Text("Swipe up for Directions")
            }
        }
    }
}
//#Preview {
//    ContentView()
//}
