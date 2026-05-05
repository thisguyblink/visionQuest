//
//  WarningSystem.swift
//  Vision Quest
//
//  Created by Patrick Smith on 5/4/26.
//

import Foundation
import QuartzCore

class WarningSystem : ObservableObject {
    private var lidarManager : DepthCameraManager
//    private var objectManager = ObjectDetectionViewModel(visual: false) lidar manager handles image cycle
    private var speechManager = SpeechFuncts()
    private var currentTime: Double
    private let cyclesPerSecond: Int = 5
    private let warningCooldown: Double = 3.0
    private var lastSpokenMessage: String = ""
    private var lastWarningTime: Double = 0
    private let warningQueue = DispatchQueue(label: "warning.loop", qos: .utility)  // lower priority than userInitiated

    private var screenSize: CGSize = .zero
    private let warningDistance = Float(2.0)
    @Published var running = false
    
    @Published var spokenMessage: String = ""
    
    init(lidarManager: DepthCameraManager) {
        self.lidarManager = lidarManager
        currentTime = CACurrentMediaTime()
    }
    
    func startWarningSystem() {
        running = true
        scheduleLoop()
    }
    
    func stopWarningSystem() {
        running = false
    }
    
    private func scheduleLoop() {
            guard running else { return }
            warningQueue.asyncAfter(deadline: .now() + 1.0 / Double(cyclesPerSecond)) { [weak self] in
                    guard let self = self, self.running else { return }
                    self.logicLoop()
                    self.scheduleLoop()
                }
        }
    
    private func logicLoop() {
        screenSize = lidarManager.objectDetection.bufferSize // lidar --> object detection 
        if screenSize == .zero {
            fatalError("Screen size not recieved from Object Detection View Model")
        }
        let minRow = Int(screenSize.height) / 4
        let maxRow = Int(screenSize.height) * 3 / 4
        let minCol = Int(screenSize.width) / 4
        let maxCol = Int(screenSize.width) * 3 / 4
            if ( CACurrentMediaTime() - currentTime) >= 1/Double(cyclesPerSecond) {
                // lidar --> object detection
                let objects = lidarManager.objectDetection.getObjectDetectionDataList() // dimensions grabbed in bufferSize
                let lidarData = lidarManager.latestDepthGrid // dimesions 192H x 256 W
                let scaledLidar = scaleLidarToScreen(grid: lidarData)
                let depthValue = scaledLidar.values
                var type: String = "None"
                var minDistance: Float = Float(5.0)
                for object in objects {
                    // only check import object types
                    if object.type == "hazard" || object.type == "object" {
                        print("Hazard or Object Detected")
                        var startRow = Int(object.topLeft.y)
                        var endRow   = Int(object.bottomLeft.y)
                        var startCol = Int(object.topLeft.x)
                        var endCol   = Int(object.topRight.x)
                        
                        startRow = max(minRow, startRow)
                        endRow   = min(maxRow, endRow)
                        startCol = max(minCol, startCol)
                        endCol   = min(maxCol, endCol)
                        
                        let rowRange = startRow...endRow
                        let colRange = startCol...endCol
                        
                        guard startRow < endRow, startCol < endCol else {
                            print("DEBUG [logicLoop]: skipping object — invalid range")
                            continue
                        }
                        
                        // start search for closest hazard
                        for row in rowRange {
                            for col in colRange {
                                let depth = depthValue[row][col]
                                if depth > Float(0.1) && depth < minDistance {  // skip -1 sentinel values
                                        minDistance = depth
                                        type = object.type
                                    }
                                }
                            }
                    }
                }
                // send warning to be spoken
                if type != "None" {
                    let grid = lidarManager.latestDepthGrid
                        DispatchQueue.global(qos: .background).async {
                            self.lidarManager.exportSnapshot(depthGrid: grid)
                        }
                    sendWarning(type: type, distance: minDistance)
                }
                
            } else {
                print("Processing time faster than cycle speed")
            }
    }
    
    private func scaleLidarToScreen(grid: DepthGrid) -> DepthGrid {
        let scaleX = screenSize.width  / CGFloat(grid.width)
        let scaleY = screenSize.height / CGFloat(grid.height)
        
        let newWidth  = Int(screenSize.width)
        let newHeight = Int(screenSize.height)
        
        var scaledValues = Array(repeating: Array(repeating: Float(0), count: newWidth), count: newHeight)
        
        for row in 0..<newHeight {
            for col in 0..<newWidth {
                // Map scaled pixel back to original grid coordinate
                let srcCol = Int(CGFloat(col) / scaleX)
                let srcRow = Int(CGFloat(row) / scaleY)
                
                let clampedCol = min(srcCol, grid.width  - 1)
                let clampedRow = min(srcRow, grid.height - 1)
                
                scaledValues[row][col] = grid.values[clampedRow][clampedCol]
            }
        }
        
        return DepthGrid(values: scaledValues, width: newWidth, height: newHeight,
                         maxDepth: grid.maxDepth, minDepth: grid.minDepth)
    }
    
    func sendWarning(type: String, distance: Float) {
        let now = CACurrentMediaTime()
        let output = "\(type) in \(distance) meters"
        
        guard output != lastSpokenMessage || (now - lastWarningTime) >= warningCooldown else {
            return
        }
                
        lastWarningTime = now
        lastSpokenMessage = output
        
            DispatchQueue.main.async {
                self.spokenMessage = output
                self.speechManager.speak(output)
            }
        }
    
}
