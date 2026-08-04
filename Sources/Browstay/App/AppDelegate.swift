import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    AppRuntime.shared.handleIncomingURLs(urls)
  }
}
