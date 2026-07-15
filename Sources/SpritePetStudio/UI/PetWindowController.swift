import AppKit
import SpriteKit

@MainActor
final class PetWindowController {
    private let panel: NSPanel
    private let skView: InteractiveSKView
    private let scene: PetScene
    private let store: DocumentStore
    private let bus: PetEventBus
    private var currentProject: PetProjectDefinition?

    var onWindowMoved: ((CGPoint) -> Void)? {
        didSet { skView.onWindowMoved = onWindowMoved }
    }
    var onInteraction: (() -> Void)? {
        didSet { skView.onInteraction = onInteraction }
    }
    var onOpenSettings: (() -> Void)? {
        didSet { skView.onOpenSettings = onOpenSettings }
    }

    init(store: DocumentStore, bus: PetEventBus, projectID: String) {
        self.store = store
        self.bus = bus
        scene = PetScene(size: CGSize(width: 192, height: 208))
        skView = InteractiveSKView(frame: CGRect(x: 0, y: 0, width: 192, height: 208))
        panel = NSPanel(
            contentRect: skView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = skView
        panel.acceptsMouseMovedEvents = true

        skView.wantsLayer = true
        skView.layer?.isOpaque = false
        skView.layer?.backgroundColor = NSColor.clear.cgColor
        skView.layer?.borderWidth = 0
        skView.layer?.masksToBounds = true
        skView.alphaValue = 0
        skView.autoresizingMask = [.width, .height]
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.eventBus = bus
        skView.projectID = projectID
        skView.presentScene(scene)
        scene.onActionFinished = { [weak scene] _ in
            scene?.returnToDefault()
        }
        scene.onFirstFrameRendered = { [weak skView] in
            skView?.alphaValue = 1
        }
    }

    func apply(
        project: PetProjectDefinition,
        general: GeneralSettings,
        defaultPositionIndex: Int
    ) throws {
        let projectChanged = currentProject != project
        currentProject = project
        if projectChanged {
            skView.alphaValue = 0
            let atlas = try TextureAtlas(
                imageURL: store.imageURL(for: project),
                project: project
            )
            scene.configure(project: project, atlas: atlas)
        }

        let backingScale = panel.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        let divisor = CGFloat(greatestCommonDivisor(
            max(1, project.atlas.cellWidth),
            max(1, project.atlas.cellHeight)
        ))
        let requestedPixelScale = CGFloat(general.petScale) * backingScale
        let snappedPixelScale = round(requestedPixelScale * divisor) / divisor
        let snappedPointScale = snappedPixelScale / backingScale
        let width = CGFloat(project.atlas.cellWidth) * snappedPointScale
        let height = CGFloat(project.atlas.cellHeight) * snappedPointScale
        var frame = panel.frame
        frame.size = CGSize(width: width, height: height)
        if let x = project.desktopOriginX, let y = project.desktopOriginY {
            frame.origin = pixelAlignedOrigin(CGPoint(x: x, y: y))
        } else if panel.frame.origin == .zero, let screen = NSScreen.main {
            let cascade = CGFloat(defaultPositionIndex % 8) * 34
            frame.origin = CGPoint(
                x: screen.visibleFrame.maxX - width - 24 - cascade,
                y: screen.visibleFrame.minY + 24 + cascade
            )
        }
        frame.origin = pixelAlignedOrigin(frame.origin)
        panel.setFrame(frame, display: true)
        skView.frame = CGRect(origin: .zero, size: frame.size)
        skView.layer?.contentsScale = panel.backingScaleFactor
        panel.level = general.alwaysOnTop ? .floating : .normal
        skView.preferredFramesPerSecond = general.preferredFramesPerSecond

        if general.isPetVisible && project.showsOnDesktop {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func reloadProject(_ project: PetProjectDefinition) throws {
        currentProject = project
        skView.alphaValue = 0
        let atlas = try TextureAtlas(
            imageURL: store.imageURL(for: project),
            project: project
        )
        scene.configure(project: project, atlas: atlas)
    }

    func play(_ action: PetActionDefinition, restart: Bool, force: Bool = false) {
        scene.play(action, force: force, restart: restart)
    }

    func playForce(_ action: PetActionDefinition) {
        scene.play(action, force: true, restart: true)
    }

    func controlAngle(_ action: PetActionDefinition, angleDegrees: Double) {
        scene.setAngleAction(action, angleDegrees: angleDegrees)
    }

    func returnToDefault() {
        scene.returnToDefault()
    }

    func stopAngleAction(_ actionID: String) {
        guard scene.currentActionID == actionID else { return }
        scene.returnToDefault()
    }

    func centerInScreenCoordinates() -> CGPoint {
        CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    }

    func updateMousePassThrough(mouseLocation: CGPoint) {
        if skView.hasActiveDragSession {
            panel.ignoresMouseEvents = false
            return
        }
        let local = CGPoint(x: mouseLocation.x - panel.frame.minX, y: mouseLocation.y - panel.frame.minY)
        let center = CGPoint(x: panel.frame.width / 2, y: panel.frame.height / 2)
        let dx = (local.x - center.x) / max(1, panel.frame.width * 0.46)
        let dy = (local.y - center.y) / max(1, panel.frame.height * 0.48)
        let isOverPetInteractionArea = dx * dx + dy * dy <= 1
        panel.ignoresMouseEvents = !isOverPetInteractionArea
    }

    func resetPosition(defaultPositionIndex: Int = 0) -> CGPoint? {
        guard let screen = NSScreen.main else { return nil }
        let cascade = CGFloat(defaultPositionIndex % 8) * 34
        let origin = CGPoint(
            x: screen.visibleFrame.maxX - panel.frame.width - 24 - cascade,
            y: screen.visibleFrame.minY + 24 + cascade
        )
        let alignedOrigin = pixelAlignedOrigin(origin)
        panel.setFrameOrigin(alignedOrigin)
        return alignedOrigin
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func greatestCommonDivisor(_ first: Int, _ second: Int) -> Int {
        var a = first
        var b = second
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(1, a)
    }

    private func pixelAlignedOrigin(_ origin: CGPoint) -> CGPoint {
        let backingScale = max(1, panel.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        return CGPoint(
            x: round(origin.x * backingScale) / backingScale,
            y: round(origin.y * backingScale) / backingScale
        )
    }
}
