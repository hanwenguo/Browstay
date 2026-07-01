import AppKit
import CoreGraphics

public struct CoreGraphicsWindowSnapshotProvider: WindowSnapshotProviding {
  public init() {}

  public func currentOnScreenWindows() -> [WindowInfo] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
      return []
    }

    return rawWindows.compactMap(Self.windowInfo(from:))
  }

  static func windowInfo(from dictionary: [String: Any]) -> WindowInfo? {
    guard
      let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
      let layer = dictionary[kCGWindowLayer as String] as? Int,
      let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
      let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
    else {
      return nil
    }

    let alpha = (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
    let name = dictionary[kCGWindowName as String] as? String
    // Missing onscreen metadata defaults to true because snapshots come from .optionOnScreenOnly.
    let isOnscreen = (dictionary[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true
    let pidNumber = dictionary[kCGWindowOwnerPID as String] as? NSNumber
    let processIdentifier = pidNumber.map { pid_t($0.int32Value) }
    let bundleIdentifier = processIdentifier
      .flatMap { NSRunningApplication(processIdentifier: $0) }
      .flatMap(\.bundleIdentifier)

    return WindowInfo(
      ownerName: ownerName,
      bundleIdentifier: bundleIdentifier,
      processIdentifier: processIdentifier,
      layer: layer,
      alpha: alpha,
      bounds: bounds,
      name: name,
      isOnscreen: isOnscreen
    )
  }
}
