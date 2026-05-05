//
//  Object Detection.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI
import Vision
import ARKit
import CoreML

// MARK: - ViewModel

class ObjectDetectionViewModel: NSObject, ObservableObject, ARSessionDelegate {
    
    private let session: ARSession
    let detectionOverlay = CALayer()
    var bufferSize: CGSize = CGSize(width: 1920, height: 1440) // ARKit default
    var objectDetectionDataList = [ObjectDetectionData]()
    
    private var requests = [VNRequest]()
    private var isProcessingFrame = false
    private let processingQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
    
    init(session: ARSession, visual: Bool) {
        self.session = session
        super.init()
        session.delegate = self
        setupVisionRequest(visual: visual)
//        startARSession() session is owned by depth map capture 
    }
    
    // MARK: - Setup
    
    private func startARSession() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("DEBUG: sceneDepth not supported, running without depth")
            let config = ARWorldTrackingConfiguration()
            session.run(config)
            return
        }
        let config = ARWorldTrackingConfiguration()
        session.run(config)
    }
    
    private func setupVisionRequest(visual: Bool) {
        do {
            let visionModel = try VNCoreMLModel(for: best().model)
            let objectRecognition = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                if let error = error {
                    print("DEBUG [VNCoreMLRequest]: error — \(error)")
                    return
                }
                DispatchQueue.main.async {
                    if let results = request.results {
                        if visual {
                            self?.drawVisionRequestResults(results)
                        } else {
                            self?.makeBoundaryBoxes(results)
                        }
                    }
                }
            }
            requests = [objectRecognition]
        } catch {
            print("DEBUG [setupVisionRequest]: FAILED — \(error)")
        }
    }
    
    // MARK: - ARSession Delegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true
        
        let colorBuffer = frame.capturedImage
        let width  = CVPixelBufferGetWidth(colorBuffer)
        let height = CVPixelBufferGetHeight(colorBuffer)
        bufferSize = CGSize(width: width, height: height)
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            let handler = VNImageRequestHandler(
                cvPixelBuffer: colorBuffer,
                orientation: .right,  // ARKit frames are landscape
                options: [:]
            )
            do {
                try handler.perform(self.requests)
            } catch {
                print("DEBUG [ARFrame]: vision error — \(error)")
            }
            self.isProcessingFrame = false
        }
    }
    
    // MARK: - Boundary Boxes (data only)
    
    private func makeBoundaryBoxes(_ results: [VNObservation]) {
        guard let observation = results.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else { return }
        
        let numDetections = multiArray.shape[1].intValue
        let confidenceThreshold: Float = 0.3
        objectDetectionDataList.removeAll()
        
        for i in 0..<numDetections {
            let confidence = multiArray[[0, i as NSNumber, 4]].floatValue
            guard confidence >= confidenceThreshold else { continue }
            
            let xCenter = multiArray[[0, i as NSNumber, 0]].floatValue
            let yCenter = multiArray[[0, i as NSNumber, 1]].floatValue
            let width   = multiArray[[0, i as NSNumber, 2]].floatValue
            let height  = multiArray[[0, i as NSNumber, 3]].floatValue
            let classId = Int(multiArray[[0, i as NSNumber, 5]].floatValue)
            let type    = classLabel(for: classId)
            
            let scaledRect = toScaledRect(xCenter: xCenter, yCenter: yCenter,
                                          width: width, height: height)
            
            objectDetectionDataList.append(ObjectDetectionData(
                topLeft:     CGPoint(x: scaledRect.minX, y: scaledRect.minY),
                topRight:    CGPoint(x: scaledRect.maxX, y: scaledRect.minY),
                bottomLeft:  CGPoint(x: scaledRect.minX, y: scaledRect.maxY),
                bottomRight: CGPoint(x: scaledRect.maxX, y: scaledRect.maxY),
                type:        type
            ))
        }
    }
    
    func getObjectDetectionDataList() -> [ObjectDetectionData] {
        return objectDetectionDataList
    }
    
    // MARK: - Drawing
    
    private func drawVisionRequestResults(_ results: [VNObservation]) {
        detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard let observation = results.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else { return }
        
        let numDetections = multiArray.shape[1].intValue
        let confidenceThreshold: Float = 0.3
        
        for i in 0..<numDetections {
            let confidence = multiArray[[0, i as NSNumber, 4]].floatValue
            guard confidence >= confidenceThreshold else { continue }
            
            let xCenter = multiArray[[0, i as NSNumber, 0]].floatValue
            let yCenter = multiArray[[0, i as NSNumber, 1]].floatValue
            let width   = multiArray[[0, i as NSNumber, 2]].floatValue
            let height  = multiArray[[0, i as NSNumber, 3]].floatValue
            let classId = Int(multiArray[[0, i as NSNumber, 5]].floatValue)
            let type    = classLabel(for: classId)
            
            let scaledRect = toScaledRect(xCenter: xCenter, yCenter: yCenter,
                                          width: width, height: height)
            
            let shapeLayer = createRoundedRectLayer(bounds: scaledRect)
            let textLayer  = createTextLayer(bounds: scaledRect,
                                             identifier: type,
                                             confidence: VNConfidence(confidence))
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
    }
    
    // MARK: - Helpers
    
    private func toScaledRect(xCenter: Float, yCenter: Float,
                               width: Float, height: Float) -> CGRect {
        let modelInputSize: CGFloat = 640.0
        let normalized = CGRect(
            x: CGFloat(xCenter - width / 2) / modelInputSize,
            y: 1.0 - CGFloat(yCenter + height / 2) / modelInputSize,
            width: CGFloat(width) / modelInputSize,
            height: CGFloat(height) / modelInputSize
        ).clamped
        return CGRect(
            x: normalized.minX * bufferSize.width,
            y: normalized.minY * bufferSize.height,
            width: normalized.width * bufferSize.width,
            height: normalized.height * bufferSize.height
        )
    }
    
    private func classLabel(for classId: Int) -> String {
        switch classId {
        case 0: return "hazard"
        case 1: return "object"
        case 2: return "opening"
        case 3: return "signage"
        case 4: return "transition"
        default: return "default"
        }
    }
    
    private func createRoundedRectLayer(bounds: CGRect) -> CALayer {
        let layer = CALayer()
        layer.bounds = bounds
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.name = "Found Object"
        layer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                        components: [1.0, 0.0, 0.0, 0.6])
        layer.cornerRadius = 7
        return layer
    }
    
    private func createTextLayer(bounds: CGRect,
                                 identifier: String,
                                 confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        textLayer.string = String(format: "\(identifier)\n%.1f%%", confidence * 100)
        textLayer.fontSize = 14
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - 10, height: bounds.height - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = .zero
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                            components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = UIScreen.main.scale
        return textLayer
    }
}

