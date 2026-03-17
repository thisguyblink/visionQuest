import SwiftUI

struct Depth_Map: View {
    
    @StateObject private var camera = DepthCameraManager()
    
    var body: some View {
    
        VStack(spacing: 20) {
            
            if camera.depthAvailable {
                Text("LiDAR Available ✅")
            } else {
                Text("LiDAR Not Available ❌")
            }
            
            Button("Capture Depth Photo") {
                camera.captureDepthMap()
            }
        }
    }
}

#Preview {
    Depth_Map()
}
