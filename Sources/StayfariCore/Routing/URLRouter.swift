import Foundation

public protocol SafariWindowDetecting: Sendable {
  func hasVisibleSafariWindow() async -> Bool
}

public protocol SafariOpening: AnyObject, Sendable {
  @MainActor func openNormally(_ urls: [WebURL]) async throws
  @MainActor func openInNewWindow(_ url: WebURL) async throws
}

public enum RoutingAction: Equatable, Sendable {
  case rejected(URL)
  case openedNormally(URL)
  case openedNewWindow(URL)
  case fellBackToNormal(URL, reason: String)
  case failed(URL, reason: String)
}

public struct URLRoutingSummary: Equatable, Sendable {
  public let actions: [RoutingAction]

  public init(actions: [RoutingAction]) {
    self.actions = actions
  }
}

public actor URLRouter {
  private let detector: SafariWindowDetecting
  private let opener: SafariOpening
  private var isEnabled: Bool

  public init(detector: SafariWindowDetecting, opener: SafariOpening, isEnabled: Bool = true) {
    self.detector = detector
    self.opener = opener
    self.isEnabled = isEnabled
  }

  public func setEnabled(_ isEnabled: Bool) {
    self.isEnabled = isEnabled
  }

  public func handle(_ urls: [URL]) async -> URLRoutingSummary {
    let validURLs = WebURL.validWebURLs(from: urls)
    var actions = urls
      .filter { WebURL($0) == nil }
      .map(RoutingAction.rejected)

    guard !validURLs.isEmpty else {
      return URLRoutingSummary(actions: actions)
    }

    if !isEnabled {
      actions.append(contentsOf: await openNormally(validURLs))
      return URLRoutingSummary(actions: actions)
    }

    if await detector.hasVisibleSafariWindow() {
      actions.append(contentsOf: await openNormally(validURLs))
      return URLRoutingSummary(actions: actions)
    }

    let first = validURLs[0]
    let rest = Array(validURLs.dropFirst())

    do {
      try await opener.openInNewWindow(first)
      actions.append(.openedNewWindow(first.url))
      if !rest.isEmpty {
        actions.append(contentsOf: await openNormally(rest))
      }
    } catch {
      let reason = String(describing: error)
      do {
        try await opener.openNormally(validURLs)
        actions.append(contentsOf: validURLs.map { .fellBackToNormal($0.url, reason: reason) })
      } catch {
        let normalReason = String(describing: error)
        actions.append(contentsOf: validURLs.map { .failed($0.url, reason: normalReason) })
      }
    }

    return URLRoutingSummary(actions: actions)
  }

  private func openNormally(_ urls: [WebURL]) async -> [RoutingAction] {
    do {
      try await opener.openNormally(urls)
      return urls.map { .openedNormally($0.url) }
    } catch {
      let reason = String(describing: error)
      return urls.map { .failed($0.url, reason: reason) }
    }
  }
}
