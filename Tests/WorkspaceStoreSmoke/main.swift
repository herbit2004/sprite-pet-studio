import AppKit
import Foundation

@main
struct WorkspaceStoreSmoke {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let exportRoot = root.appendingPathComponent("Exports", isDirectory: true)
        let store = DocumentStore(applicationSupportURL: root.appendingPathComponent("Library", isDirectory: true))

        var document = try store.load()
        precondition(document.projects.count == 2)
        precondition(document.projects.allSatisfy(\.isReadOnlyTemplate))
        precondition(document.projects.allSatisfy { $0.atlas.imagePath.hasPrefix("builtin://") })
        precondition(document.projects.map(\.id) == ["little-naruto-v5", "dimoo-heartfelt-mix"])
        precondition(document.projects.allSatisfy { project in
            project.actions.allSatisfy { action in
                action.triggers.allSatisfy { $0.delaySeconds == 0 }
            }
        })
        try assertTemplateRuntimeParametersMatch(document.projects)

        var delayedProject = document.projects[0]
        delayedProject.actions[0].triggers[0].delaySeconds = 1.25
        let delayedData = try JSONEncoder().encode(delayedProject)
        let delayedRoundTrip = try JSONDecoder().decode(PetProjectDefinition.self, from: delayedData)
        precondition(delayedRoundTrip.actions[0].triggers[0].delaySeconds == 1.25)

        let template = document.projects[0]
        do {
            _ = try store.bakeAllFrameTransforms(in: template)
            preconditionFailure("A template accepted a destructive atlas edit")
        } catch DocumentStore.StoreError.readOnlyTemplate {
            // Expected: templates can run and export, but never enter write paths.
        }

        let copy = try store.duplicateProject(template, id: "template-copy", name: "可编辑副本")
        document.projects.append(copy)
        document.selectedProjectID = copy.id
        try store.save(document)

        let projectFolder = store.projectsURL.appendingPathComponent(copy.id, isDirectory: true)
        for filename in ["pet.json", "studio.json", "spritesheet.png"] {
            precondition(FileManager.default.fileExists(atPath: projectFolder.appendingPathComponent(filename).path))
        }
        try assertSingleProjectIDInvariant(copy, store: store)

        // Simulate a fresh state file while keeping the user's Projects folder.
        // The two templates must come from the App bundle and the private copy
        // must be independently rediscovered from its own studio.json.
        try FileManager.default.removeItem(at: store.stateURL)
        let reopened = try DocumentStore(applicationSupportURL: store.applicationSupportURL).load()
        precondition(reopened.projects.count == 3)
        precondition(reopened.projects.filter(\.isReadOnlyTemplate).count == 2)
        precondition(reopened.projects.first(where: { $0.id == copy.id })?.isReadOnlyTemplate == false)

        for bundledTemplate in document.projects.filter(\.isReadOnlyTemplate) {
            try store.exportProject(bundledTemplate, to: exportRoot)
            let exportID = bundledTemplate.id
            let exportedFolder = exportRoot.appendingPathComponent(exportID, isDirectory: true)
            for filename in ["pet.json", "studio.json", "spritesheet.png"] {
                precondition(FileManager.default.fileExists(atPath: exportedFolder.appendingPathComponent(filename).path))
            }
            let exportedManifest = try JSONDecoder.spritePet.decode(
                CodexPetManifest.self,
                from: Data(contentsOf: exportedFolder.appendingPathComponent("pet.json"))
            )
            let exportedStudio = try JSONDecoder.spritePet.decode(
                PetProjectDefinition.self,
                from: Data(contentsOf: exportedFolder.appendingPathComponent("studio.json"))
            )
            precondition(exportedManifest.id == exportID)
            precondition(exportedStudio.id == exportID)
        }

