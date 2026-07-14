import CoreGraphics
import Foundation

enum PetEventType: String {
    case appLaunch
    case timer
    case mouseMoved
    case mouseEnter
    case mouseExit
    case singleClick
    case doubleClick
    case rightClick
    case dragStart
    case dragLeft
    case dragRight
    case dragEnd
    case systemWake
    case systemSleep
    case screenLocked
    case screenUnlocked
    case activeAppChanged
    case external
    case manual
}

struct PetEvent {
    var type: PetEventType
    var date = Date()
    var point: CGPoint?
    var distance: Double?
    var angleDegrees: Double?
    var stringValue: String?
    var idleSeconds: Double?
    var projectID: String?

    static func simple(_ type: PetEventType, projectID: String? = nil) -> PetEvent {
        PetEvent(type: type, projectID: projectID)
    }
}

@MainActor
final class PetEventBus {
    typealias Handler = (PetEvent) -> Void
    private var handlers: [UUID: Handler] = [:]

    @discardableResult
    func subscribe(_ handler: @escaping Handler) -> UUID {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func unsubscribe(_ token: UUID) {
        handlers.removeValue(forKey: token)
    }

    func post(_ event: PetEvent) {
        for handler in handlers.values {
            handler(event)
        }
    }
}
