import CoreServices
import Foundation

public enum BrowserScheme: String, CaseIterable, Sendable {
  case http
  case https
}

public struct SchemeHandlerStatus: Equatable, Sendable {
  public let scheme: BrowserScheme
  public let currentHandler: String?
  public let isBrowstay: Bool
}

public struct SchemeSetResult: Equatable, Sendable {
  public let scheme: BrowserScheme
  public let requestedHandler: String
  public let status: OSStatus

  public var succeeded: Bool {
    status == noErr
  }
}

public protocol LaunchServicesClient: AnyObject {
  func copyDefaultHandler(for scheme: String) -> String?
  func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus
}

public final class SystemLaunchServicesClient: LaunchServicesClient {
  public init() {}

  public func copyDefaultHandler(for scheme: String) -> String? {
    LSCopyDefaultHandlerForURLScheme(scheme as CFString)?
      .takeRetainedValue() as String?
  }

  public func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus {
    LSSetDefaultHandlerForURLScheme(scheme as CFString, handler as CFString)
  }
}

public final class DefaultBrowserManager {
  private let ownBundleIdentifier: String
  private let launchServicesClient: LaunchServicesClient

  public init(
    ownBundleIdentifier: String = BrowstayVersion.bundleIdentifier,
    launchServicesClient: LaunchServicesClient = SystemLaunchServicesClient()
  ) {
    self.ownBundleIdentifier = ownBundleIdentifier
    self.launchServicesClient = launchServicesClient
  }

  public func status() -> [SchemeHandlerStatus] {
    BrowserScheme.allCases.map { scheme in
      let handler = launchServicesClient.copyDefaultHandler(for: scheme.rawValue)
      return SchemeHandlerStatus(
        scheme: scheme,
        currentHandler: handler,
        isBrowstay: handler == ownBundleIdentifier
      )
    }
  }

  public func setBrowstayAsDefault() -> [SchemeSetResult] {
    setDefaultHandler(ownBundleIdentifier)
  }

  public func restoreDefault(to browser: BrowserDefinition) -> [SchemeSetResult] {
    setDefaultHandler(browser.bundleIdentifier)
  }

  private func setDefaultHandler(_ handler: String) -> [SchemeSetResult] {
    BrowserScheme.allCases.map { scheme in
      let status = launchServicesClient.setDefaultHandler(handler, for: scheme.rawValue)
      return SchemeSetResult(scheme: scheme, requestedHandler: handler, status: status)
    }
  }
}
