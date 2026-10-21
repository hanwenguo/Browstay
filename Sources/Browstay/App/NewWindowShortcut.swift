import Carbon.HIToolbox
import SwiftUI

/// Control-Option-Command-N opens a selected-browser window on the current
/// display and Desktop.
enum NewWindowShortcut {
  static let carbonKeyCode = kVK_ANSI_N
  static let carbonModifiers = controlKey | optionKey | cmdKey

  static let keyEquivalent: SwiftUI.KeyEquivalent = "n"
  static let eventModifiers: SwiftUI.EventModifiers = [.control, .option, .command]
}
