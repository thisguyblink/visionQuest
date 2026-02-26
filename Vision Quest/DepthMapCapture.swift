import AVFoundation
import SwiftUI

class DepthCameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    
    @Published var depthAvailable = false
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera,
                                                   for: .video,
                                                   position: .back) else {
            print("No LiDAR device")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isDepthDataDeliveryEnabled = true
            }
            
            depthAvailable = photoOutput.isDepthDataDeliverySupported
            
            session.commitConfiguration()
            session.startRunning()
            
        } catch {
            print("Error configuring session: \(error)")
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.isDepthDataDeliveryEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Delegate
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        
        if let depthData = photo.depthData {
            print("Depth data captured!")
            
            let convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            let depthMap = convertedDepth.depthDataMap
            
            print("Depth map size: \(CVPixelBufferGetWidth(depthMap)) x \(CVPixelBufferGetHeight(depthMap))")
        }
    }
}
