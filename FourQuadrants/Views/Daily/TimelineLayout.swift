import UIKit

protocol TimelineLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, startTimeForItemAt indexPath: IndexPath) -> Date
    func collectionView(_ collectionView: UICollectionView, durationForItemAt indexPath: IndexPath) -> TimeInterval
}

class TimelineLayout: UICollectionViewLayout {
    weak var delegate: TimelineLayoutDelegate?
    
    var hourHeight: CGFloat = 60
    var timeColumnWidth: CGFloat = 50
    var horizontalPadding: CGFloat = 8
    
    private var cache: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width
    }
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    override func prepare() {
        guard let collectionView = collectionView, cache.isEmpty else { return }
        
        let section = 0
        let itemCount = collectionView.numberOfItems(inSection: section)
        let availableWidth = contentWidth - timeColumnWidth - (horizontalPadding * 2)
        
        // 1. 获取所有任务的信息
        var tasks: [(index: Int, start: Date, end: Date, duration: TimeInterval)] = []
        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i, section: section)
            let start = delegate?.collectionView(collectionView, startTimeForItemAt: indexPath) ?? Date()
            let duration = delegate?.collectionView(collectionView, durationForItemAt: indexPath) ?? 3600
            tasks.append((index: i, start: start, end: start.addingTimeInterval(duration), duration: duration))
        }
        
        // 2. 排序 (按开始时间)
        let sortedTasks = tasks.sorted { $0.start < $1.start }
        
        // 3. 分组算法 (处理重叠)
        var clusters: [[Int]] = []
        var currentCluster: [Int] = []
        var clusterEndTime: Date?
        
        for task in sortedTasks {
            if let end = clusterEndTime, task.start < end {
                currentCluster.append(task.index)
                if task.end > end { clusterEndTime = task.end }
            } else {
                if !currentCluster.isEmpty { clusters.append(currentCluster) }
                currentCluster = [task.index]
                clusterEndTime = task.end
            }
        }
        if !currentCluster.isEmpty { clusters.append(currentCluster) }
        
        // 4. 为每个分组计算布局
        for cluster in clusters {
            layoutCluster(cluster, tasks: tasks, availableWidth: availableWidth)
        }
        
        contentHeight = 24 * hourHeight + 20
    }
    
    private func layoutCluster(_ clusterIndices: [Int], tasks: [(index: Int, start: Date, end: Date, duration: TimeInterval)], availableWidth: CGFloat) {
        var columns: [Date] = []
        var taskColumnMap: [Int: Int] = [:]
        
        // 贪婪列分配
        for idx in clusterIndices {
            let task = tasks.first { $0.index == idx }!
            var placed = false
            for (colIdx, endTime) in columns.enumerated() {
                if task.start >= endTime {
                    columns[colIdx] = task.end
                    taskColumnMap[idx] = colIdx
                    placed = true
                    break
                }
            }
            if !placed {
                columns.append(task.end)
                taskColumnMap[idx] = columns.count - 1
            }
        }
        
        let totalColumns = CGFloat(columns.count)
        let colWidth = availableWidth / totalColumns
        
        for idx in clusterIndices {
            let task = tasks.first { $0.index == idx }!
            let colIdx = taskColumnMap[idx]!
            
            let calendar = Calendar.current
            let hour = CGFloat(calendar.component(.hour, from: task.start))
            let minute = CGFloat(calendar.component(.minute, from: task.start))
            let y = (hour + minute / 60.0) * hourHeight + 10
            let h = CGFloat(task.duration / 3600.0) * hourHeight
            let x = timeColumnWidth + horizontalPadding + CGFloat(colIdx) * colWidth
            
            let indexPath = IndexPath(item: idx, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(x: x, y: y, width: colWidth, height: h)
            cache[indexPath] = attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath]
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        cache.removeAll()
    }
}
