import Foundation

nonisolated enum MicrosoftGraphError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)
    case throttled(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Microsoft Graph 返回了无法识别的数据。"
        case let .httpStatus(status, message): "Microsoft Graph 请求失败（\(status)）：\(message)"
        case .throttled: "Microsoft 服务暂时繁忙，请稍后重试。"
        }
    }
}

nonisolated struct MicrosoftTodoList: Decodable, Sendable {
    let id: String
    let displayName: String
    let wellknownListName: String?
}

nonisolated struct MicrosoftTodoTask: Decodable, Sendable {
    nonisolated struct Body: Codable, Sendable { let content: String? }
    nonisolated struct DateTimeValue: Codable, Sendable {
        let dateTime: String?
        let timeZone: String?
    }
    nonisolated struct Removed: Decodable, Sendable {}
    nonisolated struct FourQuadrantsMetadata: Decodable, Sendable {
        let extensionName: String?
        let schemaVersion: Int?
        let localTaskIdentifier: String?
        let manualIsUrgent: Bool?
        let hasUrgentThresholdDays: Bool?
        let urgentThresholdDays: Int?
        let hasOriginalUrgentThresholdDays: Bool?
        let originalUrgentThresholdDays: Int?
        let hasOriginalImportance: Bool?
        let originalImportance: String?
        let isTop: Bool?
        let operationIdentifier: String?
    }

    let id: String
    let eTag: String?
    let title: String?
    let body: Body?
    let importance: String?
    let status: String?
    let createdDateTime: String?
    let lastModifiedDateTime: String?
    let dueDateTime: DateTimeValue?
    let completedDateTime: DateTimeValue?
    let removed: Removed?
    let extensions: [FourQuadrantsMetadata]?

    enum CodingKeys: String, CodingKey {
        case id, title, body, importance, status, createdDateTime, lastModifiedDateTime, dueDateTime, completedDateTime, extensions
        case eTag = "@odata.etag"
        case removed = "@removed"
    }
}

nonisolated extension MicrosoftTodoTask {
    var fourQuadrantsMetadata: FourQuadrantsMetadata? {
        extensions?.first { $0.extensionName == MicrosoftTodoTaskMetadata.extensionName }
    }

    func replacingExtensions(_ extensions: [FourQuadrantsMetadata]) -> MicrosoftTodoTask {
        MicrosoftTodoTask(
            id: id,
            eTag: eTag,
            title: title,
            body: body,
            importance: importance,
            status: status,
            createdDateTime: createdDateTime,
            lastModifiedDateTime: lastModifiedDateTime,
            dueDateTime: dueDateTime,
            completedDateTime: completedDateTime,
            removed: removed,
            extensions: extensions
        )
    }
}

nonisolated struct MicrosoftGraphDeltaPage<Value: Decodable & Sendable>: Decodable, Sendable {
    let value: [Value]
    let nextLink: String?
    let deltaLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
        case deltaLink = "@odata.deltaLink"
    }
}

nonisolated struct MicrosoftTodoTaskPayload: Encodable, Sendable {
    nonisolated struct Body: Encodable, Sendable {
        let content: String
        let contentType = "text"
    }
    nonisolated struct DateTimeValue: Encodable, Sendable {
        let dateTime: String
        let timeZone: String

        init(date: Date, timeZone: TimeZone = .current) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateTime = formatter.string(from: date)
            self.timeZone = timeZone.identifier
        }

        init(dueDateKey: String, timeZoneIdentifier: String) {
            dateTime = "\(dueDateKey)T00:00:00"
            timeZone = MicrosoftGraphTimeZone.graphIdentifier(for: timeZoneIdentifier)
        }
    }

    let title: String
    let body: Body
    let importance: String
    let status: String
    let dueDateTime: DateTimeValue?
    let extensions: [MicrosoftTodoTaskMetadata]?

    init(
        title: String,
        body: Body,
        importance: String,
        status: String,
        dueDateTime: DateTimeValue?,
        extensions: [MicrosoftTodoTaskMetadata]? = nil
    ) {
        self.title = title
        self.body = body
        self.importance = importance
        self.status = status
        self.dueDateTime = dueDateTime
        self.extensions = extensions
    }

    enum CodingKeys: String, CodingKey {
        case title, body, importance, status, dueDateTime, extensions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(importance, forKey: .importance)
        try container.encode(status, forKey: .status)
        // A missing due date must clear the Graph field during PATCH instead of leaving it stale.
        try container.encode(dueDateTime, forKey: .dueDateTime)
        try container.encodeIfPresent(extensions, forKey: .extensions)
    }
}

