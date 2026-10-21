import AppKit
import Foundation

public enum BrowserOpenError: Error, Equatable, LocalizedError {
  case browserNotFound(BrowserID)
  case appleScriptCreationFailed
  case appleScriptFailed(String)

  public var errorDescription: String? {
    switch self {
    case .browserNotFound(let browserID):
      return "\(BrowserDefinition.definition(for: browserID).displayName) could not be found."
    case .appleScriptCreationFailed:
      return "Browstay could not create the browser automation script."
    case .appleScriptFailed(let message):
      return "Browser automation failed: \(message)"
    }
  }
}

@MainActor
public protocol BrowserWorkspaceOpening: AnyObject {
  func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
  func open(_ urls: [URL], withApplicationAt applicationURL: URL) async throws
}

@MainActor
public final class SystemBrowserWorkspace: BrowserWorkspaceOpening {
  private let workspace: NSWorkspace

  public init(workspace: NSWorkspace = .shared) {
    self.workspace = workspace
  }

  public func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
    workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }

  public func open(_ urls: [URL], withApplicationAt applicationURL: URL) async throws {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.promptsUserIfNeeded = true
    configuration.allowsRunningApplicationSubstitution = true

    _ = try await workspace.open(
      urls,
      withApplicationAt: applicationURL,
      configuration: configuration
    )
  }
}

@MainActor
public protocol AppleScriptExecuting: AnyObject {
  func execute(source: String) throws
}

@MainActor
public final class SystemAppleScriptExecutor: AppleScriptExecuting {
  public init() {}

  public func execute(source: String) throws {
    guard let script = NSAppleScript(source: source) else {
      throw BrowserOpenError.appleScriptCreationFailed
    }

    var errorInfo: NSDictionary?
    script.executeAndReturnError(&errorInfo)

    if let errorInfo {
      throw BrowserOpenError.appleScriptFailed(errorInfo.description)
    }
  }
}

@MainActor
public protocol BrowserOpening: AnyObject, Sendable {
  func isAvailable(_ browser: BrowserDefinition) -> Bool
  func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws
  func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws
  func openEmptyWindow(in browser: BrowserDefinition, within bounds: WindowBounds?) async throws
}

@MainActor
public final class BrowserOpener: BrowserOpening {
  private let workspace: BrowserWorkspaceOpening
  private let scriptExecutor: AppleScriptExecuting

  public init(
    workspace: BrowserWorkspaceOpening = SystemBrowserWorkspace(),
    scriptExecutor: AppleScriptExecuting = SystemAppleScriptExecutor()
  ) {
    self.workspace = workspace
    self.scriptExecutor = scriptExecutor
  }

  public func isAvailable(_ browser: BrowserDefinition) -> Bool {
    workspace.applicationURL(forBundleIdentifier: browser.bundleIdentifier) != nil
  }

  public func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws {
    guard !urls.isEmpty else {
      return
    }

    guard let applicationURL = workspace.applicationURL(
      forBundleIdentifier: browser.bundleIdentifier
    ) else {
      throw BrowserOpenError.browserNotFound(browser.id)
    }

    try await workspace.open(urls.map(\.url), withApplicationAt: applicationURL)
  }

  public func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws {
    guard isAvailable(browser) else {
      throw BrowserOpenError.browserNotFound(browser.id)
    }

    try scriptExecutor.execute(source: Self.newWindowScriptSource(for: url, browser: browser))
  }

  public func openEmptyWindow(
    in browser: BrowserDefinition,
    within bounds: WindowBounds?
  ) async throws {
    guard isAvailable(browser) else {
      throw BrowserOpenError.browserNotFound(browser.id)
    }

    try scriptExecutor.execute(
      source: Self.emptyWindowScriptSource(for: browser, within: bounds)
    )
  }

  public nonisolated static func newWindowScriptSource(
    for url: WebURL,
    browser: BrowserDefinition
  ) -> String {
    let literal = appleScriptStringLiteral(url.url.absoluteString)

    switch browser.newWindowStrategy {
    case .safariDocument, .orionDocument:
      return """
      tell application id "\(browser.bundleIdentifier)"
        activate
        make new document with properties {URL:\(literal)}
      end tell
      """
    case .chromiumWindow:
      return """
      tell application id "\(browser.bundleIdentifier)"
        activate
        set newWindow to make new window with properties {mode:"normal"}
        set URL of active tab of newWindow to \(literal)
      end tell
      """
    }
  }

  /// Creates a window on the current Space. When `bounds` is given and the
  /// browser placed the window elsewhere, the window is moved and centered
  /// inside `bounds`, shrinking it if it does not fit.
  public nonisolated static func emptyWindowScriptSource(
    for browser: BrowserDefinition,
    within bounds: WindowBounds?
  ) -> String {
    var lines = [
      "tell application id \"\(browser.bundleIdentifier)\"",
      "  activate"
    ]

    switch browser.newWindowStrategy {
    case .safariDocument, .orionDocument:
      lines += [
        "  make new document",
        "  set newWindow to front window"
      ]
    case .chromiumWindow:
      lines += [
        "  set newWindow to make new window with properties {mode:\"normal\"}"
      ]
    }

    if let bounds {
      lines += [
        "  set {windowLeft, windowTop, windowRight, windowBottom} to bounds of newWindow",
        "  set windowCenterX to (windowLeft + windowRight) / 2",
        "  set windowCenterY to (windowTop + windowBottom) / 2",
        "  if windowCenterX < \(bounds.left) or windowCenterX > \(bounds.right) "
          + "or windowCenterY < \(bounds.top) or windowCenterY > \(bounds.bottom) then",
        "    set windowWidth to windowRight - windowLeft",
        "    if windowWidth > \(bounds.width) then set windowWidth to \(bounds.width)",
        "    set windowHeight to windowBottom - windowTop",
        "    if windowHeight > \(bounds.height) then set windowHeight to \(bounds.height)",
        "    set newLeft to \(bounds.left) + (\(bounds.width) - windowWidth) div 2",
        "    set newTop to \(bounds.top) + (\(bounds.height) - windowHeight) div 2",
        "    set bounds of newWindow to {newLeft, newTop, newLeft + windowWidth, newTop + windowHeight}",
        "  end if"
      ]
    }

    lines.append("end tell")
    return lines.joined(separator: "\n")
  }

  public nonisolated static func appleScriptStringLiteral(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")

    return "\"\(escaped)\""
  }
}
