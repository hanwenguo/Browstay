import AppKit
import BrowstayCore

enum CurrentDisplay {
  /// The usable area of the display under the mouse pointer, falling back to
  /// the display AppKit considers active.
  @MainActor
  static func visibleBounds() -> WindowBounds? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    guard
      let primaryScreen = screens.first,
      let screen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
        ?? NSScreen.main
    else {
      return nil
    }

    return WindowBounds(
      appKitFrame: screen.visibleFrame,
      primaryScreenHeight: primaryScreen.frame.height
    )
  }
}
