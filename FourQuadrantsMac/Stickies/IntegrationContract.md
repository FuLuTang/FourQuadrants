# macOS ToDo便笺 integration contract

The host macOS app owns lifecycle and dependency injection. Construct one
`MacStickyCoordinator(container:taskStore:)`, inject it into the workspace
with `.environment(coordinator)`, call
`restoreWindows()` after the app is ready, and call `closeAllWindows()` only
when the app is terminating. Keep the coordinator alive while sticky windows
are open; the host must not terminate when only the main window closes. Sticky
windows can become key windows, so task checkboxes and title controls remain interactive.

The host app should listen for `.macShowTask` and open its main scene with
`openWindow(id: "main")`. The notification's `object` is the selected task's
`UUID`. Once the main scene is available, its Workspace resolves that UUID
using the shared model context and selects/routes to that task. The sticky
already calls `NSApp.activate(ignoringOtherApps: true)` before posting.

The coordinator uses its own Codable payload in `UserDefaults`; it does not
add fields to or migrate the SwiftData schema. The six ToDo modes read the
shared task store. Removing a floating window configuration only removes its
local display preferences and never removes a task.
Window frames restore from the saved configuration when each window is created;
view appearance never resets the saved position or size.

The compact state preserves the expanded frame's left edge, top edge, and width;
only the lower edge moves upward. Dragging the center title-strip grip translates
the saved expanded frame without changing its size. Double-clicking that grip
toggles the same persisted compact state as the settings menu. Clicking the
category heading opens the six-mode selector. Newly created single-category
windows start at 195 pt wide; existing saved frame sizes remain unchanged.
