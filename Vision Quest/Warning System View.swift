//
//  Warning System View.swift
//  Vision Quest
//
//  Created by Patrick Smith on 5/4/26.
//

import Foundation

import SwiftUI


struct WarningSystemView : View {
    @StateObject private var warningSystem = WarningSystem()
    @State private var isRunning = false
    @State private var spokenMessage = ""
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Vision Quest - Warning System")
                    .font(.title2)
                
                Button(action: {
                    if !isRunning {
                        warningSystem.startWarningSystem()
                        isRunning = true
                    } else {
                        warningSystem.stopWarningSystem()
                        isRunning = false
                    }
                }) {
                    Text(isRunning ? "Stop Warning" : "Start Warning")
                        .padding()
                        .background(isRunning ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                if isRunning {
                    Text("Warning System is running...")
                        .foregroundColor(.blue)
                } else {
                    Text("Warning System is stopped.")
                        .foregroundColor(.gray)
                }
                if !warningSystem.spokenMessage.isEmpty {
                    Text(warningSystem.spokenMessage)
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .opacity(0.8) // Slightly transparent to indicate it's a temporary message
                }

            }
            .padding()
        }

}
