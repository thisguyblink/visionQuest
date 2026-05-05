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
        VStack(spacing: 20) {
            Text("Vision Quest - Warning System")
                .font(.title2)

            Button(action: {
                if !warningSystem.running {
                    warningSystem.startWarningSystem()
                } else {
                    warningSystem.stopWarningSystem()
                }
            }) {
                Text(warningSystem.running ? "Stop Warning" : "Start Warning")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(warningSystem.running ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            if warningSystem.running {
                Text("Warning System is running...")
                    .foregroundColor(.blue)
            } else {
                Text("Warning System is stopped.")
                    .foregroundColor(.gray)
            }

            if !warningSystem.spokenMessage.isEmpty {
                Text(warningSystem.spokenMessage)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .opacity(0.8)
            }

            Spacer()
        }
        .padding()
        .onDisappear {
            warningSystem.stopWarningSystem()
        }
    }
}
