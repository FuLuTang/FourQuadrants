# macOS Stickies integration contract

The host macOS app owns lifecycle and dependency injection. Construct one
`MacStickyCoordinator(container:taskStore:)`, inject it into the app's
`MacStickiesLibraryView` with `.environment(coordinator)`, call
`restoreWindows()` after the app is ready, and call `closeAllWindows()` only
when the app is terminating. Keep the coordinator alive while sticky windows
are open; the host must not terminate when only the main window closes. Sticky
windows can become key windows, so their task fields remain editable.

The host app should listen for `.macShowTask` and open its main scene with
`openWindow(id: "main")`. The notification's `object` is the selected task's
`UUID`. Once the main scene is available, its Workspace resolves that UUID
using the shared model context and selects/routes to that task. The sticky
already calls `NSApp.activate(ignoringOtherApps: true)` before posting.

The coordinator uses its own Codable payload in `UserDefaults`; it does not
add fields to or migrate the SwiftData schema. Removing a sticky configuration
only removes its saved UUID references and window preferences.
Window frames restore from the saved configuration when each window is created;
view appearance never resets the saved position or size.
