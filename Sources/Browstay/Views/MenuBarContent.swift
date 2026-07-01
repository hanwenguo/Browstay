import AppKit
import BrowstayCore
import SwiftUI

struct MenuBarContent: View {
  @Bindable var runtime: AppRuntime

  var body: some View {
    Toggle("Open Links on Current Space", isOn: Binding(
      get: { runtime.isEnabled },
      set: { runtime.setEnabled($0) }
    ))

    Picker("Browser", selection: Binding(
      get: { runtime.selectedBrowserID },
      set: { runtime.selectBrowser($0) }
    )) {
      ForEach(runtime.browserChoices) { browser in
        Text(browserLabel(browser))
          .tag(browser.id)
      }
    }

    Divider()

    Button("Set Browstay as Default") {
      runtime.setAsDefaultBrowser()
    }
    .disabled(!runtime.isBrowserInstalled(runtime.selectedBrowserID))

    Button("Restore \(runtime.selectedBrowser.displayName) as Default") {
      runtime.restoreSelectedBrowserAsDefault()
    }
    .disabled(!runtime.isBrowserInstalled(runtime.selectedBrowserID))

    Button("Refresh Browsers & Status") {
      runtime.refreshBrowsersAndStatus()
    }

    Divider()

    Button("Test Open") {
      runtime.openTestURL()
    }

    Text(runtime.defaultBrowserSummary)
      .foregroundStyle(.secondary)

    Text(runtime.selectedBrowserAvailabilitySummary)
      .foregroundStyle(.secondary)

    Text(runtime.lastEventSummary)
      .foregroundStyle(.secondary)

    Divider()

    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
  }

  private func browserLabel(_ browser: BrowserDefinition) -> String {
    runtime.isBrowserInstalled(browser.id)
      ? browser.displayName
      : "\(browser.displayName) (Unavailable)"
  }
}
