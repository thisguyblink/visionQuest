//
//  WarningSystem.swift
//  Vision Quest
//
//  Created by Patrick Smith on 5/4/26.
//

import Foundation
import SwiftUI

class WarningSystem {
    private var lidarManager = DepthCameraManager()
    private var objectManager = ObjectDetectionViewModel(visual: false)
    private var speechManager = SpeechFuncts()
    private var currentTime: Double
    private let cyclesPerSecond: Int = 5
    private var screenSize: CGSize = .zero
    private let warningDistance = Float(2.0)
    var running = false
    
    init() {
        currentTime = CACurrentMediaTime()
        lidarManager.start()
    }
    
    func startWarningSystem() {
        running = true
        DispatchQueue.main.async {
            self.logicLoop()
        }
    }
    
    func stopWarningSystem() {
        running = false
    }
    
    private func logicLoop() {
        screenSize = objectManager.bufferSize
        if screenSize == .zero {
            fatalError("Screen size not recieved from Object Detection View Model")
        }
        let minRow = Int(screenSize.height) / 4
        let maxRow = Int(screenSize.height) * 3 / 4
        let minCol = Int(screenSize.width) / 4
        let maxCol = Int(screenSize.width) * 3 / 4
        while running {
            if ( CACurrentMediaTime() - currentTime) >= 1/Double(cyclesPerSecond) {
                var objects = objectManager.getObjectDetectionDataList() // dimensions grabbed in bufferSize
                var lidarData = lidarManager.latestDepthGrid // dimesions 192H x 256 W
                var scaledLidar = scaleLidarToScreen(grid: lidarData)
                let depthValue = scaledLidar.values
                var type: String = "None"
                var minDistance: Float = Float(5.0)
                for object in objects {
                    // only check import object types
                    if object.type == "hazard" || object.type == "object" {
                        var startRow = Int(object.topLeft.y)
                        var endRow   = Int(object.bottomLeft.y)
                        var startCol = Int(object.topLeft.x)
                        var endCol   = Int(object.bottomRight.x)
                        // reduce search to middle .75 of screen
                        startRow = max(startRow, minRow)
                        endRow   = min(endRow, maxRow)
                        startCol = max(startCol, minCol)
                        endCol   = min(endCol, maxCol)
                        let rowRange = startRow...endRow
                        let colRange = startCol...endCol
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
                sendWarning(type: type, distance: minDistance)
                
            } else {
                print("Processing time faster than cycle speed")
            }
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
        if type == "None" {
            return
        }
            let output = "\(type) in \(distance) meters"
            DispatchQueue.main.async {
                self.speechManager.speak(output)
            }
        }
}
