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

                Canvas { context, size in
                    let cellW = size.width  / CGFloat(grid.width)
                    let cellH = size.height / CGFloat(grid.height)

                    for row in 0..<grid.height {
                        for col in 0..<grid.width {
                            let val = grid.values[row][col]

                            let color: Color
                            if val == -1 {
                                color = .gray
                            } else {
                                let normalized = Double(val / grid.maxDepth)
                                    .clamped(to: 0...1)
                                color = Color(
                                    hue: (1.0 - normalized) * 0.66,
                                    saturation: 0.9,
                                    brightness: 0.9
                                )
                            }

                            context.fill(Path(CGRect(
                                x: CGFloat(col) * cellW,
                                y: CGFloat(row) * cellH,
                                width: cellW,
                                height: cellH
                            )), with: .color(color))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(grid.width) / CGFloat(grid.height), contentMode: .fit)
                .rotationEffect(.degrees(90)) 
                .cornerRadius(12)
                .padding(.horizontal)

                Text("Grid: \(grid.width) × \(grid.height)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

            } else {
                // Show placeholder until a button is pressed
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(256.0 / 192.0, contentMode: .fit)
                    .padding(.horizontal)
                    .overlay(Text("Press Start or Mock to capture")
                        .foregroundColor(.secondary)
                        .font(.caption))
            }

            // Buttons
            HStack(spacing: 12) {
                Button(manager.isRunning ? "Stop" : "Start") {
                    manager.isRunning ? manager.stop() : manager.start()
                }
                .buttonStyle(.borderedProminent)

                Button("Mock") {
                    manager.startMock()
                }
                .buttonStyle(.bordered)
            }
        }
        // ← onAppear removed, nothing auto-starts
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    Depth_Map()
}