nonisolated struct MicrosoftTodoTaskMetadata: Codable, Sendable {
    static let extensionName = "com.fulu.FourQuadrants.taskMetadata"

    let extensionName: String
    let schemaVersion: Int
    let localTaskIdentifier: String
    let manualIsUrgent: Bool
    let hasUrgentThresholdDays: Bool
    let urgentThresholdDays: Int
    let hasOriginalUrgentThresholdDays: Bool
    let originalUrgentThresholdDays: Int
    let hasOriginalImportance: Bool
    let originalImportance: String
    let isTop: Bool
    let operationIdentifier: String?

    init(
        localTaskIdentifier: String,
        manualIsUrgent: Bool,
        urgentThresholdDays: Int?,
        originalUrgentThresholdDays: Int?,
        originalImportance: String?,
        isTop: Bool,
        operationIdentifier: UUID? = nil
    ) {
        extensionName = Self.extensionName
        schemaVersion = 1
        self.localTaskIdentifier = localTaskIdentifier
        self.manualIsUrgent = manualIsUrgent
        hasUrgentThresholdDays = urgentThresholdDays != nil
        self.urgentThresholdDays = urgentThresholdDays ?? 0
        hasOriginalUrgentThresholdDays = originalUrgentThresholdDays != nil
        self.originalUrgentThresholdDays = originalUrgentThresholdDays ?? 0
        hasOriginalImportance = originalImportance != nil
        self.originalImportance = originalImportance ?? ""
        self.isTop = isTop
        self.operationIdentifier = operationIdentifier?.uuidString
    }

    enum CodingKeys: String, CodingKey {
        case extensionName, schemaVersion, localTaskIdentifier, manualIsUrgent, hasUrgentThresholdDays, urgentThresholdDays, hasOriginalUrgentThresholdDays, originalUrgentThresholdDays, hasOriginalImportance, originalImportance, isTop, operationIdentifier
        case odataType = "@odata.type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extensionName = try container.decode(String.self, forKey: .extensionName)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        operationIdentifier = try container.decodeIfPresent(String.self, forKey: .operationIdentifier)
        localTaskIdentifier = try container.decode(String.self, forKey: .localTaskIdentifier)
        manualIsUrgent = try container.decode(Bool.self, forKey: .manualIsUrgent)
        hasUrgentThresholdDays = try container.decode(Bool.self, forKey: .hasUrgentThresholdDays)
        urgentThresholdDays = try container.decode(Int.self, forKey: .urgentThresholdDays)
        hasOriginalUrgentThresholdDays = try container.decode(Bool.self, forKey: .hasOriginalUrgentThresholdDays)
        originalUrgentThresholdDays = try container.decode(Int.self, forKey: .originalUrgentThresholdDays)
        hasOriginalImportance = try container.decode(Bool.self, forKey: .hasOriginalImportance)
        originalImportance = try container.decode(String.self, forKey: .originalImportance)
        isTop = try container.decode(Bool.self, forKey: .isTop)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("microsoft.graph.openTypeExtension", forKey: .odataType)
        try container.encode(extensionName, forKey: .extensionName)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(localTaskIdentifier, forKey: .localTaskIdentifier)
        try container.encode(manualIsUrgent, forKey: .manualIsUrgent)
        try container.encode(hasUrgentThresholdDays, forKey: .hasUrgentThresholdDays)
        try container.encode(urgentThresholdDays, forKey: .urgentThresholdDays)
        try container.encode(hasOriginalUrgentThresholdDays, forKey: .hasOriginalUrgentThresholdDays)
        try container.encode(originalUrgentThresholdDays, forKey: .originalUrgentThresholdDays)
        try container.encode(hasOriginalImportance, forKey: .hasOriginalImportance)
        try container.encode(originalImportance, forKey: .originalImportance)
        try container.encode(isTop, forKey: .isTop)
        try container.encodeIfPresent(operationIdentifier, forKey: .operationIdentifier)
    }
}

nonisolated enum MicrosoftGraphTimeZone {
    private static let windowsIdentifiers: [String: String] = [
        "Asia/Shanghai": "China Standard Time",
        "Europe/Paris": "Romance Standard Time",
        "America/New_York": "Eastern Standard Time",
        "America/Los_Angeles": "Pacific Standard Time",
        "UTC": "UTC"
    ]

    private static let foundationIdentifiers: [String: String] = [
        "China Standard Time": "Asia/Shanghai",
        "Romance Standard Time": "Europe/Paris",
        "Eastern Standard Time": "America/New_York",
        "Pacific Standard Time": "America/Los_Angeles",
        "UTC": "UTC"
    ]

    static func graphIdentifier(for identifier: String) -> String {
        windowsIdentifiers[identifier] ?? identifier
    }

    static func foundationIdentifier(for identifier: String) -> String {
        foundationIdentifiers[identifier] ?? identifier
    }
}

