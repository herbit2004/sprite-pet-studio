import AppKit
import SpriteKit

@MainActor
final class InteractiveSKView: SKView {
    var eventBus: PetEventBus?
    var onWindowMoved: ((CGPoint) -> Void)?
    var onInteraction: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var contextActionsProvider: (() -> [PetActionDefinition])?
    var onPlayAction: ((String) -> Void)?
    var projectID: String?

    private var trackingAreaReference: NSTrackingArea?
    private var dragStartMouse: CGPoint?
    private var dragStartWindowOrigin: CGPoint?
    private var didDrag = false
    private var lastDirection: PetEventType?

    var hasActiveDragSession: Bool { dragStartMouse != nil }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        post(.mouseEnter)
    }

    override func mouseExited(with event: NSEvent) {
        post(.mouseExit)
    }

    override func mouseDown(with event: NSEvent) {
        onInteraction?()
        dragStartMouse = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
        didDrag = false
        lastDirection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let mouseStart = dragStartMouse, let originStart = dragStartWindowOrigin else { return }
        let mouse = NSEvent.mouseLocation
        let delta = CGPoint(x: mouse.x - mouseStart.x, y: mouse.y - mouseStart.y)
        if !didDrag, hypot(delta.x, delta.y) >= 2 {
            didDrag = true
            post(.dragStart)
        }
        guard didDrag else { return }

        let proposedOrigin = CGPoint(x: originStart.x + delta.x, y: originStart.y + delta.y)
        let backingScale = max(1, window.backingScaleFactor)
        let origin = CGPoint(
            x: round(proposedOrigin.x * backingScale) / backingScale,
            y: round(proposedOrigin.y * backingScale) / backingScale
        )
        window.setFrameOrigin(origin)
        onInteraction?()

        // Use the latest movement, not the accumulated distance from the
        // original mouse-down point. The current run loop stays active while
        // movement pauses and changes only when the user reverses direction.
        guard abs(event.deltaX) > 0.05 else { return }
        let direction: PetEventType = event.deltaX < 0 ? .dragLeft : .dragRight
        if direction != lastDirection {
            post(direction)
            lastDirection = direction
        }
    }

    override func mouseUp(with event: NSEvent) {
        onInteraction?()
        if didDrag {
            post(.dragEnd)
            if let origin = window?.frame.origin {
                onWindowMoved?(origin)
            }
        } else {
            post(event.clickCount >= 2 ? .doubleClick : .singleClick)
        }
        dragStartMouse = nil
        dragStartWindowOrigin = nil
        didDrag = false
        lastDirection = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        onInteraction?()
        post(.rightClick)
        let menu = NSMenu(title: "桌宠工坊")
        let settingsItem = NSMenuItem(
            title: "打开设置…",
            action: #selector(openSettingsFromContextMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let actions = contextActionsProvider?() ?? []
        if !actions.isEmpty {
            menu.addItem(.separator())
            for action in actions {
                let actionItem = NSMenuItem(
                    title: "播放：\(action.name)",
                    action: #selector(playActionFromContextMenu(_:)),
                    keyEquivalent: ""
                )
                actionItem.target = self
                actionItem.representedObject = action.id
                actionItem.isEnabled = !action.frames.isEmpty
                menu.addItem(actionItem)
            }
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openSettingsFromContextMenu() {
        onOpenSettings?()
    }

    @objc private func playActionFromContextMenu(_ sender: NSMenuItem) {
        guard let actionID = sender.representedObject as? String else { return }
        onPlayAction?(actionID)
    }

    private func post(_ type: PetEventType) {
        eventBus?.post(.simple(type, projectID: projectID))
    }
}
