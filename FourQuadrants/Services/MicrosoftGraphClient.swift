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
    /// The optional projections below are kept for call sites, while the
    /// observations retain the important distinction between an omitted delta
    /// property and an explicit JSON null.
    let titleObservation: MicrosoftGraphField<String>
    let bodyObservation: MicrosoftGraphField<Body>
    let importanceObservation: MicrosoftGraphField<String>
    let statusObservation: MicrosoftGraphField<String>
    let createdDateTime: String?
    let lastModifiedDateTime: String?
    let dueDateTimeObservation: MicrosoftGraphField<DateTimeValue>
    let completedDateTimeObservation: MicrosoftGraphField<DateTimeValue>
    /// Kept opaque on purpose: Four Quadrants does not own Microsoft To Do
    /// recurrence semantics and must not reduce an unfamiliar rule to a local enum.
    let recurrence: MicrosoftGraphJSONField
    let removed: Removed?
    let extensions: [FourQuadrantsMetadata]?

    enum CodingKeys: String, CodingKey {
        case id, title, body, importance, status, createdDateTime, lastModifiedDateTime, dueDateTime, completedDateTime, recurrence, extensions
        case eTag = "@odata.etag"
        case removed = "@removed"
    }

    init(
        id: String, eTag: String?, title: String?, body: Body?, importance: String?, status: String?,
        createdDateTime: String?, lastModifiedDateTime: String?, dueDateTime: DateTimeValue?,
        completedDateTime: DateTimeValue?, recurrence: MicrosoftGraphJSONField = .unobserved,
        removed: Removed?, extensions: [FourQuadrantsMetadata]?
    ) {
        self.init(
            id: id,
            eTag: eTag,
            titleObservation: title.map { .value($0) } ?? .null,
            bodyObservation: body.map { .value($0) } ?? .null,
            importanceObservation: importance.map { .value($0) } ?? .null,
            statusObservation: status.map { .value($0) } ?? .null,
            createdDateTime: createdDateTime,
            lastModifiedDateTime: lastModifiedDateTime,
            dueDateTimeObservation: dueDateTime.map { .value($0) } ?? .null,
            completedDateTimeObservation: completedDateTime.map { .value($0) } ?? .null,
            recurrence: recurrence,
            removed: removed,
            extensions: extensions
        )
    }

    init(
        id: String,
        eTag: String?,
        titleObservation: MicrosoftGraphField<String>,
        bodyObservation: MicrosoftGraphField<Body>,
        importanceObservation: MicrosoftGraphField<String>,
        statusObservation: MicrosoftGraphField<String>,
        createdDateTime: String?,
        lastModifiedDateTime: String?,
        dueDateTimeObservation: MicrosoftGraphField<DateTimeValue>,
        completedDateTimeObservation: MicrosoftGraphField<DateTimeValue>,
        recurrence: MicrosoftGraphJSONField = .unobserved,
        removed: Removed?,
        extensions: [FourQuadrantsMetadata]?
    ) {
        self.id = id
        self.eTag = eTag
        self.titleObservation = titleObservation
        self.bodyObservation = bodyObservation
        self.importanceObservation = importanceObservation
        self.statusObservation = statusObservation
        self.createdDateTime = createdDateTime
        self.lastModifiedDateTime = lastModifiedDateTime
        self.dueDateTimeObservation = dueDateTimeObservation
        self.completedDateTimeObservation = completedDateTimeObservation
        self.recurrence = recurrence
        self.removed = removed; self.extensions = extensions
    }

    var title: String? { titleObservation.value }
    var body: Body? { bodyObservation.value }
    var importance: String? { importanceObservation.value }
    var status: String? { statusObservation.value }
    var dueDateTime: DateTimeValue? { dueDateTimeObservation.value }
    var completedDateTime: DateTimeValue? { completedDateTimeObservation.value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        eTag = try container.decodeIfPresent(String.self, forKey: .eTag)
        titleObservation = try container.decodeMicrosoftGraphField(String.self, forKey: .title)
        bodyObservation = try container.decodeMicrosoftGraphField(Body.self, forKey: .body)
        importanceObservation = try container.decodeMicrosoftGraphField(String.self, forKey: .importance)
        statusObservation = try container.decodeMicrosoftGraphField(String.self, forKey: .status)
        createdDateTime = try container.decodeIfPresent(String.self, forKey: .createdDateTime)
        lastModifiedDateTime = try container.decodeIfPresent(String.self, forKey: .lastModifiedDateTime)
        dueDateTimeObservation = try container.decodeMicrosoftGraphField(DateTimeValue.self, forKey: .dueDateTime)
        completedDateTimeObservation = try container.decodeMicrosoftGraphField(DateTimeValue.self, forKey: .completedDateTime)
        if !container.contains(.recurrence) {
            recurrence = .unobserved
        } else if try container.decodeNil(forKey: .recurrence) {
            recurrence = .null
        } else {
            recurrence = .value(try container.decode(MicrosoftGraphJSON.self, forKey: .recurrence))
        }
        removed = try container.decodeIfPresent(Removed.self, forKey: .removed)
        extensions = try container.decodeIfPresent([FourQuadrantsMetadata].self, forKey: .extensions)
    }
}

