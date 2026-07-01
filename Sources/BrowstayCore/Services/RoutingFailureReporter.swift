import Foundation
import UserNotifications

@MainActor
public protocol BrowstayNotificationClient: AnyObject {
  func requestAuthorization() async
  func post(title: String, body: String) async
}

@MainActor
public final class SystemBrowstayNotificationClient: BrowstayNotificationClient {
  private let center: UNUserNotificationCenter

  public init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  public func requestAuthorization() async {
    _ = try? await center.requestAuthorization(options: [.alert, .sound])
  }

  public func post(title: String, body: String) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    try? await center.add(request)
  }
}

@MainActor
public protocol RoutingFailureReporting: AnyObject {
  func requestAuthorization() async
  func report(_ summary: URLRoutingSummary) async
}

@MainActor
public final class RoutingFailureReporter: RoutingFailureReporting {
  private let notificationClient: BrowstayNotificationClient

  public init(notificationClient: BrowstayNotificationClient = SystemBrowstayNotificationClient()) {
    self.notificationClient = notificationClient
  }

  public func requestAuthorization() async {
    await notificationClient.requestAuthorization()
  }

  public func report(_ summary: URLRoutingSummary) async {
    if let browser = unavailableBrowser(in: summary.actions) {
      let count = summary.actions.count { action in
        if case .browserUnavailable(_, browser: browser) = action {
          return true
        }
        return false
      }
      let name = BrowserDefinition.definition(for: browser).displayName
      await notificationClient.post(
        title: "\(name) is unavailable",
        body: "Browstay could not open \(linkCount(count)) because \(name) is not installed."
      )
      return
    }

    if let browser = failedBrowser(in: summary.actions) {
      let count = summary.actions.count { action in
        if case .failed(_, browser: browser, reason: _) = action {
          return true
        }
        return false
      }
      let name = BrowserDefinition.definition(for: browser).displayName
      await notificationClient.post(
        title: "Could not open in \(name)",
        body: "Browstay could not open \(linkCount(count)). Check the menu for details."
      )
      return
    }

    if let browser = fallbackBrowser(in: summary.actions) {
      let name = BrowserDefinition.definition(for: browser).displayName
      await notificationClient.post(
        title: "Opened normally in \(name)",
        body: "Current-Space automation failed; \(name) used its normal link behavior."
      )
    }
  }

  private func unavailableBrowser(in actions: [RoutingAction]) -> BrowserID? {
    for action in actions {
      if case .browserUnavailable(_, let browser) = action {
        return browser
      }
    }
    return nil
  }

  private func failedBrowser(in actions: [RoutingAction]) -> BrowserID? {
    for action in actions {
      if case .failed(_, let browser, _) = action {
        return browser
      }
    }
    return nil
  }

  private func fallbackBrowser(in actions: [RoutingAction]) -> BrowserID? {
    for action in actions {
      if case .fellBackToNormal(_, let browser, _) = action {
        return browser
      }
    }
    return nil
  }

  private func linkCount(_ count: Int) -> String {
    "\(count) \(count == 1 ? "link" : "links")"
  }
}
