//
//  Directions.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI
import Foundation
import CoreLocation
import GoogleMaps

struct Directions: View {
    @StateObject private var dirFunc = DirectionsFuncts()
    @StateObject private var speech = SpeechFuncts()
    @State private var isListening = false
    @State private var navigationState: NavState = .idle
    


    // swipe feature
    enum NavState {
        case idle
        case searching
        case confirming
        case navigating
    }

    var body: some View {
        ZStack {
            
            // Map Layer
            if let mapView = dirFunc.mapView {
                GoogleMapView(mapView: mapView)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // UI Overlay
            VStack {
                Spacer()
                
                switch navigationState {
                    
                case .idle:
                    micButton
                    
                case .searching:
                    statusCard(icon: "magnifyingglass", message: "Searching...")
                    
                case .confirming:
                    swipeCard
                    
                case .navigating:
                    navigationCard
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            dirFunc.setupLocation()
            
            dirFunc.onResultReady = {
                isListening = false
                navigationState = .confirming
            }
            
            dirFunc.onNavigationStart = {
                isListening = false
                navigationState = .navigating
            }
            
            dirFunc.onNavigationEnd = {
                isListening = false
                navigationState = .idle
            }
        }
    }

    // Mic Button
    var micButton: some View {
        Button {
            isListening = true
            navigationState = .searching
            dirFunc.startListening()
        
        } label: {
            VStack(spacing: 12) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                Text("Tap & Speak")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 160, height: 160)
            .background(Color.blue.opacity(0.85))
            .clipShape(Circle())
            .shadow(radius: 10)
        }
        .accessibilityLabel("Tap to start voice search for a destination")
    }

    // MARK: Swipe Card (confirm/deny destination)
    var swipeCard: some View {
        VStack(spacing: 16) {
            Text("Swipe to respond")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 20) {
                // Decline
                swipeActionButton(
                    icon: "xmark",
                    label: "No",
                    color: .red
                ) {
                    dirFunc.userResponse("no")
                }

                // Accept
                swipeActionButton(
                    icon: "checkmark",
                    label: "Yes",
                    color: .green
                ) {
                    dirFunc.userResponse("yes")
                    navigationState = .navigating
                }
            }

            // Cancel option
            Button("Cancel") {
                dirFunc.userResponse("cancel")
                navigationState = .idle
                isListening = false
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))
            .padding(.top, 4)
        }
        .padding(24)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 50 {
                        // Swipe right = Yes
                        dirFunc.userResponse("yes")
                        navigationState = .navigating
                    } else if value.translation.width < -50 {
                        // Swipe left = No (next result)
                        dirFunc.userResponse("no")
                    }
                }
        )
        .accessibilityLabel("Swipe right to accept destination, swipe left for next result")
    }

    // MARK: Navigation Card
    var navigationCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.title2)
                .foregroundColor(.blue)

            Text("Navigating...")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                dirFunc.userResponse("cancel")
                navigationState = .idle
                isListening = false
            } label: {
                Text("End")
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.75))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: Status Card
    func statusCard(icon: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(14)
    }

    // MARK: Action Button helper
    func swipeActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                Text(label)
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(color.opacity(0.85))
            .clipShape(Circle())
            .shadow(radius: 6)
        }
        .accessibilityLabel("\(label) — \(label == "Yes" ? "accept this destination" : "show next result")")
    }
}

// MARK: GMSMapView wrapper
struct GoogleMapView: UIViewRepresentable {
    let mapView: GMSMapView

    func makeUIView(context: Context) -> GMSMapView { mapView }
    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

