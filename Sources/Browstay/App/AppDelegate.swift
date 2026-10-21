import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var newWindowHotKey: GlobalHotKey?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    newWindowHotKey = GlobalHotKey(
      keyCode: NewWindowShortcut.carbonKeyCode,
      modifiers: NewWindowShortcut.carbonModifiers
    ) {
      AppRuntime.shared.openNewWindowOnCurrentDisplay()
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    AppRuntime.shared.handleIncomingURLs(urls)
  }
}
