import AppKit
import Foundation

struct CodexPetManifest: Codable {
    var id: String
    var displayName: String
    var description: String
    var spriteVersionNumber: Int
    var spritesheetPath: String

    private enum CodingKeys: String, CodingKey {
        case id, displayName, description, spriteVersionNumber, spritesheetPath
    }

    init(
        id: String,
        displayName: String,
        description: String,
        spriteVersionNumber: Int,
        spritesheetPath: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spriteVersionNumber = spriteVersionNumber
        self.spritesheetPath = spritesheetPath
    }

    /// Codex v1 manifests predate `spriteVersionNumber` and sometimes omit
    /// display metadata. The ID and atlas path are the only required fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? id
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        spriteVersionNumber = try container.decodeIfPresent(Int.self, forKey: .spriteVersionNumber) ?? 1
        spritesheetPath = try container.decode(String.self, forKey: .spritesheetPath)
    }
}

struct CodexV2ActionSpec: Identifiable {
    let id: String
    let listLabel: String
    let name: String
    let positions: [(row: Int, column: Int)]
    let durationsMilliseconds: [Double]
    let framesPerSecond: Double
    let playback: PlaybackMode
    let priority: Int
    let interruption: InterruptionPolicy
}

enum CodexV2Schema {
    static let columns = 8
    static let rows = 11
    static let cellWidth = 192
    static let cellHeight = 208
    static let atlasWidth = 1536
    static let atlasHeight = 2288

    static let configuration = AtlasConfiguration(
        id: "codex-v2",
        name: "Codex v2 固定图集",
        configurationDescription: "Codex 桌宠的标准 8 × 11 图集协议。",
        isBuiltIn: true,
        compatibility: .codexV2,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        actions: actions.map { spec in
            AtlasActionConfiguration(
                name: spec.name,
                key: spec.id,
                frameCount: spec.positions.count,
                occupiedRows: spec.id == "look-around" ? 2 : 1
            )
        }
    )

    static let actions: [CodexV2ActionSpec] = [
        standard(
            id: "idle", label: "第 1 排", name: "常态（6 帧 + 中立帧）",
            row: 0, columns: 0...6,
            durations: [280, 110, 110, 140, 140, 320, 320], fps: 10,
            playback: .loop, priority: 0, interruption: .always
        ),
        standard(
            id: "running-right", label: "第 2 排", name: "向右跑",
            row: 1, columns: 0...7,
            durations: [120, 120, 120, 120, 120, 120, 120, 220], fps: 10,
            playback: .loop, priority: 70, interruption: .always
        ),
        standard(
            id: "running-left", label: "第 3 排", name: "向左跑",
            row: 2, columns: 0...7,
            durations: [120, 120, 120, 120, 120, 120, 120, 220], fps: 10,
            playback: .loop, priority: 70, interruption: .always
        ),
        standard(
            id: "waving", label: "第 4 排", name: "挥手",
            row: 3, columns: 0...3,
            durations: [140, 140, 140, 280], fps: 10,
            playback: .once, priority: 60, interruption: .higherPriority
        ),
        standard(
            id: "jumping", label: "第 5 排", name: "跳跃 / 悬浮动作",
            row: 4, columns: 0...4,
            durations: [140, 140, 140, 140, 280], fps: 10,
            playback: .once, priority: 85, interruption: .never
        ),
        standard(
            id: "failed", label: "第 6 排", name: "失败",
            row: 5, columns: 0...7,
            durations: [140, 140, 140, 140, 140, 140, 140, 240], fps: 10,
            playback: .once, priority: 90, interruption: .never
        ),
        standard(
            id: "waiting", label: "第 7 排", name: "等待",
            row: 6, columns: 0...5,
            durations: [150, 150, 150, 150, 150, 260], fps: 10,
            playback: .loop, priority: 20, interruption: .higherPriority
        ),
        standard(
            id: "running", label: "第 8 排", name: "执行任务",
            row: 7, columns: 0...5,
            durations: [120, 120, 120, 120, 120, 220], fps: 10,
            playback: .loop, priority: 55, interruption: .always
        ),
        standard(
            id: "review", label: "第 9 排", name: "检查结果",
            row: 8, columns: 0...5,
            durations: [150, 150, 150, 150, 150, 280], fps: 10,
            playback: .once, priority: 65, interruption: .never
        ),
        CodexV2ActionSpec(
            id: "look-around",
            listLabel: "第 10–11 排",
            name: "16 方向视线跟随",
            positions: (0..<16).map { index in
                index < 8 ? (row: 9, column: index) : (row: 10, column: index - 8)
            },
            durationsMilliseconds: Array(repeating: 16.67, count: 16),
            framesPerSecond: 60,
            playback: .angleControlled,
            priority: 25,
            interruption: .higherPriority
        )
    ]

