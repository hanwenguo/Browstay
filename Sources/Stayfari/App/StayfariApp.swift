import AppKit
import StayfariCore
import SwiftUI

@main
struct StayfariApp: App {
  var body: some Scene {
    MenuBarExtra(StayfariVersion.appName, systemImage: "safari") {
      Text(StayfariVersion.appName)
      Divider()
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    }
  }
}
