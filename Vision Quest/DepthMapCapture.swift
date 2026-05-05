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
        lazy var objectDetection = ObjectDetectionViewModel(session: session, visual: false)
        private var frameCount = 0
        private var totalProcessingTime: Double = 0
        
        @Published var latestDepthGrid: DepthGrid
        @Published var isRunning = false
    
        private var visionRequests = [VNRequest]()
        private var isProcessingFrame: Bool = false
        private let processingQueue = DispatchQueue(label: "depth.processing", qos: .userInitiated)
        
        
    override init() {
        self.latestDepthGrid = DepthGrid(values: [], width: 0, height: 0, maxDepth: 0, minDepth: 0)
        super.init()
        session.delegate = self
        self.latestDepthGrid = buildMockGrid()  // replace with mock after init
        print("DEBUG [DepthCameraManager]: init — \(Thread.callStackSymbols.prefix(6).joined(separator: "\n"))")

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
        print("DEBUG [DepthCameraManager]: start() called — \(Thread.callStackSymbols.prefix(6).joined(separator: "\n"))")

    }
    
    func setupVisionRequest(with requests: [VNRequest]) {
           visionRequests = requests
       }
       
    private func runVisionRequest(on pixelBuffer: CVPixelBuffer) {
           guard !visionRequests.isEmpty else { return }
           let handler = VNImageRequestHandler(
               cvPixelBuffer: pixelBuffer,
               orientation: .right,  // ARKit frames are landscape
               options: [:]
           )
           do {
               try handler.perform(visionRequests)
           } catch {
               print("❌ Vision error: \(error)")
           }
       }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if frameCount % 5 != 0 {
            return
        }
        isProcessingFrame = true
        let startTime = CACurrentMediaTime()
        let colorBuffer    = frame.capturedImage
        let depthMap       = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap
        let confidenceMap  = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.confidenceMap

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Run object detection on color frame
            self.runVisionRequest(on: colorBuffer)

            // Build depth grid if available
            if let depthMap = depthMap {
                let grid = self.buildGrid(from: depthMap, confidence: confidenceMap)
                DispatchQueue.main.async {
                    self.latestDepthGrid = grid
                }
            }
            let elapsed = CACurrentMediaTime() - startTime
                    self.frameCount += 1
                    self.totalProcessingTime += elapsed
                    let average = self.totalProcessingTime / Double(self.frameCount)

                    print(String(format: "⏱ Frame %d: %.1fms | avg: %.1fms",
                                 self.frameCount,
                                 elapsed * 1000,
                                 average * 1000))
            self.isProcessingFrame = false
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
