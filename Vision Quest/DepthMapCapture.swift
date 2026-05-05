import Foundation
import ARKit
import SwiftUI
import UIKit
import Photos


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
    
        
        private var isProcessingFrame: Bool = false
        private let processingQueue = DispatchQueue(label: "depth.processing", qos: .userInitiated)
    
        private(set) var latestColorBuffer: CVPixelBuffer?
        
        
    override init() {
        self.latestDepthGrid = DepthGrid(values: [], width: 0, height: 0, maxDepth: 0, minDepth: 0)
        super.init()
        session.delegate = self
        self.latestDepthGrid = buildMockGrid()  // replace with mock after init

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
        frameCount += 1 
        guard frameCount % 5 == 0 else { return }
        isProcessingFrame = true
        let startTime = CACurrentMediaTime()
        let colorBuffer    = frame.capturedImage
        latestColorBuffer = colorBuffer
        let depthMap       = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap
        let confidenceMap  = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.confidenceMap
        guard depthMap != nil else {
                print("❌ No depth map in frame \(frameCount)")
                isProcessingFrame = false
                return
            }
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Run object detection on color frame
            self.objectDetection.runVisionRequest(on: colorBuffer)

            // Build depth grid if available
            if let depthMap = depthMap {
                let grid = self.buildGrid(from: depthMap, confidence: confidenceMap)
                DispatchQueue.main.async {
                    self.latestDepthGrid = grid
                }
            }
            let elapsed = CACurrentMediaTime() - startTime
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
    
    func exportSnapshot(depthGrid: DepthGrid) {
        guard let colorBuffer = latestColorBuffer else {
            print("❌ No color frame available")
            return
        }
        
        // Convert color buffer to UIImage
        let ciImage = CIImage(cvPixelBuffer: colorBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ Could not create CGImage")
            return
        }
        let colorImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        // Convert depth grid to UIImage
        let depthImage = renderDepthGrid(depthGrid)
        
        // Save both to photo library
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("❌ Photo library access denied")
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: colorImage)
                PHAssetChangeRequest.creationRequestForAsset(from: depthImage)
            } completionHandler: { success, error in
                if success {
                    print("✅ Exported color + depth images")
                } else if let error = error {
                    print("❌ Export error: \(error)")
                }
            }
        }
    }

    private func renderDepthGrid(_ grid: DepthGrid) -> UIImage {
        let width  = grid.width
        let height = grid.height
        let size   = CGSize(width: width, height: height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        for row in 0..<height {
            for col in 0..<width {
                let val = grid.values[row][col]
                let color: UIColor
                if val == -1 {
                    color = .gray
                } else {
                    let normalized = min(max(CGFloat(val / grid.maxDepth), 0.0), 1.0)
                    color = UIColor(hue: (1.0 - normalized) * 0.66,
                                    saturation: 0.9,
                                    brightness: 0.9,
                                    alpha: 1.0)
                }
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: col, y: row, width: 1, height: 1))
            }
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
        
}
