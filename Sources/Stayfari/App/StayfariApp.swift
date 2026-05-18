import StayfariCore
import SwiftUI

@main
struct StayfariApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var runtime = AppRuntime.shared

  var body: some Scene {
    MenuBarExtra(StayfariVersion.appName, systemImage: "safari") {
      MenuBarContent(runtime: runtime)
    }
    .menuBarExtraStyle(.menu)
  }
}
