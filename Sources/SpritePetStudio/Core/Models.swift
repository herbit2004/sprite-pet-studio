import CoreGraphics
import Foundation

struct AppDocument: Codable, Equatable {
    var selectedProjectID: String
    var general: GeneralSettings
    var projects: [PetProjectDefinition]
    var atlasConfigurations: [AtlasConfiguration]

    init(
        selectedProjectID: String,
        general: GeneralSettings,
        projects: [PetProjectDefinition],
        atlasConfigurations: [AtlasConfiguration] = [CodexV2Schema.configuration]
    ) {
        self.selectedProjectID = selectedProjectID
        self.general = general
        self.projects = projects
        self.atlasConfigurations = atlasConfigurations
    }

    private enum CodingKeys: String, CodingKey {
        case selectedProjectID, general, projects, atlasConfigurations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedProjectID = try container.decode(String.self, forKey: .selectedProjectID)
        general = try container.decode(GeneralSettings.self, forKey: .general)
        projects = try container.decode([PetProjectDefinition].self, forKey: .projects)
        atlasConfigurations = try container.decodeIfPresent(
            [AtlasConfiguration].self,
            forKey: .atlasConfigurations
        ) ?? [CodexV2Schema.configuration]
    }
}

struct GeneralSettings: Codable, Equatable {
    var isPetVisible = true
    var alwaysOnTop = true
    var petScale = 0.72
    var preferredFramesPerSecond = 60
    var mousePollingRate = 30
    var launchAtLogin = false
    var windowOriginX: Double?
    var windowOriginY: Double?
}

struct PetProjectDefinition: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var author: String
    var projectDescription: String
    var formatVersion: Int
    var isBuiltIn: Bool
    var atlas: AtlasDefinition
    var defaultActionID: String
    var actions: [PetActionDefinition]
    var atlasConfiguration: AtlasConfiguration? = nil
    var configurationLibraryID: String? = nil
    var isVisibleOnDesktop: Bool? = nil
    var desktopOriginX: Double? = nil
    var desktopOriginY: Double? = nil

    var showsOnDesktop: Bool { isVisibleOnDesktop ?? false }
}

struct AtlasConfiguration: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var configurationDescription: String
    var isBuiltIn: Bool
    var compatibility: AtlasCompatibility
    var cellWidth: Int
    var cellHeight: Int
    var actions: [AtlasActionConfiguration]

    private enum CodingKeys: String, CodingKey {
        case id, name, configurationDescription, isBuiltIn, compatibility
        case cellWidth, cellHeight, actions
        case legacyCellsPerRow = "cellsPerRow"
    }

    init(
        id: String,
        name: String,
        configurationDescription: String,
        isBuiltIn: Bool,
        compatibility: AtlasCompatibility,
        cellWidth: Int,
        cellHeight: Int,
        actions: [AtlasActionConfiguration]
    ) {
        self.id = id
        self.name = name
        self.configurationDescription = configurationDescription
        self.isBuiltIn = isBuiltIn
        self.compatibility = compatibility
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        configurationDescription = try container.decode(String.self, forKey: .configurationDescription)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        compatibility = try container.decode(AtlasCompatibility.self, forKey: .compatibility)
        cellWidth = try container.decode(Int.self, forKey: .cellWidth)
        cellHeight = try container.decode(Int.self, forKey: .cellHeight)
        actions = try container.decode([AtlasActionConfiguration].self, forKey: .actions)

        if let legacyColumns = try container.decodeIfPresent(Int.self, forKey: .legacyCellsPerRow) {
            let safeColumns = max(1, legacyColumns)
            for index in actions.indices where actions[index].occupiedRows == nil {
                actions[index].occupiedRows = max(
                    1,
                    Int(ceil(Double(max(1, actions[index].frameCount)) / Double(safeColumns)))
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(configurationDescription, forKey: .configurationDescription)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encode(compatibility, forKey: .compatibility)
        try container.encode(cellWidth, forKey: .cellWidth)
        try container.encode(cellHeight, forKey: .cellHeight)
        try container.encode(actions, forKey: .actions)
    }

    var rowCount: Int {
        actions.reduce(0) { $0 + $1.occupiedRowCount }
    }

    var cellsPerRow: Int {
        max(1, actions.map { action in
            Int(ceil(Double(max(1, action.frameCount)) / Double(action.occupiedRowCount)))
        }.max() ?? 1)
    }

    var atlasWidth: Int { max(1, cellsPerRow) * max(1, cellWidth) }
    var atlasHeight: Int { max(1, rowCount) * max(1, cellHeight) }

    func positions(for actionKey: String) -> [(row: Int, column: Int)] {
        var row = 0
        let columns = max(1, cellsPerRow)
        for action in actions {
            if action.key == actionKey {
                return (0..<max(1, action.frameCount)).map { index in
                    let localRow = min(action.occupiedRowCount - 1, index / columns)
                    return (row: row + localRow, column: index % columns)
                }
            }
            row += action.occupiedRowCount
        }
        return []
    }

    func rowLabel(for actionKey: String) -> String {
        var firstRow = 0
        for action in actions {
            if action.key == actionKey {
                let lastRow = firstRow + action.occupiedRowCount - 1
                return firstRow == lastRow
                    ? "第 \(firstRow + 1) 排"
                    : "第 \(firstRow + 1)–\(lastRow + 1) 排"
            }
            firstRow += action.occupiedRowCount
        }
        return "未分配"
    }
}

struct AtlasActionConfiguration: Codable, Identifiable, Equatable {
    var name: String
    var key: String
    var frameCount: Int
    var occupiedRows: Int? = nil

    var id: String { key }
    var occupiedRowCount: Int { max(1, occupiedRows ?? 1) }
}

enum AtlasCompatibility: String, Codable, CaseIterable, Identifiable {
    case codexV2
    case spritePetStudio

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .codexV2: return "Codex v2"
        case .spritePetStudio: return "SpritePet Studio"
        }
    }
}

