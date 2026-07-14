import SpriteKit

@MainActor
final class PetScene: SKScene {
    private let sprite = SKSpriteNode()
    private var atlas: TextureAtlas?
    private var project: PetProjectDefinition?
    private var currentAction: PetActionDefinition?
    private var frameIndex = 0
    private var playbackDirection = 1
    private var frameStartedAt: TimeInterval?
    private var lastUpdateTime: TimeInterval = 0
    private var viewportScale: CGFloat = 1

    var onActionFinished: ((String) -> Void)?
    var currentActionID: String? { currentAction?.id }
    var currentPriority: Int { currentAction?.priority ?? Int.min }

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(sprite)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(project: PetProjectDefinition, atlas: TextureAtlas) {
        self.project = project
        self.atlas = atlas
        size = CGSize(width: project.atlas.cellWidth, height: project.atlas.cellHeight)
        viewportScale = 1
        sprite.size = size
        currentAction = nil
        frameIndex = 0
        frameStartedAt = nil
        if let action = project.defaultAction {
            play(action, force: true, restart: true)
        }
    }

    func setViewportSize(_ viewportSize: CGSize, fitSprite: Bool) {
        guard let project, viewportSize.width > 0, viewportSize.height > 0 else { return }
        size = viewportSize
        let cellSize = CGSize(width: project.atlas.cellWidth, height: project.atlas.cellHeight)
        viewportScale = fitSprite
            ? min(viewportSize.width / max(1, cellSize.width), viewportSize.height / max(1, cellSize.height))
            : 1
        sprite.size = CGSize(
            width: cellSize.width * viewportScale,
            height: cellSize.height * viewportScale
        )
        if let currentAction,
           currentAction.playableFrames.indices.contains(frameIndex) {
            renderFrame(currentAction.playableFrames[frameIndex])
        }
    }

    func play(_ action: PetActionDefinition, force: Bool = false, restart: Bool = true) {
        let frames = action.playableFrames
        guard action.isEnabled, !frames.isEmpty else { return }

        if !force, let currentAction {
            if currentAction.id == action.id, !restart { return }
            switch currentAction.interruption {
            case .never:
                return
            case .higherPriority where action.priority < currentAction.priority:
                return
            default:
                break
            }
        }

        currentAction = action
        frameIndex = 0
        playbackDirection = 1
        frameStartedAt = nil
        renderFrame(frames[0])
    }

    func returnToDefault(force: Bool = true) {
        guard let action = project?.defaultAction else { return }
        play(action, force: force, restart: currentAction?.id != action.id)
    }

    func setAngleAction(_ action: PetActionDefinition, angleDegrees: Double) {
        if currentAction?.id != action.id {
            play(action, force: action.priority >= currentPriority, restart: false)
        }
        let frames = action.playableFrames
        guard currentAction?.id == action.id, !frames.isEmpty else { return }
        let normalized = angleDegrees.truncatingRemainder(dividingBy: 360)
        let best = frames.enumerated().min { lhs, rhs in
            angularDistance(lhs.element.angleDegrees ?? inferredAngle(lhs.offset, count: frames.count), normalized)
                < angularDistance(rhs.element.angleDegrees ?? inferredAngle(rhs.offset, count: frames.count), normalized)
        }
        if let best {
            frameIndex = best.offset
            renderFrame(best.element)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        lastUpdateTime = currentTime
        guard let action = currentAction,
              action.playback != .angleControlled,
              action.playableFrames.count > 1 else {
            return
        }

        if frameStartedAt == nil {
            frameStartedAt = currentTime
            return
        }
        let frame = action.playableFrames[frameIndex]
        let duration = max(1 / 120, frame.durationMultiplier / max(1, action.framesPerSecond))
        guard currentTime - (frameStartedAt ?? currentTime) >= duration else { return }
        frameStartedAt = currentTime
        advance(action)
    }

    private func advance(_ action: PetActionDefinition) {
        let frames = action.playableFrames
        switch action.playback {
        case .loop:
            frameIndex = (frameIndex + 1) % frames.count
        case .pingPong:
            if frameIndex == frames.count - 1 { playbackDirection = -1 }
            if frameIndex == 0 { playbackDirection = 1 }
            frameIndex += playbackDirection
        case .once:
            if frameIndex >= frames.count - 1 {
                onActionFinished?(action.id)
                return
            }
            frameIndex += 1
        case .holdLast:
            frameIndex = min(frameIndex + 1, frames.count - 1)
        case .angleControlled:
            return
        }
        renderFrame(frames[frameIndex])
    }

    private func renderFrame(_ frame: PetFrameDefinition) {
        guard let atlas else { return }
        sprite.texture = atlas.texture(for: frame)
        sprite.position = CGPoint(
            x: frame.offsetX * Double(viewportScale),
            y: frame.offsetY * Double(viewportScale)
        )
        sprite.setScale(frame.scale)
    }

    private func inferredAngle(_ index: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return Double(index) * 360 / Double(count)
    }

    private func angularDistance(_ first: Double, _ second: Double) -> Double {
        let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }
}
