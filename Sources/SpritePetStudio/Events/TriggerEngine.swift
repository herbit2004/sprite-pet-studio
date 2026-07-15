import Foundation

@MainActor
final class TriggerEngine {
    private let bus: PetEventBus
    private let projectID: String
    private var subscription: UUID?
    private var randomDeadlines: [UUID: Date] = [:]
    private var cooldowns: [UUID: Date] = [:]
    private var mouseInsideRules: [UUID: Bool] = [:]
    private var idleRulesHaveFired: Set<UUID> = []
    private var scheduledFireKeys: [UUID: String] = [:]
    private var delayedFires: [UUID: Task<Void, Never>] = [:]
    private var lastTimerEvaluation = Date.distantPast
    private var angleActionID: String?
    private var isDragging = false

    var projectProvider: (() -> PetProjectDefinition?)?
    var playAction: ((PetActionDefinition, Bool, Bool) -> Void)?
    var controlAngle: ((PetActionDefinition, Double) -> Void)?
    var stopAngleControl: ((String) -> Void)?
    var petCenterProvider: (() -> CGPoint?)?

    init(bus: PetEventBus, projectID: String) {
        self.bus = bus
        self.projectID = projectID
    }

    func start() {
        subscription = bus.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let subscription { bus.unsubscribe(subscription) }
        subscription = nil
        cancelDelayedFires()
    }

    func reset() {
        cancelDelayedFires()
        randomDeadlines.removeAll()
        cooldowns.removeAll()
        mouseInsideRules.removeAll()
        idleRulesHaveFired.removeAll()
        scheduledFireKeys.removeAll()
        angleActionID = nil
        isDragging = false
    }

    private func handle(_ incomingEvent: PetEvent) {
        if let targetProjectID = incomingEvent.projectID, targetProjectID != projectID { return }
        var event = incomingEvent
        if event.type == .mouseMoved,
           let mouse = event.point,
           let center = petCenterProvider?() {
            let dx = mouse.x - center.x
            let dy = mouse.y - center.y
            event.distance = hypot(dx, dy)
            var degrees = atan2(dy, dx) * 180 / .pi
            if degrees < 0 { degrees += 360 }
            event.angleDegrees = (90 - degrees + 360).truncatingRemainder(dividingBy: 360)
        }
        guard let project = projectProvider?() else { return }

        if event.type == .dragStart {
            isDragging = true
            if let activeAngleActionID = angleActionID {
                stopAngleControl?(activeAngleActionID)
                angleActionID = nil
            }
        } else if event.type == .dragEnd {
            isDragging = false
        } else if isDragging,
                  event.type != .dragLeft,
                  event.type != .dragRight {
            // Dragging is an exclusive interaction session. Random, hover,
            // look-direction and system events must not steal its animation.
            return
        }

        if event.type == .timer {
            guard event.date.timeIntervalSince(lastTimerEvaluation) >= 0.5 else { return }
            lastTimerEvaluation = event.date
        }

        var candidates: [(PetActionDefinition, TriggerRule)] = []
        var foundAngleAction = false

        for action in project.actions where action.isEnabled && !action.frames.isEmpty {
            for rule in action.triggers where rule.isEnabled {
                if rule.kind == .mouseLook, event.type == .mouseMoved,
                   let distance = event.distance, let angle = event.angleDegrees,
                   action.playback == .angleControlled,
                   distanceMatches(rule, distance: distance) {
                    foundAngleAction = true
                    angleActionID = action.id
                    controlAngle?(action, angle)
                    continue
                }

                if matches(rule, event: event) && isPastCooldown(rule, at: event.date) {
                    candidates.append((action, rule))
                }
            }
        }

        if event.type == .mouseMoved, !foundAngleAction,
           let activeAngleActionID = angleActionID {
            stopAngleControl?(activeAngleActionID)
            self.angleActionID = nil
        }

        guard !candidates.isEmpty else { return }
        let maxPriority = candidates.map { $0.0.priority }.max() ?? 0
        let prioritized = candidates.filter { $0.0.priority == maxPriority }
        let chosen = weightedChoice(prioritized)
        cooldowns[chosen.1.id] = event.date.addingTimeInterval(max(0, chosen.1.cooldownSeconds))
        let isDragEvent: Bool
        switch event.type {
        case .dragStart, .dragLeft, .dragRight, .dragEnd:
            isDragEvent = true
        default:
            isDragEvent = false
        }
        let restart = event.type != .dragLeft && event.type != .dragRight
        schedulePlayback(
            action: chosen.0,
            rule: chosen.1,
            restart: restart,
            force: isDragEvent
        )
    }

