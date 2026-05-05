//
//  Object Detection.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI
import Vision
import AVFoundation
import CoreML

// MARK: - ViewModel

class ObjectDetectionViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let session = AVCaptureSession()
    let detectionOverlay = CALayer()
    var bufferSize: CGSize = .zero
    var objectDetectionDataList = [ObjectDetectionData]()
    
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var requests = [VNRequest]()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
    
    init(visual: Bool) {
        super.init()
        setupAll(visual: visual)
    }
    
    // MARK: - Setup
    
    func setupAll(visual: Bool) {
        guard let videoDevice = discoverCamera() else {
            return
        }
        setupCaptureSession(videoDevice: videoDevice)
        setupVisionRequest(visual: visual)
        
        DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
    }
    
    
    
    private func discoverCamera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices
        return devices.first
    }
    
    private func setupCaptureSession(videoDevice: AVCaptureDevice) {
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        guard session.canAddInput(deviceInput) else {
            session.commitConfiguration()
            return
        }
        
        session.addInput(deviceInput)
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        guard session.canAddOutput(videoDataOutput) else {
            session.commitConfiguration()
            return
        }
        
        session.addOutput(videoDataOutput)
        
        // Set buffer size
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            bufferSize.width  = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print("DEBUG [setupCaptureSession]: buffer size error — \(error)")
        }
        
        session.commitConfiguration()
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
    
    // MARK: - Sample Buffer Delegate
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = resolveExifOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: exifOrientation,
                                            options: [:])
        do {
            try handler.perform(requests)
        } catch {
            print("DEBUG [captureOutput]: handler error — \(error)")
        }
    }
    
    // MARK: - Orientation
    
    private func resolveExifOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:   return .left
        case .landscapeLeft:        return .upMirrored
        case .landscapeRight:       return .down
        case .portrait:             return .up
        default:                    return .up
        }
    }
    
    // Object detection with data only for Warning System
    
    private func makeBoundaryBoxes(_ results: [VNObservation])  {
        
        guard let observation = results.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else {
            return
        }
        
        let numDetections = multiArray.shape[1].intValue  // 300
        let confidenceThreshold: Float = 0.3
        var boxesDrawn = 0
        // remove all previous object detections from list
        objectDetectionDataList.removeAll()
        for i in 0..<numDetections {
            let confidence = multiArray[[0, i as NSNumber, 4]].floatValue
            guard confidence >= confidenceThreshold else { continue }
            
            let xCenter  = multiArray[[0, i as NSNumber, 0]].floatValue
            let yCenter  = multiArray[[0, i as NSNumber, 1]].floatValue
            let width    = multiArray[[0, i as NSNumber, 2]].floatValue
            let height   = multiArray[[0, i as NSNumber, 3]].floatValue
            let classId  = Int(multiArray[[0, i as NSNumber, 5]].floatValue)
            var type = "default"
            switch classId {
            case 0:
                type = "hazard"
            case 1:
                type = "object"
            case 2:
                type = "opening"
            case 3:
                type = "signage"
            case 4:
                type = "transition"
            default:
                type = "default"
            }
            
            
            // Convert from center format to pixel coords
            
            // Convert from model pixel space to 0-1 normalized
            let modelInputSize: CGFloat = 640.0
            
            let normalizedRect = CGRect(
                x: CGFloat(xCenter - width / 2) / modelInputSize,
                y: 1.0 - CGFloat(yCenter + height / 2) / modelInputSize,  // flip Y here
                width: CGFloat(width) / modelInputSize,
                height: CGFloat(height) / modelInputSize
            ).clamped
            
            let scaledRect = CGRect(
                x: normalizedRect.minX * bufferSize.width,
                y: normalizedRect.minY * bufferSize.height,
                width: normalizedRect.width * bufferSize.width,
                height: normalizedRect.height * bufferSize.height
            )
            
            let objectDetectionData = ObjectDetectionData(
                topLeft:     CGPoint(x: scaledRect.minX, y: scaledRect.minY),
                topRight:    CGPoint(x: scaledRect.maxX, y: scaledRect.minY),
                bottomLeft:  CGPoint(x: scaledRect.minX, y: scaledRect.maxY),
                bottomRight: CGPoint(x: scaledRect.maxX, y: scaledRect.maxY),
                type:        type
            )
            objectDetectionDataList.append(objectDetectionData)
            
        }
    }
    
    func getObjectDetectionDataList() -> [ObjectDetectionData] {
        return objectDetectionDataList
    }
    
    
    // MARK: - Drawing
    
    private func drawVisionRequestResults(_ results: [VNObservation]) {
        detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard let observation = results.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else {
            print("DEBUG [draw]: could not get multiArray")
            return
        }
        
        let numDetections = multiArray.shape[1].intValue  // 300
//        let numValues     = multiArray.shape[2].intValue  // 6
        let confidenceThreshold: Float = 0.3
        var boxesDrawn = 0
        
        for i in 0..<numDetections {
            let confidence = multiArray[[0, i as NSNumber, 4]].floatValue
            guard confidence >= confidenceThreshold else { continue }
            
            let xCenter  = multiArray[[0, i as NSNumber, 0]].floatValue
            let yCenter  = multiArray[[0, i as NSNumber, 1]].floatValue
            let width    = multiArray[[0, i as NSNumber, 2]].floatValue
            let height   = multiArray[[0, i as NSNumber, 3]].floatValue
            let classId  = Int(multiArray[[0, i as NSNumber, 5]].floatValue)
            var type = "default"
                switch classId {
                case 0:
                    type = "hazard"
                case 1:
                    type = "object"
                case 2:
                    type = "opening"
                case 3:
                    type = "signage"
                case 4:
                    type = "transition"
                default:
                    type = "default"
                }
            
            
            // Convert from center format to pixel coords
            
            // Convert from model pixel space to 0-1 normalized
            let modelInputSize: CGFloat = 640.0

            let normalizedRect = CGRect(
                x: CGFloat(xCenter - width / 2) / modelInputSize,
                y: 1.0 - CGFloat(yCenter + height / 2) / modelInputSize,  // flip Y here
                width: CGFloat(width) / modelInputSize,
                height: CGFloat(height) / modelInputSize
            ).clamped

            let scaledRect = CGRect(
                x: normalizedRect.minX * bufferSize.width,
                y: normalizedRect.minY * bufferSize.height,
                width: normalizedRect.width * bufferSize.width,
                height: normalizedRect.height * bufferSize.height
            )
            
            let objectDetectionData = ObjectDetectionData(
                topLeft:     CGPoint(x: scaledRect.minX, y: scaledRect.minY),
                topRight:    CGPoint(x: scaledRect.maxX, y: scaledRect.minY),
                bottomLeft:  CGPoint(x: scaledRect.minX, y: scaledRect.maxY),
                bottomRight: CGPoint(x: scaledRect.maxX, y: scaledRect.maxY),
                type:        type
            )

            let shapeLayer = createRoundedRectLayer(bounds: scaledRect)
            let textLayer  = createTextLayer(
                bounds: scaledRect,
                identifier: "class \(classId)",
                confidence: VNConfidence(confidence)
            )
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
            boxesDrawn += 1
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

struct Object_Detection: View {
    
    @StateObject private var vm = ObjectDetectionViewModel(visual: true)
    
    var body: some View {
        let _ = print("DEBUG [body]: rendered — session running: \(vm.session.isRunning), inputs: \(vm.session.inputs.count)")
        ZStack {
            CameraPreview(session: vm.session)
                .ignoresSafeArea()
            DetectionOverlay(detectionLayer: vm.detectionOverlay)
                .ignoresSafeArea()
        }
    }
}

// MARK: - UIViewRepresentable

struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        print("DEBUG [CameraPreview]: makeUIView — session running: \(session.isRunning)")
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        print("DEBUG [CameraPreview]: updateUIView — bounds: \(uiView.bounds)")
    }
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
        detectionLayer.setAffineTransform(.identity)  // reset any previous transform
    }
}

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
