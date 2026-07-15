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

        var errorDescription: String? {
            switch self {
            case .bundledProjectMissing(let name):
                return "找不到内置工程：\(name)。"
            case .projectImageMissing(let path):
                return "工程图集不存在：\(path)"
            case .readOnlyTemplate(let name):
                return "“\(name)”是只读模板。请先复制完整工程，再编辑动作或图集。"
            case .invalidCodexManifest(let reason):
                return "不是可用的 Codex v2 工程：\(reason)"
            case .invalidAtlas(let width, let height, let expectedWidth, let expectedHeight):
                return "图集必须是 \(expectedWidth) × \(expectedHeight)，当前是 \(width) × \(height)。"
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

        document.atlasConfigurations.removeAll { $0.id == CodexV2Schema.configuration.id }
        document.atlasConfigurations.insert(CodexV2Schema.configuration, at: 0)

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
            if document.projects[index].effectiveAtlasConfiguration.id == CodexV2Schema.configuration.id {
                document.projects[index].configurationLibraryID = CodexV2Schema.configuration.id
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

        var stored = project
        stored.isBuiltIn = false
        try JSONEncoder.spritePet.encode(stored)
            .write(to: folder.appendingPathComponent("studio.json"), options: .atomic)

        let manifest = CodexPetManifest(
            id: stored.id,
            displayName: stored.name,
            description: stored.projectDescription,
            spriteVersionNumber: stored.effectiveAtlasConfiguration.compatibility == .codexV2 ? 2 : 0,
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

    func projectIdentifier(in projectJSONURL: URL) throws -> String {
        let data = try Data(contentsOf: projectJSONURL)
        if projectJSONURL.lastPathComponent == "pet.json" {
            return try JSONDecoder.spritePet.decode(CodexPetManifest.self, from: data).id
        }
        return try JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data).id
    }

    func importProject(from projectJSONURL: URL, as targetID: String? = nil) throws -> PetProjectDefinition {
        let project: PetProjectDefinition
        if projectJSONURL.lastPathComponent == "pet.json" {
            project = try importCodexProject(from: projectJSONURL, targetID: targetID)
        } else {
            let data = try Data(contentsOf: projectJSONURL)
            var imported = try JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: data)
            imported.id = targetID ?? imported.id
            imported.isBuiltIn = false

            let sourceFolder = projectJSONURL.deletingLastPathComponent()
            let destination = projectsURL.appendingPathComponent(imported.id, isDirectory: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceFolder, to: destination)
            if !imported.atlas.imagePath.hasPrefix("project://") {
                imported.atlas.imagePath = "project://\((imported.atlas.imagePath as NSString).lastPathComponent)"
            }
            guard let image = NSImage(contentsOf: try imageURL(for: imported)) else {
                throw StoreError.projectImageMissing(imported.atlas.imagePath)
            }
            try requireAtlas(image, definition: imported.atlas)
            project = CodexV2Schema.normalize(imported)
        }
        try saveWorkspaceMetadata(for: project)
        return project
    }

    func exportProject(_ project: PetProjectDefinition, to folder: URL) throws {
        let destination = folder.appendingPathComponent(project.id, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        var exported = CodexV2Schema.normalize(project)
        exported.isBuiltIn = false
        let imageSource = try imageURL(for: project)
        guard let image = NSImage(contentsOf: imageSource) else {
            throw StoreError.projectImageMissing(imageSource.path)
        }
        try requireAtlas(image, definition: exported.atlas)
        let imageDestination = destination.appendingPathComponent("spritesheet.png")
        try writePNG(
            image,
            to: imageDestination,
            pixelSize: CGSize(width: exported.atlas.columns * exported.atlas.cellWidth, height: exported.atlas.rows * exported.atlas.cellHeight)
        )

        let manifest = CodexPetManifest(
            id: project.id,
            displayName: project.name,
            description: project.projectDescription,
            spriteVersionNumber: exported.effectiveAtlasConfiguration.compatibility == .codexV2 ? 2 : 0,
            spritesheetPath: "spritesheet.png"
        )
        try JSONEncoder.spritePet.encode(manifest)
            .write(to: destination.appendingPathComponent("pet.json"), options: .atomic)

        exported.atlas.imagePath = "project://spritesheet.png"
        try JSONEncoder.spritePet.encode(exported)
            .write(to: destination.appendingPathComponent("studio.json"), options: .atomic)
    }

    func createBlankProject(
        id: String,
        name: String,
        description: String,
        configuration: AtlasConfiguration,
        configurationLibraryID: String?
    ) throws -> PetProjectDefinition {
        let atlas = AtlasDefinition(
            imagePath: "project://spritesheet.png",
            columns: max(1, configuration.cellsPerRow),
            rows: max(1, configuration.rowCount),
            cellWidth: max(1, configuration.cellWidth),
            cellHeight: max(1, configuration.cellHeight),
            filtering: .linear
        )
        var project = PetProjectDefinition(
            id: id,
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
            .appendingPathComponent(id, isDirectory: true)
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
        guard let sourceImage = NSImage(contentsOf: try imageURL(for: source)) else {
            throw StoreError.projectImageMissing(source.atlas.imagePath)
        }
        try requireAtlas(sourceImage, definition: source.atlas)

        let destinationFolder = projectsURL.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let destinationImage = destinationFolder.appendingPathComponent("spritesheet.png")
        try writePNG(
            sourceImage,
            to: destinationImage,
            pixelSize: CGSize(
                width: source.atlas.columns * source.atlas.cellWidth,
                height: source.atlas.rows * source.atlas.cellHeight
            )
        )

        var copy = source
        copy.id = id
        copy.name = name
        copy.isBuiltIn = false
        copy.atlas.imagePath = "project://spritesheet.png"
        copy.isVisibleOnDesktop = false
        copy.desktopOriginX = nil
        copy.desktopOriginY = nil
        try saveWorkspaceMetadata(for: copy)
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

    private func importCodexProject(from petJSONURL: URL, targetID: String?) throws -> PetProjectDefinition {
        let data = try Data(contentsOf: petJSONURL)
        var manifest = try JSONDecoder.spritePet.decode(CodexPetManifest.self, from: data)
        manifest.id = targetID ?? manifest.id
        let sourceAtlasURL = petJSONURL.deletingLastPathComponent()
            .appendingPathComponent(manifest.spritesheetPath)
        guard let sourceImage = NSImage(contentsOf: sourceAtlasURL) else {
            throw StoreError.projectImageMissing(sourceAtlasURL.path)
        }
        let studioURL = petJSONURL.deletingLastPathComponent().appendingPathComponent("studio.json")
        let studioTemplate: PetProjectDefinition?
        if FileManager.default.fileExists(atPath: studioURL.path) {
            studioTemplate = try? JSONDecoder.spritePet.decode(
                PetProjectDefinition.self,
                from: Data(contentsOf: studioURL)
            )
        } else {
            studioTemplate = try? bundledNaruto()
        }
        let configuration: AtlasConfiguration
        if let embedded = studioTemplate?.atlasConfiguration {
            configuration = embedded
        } else {
            guard manifest.spriteVersionNumber == 2 else {
                throw StoreError.invalidCodexManifest("自定义图集需要同目录的 studio.json")
            }
            configuration = CodexV2Schema.configuration
        }
        let atlasDefinition = AtlasDefinition(
            imagePath: "project://spritesheet.png",
            columns: configuration.cellsPerRow,
            rows: configuration.rowCount,
            cellWidth: configuration.cellWidth,
            cellHeight: configuration.cellHeight,
            filtering: studioTemplate?.atlas.filtering ?? .linear
        )
        try requireAtlas(sourceImage, definition: atlasDefinition)

        let destination = projectsURL.appendingPathComponent(manifest.id, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let atlasDestination = destination.appendingPathComponent("spritesheet.png")
        try writePNG(
            sourceImage,
            to: atlasDestination,
            pixelSize: CGSize(width: configuration.atlasWidth, height: configuration.atlasHeight)
        )

        frameImageCache.removeAllObjects()
        if var studioTemplate {
            studioTemplate.id = manifest.id
            studioTemplate.name = manifest.displayName
            studioTemplate.projectDescription = manifest.description
            studioTemplate.isBuiltIn = false
            studioTemplate.atlas = atlasDefinition
            studioTemplate.atlasConfiguration = configuration
            return CodexV2Schema.normalize(studioTemplate, using: configuration)
        }
        return CodexV2Schema.makeProject(
            manifest: manifest,
            atlasPath: "project://spritesheet.png",
            settingsTemplate: nil
        )
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
