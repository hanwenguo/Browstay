import AppKit
import Foundation

public enum SafariOpenError: Error, Equatable, LocalizedError {
  case safariNotFound
  case appleScriptCreationFailed
  case appleScriptFailed(String)

  public var errorDescription: String? {
    switch self {
    case .safariNotFound:
      return "Safari could not be found."
    case .appleScriptCreationFailed:
      return "Stayfari could not create the Safari automation script."
    case .appleScriptFailed(let message):
      return "Safari automation failed: \(message)"
    }
  }
}

@MainActor
public final class SafariOpener: SafariOpening {
  private let workspace: NSWorkspace

  public init(workspace: NSWorkspace = .shared) {
    self.workspace = workspace
  }

  public func openNormally(_ urls: [WebURL]) async throws {
    guard !urls.isEmpty else {
      return
    }

    let safariURL = try safariApplicationURL()
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.promptsUserIfNeeded = true
    configuration.allowsRunningApplicationSubstitution = true

    _ = try await workspace.open(
      urls.map(\.url),
      withApplicationAt: safariURL,
      configuration: configuration
    )
  }

  public func openInNewWindow(_ url: WebURL) async throws {
    let source = Self.newWindowScriptSource(for: url)
    guard let script = NSAppleScript(source: source) else {
      throw SafariOpenError.appleScriptCreationFailed
    }

    var errorInfo: NSDictionary?
    script.executeAndReturnError(&errorInfo)

    if let errorInfo {
      throw SafariOpenError.appleScriptFailed(errorInfo.description)
    }
  }

  private func safariApplicationURL() throws -> URL {
    guard let safariURL = workspace.urlForApplication(withBundleIdentifier: StayfariVersion.safariBundleIdentifier) else {
      throw SafariOpenError.safariNotFound
    }

    return safariURL
  }

  public nonisolated static func newWindowScriptSource(for url: WebURL) -> String {
    """
    tell application id "\(StayfariVersion.safariBundleIdentifier)"
      activate
      make new document with properties {URL:\(appleScriptStringLiteral(url.url.absoluteString))}
    end tell
    """
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
