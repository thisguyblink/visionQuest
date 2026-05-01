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
            
            if currentPage == .home {HomeOverlay()}
            
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
    
    // MARK: - Home Overlay

    struct HomeOverlay: View {
        @State private var pulsing = false

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let sideRadius: CGFloat = 200
                let bottomRadius: CGFloat = 200

                ZStack {
                    // Left edge — Depth Map (blue)
                    ZStack {
                        SemicircleShape()
                            .fill(Color(red: 0.22, green: 0.44, blue: 0.95))
                            .shadow(color: Color(red: 0.22, green: 0.44, blue: 0.95).opacity(0.5), radius: 12)
                            .scaleEffect(x: -1) // flip to face right
                        Image(systemName: "arrow.left")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.white)
                            .offset(x: 28)
                    }
                    .frame(width: sideRadius, height: sideRadius * 2)
                    .offset(x: pulsing ? -8 : 0)
                    .position(x: 0, y: h / 2)
                    .accessibilityLabel("Swipe left for Depth Map")

                    // Right edge — Object Detection (red)
                    ZStack {
                        SemicircleShape()
                            .fill(Color(red: 0.95, green: 0.25, blue: 0.25))
                            .shadow(color: Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.5), radius: 12)
                            .scaleEffect(x: 1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.white)
                            .offset(x: -28)
                    }
                    .frame(width: sideRadius, height: sideRadius * 2)
                    .offset(x: pulsing ? 8 : 0)
                    .position(x: w, y: h / 2)
                    .accessibilityLabel("Swipe right for Object Detection")

                    // Bottom edge — Directions (green)
                    ZStack {
                        BottomSemicircleShape()
                            .fill(Color(red: 0.1, green: 0.78, blue: 0.35))
                            .shadow(color: Color(red: 0.1, green: 0.78, blue: 0.35).opacity(0.5), radius: 12)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.white)
                            .offset(y: -28)
                    }
                    .frame(width: bottomRadius * 2, height: bottomRadius)
                    .offset(y: pulsing ? 8 : 0)
                    .position(x: w / 2, y: h)
                    .accessibilityLabel("Swipe up for Directions")

                    // Center content
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 110, height: 110)
                            .overlay(
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray)
                            )

                        Text("VisionQuest")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .position(x: w / 2, y: h / 2)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
        }
    }

    // MARK: - Shapes

    struct SemicircleShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.midY),
                radius: rect.height / 2,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.closeSubpath()
            return path
        }
    }

    struct BottomSemicircleShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.maxY),
                radius: rect.width / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.closeSubpath()
            return path
        }
    }

    struct HomeView: View {
        var body: some View {
            Color(.systemBackground).ignoresSafeArea()
        }
    }
}
