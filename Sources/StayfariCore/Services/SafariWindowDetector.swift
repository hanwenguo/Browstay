import CoreGraphics

public protocol WindowSnapshotProviding: Sendable {
  func currentOnScreenWindows() -> [WindowInfo]
}

public struct SafariWindowDetector: SafariWindowDetecting {
  private let snapshotProvider: WindowSnapshotProviding

  public init(snapshotProvider: WindowSnapshotProviding) {
    self.snapshotProvider = snapshotProvider
  }

  public func hasVisibleSafariWindow() async -> Bool {
    hasVisibleSafariWindow(in: snapshotProvider.currentOnScreenWindows())
  }

  public func hasVisibleSafariWindow(in windows: [WindowInfo]) -> Bool {
    windows.contains(where: Self.isNormalVisibleSafariWindow)
  }

  public static func isNormalVisibleSafariWindow(_ window: WindowInfo) -> Bool {
    let isSafari = window.bundleIdentifier == StayfariVersion.safariBundleIdentifier
      || (window.bundleIdentifier == nil && window.ownerName == StayfariVersion.safariOwnerName)

    return isSafari
      && window.isOnscreen
      && window.layer == 0
      && window.alpha > 0
      && window.bounds.width >= 80
      && window.bounds.height >= 80
  }
}
