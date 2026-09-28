import AppIntents
import Foundation

/// The app installs the handler after opening the shared SwiftData store.
@MainActor
enum WidgetTaskCompletionBridge {
    static var complete: ((UUID) -> Bool)?
}

struct CompleteWidgetTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete task"
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }
        let completed = await MainActor.run { WidgetTaskCompletionBridge.complete?(id) ?? false }
        guard completed else { throw CompletionError.saveFailed }
        return .result()
    }

    private enum CompletionError: LocalizedError {
        case saveFailed

        var errorDescription: String? { "Unable to complete the task. Please try again." }
    }
}
