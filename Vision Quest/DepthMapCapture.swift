import Foundation
import ARKit
import SwiftUI

class DepthCameraManager: NSObject, ARSessionDelegate, ObservableObject  {
    
     let session = AVCaptureSession()
     private let photoOutput = AVCapturePhotoOutput()
     
     @Published var depthAvailable = false
     
     override init() {
         super.init()
         configureSession()
     }
    
    private func configureSession() {
           session.beginConfiguration()
           
           guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
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
    
    func makeUIView(context: Context) -> some UIView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        arView.session.?.delegate = context.coordinator
        arView.session.run(config)
        return arView
    }
    
    func captureDepthMap() {
        
    }

}

class ARSessionDelegateCoordinator: NSObject, ARSessionDelegate {
    @Binding var depthMap: CVPixelBuffer?
    
    init(depthMap: CVPixelBuffer? = nil) {
        self.depthMap = depthMap
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let currentPointCloud = frame. 
    }
    
}
