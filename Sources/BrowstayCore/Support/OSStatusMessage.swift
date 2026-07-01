import CoreServices
import Foundation

public enum OSStatusMessage {
  public static func describe(_ status: OSStatus) -> String {
    if status == noErr {
      return "OK"
    }

    return "OSStatus \(status)"
  }
}
