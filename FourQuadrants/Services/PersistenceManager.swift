import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()
    private let fileName = "tasks.json"
    private let groupID = "group.com.fulu.FourQuadrants"
    
    private var fileURL: URL? {
        // Try App Group container first
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url.appendingPathComponent(fileName)
        }
        // Fallback to documents if App Group is not available (e.g. dev environment issue)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
    
    func save(tasks: [Task]) {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: url)
        } catch {
            print("Failed to save tasks: \(error)")
        }
    }
    
    func load() -> [Task] {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Task].self, from: data)
        } catch {
            print("Failed to load tasks: \(error)")
            return []
        }
    }
}