nonisolated struct MicrosoftGraphClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func listDeltaPage(url: URL? = nil, token: String) async throws -> MicrosoftGraphDeltaPage<MicrosoftTodoList> {
        try await request(url: url ?? graphURL(pathComponents: ["me", "todo", "lists", "delta"]), token: token, method: "GET")
    }

    func taskDeltaPage(listID: String, url: URL? = nil, token: String) async throws -> MicrosoftGraphDeltaPage<MicrosoftTodoTask> {
        let initialURL = graphURL(
            pathComponents: ["me", "todo", "lists", listID, "tasks", "delta"],
            queryItems: [URLQueryItem(name: "$expand", value: "extensions")]
        )
        return try await request(url: url ?? initialURL, token: token, method: "GET")
    }

    func createTask(listID: String, payload: MicrosoftTodoTaskPayload, token: String) async throws -> MicrosoftTodoTask {
        try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks"]), token: token, method: "POST", payload: payload)
    }

    func fetchTask(listID: String, taskID: String, token: String) async throws -> MicrosoftTodoTask {
        return try await request(
            url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID]),
            token: token,
            method: "GET"
        )
    }

    func updateTask(listID: String, taskID: String, payload: MicrosoftTodoTaskPayload, eTag: String?, token: String) async throws -> MicrosoftTodoTask {
        try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID]), token: token, method: "PATCH", payload: payload, eTag: eTag)
    }

    func updateTaskMetadata(listID: String, taskID: String, metadata: MicrosoftTodoTaskMetadata, token: String) async throws {
        let url = graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID, "extensions", MicrosoftTodoTaskMetadata.extensionName])
        let _: MicrosoftTodoTaskMetadata = try await request(url: url, token: token, method: "PATCH", payload: metadata)
    }

    func createTaskMetadata(listID: String, taskID: String, metadata: MicrosoftTodoTaskMetadata, token: String) async throws {
        let url = graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID, "extensions"])
        let _: MicrosoftTodoTaskMetadata = try await request(url: url, token: token, method: "POST", payload: metadata)
    }

    func fetchTaskMetadata(listID: String, taskID: String, token: String) async throws -> MicrosoftTodoTask.FourQuadrantsMetadata {
        try await request(
            url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID, "extensions", MicrosoftTodoTaskMetadata.extensionName]),
            token: token,
            method: "GET"
        )
    }

    func deleteTask(listID: String, taskID: String, eTag: String?, token: String) async throws {
        let _: EmptyResponse = try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID]), token: token, method: "DELETE", eTag: eTag)
    }

    private func graphURL(pathComponents: [String], queryItems: [URLQueryItem] = []) -> URL {
        let url = pathComponents.reduce(URL(string: "https://graph.microsoft.com/v1.0")!) { url, component in
            url.appendingPathComponent(component)
        }
        guard !queryItems.isEmpty else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return components.url!
    }

    private func request<Response: Decodable>(url: URL, token: String, method: String, payload: (any Encodable)? = nil, eTag: String? = nil) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("odata.maxpagesize=100", forHTTPHeaderField: "Prefer")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "client-request-id")
        if let eTag { request.setValue(eTag, forHTTPHeaderField: "If-Match") }
        if let payload {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(payload))
        }

        for attempt in 0 ..< 3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw MicrosoftGraphError.invalidResponse }
                if response.statusCode == 429 {
                    let retryAfter = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
                    if method != "POST", attempt < 2 {
                        try await Task.sleep(for: .seconds(retryAfter))
                        continue
                    }
                    throw MicrosoftGraphError.throttled(retryAfter)
                }
                if (500 ... 599).contains(response.statusCode), method != "POST", attempt < 2 {
                    try await Task.sleep(for: .seconds(Double(1 << attempt)))
                    continue
                }
                guard (200 ... 299).contains(response.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? ""
                    throw MicrosoftGraphError.httpStatus(response.statusCode, message)
                }
                if Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
                return try decoder.decode(Response.self, from: data)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as MicrosoftGraphError {
                throw error
            } catch {
                if method != "POST", attempt < 2 {
                    try await Task.sleep(for: .seconds(Double(1 << attempt)))
                    continue
                }
                throw error
            }
        }
        throw MicrosoftGraphError.invalidResponse
    }
}

nonisolated private struct EmptyResponse: Decodable {}

nonisolated private struct AnyEncodable: Encodable {
    private let encodeBody: (Encoder) throws -> Void
    init(_ value: any Encodable) { encodeBody = value.encode }
    func encode(to encoder: Encoder) throws { try encodeBody(encoder) }
}
