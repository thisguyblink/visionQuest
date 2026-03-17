import SwiftUI

struct Depth_Map: View {
    
    @StateObject private var manager = DepthCameraManager()
        
        var body: some View {
            VStack(spacing: 16) {
                if let grid = manager.latestDepthGrid {
                    
                    HStack {
                        Label(String(format: "%.2fm", grid.minDepth), systemImage: "arrow.down")
                        Spacer()
                        Label(String(format: "%.2fm", grid.maxDepth), systemImage: "arrow.up")
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    let step = 16
                    let rows = grid.height / step
                    let cols = grid.width / step
                    VStack(spacing: 1) {
                                ForEach(0..<rows, id: \.self) { row in
                                    HStack(spacing: 1) {
                                        ForEach(0..<cols, id: \.self) { col in
                                            Rectangle()
                                                .fill(Color.blue.opacity(
                                                                        Double(grid.values[row * step][col * step] / grid.maxDepth)
                                                                    ))
                                                .frame(height: 30)
                                                .border(Color.gray.opacity(0.4), width: 0.5)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .padding()
                    
                    Text("Grid: \(grid.width) × \(grid.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                } else {
                    ProgressView("Waiting for depth data...")
                }
                
                Button(manager.isRunning ? "Stop" : "Start") {
                    manager.isRunning ? manager.stop() : manager.start()
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear { manager.start() }
        }
}

#Preview {
    Depth_Map()
}
