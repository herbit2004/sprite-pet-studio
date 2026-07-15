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
        try assertTemplateRuntimeParametersMatch(document.projects)

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

        // Simulate a fresh state file while keeping the user's Projects folder.
        // The two templates must come from the App bundle and the private copy
        // must be independently rediscovered from its own studio.json.
        try FileManager.default.removeItem(at: store.stateURL)
        let reopened = try DocumentStore(applicationSupportURL: store.applicationSupportURL).load()
        precondition(reopened.projects.count == 3)
        precondition(reopened.projects.filter(\.isReadOnlyTemplate).count == 2)
        precondition(reopened.projects.first(where: { $0.id == copy.id })?.isReadOnlyTemplate == false)

        try store.exportProject(template, to: exportRoot)
        let exportedTemplate = exportRoot.appendingPathComponent(template.id, isDirectory: true)
        for filename in ["pet.json", "studio.json", "spritesheet.png"] {
            precondition(FileManager.default.fileExists(atPath: exportedTemplate.appendingPathComponent(filename).path))
        }

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

        print("Workspace storage smoke test: OK")
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
