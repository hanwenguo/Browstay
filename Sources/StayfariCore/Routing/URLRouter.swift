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
  private let didEnqueueRoute: (@Sendable (Int) -> Void)?
  private var isEnabled: Bool
  private var routeEnqueueCount = 0
  // FIFO barrier across actor reentrancy points; each route waits for the prior
  // route's detector/opener work to finish before starting its own.
  private var routingTail: Task<Void, Never>?

  public init(detector: SafariWindowDetecting, opener: SafariOpening, isEnabled: Bool = true) {
    self.init(detector: detector, opener: opener, isEnabled: isEnabled, didEnqueueRoute: nil)
  }

  init(
    detector: SafariWindowDetecting,
    opener: SafariOpening,
    isEnabled: Bool = true,
    didEnqueueRoute: (@Sendable (Int) -> Void)?
  ) {
    self.detector = detector
    self.opener = opener
    self.isEnabled = isEnabled
    self.didEnqueueRoute = didEnqueueRoute
  }

  public func setEnabled(_ isEnabled: Bool) {
    self.isEnabled = isEnabled
  }

  public func handle(_ urls: [URL]) async -> URLRoutingSummary {
    let detector = self.detector
    let opener = self.opener
    let isEnabled = self.isEnabled
    let previousRouting = routingTail

    let routingTask = Task {
      if let previousRouting {
        await previousRouting.value
      }
      return await Self.route(
        urls,
        detector: detector,
        opener: opener,
        isEnabled: isEnabled
      )
    }

    routingTail = Task {
      _ = await routingTask.value
    }
    routeEnqueueCount += 1
    didEnqueueRoute?(routeEnqueueCount)

    return await routingTask.value
  }

  private static func route(
    _ urls: [URL],
    detector: SafariWindowDetecting,
    opener: SafariOpening,
    isEnabled: Bool
  ) async -> URLRoutingSummary {
    let routedURLs = urls.enumerated().map { index, url in
      (index: index, url: url, webURL: WebURL(url))
    }
    let validURLs = routedURLs.compactMap { item in
      item.webURL.map { (index: item.index, webURL: $0) }
    }
    var actionsByIndex: [Int: RoutingAction] = [:]

    for item in routedURLs where item.webURL == nil {
      actionsByIndex[item.index] = .rejected(item.url)
    }

    guard !validURLs.isEmpty else {
      return URLRoutingSummary(actions: orderedActions(in: urls.indices, from: actionsByIndex))
    }

    if !isEnabled {
      let actions = await openNormally(validURLs.map(\.webURL), opener: opener)
      assign(actions, to: validURLs, in: &actionsByIndex)
      return URLRoutingSummary(actions: orderedActions(in: urls.indices, from: actionsByIndex))
    }

    if await detector.hasVisibleSafariWindow() {
      let actions = await openNormally(validURLs.map(\.webURL), opener: opener)
      assign(actions, to: validURLs, in: &actionsByIndex)
      return URLRoutingSummary(actions: orderedActions(in: urls.indices, from: actionsByIndex))
    }

    let first = validURLs[0]
    let rest = Array(validURLs.dropFirst())

    do {
      try await opener.openInNewWindow(first.webURL)
      actionsByIndex[first.index] = .openedNewWindow(first.webURL.url)
      if !rest.isEmpty {
        let actions = await openNormally(rest.map(\.webURL), opener: opener)
        assign(actions, to: rest, in: &actionsByIndex)
      }
    } catch {
      let reason = String(describing: error)
      do {
        try await opener.openNormally(validURLs.map(\.webURL))
        for item in validURLs {
          actionsByIndex[item.index] = .fellBackToNormal(item.webURL.url, reason: reason)
        }
      } catch {
        let normalReason = String(describing: error)
        for item in validURLs {
          actionsByIndex[item.index] = .failed(item.webURL.url, reason: normalReason)
        }
      }
    }

    return URLRoutingSummary(actions: orderedActions(in: urls.indices, from: actionsByIndex))
  }

  private static func openNormally(_ urls: [WebURL], opener: SafariOpening) async -> [RoutingAction] {
    do {
      try await opener.openNormally(urls)
      return urls.map { .openedNormally($0.url) }
    } catch {
      let reason = String(describing: error)
      return urls.map { .failed($0.url, reason: reason) }
    }
  }

  private static func assign(
    _ actions: [RoutingAction],
    to urls: [(index: Int, webURL: WebURL)],
    in actionsByIndex: inout [Int: RoutingAction]
  ) {
    for (url, action) in zip(urls, actions) {
      actionsByIndex[url.index] = action
    }
  }

  private static func orderedActions(
    in indices: Range<Array<URL>.Index>,
    from actionsByIndex: [Int: RoutingAction]
  ) -> [RoutingAction] {
    indices.compactMap { actionsByIndex[$0] }
  }
}
