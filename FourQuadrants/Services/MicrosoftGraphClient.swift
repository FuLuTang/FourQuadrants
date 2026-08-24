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
    nonisolated struct DateTimeValue: Codable, Sendable { let dateTime: String? }
    nonisolated struct Removed: Decodable, Sendable {}

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

    enum CodingKeys: String, CodingKey {
        case id, title, body, importance, status, createdDateTime, lastModifiedDateTime, dueDateTime, completedDateTime
        case eTag = "@odata.etag"
        case removed = "@removed"
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
        let timeZone = "UTC"
    }

    let title: String
    let body: Body
    let importance: String
    let status: String
    let dueDateTime: DateTimeValue?
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
        try await request(url: url ?? graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", "delta"]), token: token, method: "GET")
    }

    func createTask(listID: String, payload: MicrosoftTodoTaskPayload, token: String) async throws -> MicrosoftTodoTask {
        try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks"]), token: token, method: "POST", payload: payload)
    }

    func updateTask(listID: String, taskID: String, payload: MicrosoftTodoTaskPayload, eTag: String?, token: String) async throws -> MicrosoftTodoTask {
        try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID]), token: token, method: "PATCH", payload: payload, eTag: eTag)
    }

    func deleteTask(listID: String, taskID: String, eTag: String?, token: String) async throws {
        let _: EmptyResponse = try await request(url: graphURL(pathComponents: ["me", "todo", "lists", listID, "tasks", taskID]), token: token, method: "DELETE", eTag: eTag)
    }

    private func graphURL(pathComponents: [String]) -> URL {
        pathComponents.reduce(URL(string: "https://graph.microsoft.com/v1.0")!) { url, component in
            url.appendingPathComponent(component)
        }
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
