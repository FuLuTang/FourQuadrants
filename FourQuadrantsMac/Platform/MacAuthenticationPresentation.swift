import AppKit

@MainActor
enum MacAuthenticationPresentation {
    static func viewController() -> NSViewController? {
        NSApp.keyWindow?.contentViewController
            ?? NSApp.windows.first(where: \.isVisible)?.contentViewController
    }
}
