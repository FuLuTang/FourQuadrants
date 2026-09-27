import Foundation
import SwiftUI

struct DailyTaskLayout {
    struct LayoutResult {
        let frame: CGRect
        /// The interval represented by this block in the visible day.
        /// It can be clipped at midnight while the underlying task remains unchanged.
        let startAt: Date
        let duration: TimeInterval
    }

    private struct LayoutTask {
        let id: UUID
        let startAt: Date
        let endAt: Date

        var duration: TimeInterval {
            endAt.timeIntervalSince(startAt)
        }
    }
    
    /// Packs tasks into columns to handle overlaps.
    /// Returns a map of Task ID -> Relative Frame (x, y, width, height)
    /// where x and width are fractional (0.0 to 1.0), and y/height are absolute time-based.
    static func calculateLayout(for tasks: [DailyTask], hourHeight: CGFloat) -> [UUID: LayoutResult] {
        guard !tasks.isEmpty else { return [:] }

        return calculateLayout(
            for: tasks.map { LayoutTask(id: $0.id, startAt: $0.startAt, endAt: $0.endAt) },
            hourHeight: hourHeight
        )
    }

    /// Calculates a day's layout while clipping intervals that cross midnight.
    /// The returned IDs still refer to the original DailyTask objects.
    static func calculateLayout(
        for tasks: [DailyTask],
        hourHeight: CGFloat,
        visibleStart: Date,
        visibleEnd: Date
    ) -> [UUID: LayoutResult] {
        let clippedTasks = tasks.compactMap { task -> LayoutTask? in
            let startAt = max(task.startAt, visibleStart)
            let endAt = min(task.endAt, visibleEnd)
            guard startAt < endAt else { return nil }
            return LayoutTask(id: task.id, startAt: startAt, endAt: endAt)
        }
        return calculateLayout(for: clippedTasks, hourHeight: hourHeight)
    }

    private static func calculateLayout(for tasks: [LayoutTask], hourHeight: CGFloat) -> [UUID: LayoutResult] {
        guard !tasks.isEmpty else { return [:] }
        
        // 1. Sort by start time, then duration (longer first)
        let sortedTasks = tasks.sorted {
            if $0.startAt == $1.startAt {
                return $0.duration > $1.duration
            }
            return $0.startAt < $1.startAt
        }
        
        var results: [UUID: LayoutResult] = [:]
        var clusters: [[LayoutTask]] = []
        
        // 2. Group into overlapping clusters
        var currentCluster: [LayoutTask] = []
        var clusterEndTime: Date?
        
        for task in sortedTasks {
            if let end = clusterEndTime {
                if task.startAt < end {
                    // Overlaps with the current cluster's time range
                    currentCluster.append(task)
                    // Extend cluster end time if needed
                    if task.endAt > end {
                        clusterEndTime = task.endAt
                    }
                } else {
                    // New cluster
                    clusters.append(currentCluster)
                    currentCluster = [task]
                    clusterEndTime = task.endAt
                }
            } else {
                // First task
                currentCluster = [task]
                clusterEndTime = task.endAt
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
    
    private static func layoutCluster(_ tasks: [LayoutTask], hourHeight: CGFloat) -> [UUID: LayoutResult] {
        // Standard "Left-to-Right" packing algorithm (columns)
        
        // Columns stores the end time of the last task in that column
        var columns: [Date] = []
        var taskColumns: [UUID: Int] = [:]
        
        for task in tasks {
            var placed = false
            // Find first column where this task fits
            for (colIndex, endAt) in columns.enumerated() {
                if task.startAt >= endAt {
                    columns[colIndex] = task.endAt
                    taskColumns[task.id] = colIndex
                    placed = true
                    break
                }
            }
            
            if !placed {
                // Create new column
                columns.append(task.endAt)
                taskColumns[task.id] = columns.count - 1
            }
        }
        
        let totalColumns = CGFloat(columns.count)
        var results: [UUID: LayoutResult] = [:]
        
        for task in tasks {
            guard let colIndex = taskColumns[task.id] else { continue }
            
            // Calculate Vertical Geometry
            let calendar = Calendar.current
            let hour = CGFloat(calendar.component(.hour, from: task.startAt))
            let minute = CGFloat(calendar.component(.minute, from: task.startAt))
            let startY = ((hour * 60 + minute) / 60) * hourHeight + 10 // +10 padding top
            
            let durationSeconds = task.endAt.timeIntervalSince(task.startAt)
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
            results[task.id] = LayoutResult(frame: frame, startAt: task.startAt, duration: durationSeconds)
        }
        
        return results
    }
}