    static func normalize(_ source: PetProjectDefinition) -> PetProjectDefinition {
        normalize(source, using: source.atlasConfiguration ?? configuration)
    }

    static func normalize(
        _ source: PetProjectDefinition,
        using configuration: AtlasConfiguration,
        libraryID: String? = nil
    ) -> PetProjectDefinition {
        var project = source
        project.formatVersion = 2
        project.atlas.columns = max(1, configuration.cellsPerRow)
        project.atlas.rows = max(1, configuration.rowCount)
        project.atlas.cellWidth = max(1, configuration.cellWidth)
        project.atlas.cellHeight = max(1, configuration.cellHeight)
        project.atlasConfiguration = configuration
        if let libraryID { project.configurationLibraryID = libraryID }
        if !configuration.actions.contains(where: { $0.key == project.defaultActionID }) {
            project.defaultActionID = configuration.actions.first?.key ?? ""
        }

        project.actions = configuration.actions.map { actionLayout in
            let codexSpec = configuration.compatibility.isCodex
                ? actions.first(where: { $0.id == actionLayout.key })
                : nil
            let previous = source.actions.first { $0.id == actionLayout.key }
                ?? legacyAction(for: actionLayout.key, in: source.actions)
            let positions = configuration.positions(for: actionLayout.key)
            let frames = positions.enumerated().map { index, position in
                var frame = previous?.frames.indices.contains(index) == true
                    ? previous!.frames[index]
                    : PetFrameDefinition(column: position.column, row: position.row)
                frame.column = position.column
                frame.row = position.row
                if codexSpec?.playback == .angleControlled || previous?.playback == .angleControlled {
                    frame.angleDegrees = Double(index) * 360 / Double(max(1, positions.count))
                }
                if previous == nil {
                    if let codexSpec, codexSpec.durationsMilliseconds.indices.contains(index) {
                        let milliseconds = codexSpec.durationsMilliseconds[index]
                        frame.durationMultiplier = milliseconds * codexSpec.framesPerSecond / 1000
                    } else {
                        frame.durationMultiplier = 1
                    }
                }
                return frame
            }

            return PetActionDefinition(
                id: actionLayout.key,
                name: actionLayout.name,
                isEnabled: previous?.isEnabled ?? true,
                framesPerSecond: previous?.framesPerSecond ?? codexSpec?.framesPerSecond ?? 8,
                playback: previous?.playback ?? codexSpec?.playback ?? (actionLayout.key == project.defaultActionID ? .loop : .once),
                repeatCount: previous?.repeatCount ?? 1,
                priority: previous?.priority ?? codexSpec?.priority ?? (actionLayout.key == project.defaultActionID ? 0 : 50),
                interruption: previous?.interruption ?? codexSpec?.interruption ?? .higherPriority,
                frames: frames,
                triggers: previous?.triggers ?? defaultTriggers(
                    for: actionLayout.key,
                    isCodex: configuration.compatibility.isCodex,
                    isDefault: actionLayout.key == project.defaultActionID
                )
            )
        }
        return project
    }

    static func makeProject(
        manifest: CodexPetManifest,
        atlasPath: String,
        settingsTemplate: PetProjectDefinition?
    ) -> PetProjectDefinition {
        let base = PetProjectDefinition(
            id: manifest.id,
            name: manifest.displayName,
            author: settingsTemplate?.author ?? "",
            projectDescription: manifest.description,
            formatVersion: 2,
            isBuiltIn: false,
            atlas: AtlasDefinition(
                imagePath: atlasPath,
                columns: columns,
                rows: rows,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                filtering: settingsTemplate?.atlas.filtering ?? .linear
            ),
            defaultActionID: "idle",
            actions: settingsTemplate?.actions ?? []
        )
        return normalize(base, using: configuration, libraryID: configuration.id)
    }

