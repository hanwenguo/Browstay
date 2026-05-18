import AppKit
import StayfariCore
import SwiftUI

struct MenuBarContent: View {
  @Bindable var runtime: AppRuntime

  var body: some View {
    Toggle("Enabled", isOn: Binding(
      get: { runtime.isEnabled },
      set: { runtime.setEnabled($0) }
    ))

    Divider()

    Button("Set as Default") {
      runtime.setAsDefaultBrowser()
    }

    Button("Restore Safari") {
      runtime.restoreSafariAsDefaultBrowser()
    }

    Button("Refresh Status") {
      runtime.refreshDefaultBrowserStatus()
    }

    Divider()

    Button("Test Open") {
      runtime.openTestURL()
    }

    Text(runtime.defaultBrowserSummary)
      .foregroundStyle(.secondary)

    Text(runtime.lastEventSummary)
      .foregroundStyle(.secondary)

    Divider()

    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
  }
}
