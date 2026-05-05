//
//  Warning System View.swift
//  Vision Quest
//
//  Created by Patrick Smith on 5/4/26.
//

import Foundation
import SwiftUI

struct WarningSystemView: View {
    @EnvironmentObject private var lidarManager: DepthCameraManager
    @StateObject private var warningSystem: WarningSystem
    
    init(lidarManager: DepthCameraManager) {
        _warningSystem = StateObject(wrappedValue: WarningSystem(lidarManager: lidarManager))
    }

    var body: some View {
        Button(action: {
            if !warningSystem.running {
                warningSystem.startWarningSystem()
            } else {
                warningSystem.stopWarningSystem()
            }
        }) {
            ZStack {
                (warningSystem.running ? Color.black : Color.green)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: warningSystem.running ? "ear.fill" : "ear.slash.fill")
                        .font(.system(size: 80))
                        .foregroundColor(warningSystem.running ? .green : .white)

                    Text(warningSystem.running ? "Warning System Active" : "Tap to Start")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if !warningSystem.spokenMessage.isEmpty {
                        Text(warningSystem.spokenMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    Spacer()

                    if warningSystem.running {
                        Text("Tap anywhere to stop")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .onDisappear {
            warningSystem.stopWarningSystem()
        }
    }
}
