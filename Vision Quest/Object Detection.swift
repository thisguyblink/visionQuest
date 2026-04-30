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

struct Object_Detection: View {
    
    private let session = AVCaptureSession()
    private var bufferSize: CGSize = .zero
    private var deviceInput: AVCaptureDeviceInput?
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private let detectionOverlay = CALayer()
    private let shapeOverlay = CAShapeLayer()
    
    var body: some View {
        Text("This is the Oject Detection Page")
    }
    
    // MARK: - Setup Functions
    mutating func setupAll(modelURL: URL) {
        guard let videoDevice = discoverCamera() else {
            print("No camera found")
            return
        }
        
        setupCaptureSession(videoDevice: videoDevice)
        let exifOrientation = resolveExifOrientation()
        
        if let visionRequest = setupVisionRequest(modelURL: modelURL) {
            // Store or use visionRequest as needed
            _ = visionRequest
        }
    }
    
    // MARK: - Camera Discovery
    
    /// Returns the first available back wide-angle camera, or nil if none found
    private func discoverCamera() -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first
    }
    
    // MARK: - Capture Session Setup
    
    private mutating func setupCaptureSession(videoDevice: AVCaptureDevice) {
        guard let deviceInput = createDeviceInput(from: videoDevice) else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        
        session.addInput(deviceInput)
        configureVideoOutput()
        configureBufferSize(for: videoDevice)
        session.commitConfiguration()
    }
    
    /// Creates and returns an AVCaptureDeviceInput from the given device
    private func createDeviceInput(from videoDevice: AVCaptureDevice) -> AVCaptureDeviceInput? {
        do {
            return try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            return nil
        }
    }
    
    /// Enables the video capture connection on the data output
    private func configureVideoOutput() {
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
    }
    
    /// Locks the device and reads the active format dimensions into bufferSize
    private mutating func configureBufferSize(for videoDevice: AVCaptureDevice) {
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(
                videoDevice.activeFormat.formatDescription
            )
            bufferSize.width  = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print("Failed to lock device for configuration: \(error)")
        }
    }
    
    // MARK: - Orientation
    
    /// Maps the current device orientation to the corresponding CGImagePropertyOrientation
    private func resolveExifOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:   return .left
        case .landscapeLeft:        return .upMirrored
        case .landscapeRight:       return .down
        case .portrait:             return .up
        default:                    return .up
        }
    }
    
    // MARK: - Vision / CoreML
    
    /// Loads the CoreML model and returns a configured VNCoreMLRequest
    private func setupVisionRequest(modelURL: URL) -> VNCoreMLRequest? {
        do {
            let visionModel = try VNCoreMLModel(for: best().model)
            
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    print("Vision request error: \(error)")
                    return
                }
                DispatchQueue.main.async {
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                }
            }
            return objectRecognition
            
        } catch {
            print("Failed to load CoreML model: \(error)")
            return nil
        }
    }
    
    
    private func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                             components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

    private func createTextSubLayerInBounds(_ bounds: CGRect,
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
    
    // MARK: - Drawing
    
    /// Processes and draws the results returned by the Vision request
    private func drawVisionRequestResults(_ results: [VNObservation]) {
        detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        for observation in results.compactMap({ $0 as? VNRecognizedObjectObservation }) {
            guard let topLabel = observation.labels.first else { continue }
            
            let objectBounds = VNImageRectForNormalizedRect(
                observation.boundingBox,
                Int(bufferSize.width),
                Int(bufferSize.height)
            )
            
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            let textLayer = self.createTextSubLayerInBounds(
                objectBounds,
                identifier: topLabel.identifier,
                confidence: topLabel.confidence
            )
            
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
    }
}
