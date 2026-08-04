import BrowstayCore
import SwiftUI

@main
struct BrowstayApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var runtime = AppRuntime.shared

  var body: some Scene {
    MenuBarExtra(BrowstayVersion.appName, systemImage: "link") {
      MenuBarContent(runtime: runtime)
    }
    .menuBarExtraStyle(.menu)
  }
}