/// A Graph delta response is a projection, so `nil` alone cannot tell us
/// whether a property was omitted or explicitly cleared.
nonisolated enum MicrosoftGraphField<Value: Sendable>: Sendable {
    case unobserved
    case null
    case value(Value)

    var value: Value? {
        guard case let .value(value) = self else { return nil }
        return value
    }

    var isObserved: Bool {
        if case .unobserved = self { return false }
        return true
    }
}

private extension KeyedDecodingContainer {
    nonisolated func decodeMicrosoftGraphField<Value: Decodable & Sendable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> MicrosoftGraphField<Value> {
        guard contains(key) else { return .unobserved }
        if try decodeNil(forKey: key) { return .null }
        return .value(try decode(type, forKey: key))
    }
}

/// Distinguishes an omitted delta property from an explicit JSON null. The value
/// is persisted as JSON data in the bridge store, never interpreted as a local rule.
nonisolated enum MicrosoftGraphJSONField: Sendable {
    case unobserved
    case null
    case value(MicrosoftGraphJSON)

    var rawValue: String { switch self { case .unobserved: "unobserved"; case .null: "null"; case .value: "value" } }
    var encodedData: Data? { guard case let .value(value) = self else { return nil }; return try? JSONEncoder().encode(value) }
}

nonisolated enum MicrosoftGraphJSON: Codable, Sendable {
    case object([String: MicrosoftGraphJSON]), array([MicrosoftGraphJSON]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([String: MicrosoftGraphJSON].self) { self = .object(value) }
        else { self = .array(try c.decode([MicrosoftGraphJSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case let .object(v): try c.encode(v); case let .array(v): try c.encode(v); case let .string(v): try c.encode(v); case let .number(v): try c.encode(v); case let .bool(v): try c.encode(v); case .null: try c.encodeNil() }
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
            titleObservation: titleObservation,
            bodyObservation: bodyObservation,
            importanceObservation: importanceObservation,
            statusObservation: statusObservation,
            createdDateTime: createdDateTime,
            lastModifiedDateTime: lastModifiedDateTime,
            dueDateTimeObservation: dueDateTimeObservation,
            completedDateTimeObservation: completedDateTimeObservation,
            recurrence: recurrence,
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

    let title: String?
    let body: Body?
    let importance: String?
    let status: String?
    let dueDateTime: DateTimeValue?
    let extensions: [MicrosoftTodoTaskMetadata]?
    let includesTitle: Bool
    let includesBody: Bool
    let includesImportance: Bool
    let includesStatus: Bool
    let includesDueDateTime: Bool

    var isEmptyPatch: Bool {
        !includesTitle && !includesBody && !includesImportance && !includesStatus && !includesDueDateTime && extensions == nil
    }

    init(
        title: String?,
        body: Body?,
        importance: String?,
        status: String?,
        dueDateTime: DateTimeValue?,
        extensions: [MicrosoftTodoTaskMetadata]? = nil,
        includesTitle: Bool = true,
        includesBody: Bool = true,
        includesImportance: Bool = true,
        includesStatus: Bool = true,
        includesDueDateTime: Bool = true
    ) {
        self.title = title
        self.body = body
        self.importance = importance
        self.status = status
        self.dueDateTime = dueDateTime
        self.extensions = extensions
        self.includesTitle = includesTitle
        self.includesBody = includesBody
        self.includesImportance = includesImportance
        self.includesStatus = includesStatus
        self.includesDueDateTime = includesDueDateTime
    }

    enum CodingKeys: String, CodingKey {
        case title, body, importance, status, dueDateTime, extensions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if includesTitle { try container.encode(title, forKey: .title) }
        if includesBody { try container.encode(body, forKey: .body) }
        if includesImportance { try container.encode(importance, forKey: .importance) }
        if includesStatus { try container.encode(status, forKey: .status) }
        if includesDueDateTime { try container.encode(dueDateTime, forKey: .dueDateTime) }
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
