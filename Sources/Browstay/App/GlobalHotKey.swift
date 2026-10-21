import Carbon.HIToolbox

/// A system-wide keyboard shortcut registered through Carbon, which does not
/// require Accessibility permission. The event handler holds an unretained
/// reference, so keep the instance alive for as long as the shortcut is needed.
@MainActor
final class GlobalHotKey {
  private static let signature: OSType = 0x4252_5354 // "BRST"
  private static var nextID: UInt32 = 1

  private let id: UInt32
  private let action: @MainActor () -> Void
  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?

  init?(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
    self.id = Self.nextID
    Self.nextID += 1
    self.action = action

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else {
          return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )
        guard status == noErr else {
          return status
        }

        return MainActor.assumeIsolated {
          let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
          guard hotKeyID.signature == GlobalHotKey.signature, hotKeyID.id == hotKey.id else {
            return OSStatus(eventNotHandledErr)
          }
          hotKey.action()
          return noErr
        }
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &handlerRef
    )
    guard handlerStatus == noErr else {
      return nil
    }

    let registerStatus = RegisterEventHotKey(
      UInt32(keyCode),
      UInt32(modifiers),
      EventHotKeyID(signature: Self.signature, id: id),
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    guard registerStatus == noErr else {
      RemoveEventHandler(handlerRef)
      return nil
    }
  }
}
