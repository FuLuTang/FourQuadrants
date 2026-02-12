import Foundation
import SwiftUI

struct DailyTaskLayout {
    struct LayoutResult {
        let frame: CGRect
    }
    
    /// Packs tasks into columns to handle overlaps.
    /// Returns a map of Task ID -> Relative Frame (x, y, width, height)
    /// where x and width are fractional (0.0 to 1.0), and y/height are absolute time-based.
    static func calculateLayout(for tasks: [DailyTask], hourHeight: CGFloat) -> [UUID: LayoutResult] {
        guard !tasks.isEmpty else { return [:] }
        
        // 1. Sort by start time, then duration (longer first)
        let sortedTasks = tasks.sorted {
            if $0.startTime == $1.startTime {
                return $0.duration > $1.duration
            }
            return $0.startTime < $1.startTime
        }
        
        var results: [UUID: LayoutResult] = [:]
        var clusters: [[DailyTask]] = []
        
        // 2. Group into overlapping clusters
        var currentCluster: [DailyTask] = []
        var clusterEndTime: Date?
        
        for task in sortedTasks {
            if let end = clusterEndTime {
                if task.startTime < end {
                    // Overlaps with the current cluster's time range
                    currentCluster.append(task)
                    // Extend cluster end time if needed
                    if task.endTime > end {
                        clusterEndTime = task.endTime
                    }
                } else {
                    // New cluster
                    clusters.append(currentCluster)
                    currentCluster = [task]
                    clusterEndTime = task.endTime
                }
            } else {
                // First task
                currentCluster = [task]
                clusterEndTime = task.endTime
            }
        }
        
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        // 3. Layout each cluster
        for cluster in clusters {
            let clusterResults = layoutCluster(cluster, hourHeight: hourHeight)
            results.merge(clusterResults) { (_, new) in new }
        }
        
        return results
    }
    
    private static func layoutCluster(_ tasks: [DailyTask], hourHeight: CGFloat) -> [UUID: LayoutResult] {
        // Standard "Left-to-Right" packing algorithm (columns)
        
        // Columns stores the end time of the last task in that column
        var columns: [Date] = []
        var taskColumns: [UUID: Int] = [:]
        
        for task in tasks {
            var placed = false
            // Find first column where this task fits
            for (colIndex, endTime) in columns.enumerated() {
                if task.startTime >= endTime {
                    columns[colIndex] = task.endTime
                    taskColumns[task.id] = colIndex
                    placed = true
                    break
                }
            }
            
            if !placed {
                // Create new column
                columns.append(task.endTime)
                taskColumns[task.id] = columns.count - 1
            }
        }
        
        let totalColumns = CGFloat(columns.count)
        var results: [UUID: LayoutResult] = [:]
        
        for task in tasks {
            guard let colIndex = taskColumns[task.id] else { continue }
            
            // Calculate Vertical Geometry
            let calendar = Calendar.current
            let hour = CGFloat(calendar.component(.hour, from: task.startTime))
            let minute = CGFloat(calendar.component(.minute, from: task.startTime))
            let startY = ((hour * 60 + minute) / 60) * hourHeight + 10 // +10 padding top
            
            let durationSeconds = task.duration
            let height = (CGFloat(durationSeconds) / 3600.0) * hourHeight
            
            // Calculate Horizontal Geometry
            // Width is 1.0 / totalColumns
            // X is colIndex / totalColumns
            // We return "relative" width/x for the view to scale
            // But CGRect usually expects absolute points.
            // Let's store fractional X and Width in the CGRect for now, consumer handles scaling.
            
            let colWidth = 1.0 / totalColumns
            let xPos = CGFloat(colIndex) * colWidth
            
            // x, width are fractional (0.0-1.0). y, height are points.
            let frame = CGRect(x: xPos, y: startY, width: colWidth, height: height)
            results[task.id] = LayoutResult(frame: frame)
        }
        
        return results
    }
}
