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
    case warningSystem
}

struct ContentView: View {
    @State private var currentPage: AppPage = .home
    @StateObject private var dirFunc = DirectionsFuncts()
    @EnvironmentObject var lidarManager : DepthCameraManager

    var body: some View {
        
        ZStack {
            currentScreen

            if currentPage == .home {
                HomeOverlay(currentPage: $currentPage, dirFunc: dirFunc)
            }
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
            WarningSystemView(lidarManager: lidarManager)
        case .objectDetection:
            WarningSystemView(lidarManager: lidarManager)
        case .directions:
            Directions(dirFunc: dirFunc, currentPage: $currentPage)
        case .warningSystem:
            WarningSystemView(lidarManager: lidarManager)
        }
        
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        let horizontalThreshold: CGFloat = 50
        let verticalThreshold: CGFloat = 30
        
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
        @Binding var currentPage: AppPage
        @ObservedObject var dirFunc: DirectionsFuncts

        @State private var pulsing = false
        @State private var isHoldingMic = false
        @State private var micScale: CGFloat = 2.9
        @State private var ringScale: CGFloat = 1.0

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
                            .scaleEffect(x: -1)
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
                    VStack(spacing: 24) {
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
                            .padding(.bottom , 128)

                        // MARK: — Hold-to-Record Mic Button
                        ZStack {
                            // Pulsing glow ring while recording
                            Circle()
                                .stroke(Color.blue.opacity(isHoldingMic ? 0.45 : 0), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .scaleEffect(ringScale)

                            // Button body
                            Circle()
                                .fill(
                                    isHoldingMic
                                        ? Color.blue.opacity(0.9)
                                        : Color(.systemGray4).opacity(0.85)
                                )
                                .frame(width: 72, height: 72)
                                .shadow(
                                    color: isHoldingMic
                                        ? Color.blue.opacity(0.55)
                                        : Color.black.opacity(0.2),
                                    radius: isHoldingMic ? 18 : 12
                                )
                                .scaleEffect(micScale)

                            Image(systemName: isHoldingMic ? "mic.fill" : "mic")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(isHoldingMic ? .white : .primary)
                                .scaleEffect(micScale)
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: micScale)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    guard !isHoldingMic else { return }
                                    beginListening()
                                }
                                .onEnded { _ in
                                    guard isHoldingMic else { return }
                                    finishListeningAndNavigate()
                                }
                        )
                        .accessibilityLabel("Hold to speak a destination, release to navigate")

                        Text(isHoldingMic ? "Listening…" : "Hold for directions")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(isHoldingMic ? .blue : Color(.secondaryLabel))
                            .animation(.easeInOut(duration: 0.2), value: isHoldingMic)
                            
                    }
                    .position(x: w / 2, y: h / 2)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
                // set up location when user presses mic
                dirFunc.setupLocation()
            }
        }

        // MARK: — Mic helpers

        private func beginListening() {
            isHoldingMic = true
            micScale = 2.0

            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                ringScale = 2.2
            }
            
            // voice commands start
            dirFunc.startListening()
        }

        private func finishListeningAndNavigate() {
            isHoldingMic = false
            micScale = 1.0
            // Resetting ringScale stops the repeating animation on its next cycle
            withAnimation(.default) { ringScale = 1.0 }

            // Switch to Directions 
            currentPage = .directions
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
