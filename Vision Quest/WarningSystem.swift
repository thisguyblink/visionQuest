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
    
    var minRow = Int(0)
    var maxRow = Int(100)
    var minCol = Int(0)
    var maxCol = Int(100)
    
    init(lidarManager: DepthCameraManager) {
        self.lidarManager = lidarManager
        currentTime = CACurrentMediaTime()
    }
    
    func startWarningSystem() {
        print("warning System started")
        running = true
        scheduleLoop()
        screenSize = lidarManager.objectDetection.bufferSize
        minRow = Int(screenSize.height) / 4
        maxRow = Int(screenSize.height) * 3 / 4
        minCol = Int(screenSize.width) / 4
        maxCol = Int(screenSize.width) * 3 / 4
    }
    
    func stopWarningSystem() {
        running = false
    }
    
    private func scheduleLoop(delay: Double = 0.2) {
        guard running else { return }

        warningQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.running else { return }

            let hasObjects = !self.lidarManager.objectDetection.getObjectDetectionDataList().isEmpty

            self.logicLoop()

            // slower loop if nothing detected
            let nextDelay = hasObjects ? 0.1 : 0.3

            self.scheduleLoop(delay: nextDelay)
        }
    }
    
    private func logicLoop() {
        print("logic Loop running")
        let objects = lidarManager.objectDetection.getObjectDetectionDataList()
        guard !objects.isEmpty else {
                print("No objects yet")
                return
            }
        guard screenSize != .zero else { return }
                // lidar --> object detection
                // dimensions grabbed in bufferSize
                let lidarData = lidarManager.latestDepthGrid // dimesions 192H x 256 W
                let scaledLidar = scaleLidarToScreen(grid: lidarData)
                let depthValue = scaledLidar.values
                var type: String = "None"
                var minDistance: Float = Float(4.0)
                objectLoop: for object in objects {
                    // only check import object types
                    print("Object type is \(object.type)")
                    if object.type == "hazard" || object.type == "object" {
                        let grid = lidarManager.latestDepthGrid
                        let startRow = Int(object.minY * Float(grid.height))
                        let endRow   = Int(object.maxY * Float(grid.height))
                        let startCol = Int(object.minX * Float(grid.width))
                        let endCol   = Int(object.maxX * Float(grid.width))
                            // trying to bound objects to middle 50% but fails when both of the bounds are outside the image
//                        startRow = max(48, startRow)
//                        endRow   = min(144, endRow)
//                        startCol = max(64, startCol)
//                        endCol   = min(192, endCol)
                        
                        guard startRow < endRow, startCol < endCol else {
                            print("DEBUG [logicLoop]: skipping object — invalid range \(startRow), \(endRow), \(startCol), \(endCol), object: \(object.description)")
                            continue
                        }
                        let rowRange = startRow...endRow
                        let colRange = startCol...endCol
                        print("Checking object \(object.type) box rows \(rowRange), cols \(colRange)")
                        
                        // start search for closest hazard
                        for row in rowRange {
                            for col in colRange {
                                let depth = depthValue[row][col]
                                if depth > Float(0.1) && depth < minDistance {  // skip -1 sentinel values
                                        minDistance = depth
                                        type = object.type
                                        if minDistance <= warningDistance {
                                            break objectLoop
                                        }
                                    }
                                }
                            
                            }
                        print("Minimum object distance: \(minDistance)")
                        if minDistance != Float(4.0) {
                            break objectLoop
                        }
                    }
                }
            
                // send warning to be spoken
            if type != "None" {
                sendWarning(type: type, distance: minDistance)
                let grid = lidarManager.latestDepthGrid
                DispatchQueue.global(qos: .background).async {
                    self.lidarManager.exportSnapshot(depthGrid: grid)
                }
            }
        minDistance = Float(3.0)
                
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
        let output = "\(type) in \(String(format: "%.2f", distance)) meters"
        
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
