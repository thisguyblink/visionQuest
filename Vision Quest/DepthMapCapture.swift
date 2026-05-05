import Foundation
import ARKit
import SwiftUI


struct DepthGrid {          // <-- top level, NOT inside any class
    let values: [[Float]]
    let width: Int
    let height: Int
    let maxDepth: Float
    let minDepth: Float
}

class DepthCameraManager: NSObject, ARSessionDelegate, ObservableObject  {
    
    let session = ARSession()
        
        @Published var latestDepthGrid: DepthGrid
        @Published var isRunning = false
        
        override init() {
            super.init()
            session.delegate = self
        }
    
    func start() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("❌ Scene depth not supported")
            return
        }
        print("✅ Starting ARSession")
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth
        session.run(config)
        isRunning = true
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            print("❌ No depth data in frame")
            return
        }
        
        let grid = buildGrid(from: depth.depthMap, confidence: depth.confidenceMap)
        DispatchQueue.main.async {
            self.latestDepthGrid = grid
        }
    }
    
    func startMock() {
        latestDepthGrid = buildMockGrid()
        isRunning = true
    }
    
    func stop() {
            session.pause()
            isRunning = false
        }
    
    
    private func buildGrid(from depthBuffer: CVPixelBuffer,
                               confidence confidenceBuffer: CVPixelBuffer?) -> DepthGrid {
            
            CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }
            
            // Lock confidence map if present
            if let conf = confidenceBuffer {
                CVPixelBufferLockBaseAddress(conf, .readOnly)
            }
            defer {
                if let conf = confidenceBuffer {
                    CVPixelBufferUnlockBaseAddress(conf, .readOnly)
                }
            }
            
            let width  = CVPixelBufferGetWidth(depthBuffer)
            let height = CVPixelBufferGetHeight(depthBuffer)
            
            guard let depthBase = CVPixelBufferGetBaseAddress(depthBuffer) else {
                return DepthGrid(values: [], width: 0, height: 0,
                                 maxDepth: Float.greatestFiniteMagnitude, minDepth: 0.0)
            }
            
            let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)
            
            // Confidence pointer — ARConfidenceLevel: 0=low, 1=medium, 2=high
            let confPointer: UnsafeMutablePointer<UInt8>?
            if let conf = confidenceBuffer,
               let base = CVPixelBufferGetBaseAddress(conf) {
                confPointer = base.assumingMemoryBound(to: UInt8.self)
            } else {
                confPointer = nil
            }
            
            var grid = Array(repeating: Array(repeating: Float(0), count: width),
                             count: height)
        var MaxDepth: Float  = 0.0
        var MinDepth: Float = Float.greatestFiniteMagnitude
            for row in 0..<height {
                for col in 0..<width {
                    let index = row * width + col
                    
                    // Skip low-confidence readings if confidence map exists
                    if let conf = confPointer, conf[index] == 0 {
                        grid[row][col] = -1  // sentinel for "unreliable"
                        continue
                    }
                    if depthPointer[index] > MaxDepth {
                        MaxDepth = depthPointer[index]
                    } else if depthPointer[index] < MinDepth {
                        MinDepth = depthPointer[index]
                    }
                    grid[row][col] = depthPointer[index]
                }
            }
        
        var rotated = Array(repeating: Array(repeating: Float(0), count: height), count: width)
           for row in 0..<height {
               for col in 0..<width {
                   rotated[col][height - 1 - row] = grid[row][col]
               }
           }
        
            // need to flip height and width since the data shape is orginally landscape and needs to be vertical to match the input
            return DepthGrid(values: rotated, width: height, height: width, maxDepth: MaxDepth, minDepth: MinDepth)
        }

    
    func buildMockGrid() -> DepthGrid {
        let width = 192
        let height = 256
        var grid = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        
        var maxDepth: Float = 0
        var minDepth: Float = Float.greatestFiniteMagnitude
        
        for row in 0..<height {
            for col in 0..<width {
                // Simulate a scene — close object in center, farther at edges
                let centerX = Float(width) / 2
                let centerY = Float(height) / 2
                let dx = (Float(col) - centerX) / centerX
                let dy = (Float(row) - centerY) / centerY
                let distance = sqrt(dx * dx + dy * dy)  // 0 = center, ~1.4 = corner
                
                // Map to realistic depth range: 0.5m to 5.0m
                let depth = 0.5 + distance * 3.2
                
                grid[row][col] = depth
                if depth > maxDepth { maxDepth = depth }
                if depth < minDepth { minDepth = depth }
            }
        }
        
        return DepthGrid(values: grid, width: width, height: height,
                         maxDepth: maxDepth, minDepth: minDepth)
    }
        
}