    private func schedulePlayback(
        action: PetActionDefinition,
        rule: TriggerRule,
        restart: Bool,
        force: Bool
    ) {
        delayedFires[rule.id]?.cancel()
        delayedFires.removeValue(forKey: rule.id)

        let delay = rule.kind.supportsDelay ? min(86_400, max(0, rule.delaySeconds)) : 0
        guard delay > 0 else {
            playAction?(action, restart, force)
            return
        }

        let ruleID = rule.id
        let actionID = action.id
        let nanoseconds = UInt64(delay * 1_000_000_000)
        delayedFires[ruleID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            delayedFires.removeValue(forKey: ruleID)
            guard let currentAction = projectProvider?()?.actions.first(where: {
                $0.id == actionID && $0.isEnabled
            }) else { return }
            playAction?(currentAction, restart, force)
        }
    }

    private func cancelDelayedFires() {
        for task in delayedFires.values {
            task.cancel()
        }
        delayedFires.removeAll()
    }

    private func matches(_ rule: TriggerRule, event: PetEvent) -> Bool {
        switch rule.kind {
        case .manual:
            return event.type == .manual && (rule.stringValue.isEmpty || rule.stringValue == event.stringValue)
        case .appLaunch:
            return event.type == .appLaunch
        case .random:
            guard event.type == .timer else { return false }
            if randomDeadlines[rule.id] == nil {
                randomDeadlines[rule.id] = event.date.addingTimeInterval(randomInterval(rule))
            }
            if let deadline = randomDeadlines[rule.id], event.date >= deadline {
                randomDeadlines[rule.id] = event.date.addingTimeInterval(randomInterval(rule))
                return true
            }
            return false
        case .idle:
            guard event.type == .timer, let seconds = event.idleSeconds else { return false }
            if seconds < rule.idleSeconds {
                idleRulesHaveFired.remove(rule.id)
                return false
            }
            guard !idleRulesHaveFired.contains(rule.id) else { return false }
            idleRulesHaveFired.insert(rule.id)
            return true
        case .mouseNear:
            guard event.type == .mouseMoved, let distance = event.distance else { return false }
            let isMatching = distanceMatches(rule, distance: distance)
            let wasMatching = mouseInsideRules[rule.id] ?? false
            mouseInsideRules[rule.id] = isMatching
            return isMatching && !wasMatching
        case .mouseLook:
            return false
        case .mouseEnter: return event.type == .mouseEnter
        case .mouseExit: return event.type == .mouseExit
        case .singleClick: return event.type == .singleClick
        case .doubleClick: return event.type == .doubleClick
        case .rightClick: return event.type == .rightClick
        case .dragStart: return event.type == .dragStart
        case .dragLeft: return event.type == .dragLeft
        case .dragRight: return event.type == .dragRight
        case .dragEnd: return event.type == .dragEnd
        case .systemWake: return event.type == .systemWake
        case .systemSleep: return event.type == .systemSleep
        case .screenLocked: return event.type == .screenLocked
        case .screenUnlocked: return event.type == .screenUnlocked
        case .activeAppChanged:
            return event.type == .activeAppChanged
                && (rule.stringValue.isEmpty || rule.stringValue == event.stringValue)
        case .scheduled:
            guard event.type == .timer else { return false }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date)
            guard components.hour == rule.hour, components.minute == rule.minute else { return false }
            let key = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(rule.hour)-\(rule.minute)"
            guard scheduledFireKeys[rule.id] != key else { return false }
            scheduledFireKeys[rule.id] = key
            return true
        case .external:
            return event.type == .external
                && (rule.stringValue.isEmpty || rule.stringValue == event.stringValue)
        }
    }

    private func isPastCooldown(_ rule: TriggerRule, at date: Date) -> Bool {
        guard let deadline = cooldowns[rule.id] else { return true }
        return date >= deadline
    }

    private func distanceMatches(_ rule: TriggerRule, distance: Double) -> Bool {
        switch rule.distanceCondition ?? .inside {
        case .inside: return distance <= rule.distance
        case .outside: return distance >= rule.distance
        }
    }

    private func randomInterval(_ rule: TriggerRule) -> TimeInterval {
        let lower = max(1, min(rule.minimumIntervalSeconds, rule.maximumIntervalSeconds))
        let upper = max(lower, max(rule.minimumIntervalSeconds, rule.maximumIntervalSeconds))
        return Double.random(in: lower...upper)
    }

    private func weightedChoice(
        _ choices: [(PetActionDefinition, TriggerRule)]
    ) -> (PetActionDefinition, TriggerRule) {
        let total = choices.reduce(0.0) { $0 + max(0.01, $1.1.randomWeight) }
        var value = Double.random(in: 0..<total)
        for choice in choices {
            value -= max(0.01, choice.1.randomWeight)
            if value <= 0 { return choice }
        }
        return choices[0]
    }
}