        let exportedTemplate = exportRoot.appendingPathComponent(template.id, isDirectory: true)
        let staleExportFile = exportedTemplate.appendingPathComponent("stale.txt")
        try Data("stale".utf8).write(to: staleExportFile)
        try store.exportProject(template, to: exportRoot)
        precondition(!FileManager.default.fileExists(atPath: staleExportFile.path))
        let exportedPetJSON = exportedTemplate.appendingPathComponent("pet.json")
        let exportedID = try store.projectIdentifier(in: exportedPetJSON)
        precondition(exportedID == template.id)
        let imported = try store.importProject(from: exportedPetJSON, as: "imported-template")
        precondition(!imported.isReadOnlyTemplate)
        precondition(imported.id == "imported-template")
        let importedFolder = store.projectsURL.appendingPathComponent(imported.id, isDirectory: true)
        for filename in ["pet.json", "studio.json", "spritesheet.png"] {
            precondition(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent(filename).path))
        }

        try assertFlexibleProjectImports(
            store: store,
            fixtureRoot: root.appendingPathComponent("ImportFixtures", isDirectory: true),
            exportedV2Project: exportedTemplate
        )
        assertManualPreviewCopySemantics(using: template)

        print("Workspace storage smoke test: OK")
    }

    private static func assertSingleProjectIDInvariant(
        _ project: PetProjectDefinition,
        store: DocumentStore
    ) throws {
        let folder = store.projectsURL.appendingPathComponent(project.id, isDirectory: true)
        precondition(folder.lastPathComponent == project.id)
        let studioData = try Data(contentsOf: folder.appendingPathComponent("studio.json"))
        let manifestData = try Data(contentsOf: folder.appendingPathComponent("pet.json"))
        let studio = try JSONDecoder.spritePet.decode(PetProjectDefinition.self, from: studioData)
        let manifest = try JSONDecoder.spritePet.decode(CodexPetManifest.self, from: manifestData)
        precondition(studio.id == project.id)
        precondition(manifest.id == project.id)
        precondition(!String(decoding: studioData, as: UTF8.self).contains("\"directoryName\""))
    }

    /// Exercises every user-facing import entry point against real folders and
    /// atlas files. JSON metadata is deliberately optional: the cell geometry
    /// of the two Codex formats is enough to recover a useful project.
    private static func assertFlexibleProjectImports(
        store: DocumentStore,
        fixtureRoot: URL,
        exportedV2Project: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

        // A complete SpritePet Studio/Codex v2 export can be selected either by
        // its directory or by studio.json. Both must discover the sibling files.
        let completeV2 = fixtureRoot.appendingPathComponent("complete-v2", isDirectory: true)
        try fileManager.copyItem(at: exportedV2Project, to: completeV2)
        let completeV2SourceID = try store.projectIdentifier(in: completeV2)
        precondition(!completeV2SourceID.isEmpty)
        let directoryImport = try store.importProject(from: completeV2, as: "folder-selected-v2")
        assertImportedProject(directoryImport, expectedRows: 11, expectedActions: 10, store: store)

        let studioImport = try store.importProject(
            from: completeV2.appendingPathComponent("studio.json"),
            as: "studio-selected-v2"
        )
        assertImportedProject(studioImport, expectedRows: 11, expectedActions: 10, store: store)

        // spritesheet.png is the sole required file. A 1536 x 2288 atlas must
        // infer the v2 layout even when both JSON files are absent.
        let atlasOnlyV2 = fixtureRoot.appendingPathComponent("atlas-only-v2", isDirectory: true)
        try fileManager.createDirectory(at: atlasOnlyV2, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: exportedV2Project.appendingPathComponent("spritesheet.png"),
            to: atlasOnlyV2.appendingPathComponent("spritesheet.png")
        )
        let atlasOnlyV2FolderID = try store.projectIdentifier(in: atlasOnlyV2)
        let atlasOnlyV2FileID = try store.projectIdentifier(
            in: atlasOnlyV2.appendingPathComponent("spritesheet.png")
        )
        precondition(atlasOnlyV2FolderID == "atlas-only-v2")
        precondition(atlasOnlyV2FileID == "atlas-only-v2")
        let atlasV2Import = try store.importProject(
            from: atlasOnlyV2.appendingPathComponent("spritesheet.png"),
            as: "png-selected-v2"
        )
        assertImportedProject(atlasV2Import, expectedRows: 11, expectedActions: 10, store: store)

        // Codex v1 is the first nine v2 rows. Its historical pet.json commonly
        // has no spriteVersionNumber, so dimension inference must still import it.
        let atlasOnlyV1 = fixtureRoot.appendingPathComponent("atlas-only-v1", isDirectory: true)
        try fileManager.createDirectory(at: atlasOnlyV1, withIntermediateDirectories: true)
        let v1Atlas = atlasOnlyV1.appendingPathComponent("spritesheet.png")
        try writeTransparentPNG(width: 1_536, height: 1_872, to: v1Atlas)

        let v1FromFolder = try store.importProject(from: atlasOnlyV1, as: "folder-selected-v1")
        assertImportedProject(v1FromFolder, expectedRows: 9, expectedActions: 9, store: store)
        let v1FromPNG = try store.importProject(from: v1Atlas, as: "png-selected-v1")
        assertImportedProject(v1FromPNG, expectedRows: 9, expectedActions: 9, store: store)
        let importedV1PNG = store.projectsURL
            .appendingPathComponent(v1FromPNG.id, isDirectory: true)
            .appendingPathComponent("spritesheet.png")
        let importedV1PNGData = try Data(contentsOf: importedV1PNG)
        let sourceV1PNGData = try Data(contentsOf: v1Atlas)
        precondition(importedV1PNGData == sourceV1PNGData)

        // Even an explicitly selected legacy JSON that cannot be decoded must
        // fall back to a valid sibling atlas, because the atlas is the only
        // mandatory import artifact.
        let malformedJSONFolder = fixtureRoot.appendingPathComponent("malformed-json", isDirectory: true)
        try fileManager.createDirectory(at: malformedJSONFolder, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: v1Atlas,
            to: malformedJSONFolder.appendingPathComponent("spritesheet.png")
        )
        let malformedPetJSON = malformedJSONFolder.appendingPathComponent("pet.json")
        try Data("{ legacy-but-not-decodable }".utf8).write(to: malformedPetJSON)
        let malformedJSONFallback = try store.importProject(
            from: malformedPetJSON,
            as: "malformed-json-fallback"
        )
        assertImportedProject(malformedJSONFallback, expectedRows: 9, expectedActions: 9, store: store)

        // A colliding destination must fail without removing or partially
        // replacing the already imported project.
        let collisionMarker = store.projectsURL
            .appendingPathComponent(malformedJSONFallback.id, isDirectory: true)
            .appendingPathComponent("keep-me.txt")
        try Data("preserve".utf8).write(to: collisionMarker)
        assertImportFails(from: malformedPetJSON, store: store, targetID: malformedJSONFallback.id) { message in
            message.contains("已经存在") || message.localizedCaseInsensitiveContains("exist")
        }
        let preservedMarker = try String(contentsOf: collisionMarker, encoding: .utf8)
        precondition(preservedMarker == "preserve")

        let legacyManifestFolder = fixtureRoot.appendingPathComponent("legacy-manifest", isDirectory: true)
        try fileManager.createDirectory(at: legacyManifestFolder, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: v1Atlas,
            to: legacyManifestFolder.appendingPathComponent("spritesheet.png")
        )
        let legacyManifest = legacyManifestFolder.appendingPathComponent("pet.json")
        try writeLegacyManifest(
            id: "legacy-codex-v1",
            atlasName: "spritesheet.png",
            to: legacyManifest
        )
        let legacyManifestID = try store.projectIdentifier(in: legacyManifest)
        precondition(legacyManifestID == "legacy-codex-v1")
        let v1FromManifest = try store.importProject(from: legacyManifest, as: "pet-json-selected-v1")
        assertImportedProject(v1FromManifest, expectedRows: 9, expectedActions: 9, store: store)

        // Some old exports call the manifest path.json. Classification must use
        // its JSON shape instead of relying solely on the file name.
        let pathManifestFolder = fixtureRoot.appendingPathComponent("path-manifest", isDirectory: true)
        try fileManager.createDirectory(at: pathManifestFolder, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: v1Atlas,
            to: pathManifestFolder.appendingPathComponent("spritesheet.png")
        )
        let pathManifest = pathManifestFolder.appendingPathComponent("path.json")
        try writeLegacyManifest(
            id: "legacy-path-json",
            atlasName: "spritesheet.png",
            to: pathManifest
        )
        let pathManifestID = try store.projectIdentifier(in: pathManifest)
        precondition(pathManifestID == "legacy-path-json")
        let v1FromPathManifest = try store.importProject(
            from: pathManifest,
            as: "path-json-selected-v1"
        )
        assertImportedProject(v1FromPathManifest, expectedRows: 9, expectedActions: 9, store: store)

        // Failures should be actionable in the settings alert, not a generic
        // decoder error. Cover both a missing required atlas and unknown geometry.
        let missingAtlasFolder = fixtureRoot.appendingPathComponent("missing-atlas", isDirectory: true)
        try fileManager.createDirectory(at: missingAtlasFolder, withIntermediateDirectories: true)
        try writeLegacyManifest(
            id: "missing-atlas",
            atlasName: "spritesheet.png",
            to: missingAtlasFolder.appendingPathComponent("pet.json")
        )
        assertImportFails(from: missingAtlasFolder, store: store) { message in
            message.localizedCaseInsensitiveContains("spritesheet")
                || message.contains("图集")
        }

        let unknownAtlasFolder = fixtureRoot.appendingPathComponent("unknown-atlas", isDirectory: true)
        try fileManager.createDirectory(at: unknownAtlasFolder, withIntermediateDirectories: true)
        try writeTransparentPNG(
            width: 100,
            height: 100,
            to: unknownAtlasFolder.appendingPathComponent("spritesheet.png")
        )
        assertImportFails(from: unknownAtlasFolder, store: store) { message in
            (message.contains("100") && message.contains("图集"))
                || message.contains("配置")
                || message.localizedCaseInsensitiveContains("studio.json")
        }
    }

    /// Manual preview is a transient value copy. It must neither inherit a
    /// looping/disabled action's playback contract nor mutate the saved action.
    private static func assertManualPreviewCopySemantics(using project: PetProjectDefinition) {
        guard var source = project.actions.first(where: { $0.frames.count > 1 }) else {
            preconditionFailure("Expected a multi-frame template action")
        }
        source.isEnabled = false
        source.playback = .loop
        source.repeatCount = 7
        source.priority = -100
        source.interruption = .always
        let original = source

        let preview = source.manualPreviewCopy()
        precondition(preview.isEnabled)
        precondition(preview.playback == .once)
        precondition(preview.repeatCount == 1)
        precondition(preview.priority == Int.max)
        precondition(preview.interruption == .never)
        precondition(preview.id == original.id)
        precondition(preview.frames == original.frames)
        precondition(preview.triggers == original.triggers)
        precondition(source == original)
    }

    private static func assertImportedProject(
        _ project: PetProjectDefinition,
        expectedRows: Int,
        expectedActions: Int,
        store: DocumentStore
    ) {
        precondition(!project.isReadOnlyTemplate)
        precondition(project.atlas.columns == 8)
        precondition(project.atlas.rows == expectedRows)
        precondition(project.atlas.cellWidth == 192)
        precondition(project.atlas.cellHeight == 208)
        precondition(project.actions.count == expectedActions)
        precondition(project.actions.allSatisfy { !$0.frames.isEmpty })

        let folder = store.projectsURL.appendingPathComponent(project.id, isDirectory: true)
        for filename in ["pet.json", "studio.json", "spritesheet.png"] {
            precondition(FileManager.default.fileExists(atPath: folder.appendingPathComponent(filename).path))
        }
    }

    private static func assertImportFails(
        from source: URL,
        store: DocumentStore,
        targetID: String = "expected-import-failure",
        messageMatches: (String) -> Bool
    ) {
        do {
            _ = try store.importProject(from: source, as: targetID)
            preconditionFailure("Invalid import unexpectedly succeeded: \(source.path)")
        } catch {
            let message = error.localizedDescription
            precondition(messageMatches(message), "Unexpected import error: \(message)")
        }
    }

    private static func writeLegacyManifest(id: String, atlasName: String, to destination: URL) throws {
        let object: [String: Any] = [
            "id": id,
            "displayName": "Legacy Codex v1",
            "description": "Codex v1 manifest without spriteVersionNumber",
            "spritesheetPath": atlasName
        ]
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination, options: .atomic)
    }

    private static func writeTransparentPNG(width: Int, height: Int, to destination: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            preconditionFailure("Unable to create \(width) x \(height) PNG fixture")
        }
        if let pixels = bitmap.bitmapData {
            memset(pixels, 0, bitmap.bytesPerRow * bitmap.pixelsHigh)
        }
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            preconditionFailure("Unable to encode \(width) x \(height) PNG fixture")
        }
        try pngData.write(to: destination, options: .atomic)
    }

    private static func assertTemplateRuntimeParametersMatch(
        _ templates: [PetProjectDefinition]
    ) throws {
        guard templates.count == 2 else { preconditionFailure("Expected two bundled templates") }
        let firstActions = templates[0].actions
        let secondActions = templates[1].actions
        precondition(firstActions.count == secondActions.count)

        for (first, second) in zip(firstActions, secondActions) {
            precondition(first.id == second.id)
            precondition(first.isEnabled == second.isEnabled)
            precondition(first.framesPerSecond == second.framesPerSecond)
            precondition(first.playback == second.playback)
            precondition(first.repeatCount == second.repeatCount)
            precondition(first.priority == second.priority)
            precondition(first.interruption == second.interruption)
            precondition(first.triggers == second.triggers)
        }

        let expectedRepeatCounts = ["waiting": 3, "running": 3]
        for (actionID, count) in expectedRepeatCounts {
            precondition(firstActions.first(where: { $0.id == actionID })?.repeatCount == count)
        }
        precondition(
            firstActions.first(where: { $0.id == "waving" })?.triggers.contains(where: {
                $0.kind == .appLaunch
            }) == true
        )
        precondition(
            firstActions.first(where: { $0.id == "review" })?.triggers.contains(where: {
                $0.kind == .random
            }) == true
        )
    }
}