// MARK: - View

//struct Object_Detection: View {
//    
//    @StateObject private var vm = ObjectDetectionViewModel(visual: true)
//    
//    var body: some View {
//        ZStack {
//            ARViewRepresentable(session: vm.session)
//                .ignoresSafeArea()
//            DetectionOverlay(detectionLayer: vm.detectionOverlay)
//                .ignoresSafeArea()
//        }
//    }
//}

// MARK: - UIViewRepresentable

struct ARViewRepresentable: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = session
        arView.automaticallyUpdatesLighting = true
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct DetectionOverlay: UIViewRepresentable {
    let detectionLayer: CALayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.layer.addSublayer(detectionLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        detectionLayer.frame = uiView.bounds
        detectionLayer.setAffineTransform(.identity)
    }
}

// MARK: - Extensions & Data

extension CGRect {
    var clamped: CGRect {
        let x = max(0, minX)
        let y = max(0, minY)
        let w = min(width, 1.0 - x)
        let h = min(height, 1.0 - y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

class ObjectDetectionData {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let type: String
    
    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, type: String) {
        self.topLeft     = topLeft
        self.topRight    = topRight
        self.bottomLeft  = bottomLeft
        self.bottomRight = bottomRight
        self.type        = type
    }
    
    var description: String {
        """
        ObjectDetectionData:
          type:        \(type)
          topLeft:     (\(String(format: "%.1f", topLeft.x)), \(String(format: "%.1f", topLeft.y)))
          topRight:    (\(String(format: "%.1f", topRight.x)), \(String(format: "%.1f", topRight.y)))
          bottomLeft:  (\(String(format: "%.1f", bottomLeft.x)), \(String(format: "%.1f", bottomLeft.y)))
          bottomRight: (\(String(format: "%.1f", bottomRight.x)), \(String(format: "%.1f", bottomRight.y)))
        """
    }
}
