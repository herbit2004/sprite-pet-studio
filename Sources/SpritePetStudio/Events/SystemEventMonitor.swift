import AppKit
import Foundation

@MainActor
final class SystemEventMonitor {
    private let bus: PetEventBus
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var startedAt = Date()
    private var lastPetInteraction = Date()

    var mousePollingRate: Int = 30 {
        didSet {
            if timer != nil { restartTimer() }
        }
    }
    var mousePassThroughUpdater: ((CGPoint) -> Void)?

    init(bus: PetEventBus) {
        self.bus = bus
    }

    func start() {
        startedAt = Date()
        lastPetInteraction = Date()
        restartTimer()

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.systemWake)) }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.systemSleep)) }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.bus.post(PetEvent(type: .activeAppChanged, stringValue: app?.bundleIdentifier))
            }
        })

        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name("com.spritepetstudio.screenLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.screenLocked)) }
        })
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name("com.spritepetstudio.screenUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.screenUnlocked)) }
        })
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.screenLocked)) }
        })
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.bus.post(.simple(.screenUnlocked)) }
        })
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name("com.spritepetstudio.trigger"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.bus.post(PetEvent(type: .external, stringValue: note.object as? String))
            }
        })

        bus.post(.simple(.appLaunch))
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        let distributed = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            distributed.removeObserver(observer)
        }
        distributedObservers.removeAll()
    }

    func recordPetInteraction() {
        lastPetInteraction = Date()
    }

    private func restartTimer() {
        timer?.invalidate()
        let rate = max(5, min(mousePollingRate, 120))
        let timer = Timer(timeInterval: 1 / Double(rate), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let mouse = NSEvent.mouseLocation
        mousePassThroughUpdater?(mouse)

        var event = PetEvent(type: .mouseMoved, point: mouse)
        event.idleSeconds = Date().timeIntervalSince(lastPetInteraction)
        bus.post(event)

        // Slower event work is still carried by the same event; the trigger engine
        // performs its own per-rule deadlines and cooldowns.
        bus.post(PetEvent(
            type: .timer,
            date: Date(),
            idleSeconds: Date().timeIntervalSince(lastPetInteraction)
        ))
    }
}