    static func actionSpec(id: String) -> CodexV2ActionSpec? {
        actions.first { $0.id == id }
    }

    static func validateAtlasImage(_ image: NSImage) -> Bool {
        guard let representation = image.representations.first else { return false }
        return representation.pixelsWide == atlasWidth && representation.pixelsHigh == atlasHeight
    }

    private static func standard(
        id: String,
        label: String,
        name: String,
        row: Int,
        columns: ClosedRange<Int>,
        durations: [Double],
        fps: Double,
        playback: PlaybackMode,
        priority: Int,
        interruption: InterruptionPolicy
    ) -> CodexV2ActionSpec {
        CodexV2ActionSpec(
            id: id,
            listLabel: label,
            name: name,
            positions: columns.map { (row: row, column: $0) },
            durationsMilliseconds: durations,
            framesPerSecond: fps,
            playback: playback,
            priority: priority,
            interruption: interruption
        )
    }

    private static func legacyAction(
        for id: String,
        in actions: [PetActionDefinition]
    ) -> PetActionDefinition? {
        switch id {
        case "jumping": return actions.first { $0.id == "ghost-face" }
        case "waiting": return actions.first { $0.id == "ramen" }
        case "running": return actions.first { $0.id == "painting" }
        default: return nil
        }
    }

    private static func defaultTriggers(for id: String, isCodex: Bool = true, isDefault: Bool = false) -> [TriggerRule] {
        if !isCodex {
            if isDefault {
                return [TriggerRule(kind: .appLaunch), TriggerRule(kind: .dragEnd)]
            }
            return [TriggerRule(kind: .manual)]
        }
        switch id {
        case "idle":
            let launch = TriggerRule(kind: .appLaunch)
            let dragEnd = TriggerRule(kind: .dragEnd)
            var external = TriggerRule(kind: .external)
            external.stringValue = "idle"
            return [launch, dragEnd, external]
        case "running-right": return [TriggerRule(kind: .dragRight)]
        case "running-left": return [TriggerRule(kind: .dragLeft)]
        case "waving": return [TriggerRule(kind: .singleClick)]
        case "jumping":
            var trigger = TriggerRule(kind: .mouseNear)
            trigger.distance = 86
            return [trigger]
        case "failed":
            var trigger = TriggerRule(kind: .external)
            trigger.stringValue = "failed"
            return [trigger]
        case "waiting":
            var trigger = TriggerRule(kind: .idle)
            trigger.idleSeconds = 45
            return [trigger]
        case "running":
            var trigger = TriggerRule(kind: .external)
            trigger.stringValue = "task-running"
            return [trigger]
        case "review":
            var trigger = TriggerRule(kind: .external)
            trigger.stringValue = "review"
            return [trigger]
        case "look-around":
            var trigger = TriggerRule(kind: .mouseLook)
            trigger.distance = 520
            return [trigger]
        default: return [TriggerRule(kind: .manual)]
        }
    }
}

enum CodexV1Schema {
    static let columns = 8
    static let rows = 9
    static let cellWidth = 192
    static let cellHeight = 208
    static let atlasWidth = 1536
    static let atlasHeight = 1872

    private static let frameCounts = [6, 8, 8, 4, 5, 8, 6, 6, 6]

    static let configuration = AtlasConfiguration(
        id: "codex-v1",
        name: "Codex v1 固定图集",
        configurationDescription: "Codex v1 桌宠的标准 8 × 9 图集协议，不包含 16 方向视线动作。",
        isBuiltIn: true,
        compatibility: .codexV1,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        actions: zip(CodexV2Schema.actions.prefix(9), frameCounts).map { spec, frameCount in
            AtlasActionConfiguration(
                name: spec.name,
                key: spec.id,
                frameCount: frameCount,
                occupiedRows: 1
            )
        }
    )
}

enum CodexSchemas {
    static let builtInConfigurations = [
        CodexV2Schema.configuration,
        CodexV1Schema.configuration
    ]

    static func configuration(forAtlasWidth width: Int, height: Int) -> AtlasConfiguration? {
        switch (width, height) {
        case (CodexV2Schema.atlasWidth, CodexV2Schema.atlasHeight):
            return CodexV2Schema.configuration
        case (CodexV1Schema.atlasWidth, CodexV1Schema.atlasHeight):
            return CodexV1Schema.configuration
        default:
            return nil
        }
    }
}
