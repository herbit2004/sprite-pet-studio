import AppKit
import Foundation

final class DocumentStore {
    private static let resourceBundle: Bundle? = {
        let bundleName = "SpritePetStudio_SpritePetStudio.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName, isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName, isDirectory: true)
        ]
        for case let url? in candidates {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    enum StoreError: LocalizedError {
        case bundledProjectMissing(String)
        case projectImageMissing(String)
        case readOnlyTemplate(String)
        case invalidCodexManifest(String)
        case invalidAtlas(width: Int, height: Int, expectedWidth: Int, expectedHeight: Int)
        case unsupportedImportSelection(String)
        case invalidImportJSON(file: String, reason: String)
        case importAtlasMissing(folder: String, searched: [String])
        case unsupportedImportAtlas(width: Int, height: Int)
        case importDestinationExists(String)
        case invalidProjectID(String)
        case projectIDInUse(String)

        var errorDescription: String? {
            switch self {
            case .bundledProjectMissing(let name):
                return "找不到内置工程：\(name)。"
            case .projectImageMissing(let path):
                return "工程图集不存在：\(path)"
            case .readOnlyTemplate(let name):
                return "“\(name)”是只读模板。请先复制完整工程，再编辑动作或图集。"
            case .invalidCodexManifest(let reason):
                return "不是可用的 Codex 工程：\(reason)"
            case .invalidAtlas(let width, let height, let expectedWidth, let expectedHeight):
                return "图集必须是 \(expectedWidth) × \(expectedHeight)，当前是 \(width) × \(height)。"
            case .unsupportedImportSelection(let path):
                return "无法从“\(path)”导入。请选择工程文件夹、pet.json、path.json、studio.json、spritesheet.png 或 spritesheet.webp。"
            case .invalidImportJSON(let file, let reason):
                return "无法识别 \(file)：\(reason)"
            case .importAtlasMissing(let folder, let searched):
                return "导入失败：\(folder) 中缺少必需的图集文件。已查找：\(searched.joined(separator: "、"))。"
            case .unsupportedImportAtlas(let width, let height):
                return "无法识别 \(width) × \(height) 的图集布局。请提供匹配的 studio.json，或使用 Codex v1（1536 × 1872）/ v2（1536 × 2288）图集。"
            case .importDestinationExists(let id):
                return "导入目标“\(id)”已经存在。请换一个工程名称或先处理同名工程。"
            case .invalidProjectID(let reason):
                return "工程 ID 不可用：\(reason)"
            case .projectIDInUse(let id):
                return "工程 ID“\(id)”已经存在。"
            }
        }
    }

    let applicationSupportURL: URL
    let projectsURL: URL
    let stateURL: URL
    private let frameImageCache = NSCache<NSString, NSImage>()

    init(fileManager: FileManager = .default, applicationSupportURL overrideURL: URL? = nil) {
        let base = overrideURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SpritePetStudio", isDirectory: true)
        applicationSupportURL = base
        projectsURL = base.appendingPathComponent("Projects", isDirectory: true)
        stateURL = base.appendingPathComponent("state.json")
        try? fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
    }

    func load() throws -> AppDocument {
        let bundledProjects = try bundledProjects()
        let bundledIDs = Set(bundledProjects.map(\.id))
        let stateExists = FileManager.default.fileExists(atPath: stateURL.path)
        var document: AppDocument
        if stateExists {
            let data = try Data(contentsOf: stateURL)
            document = try JSONDecoder.spritePet.decode(AppDocument.self, from: data)
        } else {
            document = AppDocument(
                selectedProjectID: bundledProjects[0].id,
                general: GeneralSettings(),
                projects: []
            )
        }

        let builtInConfigurationIDs = Set(CodexSchemas.builtInConfigurations.map(\.id))
        document.atlasConfigurations.removeAll { builtInConfigurationIDs.contains($0.id) }
        document.atlasConfigurations.insert(contentsOf: CodexSchemas.builtInConfigurations, at: 0)

        let stateProjects = document.projects.map(CodexV2Schema.normalize)
        var personalProjects: [PetProjectDefinition] = []
        var personalProjectIndices: [String: Int] = [:]

        // Older versions stored project metadata only in state.json. Keep those
        // entries when their working atlas still exists, then materialize the new
        // per-project metadata files during save below.
        for var project in stateProjects where !bundledIDs.contains(project.id) {
            project.isBuiltIn = false
            guard projectImageExists(project) else { continue }
            personalProjectIndices[project.id] = personalProjects.count
            personalProjects.append(project)
        }

        // Projects/<id>/studio.json is the source of truth for private projects.
        // A project copied into the workspace is therefore discoverable even when
        // state.json is new, missing, or was restored independently.
        for project in workspaceProjects(excluding: bundledIDs) {
            if let index = personalProjectIndices[project.id] {
                personalProjects[index] = project
            } else {
                personalProjectIndices[project.id] = personalProjects.count
                personalProjects.append(project)
            }
        }

        let templates = bundledProjects.map { bundled -> PetProjectDefinition in
            var template = bundled
            if let previous = stateProjects.first(where: { $0.id == bundled.id }) {
                template.isVisibleOnDesktop = previous.isVisibleOnDesktop
                template.desktopOriginX = previous.desktopOriginX
                template.desktopOriginY = previous.desktopOriginY
            }
            return template
        }

        document.projects = templates + personalProjects
        for index in document.projects.indices where document.projects[index].isVisibleOnDesktop == nil {
            document.projects[index].isVisibleOnDesktop = document.projects[index].id == document.selectedProjectID
        }
        if let selectedIndex = document.projects.firstIndex(where: { $0.id == document.selectedProjectID }) {
            if document.projects[selectedIndex].desktopOriginX == nil {
                document.projects[selectedIndex].desktopOriginX = document.general.windowOriginX
            }
            if document.projects[selectedIndex].desktopOriginY == nil {
                document.projects[selectedIndex].desktopOriginY = document.general.windowOriginY
            }
        } else {
            document.selectedProjectID = document.projects.first?.id ?? ""
        }
        for index in document.projects.indices where document.projects[index].configurationLibraryID == nil {
            let configurationID = document.projects[index].effectiveAtlasConfiguration.id
            if builtInConfigurationIDs.contains(configurationID) {
                document.projects[index].configurationLibraryID = configurationID
            }
        }

        // Persist migrations immediately so private projects become complete,
        // independently discoverable workspace folders on the first new launch.
        try save(document)
        return document
    }

    func save(_ document: AppDocument) throws {
        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        for project in document.projects where !project.isReadOnlyTemplate {
            try saveWorkspaceMetadata(for: project)
        }
        let data = try JSONEncoder.spritePet.encode(document)
        try data.write(to: stateURL, options: .atomic)
    }

    private func workspaceProjects(excluding reservedIDs: Set<String>) -> [PetProjectDefinition] {
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return folders.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { folder in
            guard !reservedIDs.contains(folder.lastPathComponent),
                  (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            let studioURL = folder.appendingPathComponent("studio.json")
            guard let data = try? Data(contentsOf: studioURL),
                  var project = try? JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data) else {
                return nil
            }
            project.id = folder.lastPathComponent
            project.isBuiltIn = false
            project = CodexV2Schema.normalize(project)
            guard projectImageExists(project) else { return nil }
            return project
        }
    }

    private func projectImageExists(_ project: PetProjectDefinition) -> Bool {
        guard !project.isReadOnlyTemplate,
              let url = try? imageURL(for: project) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func saveWorkspaceMetadata(for project: PetProjectDefinition) throws {
        guard !project.isReadOnlyTemplate else { return }
        let folder = projectsURL.appendingPathComponent(project.id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try imageURL(for: project)

        try writeWorkspaceMetadata(for: project, to: folder)
    }

    private func writeWorkspaceMetadata(for project: PetProjectDefinition, to folder: URL) throws {
        guard !project.isReadOnlyTemplate else { return }

        var stored = project
        stored.isBuiltIn = false
        try JSONEncoder.spritePet.encode(stored)
            .write(to: folder.appendingPathComponent("studio.json"), options: .atomic)

        let manifest = CodexPetManifest(
            id: stored.id,
            displayName: stored.name,
            description: stored.projectDescription,
            spriteVersionNumber: stored.effectiveAtlasConfiguration.compatibility.spriteVersionNumber,
            spritesheetPath: (stored.atlas.imagePath as NSString).lastPathComponent
        )
        try JSONEncoder.spritePet.encode(manifest)
            .write(to: folder.appendingPathComponent("pet.json"), options: .atomic)
    }

    private func requireEditable(_ project: PetProjectDefinition) throws {
        guard !project.isReadOnlyTemplate else {
            throw StoreError.readOnlyTemplate(project.name)
        }
    }

    /// Project IDs are immutable after creation and double as workspace folder
    /// names, so creation and import must reject path-like or hidden values.
    func validatedProjectID(_ rawValue: String) throws -> String {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        guard !value.isEmpty else {
            throw StoreError.invalidProjectID("不能为空")
        }
        guard value != ".", value != "..", !value.hasPrefix(".") else {
            throw StoreError.invalidProjectID("不能使用隐藏名称、“.”或“..”")
        }
        guard value.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil,
              value.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw StoreError.invalidProjectID("不能包含 /、: 或控制字符")
        }
        guard value.lengthOfBytes(using: .utf8) <= 255 else {
            throw StoreError.invalidProjectID("UTF-8 长度不能超过 255 字节")
        }
        return value
    }

    func workspaceProjectIDExists(_ rawValue: String) -> Bool {
        guard let value = try? validatedProjectID(rawValue),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: projectsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else { return false }
        return contents.contains { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            return url.lastPathComponent.compare(
                value,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    func bundledNaruto() throws -> PetProjectDefinition {
        try bundledProject(
            folder: "little-naruto",
            displayName: "NARUTO 小鸣人"
        )
    }

    func bundledDimoo() throws -> PetProjectDefinition {
        try bundledProject(
            folder: "dimoo-heartfelt-mix",
            displayName: "DIMOO 心动特调"
        )
    }

    func bundledProjects() throws -> [PetProjectDefinition] {
        [try bundledNaruto(), try bundledDimoo()]
    }

    private func bundledProject(
        folder: String,
        displayName: String
    ) throws -> PetProjectDefinition {
        guard let url = Self.resourceBundle?.url(
            forResource: "project",
            withExtension: "json",
            subdirectory: "BuiltinProjects/\(folder)"
        ) else {
            throw StoreError.bundledProjectMissing(displayName)
        }
        let data = try Data(contentsOf: url)
        let source = try JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data)
        var project = CodexV2Schema.normalize(
            source,
            using: CodexV2Schema.configuration,
            libraryID: CodexV2Schema.configuration.id
        )
        project.isVisibleOnDesktop = true
        return project
    }

    func imageURL(for project: PetProjectDefinition) throws -> URL {
        try assetURL(for: project.atlas.imagePath, project: project)
    }

    func assetURL(for pathValue: String, project: PetProjectDefinition) throws -> URL {
        if pathValue.hasPrefix("builtin://") {
            let relative = String(pathValue.dropFirst("builtin://".count))
            let path = relative as NSString
            let name = path.deletingPathExtension
            let ext = path.pathExtension
            guard let url = Self.resourceBundle?.url(forResource: name, withExtension: ext) else {
                throw StoreError.projectImageMissing(pathValue)
            }
            return url
        }

        let relative = pathValue
            .replacingOccurrences(of: "project://", with: "")
        let url = projectsURL
            .appendingPathComponent(project.id, isDirectory: true)
            .appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StoreError.projectImageMissing(url.path)
        }
        return url
    }

    func frameImage(for frame: PetFrameDefinition, project: PetProjectDefinition) -> NSImage? {
        let key = "\(project.id)|\(project.atlas.imagePath)|\(frame.row)|\(frame.column)" as NSString
        if let cached = frameImageCache.object(forKey: key) { return cached }

        let image = croppedAtlasFrame(frame, project: project)
        if let image { frameImageCache.setObject(image, forKey: key) }
        return image
    }

    func replaceAtlasCell(
        from sourceURL: URL,
        frame: PetFrameDefinition,
        project: PetProjectDefinition
    ) throws -> String {
        try requireEditable(project)
        guard let source = NSImage(contentsOf: sourceURL) else {
            throw StoreError.projectImageMissing(sourceURL.path)
        }
        guard let normalized = renderImage(
            source,
            sourceRect: NSRect(origin: .zero, size: source.size),
            targetPixels: CGSize(width: project.atlas.cellWidth, height: project.atlas.cellHeight),
            aspectFit: true
        ) else {
            throw StoreError.projectImageMissing(sourceURL.path)
        }
        return try writeAtlas(project: project, replacing: frame, with: normalized)
    }

    func bakeFrameTransform(
        _ frame: PetFrameDefinition,
        project: PetProjectDefinition
    ) throws -> String {
        try requireEditable(project)
        guard let source = croppedAtlasFrame(frame, project: project) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }
        let cellSize = CGSize(
            width: CGFloat(project.atlas.cellWidth),
            height: CGFloat(project.atlas.cellHeight)
        )
        guard let bitmap = makeBitmap(size: cellSize),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = project.atlas.filtering == .nearest ? .none : .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: cellSize).fill()
        let scaledSize = NSSize(
            width: cellSize.width * CGFloat(frame.scale * frame.scaleX),
            height: cellSize.height * CGFloat(frame.scale * frame.scaleY)
        )
        let destination = NSRect(
            x: (cellSize.width - scaledSize.width) / 2 + CGFloat(frame.offsetX),
            y: (cellSize.height - scaledSize.height) / 2 + CGFloat(frame.offsetY),
            width: scaledSize.width,
            height: scaledSize.height
        )
        source.draw(
            in: destination,
            from: NSRect(origin: .zero, size: cellSize),
            operation: .sourceOver,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return try writeAtlas(project: project, replacing: frame, with: bitmap)
    }

    func bakeAllFrameTransforms(in project: PetProjectDefinition) throws -> String {
        try bakeFrameTransforms(in: project, frameIDs: nil)
    }

    func bakeFrameTransforms(
        in project: PetProjectDefinition,
        frameIDs: Set<UUID>
    ) throws -> String {
        try bakeFrameTransforms(in: project, frameIDs: Optional(frameIDs))
    }

    private func bakeFrameTransforms(
        in project: PetProjectDefinition,
        frameIDs: Set<UUID>?
    ) throws -> String {
        try requireEditable(project)
        guard let atlas = NSImage(contentsOf: try imageURL(for: project)) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }
        try requireAtlas(atlas, definition: project.atlas)

        let atlasSize = CGSize(
            width: CGFloat(project.atlas.columns * project.atlas.cellWidth),
            height: CGFloat(project.atlas.rows * project.atlas.cellHeight)
        )
        guard let output = makeBitmap(size: atlasSize),
              let context = NSGraphicsContext(bitmapImageRep: output) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = project.atlas.filtering == .nearest ? .none : .high
        context.compositingOperation = .copy
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: atlasSize).fill()
        atlas.draw(
            in: NSRect(origin: .zero, size: atlasSize),
            from: NSRect(origin: .zero, size: atlas.size),
            operation: .copy,
            fraction: 1
        )

        let transformedFrames = project.actions
            .flatMap(\.frames)
            .filter { frame in
                (frameIDs == nil || frameIDs?.contains(frame.id) == true)
                    && (abs(frame.scale - 1) > 0.0001
                    || abs(frame.scaleX - 1) > 0.0001
                    || abs(frame.scaleY - 1) > 0.0001
                    || abs(frame.offsetX) > 0.0001
                    || abs(frame.offsetY) > 0.0001)
            }

        for frame in transformedFrames {
            let sourceRect = NSRect(
                x: CGFloat(frame.column * project.atlas.cellWidth),
                y: CGFloat(project.atlas.rows * project.atlas.cellHeight - (frame.row + 1) * project.atlas.cellHeight),
                width: CGFloat(project.atlas.cellWidth),
                height: CGFloat(project.atlas.cellHeight)
            )
            let cellRect = sourceRect
            let scaledSize = NSSize(
                width: cellRect.width * CGFloat(frame.scale * frame.scaleX),
                height: cellRect.height * CGFloat(frame.scale * frame.scaleY)
            )
            let destination = NSRect(
                x: cellRect.midX - scaledSize.width / 2 + CGFloat(frame.offsetX),
                y: cellRect.midY - scaledSize.height / 2 + CGFloat(frame.offsetY),
                width: scaledSize.width,
                height: scaledSize.height
            )

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: cellRect).addClip()
            context.compositingOperation = .copy
            NSColor.clear.setFill()
            cellRect.fill()
            context.compositingOperation = .sourceOver
            atlas.draw(
                in: destination,
                from: sourceRect,
                operation: .sourceOver,
                fraction: 1
            )
            NSGraphicsContext.restoreGraphicsState()
        }

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let destination = projectsURL
            .appendingPathComponent(project.id, isDirectory: true)
            .appendingPathComponent("spritesheet.png")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let png = output.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destination.path)
        }
        try png.write(to: destination, options: .atomic)
        frameImageCache.removeAllObjects()
        return "project://spritesheet.png"
    }

    func exportFramePNG(
        _ frame: PetFrameDefinition,
        project: PetProjectDefinition,
        to destination: URL
    ) throws {
        guard let image = frameImage(for: frame, project: project),
              let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let png = representation.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destination.path)
        }
        try png.write(to: destination, options: .atomic)
    }

    /// Accepts a complete project folder or any of its public entry files.
    /// Resolution is intentionally shared with `importProject` so the ID shown
    /// by the UI always belongs to the exact project that will be imported.
    func projectIdentifier(in selectionURL: URL) throws -> String {
        try resolveImportSource(from: selectionURL).sourceID
    }

    func importProject(from selectionURL: URL, as targetID: String? = nil) throws -> PetProjectDefinition {
        let source = try resolveImportSource(from: selectionURL)
        let importedID = try validatedProjectID(targetID ?? source.sourceID)
        let configuration = source.configuration
        let atlasDefinition = AtlasDefinition(
            imagePath: "project://spritesheet.png",
            columns: configuration.cellsPerRow,
            rows: configuration.rowCount,
            cellWidth: configuration.cellWidth,
            cellHeight: configuration.cellHeight,
            filtering: source.studioProject?.atlas.filtering ?? .linear
        )

        guard let sourceImage = NSImage(contentsOf: source.atlasURL) else {
            throw StoreError.projectImageMissing(source.atlasURL.path)
        }
        try requireAtlas(sourceImage, definition: atlasDefinition)

        let sourceData = try Data(contentsOf: source.atlasURL)
        let pngData: Data
        if sourceData.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            // Preserve existing PNG pixels and color metadata byte-for-byte.
            pngData = sourceData
        } else {
            guard let normalizedAtlas = renderImage(
                sourceImage,
                sourceRect: NSRect(origin: .zero, size: sourceImage.size),
                targetPixels: CGSize(width: configuration.atlasWidth, height: configuration.atlasHeight),
                aspectFit: false
            ), let converted = normalizedAtlas.representation(using: .png, properties: [:]) else {
                throw StoreError.projectImageMissing(source.atlasURL.path)
            }
            pngData = converted
        }

        var base = source.studioProject ?? (try? bundledNaruto()) ?? PetProjectDefinition(
            id: importedID,
            name: source.displayName,
            author: "",
            projectDescription: source.projectDescription,
            formatVersion: 2,
            isBuiltIn: false,
            atlas: atlasDefinition,
            defaultActionID: configuration.actions.first?.key ?? "",
            actions: []
        )
        base.id = importedID
        base.name = source.displayName
        base.projectDescription = source.projectDescription
        base.isBuiltIn = false
        base.atlas = atlasDefinition
        base.atlasConfiguration = configuration
        base.configurationLibraryID = configuration.isBuiltIn ? configuration.id : nil
        base.isVisibleOnDesktop = false
        base.desktopOriginX = nil
        base.desktopOriginY = nil
        let project = CodexV2Schema.normalize(
            base,
            using: configuration,
            libraryID: configuration.isBuiltIn ? configuration.id : nil
        )

        let destination = projectsURL.appendingPathComponent(importedID, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw StoreError.importDestinationExists(importedID)
        }
        let staging = projectsURL.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer {
            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }
        }
        try pngData.write(to: staging.appendingPathComponent("spritesheet.png"), options: .atomic)
        try writeWorkspaceMetadata(for: project, to: staging)
        try FileManager.default.moveItem(at: staging, to: destination)

        frameImageCache.removeAllObjects()
        return project
    }

    func exportProject(_ project: PetProjectDefinition, to folder: URL) throws {
        let exportID = try validatedProjectID(project.id)
        let destination = folder.appendingPathComponent(exportID, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let staging = folder.appendingPathComponent(".export-\(UUID().uuidString)", isDirectory: true)
        let backup = folder.appendingPathComponent(".export-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer {
            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.removeItem(at: backup)
            }
        }

        var exported = CodexV2Schema.normalize(project)
        exported.isBuiltIn = false
        let imageSource = try imageURL(for: project)
        guard let image = NSImage(contentsOf: imageSource) else {
            throw StoreError.projectImageMissing(imageSource.path)
        }
        try requireAtlas(image, definition: exported.atlas)
        let imageDestination = staging.appendingPathComponent("spritesheet.png")
        try writePNG(
            image,
            to: imageDestination,
            pixelSize: CGSize(width: exported.atlas.columns * exported.atlas.cellWidth, height: exported.atlas.rows * exported.atlas.cellHeight)
        )

        let manifest = CodexPetManifest(
            id: exportID,
            displayName: project.name,
            description: project.projectDescription,
            spriteVersionNumber: exported.effectiveAtlasConfiguration.compatibility.spriteVersionNumber,
            spritesheetPath: "spritesheet.png"
        )
        try JSONEncoder.spritePet.encode(manifest)
            .write(to: staging.appendingPathComponent("pet.json"), options: .atomic)

        exported.atlas.imagePath = "project://spritesheet.png"
        try JSONEncoder.spritePet.encode(exported)
            .write(to: staging.appendingPathComponent("studio.json"), options: .atomic)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.moveItem(at: destination, to: backup)
            do {
                try FileManager.default.moveItem(at: staging, to: destination)
                try FileManager.default.removeItem(at: backup)
            } catch {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                if FileManager.default.fileExists(atPath: backup.path) {
                    try? FileManager.default.moveItem(at: backup, to: destination)
                }
                throw error
            }
        } else {
            try FileManager.default.moveItem(at: staging, to: destination)
        }
    }

    func createBlankProject(
        id: String,
        name: String,
        description: String,
        configuration: AtlasConfiguration,
        configurationLibraryID: String?
    ) throws -> PetProjectDefinition {
        let projectID = try validatedProjectID(id)
        guard !workspaceProjectIDExists(projectID) else {
            throw StoreError.projectIDInUse(projectID)
        }
        let atlas = AtlasDefinition(
            imagePath: "project://spritesheet.png",
            columns: max(1, configuration.cellsPerRow),
            rows: max(1, configuration.rowCount),
            cellWidth: max(1, configuration.cellWidth),
            cellHeight: max(1, configuration.cellHeight),
            filtering: .linear
        )
        var project = PetProjectDefinition(
            id: projectID,
            name: name,
            author: "",
            projectDescription: description,
            formatVersion: 2,
            isBuiltIn: false,
            atlas: atlas,
            defaultActionID: configuration.actions.first?.key ?? "",
            actions: [],
            atlasConfiguration: configuration,
            configurationLibraryID: configurationLibraryID
        )
        project = CodexV2Schema.normalize(
            project,
            using: configuration,
            libraryID: configurationLibraryID
        )
        project.isVisibleOnDesktop = false
        let size = CGSize(width: configuration.atlasWidth, height: configuration.atlasHeight)
        guard let bitmap = makeBitmap(size: size),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw StoreError.projectImageMissing("无法创建空白图集")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.compositingOperation = .copy
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let destination = projectsURL
            .appendingPathComponent(project.id, isDirectory: true)
            .appendingPathComponent("spritesheet.png")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destination.path)
        }
        try png.write(to: destination, options: .atomic)
        try saveWorkspaceMetadata(for: project)
        frameImageCache.removeAllObjects()
        return project
    }

    func duplicateProject(
        _ source: PetProjectDefinition,
        id: String,
        name: String
    ) throws -> PetProjectDefinition {
        let projectID = try validatedProjectID(id)
        guard let sourceImage = NSImage(contentsOf: try imageURL(for: source)) else {
            throw StoreError.projectImageMissing(source.atlas.imagePath)
        }
        try requireAtlas(sourceImage, definition: source.atlas)

        let destinationFolder = projectsURL.appendingPathComponent(projectID, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destinationFolder.path) else {
            throw StoreError.projectIDInUse(projectID)
        }
        let staging = projectsURL.appendingPathComponent(".duplicate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer {
            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }
        }
        let destinationImage = staging.appendingPathComponent("spritesheet.png")
        try writePNG(
            sourceImage,
            to: destinationImage,
            pixelSize: CGSize(
                width: source.atlas.columns * source.atlas.cellWidth,
                height: source.atlas.rows * source.atlas.cellHeight
            )
        )

        var copy = source
        copy.id = projectID
        copy.name = name
        copy.isBuiltIn = false
        copy.atlas.imagePath = "project://spritesheet.png"
        copy.isVisibleOnDesktop = false
        copy.desktopOriginX = nil
        copy.desktopOriginY = nil
        try writeWorkspaceMetadata(for: copy, to: staging)
        try FileManager.default.moveItem(at: staging, to: destinationFolder)
        frameImageCache.removeAllObjects()
        return copy
    }

    func reconfigureProject(
        _ project: PetProjectDefinition,
        using configuration: AtlasConfiguration,
        libraryID: String?
    ) throws -> PetProjectDefinition {
        try requireEditable(project)
        guard let sourceAtlas = NSImage(contentsOf: try imageURL(for: project)) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }
        try requireAtlas(sourceAtlas, definition: project.atlas)

        var updated = CodexV2Schema.normalize(
            project,
            using: configuration,
            libraryID: libraryID
        )
        updated.isBuiltIn = false
        updated.atlas.imagePath = "project://spritesheet.png"

        let outputSize = CGSize(width: configuration.atlasWidth, height: configuration.atlasHeight)
        guard let output = makeBitmap(size: outputSize),
              let context = NSGraphicsContext(bitmapImageRep: output) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = project.atlas.filtering == .nearest ? .none : .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: outputSize).fill()

        for newAction in updated.actions {
            guard let oldAction = project.actions.first(where: { $0.id == newAction.id }) else { continue }
            for index in newAction.frames.indices where oldAction.frames.indices.contains(index) {
                let oldFrame = oldAction.frames[index]
                let newFrame = newAction.frames[index]
                let sourceRect = NSRect(
                    x: CGFloat(oldFrame.column * project.atlas.cellWidth),
                    y: CGFloat(project.atlas.rows * project.atlas.cellHeight - (oldFrame.row + 1) * project.atlas.cellHeight),
                    width: CGFloat(project.atlas.cellWidth),
                    height: CGFloat(project.atlas.cellHeight)
                )
                let cellRect = NSRect(
                    x: CGFloat(newFrame.column * updated.atlas.cellWidth),
                    y: CGFloat(updated.atlas.rows * updated.atlas.cellHeight - (newFrame.row + 1) * updated.atlas.cellHeight),
                    width: CGFloat(updated.atlas.cellWidth),
                    height: CGFloat(updated.atlas.cellHeight)
                )
                let scale = min(cellRect.width / sourceRect.width, cellRect.height / sourceRect.height)
                let destination = NSRect(
                    x: cellRect.midX - sourceRect.width * scale / 2,
                    y: cellRect.midY - sourceRect.height * scale / 2,
                    width: sourceRect.width * scale,
                    height: sourceRect.height * scale
                )
                sourceAtlas.draw(
                    in: destination,
                    from: sourceRect,
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let destination = projectsURL
            .appendingPathComponent(project.id, isDirectory: true)
            .appendingPathComponent("spritesheet.png")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let png = output.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destination.path)
        }
        try png.write(to: destination, options: .atomic)
        frameImageCache.removeAllObjects()
        return updated
    }

    func deleteProjectData(_ project: PetProjectDefinition) throws {
        try requireEditable(project)
        let destination = projectsURL.appendingPathComponent(project.id, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        frameImageCache.removeAllObjects()
    }

    private struct ResolvedImportSource {
        let folderURL: URL
        let atlasURL: URL
        let manifest: CodexPetManifest?
        let studioProject: PetProjectDefinition?
        let configuration: AtlasConfiguration
        let sourceID: String
        let displayName: String
        let projectDescription: String
    }

    private func resolveImportSource(from selectionURL: URL) throws -> ResolvedImportSource {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: selectionURL.path, isDirectory: &isDirectory) else {
            throw StoreError.unsupportedImportSelection(selectionURL.path)
        }

        let folderURL = isDirectory.boolValue
            ? selectionURL
            : selectionURL.deletingLastPathComponent()
        let selectedExtension = isDirectory.boolValue
            ? ""
            : selectionURL.pathExtension.lowercased()
        let imageExtensions = Set(["png", "webp"])
        guard isDirectory.boolValue || selectedExtension == "json" || imageExtensions.contains(selectedExtension) else {
            throw StoreError.unsupportedImportSelection(selectionURL.lastPathComponent)
        }

        var manifest: CodexPetManifest?
        var studioProject: PetProjectDefinition?
        var selectedJSONFailure: String?
        if selectedExtension == "json" {
            do {
                let data = try Data(contentsOf: selectionURL)
                switch selectionURL.lastPathComponent.lowercased() {
                case "studio.json":
                    do {
                        studioProject = try JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data)
                    } catch {
                        selectedJSONFailure = "不是有效的 SpritePet Studio 工程配置（\(error.localizedDescription)）"
                    }
                case "pet.json", "path.json":
                    do {
                        manifest = try JSONDecoder.spritePet.decode(CodexPetManifest.self, from: data)
                    } catch {
                        selectedJSONFailure = "不是有效的 Codex manifest（\(error.localizedDescription)）"
                    }
                default:
                    manifest = try? JSONDecoder.spritePet.decode(CodexPetManifest.self, from: data)
                    if manifest == nil {
                        studioProject = try? JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data)
                    }
                    if manifest == nil, studioProject == nil {
                        selectedJSONFailure = "内容既不匹配 pet.json，也不匹配 studio.json"
                    }
                }
            } catch {
                selectedJSONFailure = error.localizedDescription
            }
        }

        // Sidecar JSON files enrich an import but are not required. Corrupt
        // sidecars are ignored when the user selected a folder or the atlas;
        // selecting that corrupt JSON directly still reports the error above.
        if manifest == nil {
            for filename in ["pet.json", "path.json"] {
                let candidate = folderURL.appendingPathComponent(filename)
                guard candidate.standardizedFileURL != selectionURL.standardizedFileURL,
                      fileManager.fileExists(atPath: candidate.path),
                      let data = try? Data(contentsOf: candidate),
                      let decoded = try? JSONDecoder.spritePet.decode(CodexPetManifest.self, from: data) else {
                    continue
                }
                manifest = decoded
                break
            }
        }
        if studioProject == nil {
            let candidate = folderURL.appendingPathComponent("studio.json")
            if candidate.standardizedFileURL != selectionURL.standardizedFileURL,
               fileManager.fileExists(atPath: candidate.path),
               let data = try? Data(contentsOf: candidate) {
                studioProject = try? JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data)
            }
        }

        var atlasCandidates: [URL] = []
        func appendAtlasCandidate(_ url: URL) {
            let standardized = url.standardizedFileURL
            guard !atlasCandidates.contains(where: { $0.standardizedFileURL == standardized }) else { return }
            atlasCandidates.append(url)
        }
        func appendRelativeAtlasCandidate(_ path: String) {
            let relative = path.replacingOccurrences(of: "project://", with: "")
            guard !relative.isEmpty,
                  !relative.hasPrefix("builtin://"),
                  !(relative as NSString).isAbsolutePath else { return }
            let candidate = folderURL.appendingPathComponent(relative).standardizedFileURL
            let rootPath = folderURL.standardizedFileURL.path
            guard candidate.path.hasPrefix(rootPath + "/") else { return }
            appendAtlasCandidate(candidate)
        }
        if imageExtensions.contains(selectedExtension) {
            appendAtlasCandidate(selectionURL)
        }
        if let path = manifest?.spritesheetPath, !path.isEmpty {
            appendRelativeAtlasCandidate(path)
        }
        if let path = studioProject?.atlas.imagePath, !path.isEmpty {
            appendRelativeAtlasCandidate(path)
        }
        appendAtlasCandidate(folderURL.appendingPathComponent("spritesheet.png"))
        appendAtlasCandidate(folderURL.appendingPathComponent("spritesheet.webp"))

        guard let atlasURL = atlasCandidates.first(where: { candidate in
            var candidateIsDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: candidate.path, isDirectory: &candidateIsDirectory)
                && !candidateIsDirectory.boolValue
        }) else {
            if let selectedJSONFailure {
                throw StoreError.invalidImportJSON(
                    file: selectionURL.lastPathComponent,
                    reason: "\(selectedJSONFailure)；同目录也没有可用于降级导入的 spritesheet.png / .webp"
                )
            }
            let searched = atlasCandidates.isEmpty
                ? ["spritesheet.png", "spritesheet.webp"]
                : atlasCandidates.map(\.lastPathComponent)
            throw StoreError.importAtlasMissing(
                folder: folderURL.path,
                searched: Array(Set(searched)).sorted()
            )
        }
        guard let atlasImage = NSImage(contentsOf: atlasURL) else {
            throw StoreError.projectImageMissing(atlasURL.path)
        }
        let dimensions = pixelDimensions(of: atlasImage)

        let configuration: AtlasConfiguration
        if let embedded = studioProject?.atlasConfiguration {
            let expectedWidth = embedded.atlasWidth
            let expectedHeight = embedded.atlasHeight
            guard dimensions.width == expectedWidth, dimensions.height == expectedHeight else {
                throw StoreError.invalidAtlas(
                    width: dimensions.width,
                    height: dimensions.height,
                    expectedWidth: expectedWidth,
                    expectedHeight: expectedHeight
                )
            }
            configuration = embedded
        } else if let studioProject,
                  let inferred = inferredConfiguration(from: studioProject),
                  inferred.atlasWidth == dimensions.width,
                  inferred.atlasHeight == dimensions.height {
            configuration = inferred
        } else if let standard = CodexSchemas.configuration(
            forAtlasWidth: dimensions.width,
            height: dimensions.height
        ) {
            configuration = standard
        } else {
            throw StoreError.unsupportedImportAtlas(width: dimensions.width, height: dimensions.height)
        }

        let folderName = folderURL.lastPathComponent.isEmpty ? "pet" : folderURL.lastPathComponent
        let manifestID = manifest?.id.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let studioID = studioProject?.id.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sourceID = !manifestID.isEmpty ? manifestID : (!studioID.isEmpty ? studioID : folderName)
        let manifestName = manifest?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let studioName = studioProject?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = !manifestName.isEmpty ? manifestName : (!studioName.isEmpty ? studioName : folderName)
        let manifestDescription = manifest?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let studioDescription = studioProject?.projectDescription.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ResolvedImportSource(
            folderURL: folderURL,
            atlasURL: atlasURL,
            manifest: manifest,
            studioProject: studioProject,
            configuration: configuration,
            sourceID: sourceID,
            displayName: displayName,
            projectDescription: !manifestDescription.isEmpty ? manifestDescription : studioDescription
        )
    }

    private func inferredConfiguration(from project: PetProjectDefinition) -> AtlasConfiguration? {
        guard project.atlas.columns > 0,
              project.atlas.rows > 0,
              project.atlas.cellWidth > 0,
              project.atlas.cellHeight > 0,
              !project.actions.isEmpty else { return nil }

        let actions = project.actions.map { action -> AtlasActionConfiguration in
            let rows = action.frames.map(\.row)
            let occupiedRows: Int
            if let minimum = rows.min(), let maximum = rows.max() {
                occupiedRows = max(1, maximum - minimum + 1)
            } else {
                occupiedRows = max(1, Int(ceil(Double(max(1, action.frames.count)) / Double(project.atlas.columns))))
            }
            return AtlasActionConfiguration(
                name: action.name,
                key: action.id,
                frameCount: max(1, action.frames.count),
                occupiedRows: occupiedRows
            )
        }
        let configuration = AtlasConfiguration(
            id: project.configurationLibraryID ?? "\(project.id)-layout",
            name: "\(project.name) 图集配置",
            configurationDescription: "从导入的 studio.json 恢复。",
            isBuiltIn: false,
            compatibility: .spritePetStudio,
            cellWidth: project.atlas.cellWidth,
            cellHeight: project.atlas.cellHeight,
            actions: actions
        )
        guard configuration.cellsPerRow == project.atlas.columns,
              configuration.rowCount == project.atlas.rows else { return nil }
        return configuration
    }

    private func writeAtlas(
        project: PetProjectDefinition,
        replacing frame: PetFrameDefinition,
        with cellBitmap: NSBitmapImageRep
    ) throws -> String {
        guard let atlas = NSImage(contentsOf: try imageURL(for: project)) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }
        try requireAtlas(atlas, definition: project.atlas)
        let atlasSize = CGSize(
            width: CGFloat(project.atlas.columns * project.atlas.cellWidth),
            height: CGFloat(project.atlas.rows * project.atlas.cellHeight)
        )
        guard let output = makeBitmap(size: atlasSize),
              let context = NSGraphicsContext(bitmapImageRep: output) else {
            throw StoreError.projectImageMissing(project.atlas.imagePath)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: atlasSize).fill()
        atlas.draw(
            in: NSRect(origin: .zero, size: atlasSize),
            from: NSRect(origin: .zero, size: atlas.size),
            operation: .copy,
            fraction: 1
        )

        let cellImage = NSImage(size: NSSize(
            width: CGFloat(project.atlas.cellWidth),
            height: CGFloat(project.atlas.cellHeight)
        ))
        cellImage.addRepresentation(cellBitmap)
        let destination = NSRect(
            x: CGFloat(frame.column * project.atlas.cellWidth),
            y: CGFloat(project.atlas.rows * project.atlas.cellHeight - (frame.row + 1) * project.atlas.cellHeight),
            width: CGFloat(project.atlas.cellWidth),
            height: CGFloat(project.atlas.cellHeight)
        )
        cellImage.draw(
            in: destination,
            from: NSRect(
                x: 0,
                y: 0,
                width: CGFloat(project.atlas.cellWidth),
                height: CGFloat(project.atlas.cellHeight)
            ),
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let destinationURL = projectsURL
            .appendingPathComponent(project.id, isDirectory: true)
            .appendingPathComponent("spritesheet.png")
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let png = output.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destinationURL.path)
        }
        try png.write(to: destinationURL, options: .atomic)
        frameImageCache.removeAllObjects()
        return "project://spritesheet.png"
    }

    private func requireAtlas(_ image: NSImage, definition: AtlasDefinition) throws {
        let dimensions = pixelDimensions(of: image)
        let expectedWidth = definition.columns * definition.cellWidth
        let expectedHeight = definition.rows * definition.cellHeight
        guard dimensions.width == expectedWidth,
              dimensions.height == expectedHeight else {
            throw StoreError.invalidAtlas(
                width: dimensions.width,
                height: dimensions.height,
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight
            )
        }
    }

    private func pixelDimensions(of image: NSImage) -> (width: Int, height: Int) {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return (bitmap.pixelsWide, bitmap.pixelsHigh)
        }
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            return (bitmap.pixelsWide, bitmap.pixelsHigh)
        }
        return (Int(image.size.width), Int(image.size.height))
    }

    private func writePNG(_ image: NSImage, to destination: URL, pixelSize: CGSize) throws {
        guard let representation = renderImage(
            image,
            sourceRect: NSRect(origin: .zero, size: image.size),
            targetPixels: pixelSize,
            aspectFit: false
        ), let png = representation.representation(using: .png, properties: [:]) else {
            throw StoreError.projectImageMissing(destination.path)
        }
        try png.write(to: destination, options: .atomic)
    }

    private func croppedAtlasFrame(
        _ frame: PetFrameDefinition,
        project: PetProjectDefinition
    ) -> NSImage? {
        guard let url = try? imageURL(for: project),
              let atlas = NSImage(contentsOf: url) else { return nil }
        let width = CGFloat(project.atlas.cellWidth)
        let height = CGFloat(project.atlas.cellHeight)
        let sourceRect = NSRect(
            x: CGFloat(frame.column) * width,
            y: atlas.size.height - CGFloat(frame.row + 1) * height,
            width: width,
            height: height
        )
        guard let representation = renderImage(
            atlas,
            sourceRect: sourceRect,
            targetPixels: CGSize(width: width, height: height),
            aspectFit: false
        ) else { return nil }
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(representation)
        return image
    }

    private func renderImage(
        _ image: NSImage,
        sourceRect: NSRect,
        targetPixels: CGSize,
        aspectFit: Bool
    ) -> NSBitmapImageRep? {
        let pixelWidth = max(1, Int(targetPixels.width.rounded()))
        let pixelHeight = max(1, Int(targetPixels.height.rounded()))
        guard let bitmap = makeBitmap(size: targetPixels),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight).fill()

        var destination = NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        if aspectFit, sourceRect.width > 0, sourceRect.height > 0 {
            let scale = min(destination.width / sourceRect.width, destination.height / sourceRect.height)
            let fittedSize = NSSize(width: sourceRect.width * scale, height: sourceRect.height * scale)
            destination = NSRect(
                x: (destination.width - fittedSize.width) / 2,
                y: (destination.height - fittedSize.height) / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )
        }
        image.draw(in: destination, from: sourceRect, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func makeBitmap(size: CGSize) -> NSBitmapImageRep? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        return NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }
}

extension JSONEncoder {
    static var spritePet: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

extension JSONDecoder {
    static var spritePet: JSONDecoder { JSONDecoder() }
}
