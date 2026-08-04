import AppKit
import Foundation

public protocol BrowserApplicationLocating {
  func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
}

public final class WorkspaceBrowserApplicationLocator: BrowserApplicationLocating {
  private let workspace: NSWorkspace

  public init(workspace: NSWorkspace = .shared) {
    self.workspace = workspace
  }

  public func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
    workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }
}

public struct BrowserInstallation: Equatable, Sendable {
  public let definition: BrowserDefinition
  public let applicationURL: URL

  public init(definition: BrowserDefinition, applicationURL: URL) {
    self.definition = definition
    self.applicationURL = applicationURL
  }
}

public final class BrowserCatalog {
  private let applicationLocator: BrowserApplicationLocating

  public init(applicationLocator: BrowserApplicationLocating = WorkspaceBrowserApplicationLocator()) {
    self.applicationLocator = applicationLocator
  }

  public func installedBrowsers() -> [BrowserInstallation] {
    BrowserDefinition.supported.compactMap(installation(for:))
  }

  public func installation(for browser: BrowserDefinition) -> BrowserInstallation? {
    guard let applicationURL = applicationLocator.applicationURL(
      forBundleIdentifier: browser.bundleIdentifier
    ) else {
      return nil
    }

    return BrowserInstallation(definition: browser, applicationURL: applicationURL)
  }
}
