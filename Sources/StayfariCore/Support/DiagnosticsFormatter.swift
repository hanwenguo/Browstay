import Foundation

public enum DiagnosticsFormatter {
  public static func describe(_ summary: URLRoutingSummary) -> String {
    guard let lastAction = summary.actions.last else {
      return "No URL handled yet"
    }

    switch lastAction {
    case .rejected(let url):
      return "Ignored unsupported URL: \(url.absoluteString)"
    case .openedNormally(let url):
      return "Opened normally: \(url.absoluteString)"
    case .openedNewWindow(let url):
      return "Opened new Safari window: \(url.absoluteString)"
    case .fellBackToNormal(let url, _):
      return "Opened normally after fallback: \(url.absoluteString)"
    case .failed(let url, let reason):
      return "Open failed: \(url.absoluteString) (\(reason))"
    }
  }

  public static func describeDefaultBrowserStatus(_ statuses: [SchemeHandlerStatus]) -> String {
    statuses
      .map { status in
        let scheme = status.scheme.rawValue.uppercased()
        let handler = status.isStayfari ? StayfariVersion.appName : (status.currentHandler ?? "none")
        return "\(scheme): \(handler)"
      }
      .joined(separator: ", ")
  }

  public static func describeSetResults(_ results: [SchemeSetResult]) -> String {
    results
      .map { result in
        let scheme = result.scheme.rawValue.uppercased()
        return "\(scheme): \(OSStatusMessage.describe(result.status))"
      }
      .joined(separator: ", ")
  }
}
