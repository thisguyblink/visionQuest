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
        
        @Published var latestDepthGrid: DepthGrid?
        @Published var isRunning = false
        
        override init() {
            super.init()
            session.delegate = self
        }
    
    func start() {
           guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
               print("Scene depth not supported on this device")
               return
           }
           
           let config = ARWorldTrackingConfiguration()
           config.frameSemantics = .sceneDepth  // enables depth + confidence
           session.run(config)
           isRunning = true
       }
    
    func stop() {
            session.pause()
            isRunning = false
        }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
           // Use smoothed depth if available — less noise
           guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
           
           let grid = buildGrid(from: depth.depthMap, confidence: depth.confidenceMap)
           
           DispatchQueue.main.async {
               self.latestDepthGrid = grid
           }
       }
    
    func mockSession(_ session: ARSession, didUpdate frame: ARFrame) {
           // Use smoothed depth if available — less noise
           guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
           
           let grid = buildGrid(from: depth.depthMap, confidence: depth.confidenceMap)
           
           DispatchQueue.main.async {
               self.latestDepthGrid = grid
           }
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
            
            return DepthGrid(values: grid, width: width, height: height, maxDepth: MaxDepth, minDepth: MinDepth)
        }
        
}
