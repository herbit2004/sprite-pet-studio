import AppKit
import SpriteKit
import SwiftUI

struct ProjectLivePreview: NSViewRepresentable {
    let project: PetProjectDefinition
    let store: DocumentStore

    func makeNSView(context: Context) -> ProjectPreviewSKView {
        let view = ProjectPreviewSKView()
        view.configure(project: project, store: store)
        return view
    }

    func updateNSView(_ view: ProjectPreviewSKView, context: Context) {
        if view.projectSignature != project {
            view.configure(project: project, store: store)
        }
    }
}

@MainActor
final class ProjectPreviewSKView: SKView {
    private let petScene = PetScene(size: CGSize(width: 192, height: 208))
    private var project: PetProjectDefinition?
    private var timer: Timer?
    private var trackingAreaReference: NSTrackingArea?
    private var randomDeadlines: [UUID: Date] = [:]
    private var idleStartedAt = Date()
    private var mouseRuleStates: [UUID: Bool] = [:]
    private var mouseDownPoint: CGPoint?
    private var dragged = false

    var projectSignature: PetProjectDefinition? { project }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowsTransparency = true
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        preferredFramesPerSecond = 60
        petScene.scaleMode = .resizeFill
        presentScene(petScene)
        petScene.backgroundColor = .clear
        petScene.onActionFinished = { [weak petScene] _ in petScene?.returnToDefault() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        petScene.setViewportSize(bounds.size, fitSprite: true)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            timer?.invalidate()
            timer = nil
        } else if project != nil, timer == nil {
            startTimer()
        }
    }

    func configure(project: PetProjectDefinition, store: DocumentStore) {
        self.project = project
        do {
            let atlas = try TextureAtlas(imageURL: store.imageURL(for: project), project: project)
            petScene.configure(project: project, atlas: atlas)
            // configure() restores the scene's native cell size. Reapply the
            // card viewport immediately because AppKit may not call layout()
            // again when only project data changed. Without this, resizeFill
            // stretches the native scene to the card's wide aspect ratio.
            petScene.setViewportSize(bounds.size, fitSprite: true)
            randomDeadlines.removeAll()
            mouseRuleStates.removeAll()
            idleStartedAt = Date()
            startTimer()
            playTrigger(.appLaunch)
        } catch {
            // The surrounding project card still exposes metadata when an atlas is unavailable.
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        idleStartedAt = Date()
        playTrigger(.mouseEnter)
    }

    override func mouseExited(with event: NSEvent) {
        playTrigger(.mouseExit)
        petScene.returnToDefault()
    }

    override func mouseMoved(with event: NSEvent) {
        guard let project else { return }
        idleStartedAt = Date()
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        let scale = CGFloat(project.atlas.cellWidth) / max(1, bounds.width)
        let distance = Double(hypot(dx, dy) * scale)
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let angle = Double((90 - degrees + 360).truncatingRemainder(dividingBy: 360))

        var foundLook = false
        for action in project.actions where action.isEnabled && action.playback == .angleControlled {
            for rule in action.triggers where rule.isEnabled && rule.kind == .mouseLook {
                if distanceMatches(rule, distance: distance) {
                    petScene.setAngleAction(action, angleDegrees: angle)
                    foundLook = true
                }
            }
        }
        if !foundLook, project.actions.contains(where: { $0.playback == .angleControlled && petScene.currentActionID == $0.id }) {
            petScene.returnToDefault()
        }

        for action in project.actions where action.isEnabled {
            for rule in action.triggers where rule.isEnabled && rule.kind == .mouseNear {
                let matches = distanceMatches(rule, distance: distance)
                let previous = mouseRuleStates[rule.id] ?? false
                mouseRuleStates[rule.id] = matches
                if matches && !previous { petScene.play(action, force: true, restart: true) }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !dragged {
            dragged = true
            playTrigger(.dragStart)
        }
        playTrigger(point.x < start.x ? .dragLeft : .dragRight, restart: false)
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            playTrigger(.dragEnd)
        } else {
            playTrigger(event.clickCount >= 2 ? .doubleClick : .singleClick)
        }
        mouseDownPoint = nil
        dragged = false
        idleStartedAt = Date()
    }

    override func rightMouseDown(with event: NSEvent) {
        playTrigger(.rightClick)
        idleStartedAt = Date()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.handleTimer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func handleTimer() {
        guard let project else { return }
        let now = Date()
        for action in project.actions where action.isEnabled {
            for rule in action.triggers where rule.isEnabled {
                switch rule.kind {
                case .random:
                    let deadline = randomDeadlines[rule.id] ?? now.addingTimeInterval(randomInterval(rule))
                    randomDeadlines[rule.id] = deadline
                    if now >= deadline {
                        petScene.play(action, force: true, restart: true)
                        randomDeadlines[rule.id] = now.addingTimeInterval(randomInterval(rule))
                    }
                case .idle:
                    if now.timeIntervalSince(idleStartedAt) >= rule.idleSeconds {
                        petScene.play(action, force: true, restart: true)
                        idleStartedAt = now
                    }
                default:
                    break
                }
            }
        }
    }

    private func playTrigger(_ kind: TriggerKind, restart: Bool = true) {
        guard let project else { return }
        let candidates = project.actions.filter { action in
            action.isEnabled && action.triggers.contains { $0.isEnabled && $0.kind == kind }
        }
        guard let action = candidates.max(by: { $0.priority < $1.priority }) else { return }
        petScene.play(action, force: true, restart: restart)
    }

    private func distanceMatches(_ rule: TriggerRule, distance: Double) -> Bool {
        (rule.distanceCondition ?? .inside) == .inside
            ? distance <= rule.distance
            : distance >= rule.distance
    }

    private func randomInterval(_ rule: TriggerRule) -> TimeInterval {
        let lower = max(1, min(rule.minimumIntervalSeconds, rule.maximumIntervalSeconds))
        let upper = max(lower, max(rule.minimumIntervalSeconds, rule.maximumIntervalSeconds))
        return Double.random(in: lower...upper)
    }
}