struct AtlasDefinition: Codable, Equatable {
    var imagePath: String
    var columns: Int
    var rows: Int
    var cellWidth: Int
    var cellHeight: Int
    var filtering: TextureFiltering
}

enum TextureFiltering: String, Codable, CaseIterable, Identifiable {
    case linear
    case nearest

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .linear: return "平滑"
        case .nearest: return "像素锐利"
        }
    }
}

struct PetActionDefinition: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var isEnabled: Bool
    var framesPerSecond: Double
    var playback: PlaybackMode
    var priority: Int
    var interruption: InterruptionPolicy
    var frames: [PetFrameDefinition]
    var triggers: [TriggerRule]
}

enum PlaybackMode: String, Codable, CaseIterable, Identifiable {
    case once
    case loop
    case pingPong
    case holdLast
    case angleControlled

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .once: return "播放一次"
        case .loop: return "持续循环"
        case .pingPong: return "往返循环"
        case .holdLast: return "停在末帧"
        case .angleControlled: return "按角度选帧"
        }
    }
}

enum InterruptionPolicy: String, Codable, CaseIterable, Identifiable {
    case higherPriority
    case always
    case never

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .higherPriority: return "仅更高优先级"
        case .always: return "允许任意动作打断"
        case .never: return "播放完之前不打断"
        }
    }
}

struct PetFrameDefinition: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var column: Int
    var row: Int
    var durationMultiplier: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0
    var scale: Double = 1
    var angleDegrees: Double?
}

enum TriggerKind: String, Codable, CaseIterable, Identifiable {
    case manual
    case appLaunch
    case random
    case idle
    case mouseNear
    case mouseLook
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
    case scheduled
    case external

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .manual: return "仅手动触发"
        case .appLaunch: return "桌宠启动"
        case .random: return "随机触发"
        case .idle: return "空闲一段时间"
        case .mouseNear: return "鼠标靠近"
        case .mouseLook: return "眼睛跟随鼠标"
        case .mouseEnter: return "鼠标进入桌宠"
        case .mouseExit: return "鼠标离开桌宠"
        case .singleClick: return "鼠标单击"
        case .doubleClick: return "鼠标双击"
        case .rightClick: return "鼠标右击"
        case .dragStart: return "开始拖动"
        case .dragLeft: return "向左拖动"
        case .dragRight: return "向右拖动"
        case .dragEnd: return "结束拖动"
        case .systemWake: return "电脑唤醒"
        case .systemSleep: return "电脑睡眠"
        case .screenLocked: return "屏幕锁定"
        case .screenUnlocked: return "屏幕解锁"
        case .activeAppChanged: return "前台应用切换"
        case .scheduled: return "每天定时"
        case .external: return "外部指令"
        }
    }

    var helpText: String {
        switch self {
        case .manual: return "只从菜单栏或设置界面播放。"
        case .random: return "在最短与最长间隔之间重新抽取下一次触发时间。"
        case .idle: return "没有和桌宠交互达到指定秒数后触发一次。"
        case .mouseNear: return "鼠标首次进入指定中心距离时触发。"
        case .mouseLook: return "持续计算鼠标方位，并选择动作中最接近该角度的帧。"
        case .activeAppChanged: return "切换到指定 Bundle ID 的应用；留空代表任意应用。"
        case .scheduled: return "每天到指定时、分时触发一次。"
        case .external: return "通过 spritepet://trigger/名称 或 spritepetctl trigger 名称触发。"
        default: return "由对应的桌面或系统事件触发。"
        }
    }
}

struct TriggerRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: TriggerKind
    var isEnabled: Bool = true
    var cooldownSeconds: Double = 0
    var minimumIntervalSeconds: Double = 15
    var maximumIntervalSeconds: Double = 45
    var randomWeight: Double = 1
    var idleSeconds: Double = 30
    var distance: Double = 160
    var distanceCondition: DistanceCondition? = nil
    var stringValue: String = ""
    var hour: Int = 12
    var minute: Int = 0
}

enum DistanceCondition: String, Codable, CaseIterable, Identifiable {
    case inside
    case outside

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .inside: return "距离以内"
        case .outside: return "距离以外"
        }
    }
}

extension PetProjectDefinition {
    var defaultAction: PetActionDefinition? {
        actions.first { $0.id == defaultActionID && $0.isEnabled }
            ?? actions.first { $0.isEnabled }
    }

    var effectiveAtlasConfiguration: AtlasConfiguration {
        atlasConfiguration ?? CodexV2Schema.configuration
    }
}

extension PetActionDefinition {
    var playableFrames: [PetFrameDefinition] {
        frames
    }

    static func blank(index: Int) -> PetActionDefinition {
        PetActionDefinition(
            id: "action-\(index)",
            name: "新动作 \(index)",
            isEnabled: true,
            framesPerSecond: 8,
            playback: .once,
            priority: 50,
            interruption: .higherPriority,
            frames: [PetFrameDefinition(column: 0, row: 0)],
            triggers: [TriggerRule(kind: .manual)]
        )
    }
}

extension TriggerRule {
    static func blank(_ kind: TriggerKind = .manual) -> TriggerRule {
        TriggerRule(kind: kind)
    }
}
