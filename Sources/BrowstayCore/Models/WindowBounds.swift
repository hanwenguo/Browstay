import CoreGraphics

/// Window bounds in AppleScript's global coordinate space: points measured from
/// the top-left corner of the primary display, with y increasing downward.
public struct WindowBounds: Equatable, Sendable {
  public let left: Int
  public let top: Int
  public let right: Int
  public let bottom: Int

  public init(left: Int, top: Int, right: Int, bottom: Int) {
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  }

  public var width: Int {
    right - left
  }

  public var height: Int {
    bottom - top
  }

  /// Converts an AppKit screen rectangle (bottom-left origin) to AppleScript bounds.
  public init(appKitFrame frame: CGRect, primaryScreenHeight: CGFloat) {
    self.init(
      left: Int(frame.minX.rounded()),
      top: Int((primaryScreenHeight - frame.maxY).rounded()),
      right: Int(frame.maxX.rounded()),
      bottom: Int((primaryScreenHeight - frame.minY).rounded())
    )
  }
}
