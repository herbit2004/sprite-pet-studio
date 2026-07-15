import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct PublishedAppVersion: Decodable, Equatable {
    let version: String
    let downloadURL: URL
    let releaseNotesURL: URL
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate(latestVersion: String)
    case updateAvailable(PublishedAppVersion)
    case failed(message: String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var document: AppDocument
    @Published var lastError: String? = nil
    @Published var loginItemStatusText = ""
    @Published private(set) var atlasContentRevision: UInt64 = 0
    @Published private(set) var updateCheckState: UpdateCheckState = .idle

    let store: DocumentStore
    let bus = PetEventBus()
    private let systemMonitor: SystemEventMonitor
    private var petWindows: [String: PetWindowController] = [:]
    private var triggerEngines: [String: TriggerEngine] = [:]
    private var settingsWindowController: SettingsWindowController?
    private var saveCancellable: AnyCancellable?
    private var isStarted = false

    private static let updateManifestURL = URL(
        string: "https://herbit2004.github.io/sprite-pet-studio/version.json"
    )!

    init() {
        let store = DocumentStore()
        self.store = store
        do {
            document = try store.load()
        } catch {
            let emergencyFallback = PetProjectDefinition(
                id: "empty",
                name: "空工程",
                author: "",
                projectDescription: "",
                formatVersion: 1,
                isBuiltIn: true,
                atlas: AtlasDefinition(
                    imagePath: "",
                    columns: 1,
                    rows: 1,
                    cellWidth: 192,
                    cellHeight: 208,
                    filtering: .linear
                ),
                defaultActionID: "idle",
                actions: []
            )
            var fallbackProjects = (try? store.bundledProjects()) ?? [emergencyFallback]
            for index in fallbackProjects.indices {
                fallbackProjects[index].isVisibleOnDesktop = true
            }
            document = AppDocument(
                selectedProjectID: fallbackProjects[0].id,
                general: GeneralSettings(),
                projects: fallbackProjects
            )
            lastError = error.localizedDescription
        }
        systemMonitor = SystemEventMonitor(bus: bus)
    }

    var currentProject: PetProjectDefinition? {
        document.projects.first(where: { $0.id == document.selectedProjectID })
            ?? document.projects.first
    }

    var currentProjectIndex: Int? {
        document.projects.firstIndex { $0.id == document.selectedProjectID }
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "开发版"
    }

    func checkForUpdates() {
        guard updateCheckState != .checking else { return }
        updateCheckState = .checking

        Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: Self.updateManifestURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 12
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    throw URLError(.badServerResponse)
                }

                let published = try JSONDecoder().decode(PublishedAppVersion.self, from: data)
                guard published.downloadURL.scheme == "https",
                      published.releaseNotesURL.scheme == "https" else {
                    throw URLError(.unsupportedURL)
                }

                updateCheckState = Self.isVersion(
                    published.version,
                    newerThan: currentAppVersion
                ) ? .updateAvailable(published) : .upToDate(latestVersion: published.version)
            } catch {
                updateCheckState = .failed(message: error.localizedDescription)
            }
        }
    }

    func openPublishedUpdate(_ version: PublishedAppVersion) {
        NSWorkspace.shared.open(version.downloadURL)
    }

    func openPublishedReleaseNotes(_ version: PublishedAppVersion) {
        NSWorkspace.shared.open(version.releaseNotesURL)
    }

    func updateProjectMetadata(id: String, name: String, description: String) {
        guard let index = document.projects.firstIndex(where: { $0.id == id }),
              !document.projects[index].isReadOnlyTemplate else { return }
        document.projects[index].name = name
        document.projects[index].projectDescription = description
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        systemMonitor.mousePassThroughUpdater = { [weak self] point in
            guard let self else { return }
            for window in petWindows.values {
                window.updateMousePassThrough(mouseLocation: point)
            }
        }
        systemMonitor.mousePollingRate = document.general.mousePollingRate

        do {
            try synchronizePetSessions(with: document, postLaunchForNewSessions: false)
        } catch {
            lastError = error.localizedDescription
        }

        saveCancellable = $document
            .dropFirst()
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] document in
                self?.documentDidChange(document)
            }

        refreshLoginItemStatus()
        systemMonitor.start()
    }

    func stop() {
        systemMonitor.stop()
        for engine in triggerEngines.values { engine.stop() }
        triggerEngines.removeAll()
        for window in petWindows.values { window.hide() }
        petWindows.removeAll()
        saveCancellable?.cancel()
    }

    func playAction(id: String, projectID: String? = nil, force: Bool = true) {
        let targetID = projectID ?? document.selectedProjectID
        guard let project = document.projects.first(where: { $0.id == targetID }),
              let action = project.actions.first(where: { $0.id == id }),
              let window = petWindows[targetID] else { return }
        if force { window.playForce(action) }
        else { window.play(action, restart: true) }
        systemMonitor.recordPetInteraction()
    }

    func postExternalTrigger(_ name: String) {
        bus.post(PetEvent(type: .external, stringValue: name))
    }

    func selectProject(_ id: String) {
        guard document.projects.contains(where: { $0.id == id }) else { return }
        document.selectedProjectID = id
    }

    func frameImage(_ frame: PetFrameDefinition) -> NSImage? {
        guard let project = currentProject else { return nil }
        return store.frameImage(for: frame, project: project)
    }

    func frameImage(_ frame: PetFrameDefinition, project: PetProjectDefinition) -> NSImage? {
        store.frameImage(for: frame, project: project)
    }

    func importFramePNG(actionID: String, frameID: UUID) {
        guard let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == actionID }),
              let frameIndex = document.projects[projectIndex].actions[actionIndex].frames.firstIndex(where: { $0.id == frameID }) else { return }

        let panel = NSOpenPanel()
        panel.title = "为这一帧选择 PNG"
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let project = document.projects[projectIndex]
            let frame = project.actions[actionIndex].frames[frameIndex]
            let path = try store.replaceAtlasCell(from: url, frame: frame, project: project)
            document.projects[projectIndex].atlas.imagePath = path
            try refreshEditedAtlas(projectIndex: projectIndex)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportFramePNG(actionID: String, frameID: UUID) {
        guard let project = currentProject,
              let action = project.actions.first(where: { $0.id == actionID }),
              let frame = action.frames.first(where: { $0.id == frameID }) else { return }
        let panel = NSSavePanel()
        panel.title = "导出单帧 PNG"
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(action.id)-\((action.frames.firstIndex(where: { $0.id == frameID }) ?? 0) + 1).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportFramePNG(frame, project: project, to: url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func bakeFrameTransform(actionID: String, frameID: UUID) {
        guard let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == actionID }),
              let frameIndex = document.projects[projectIndex].actions[actionIndex].frames.firstIndex(where: { $0.id == frameID }) else { return }
        do {
            let project = document.projects[projectIndex]
            let frame = project.actions[actionIndex].frames[frameIndex]
            let path = try store.bakeFrameTransform(frame, project: project)
            document.projects[projectIndex].atlas.imagePath = path
            document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scale = 1
            document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scaleX = 1
            document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scaleY = 1
            document.projects[projectIndex].actions[actionIndex].frames[frameIndex].offsetX = 0
            document.projects[projectIndex].actions[actionIndex].frames[frameIndex].offsetY = 0
            try refreshEditedAtlas(projectIndex: projectIndex)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetFrameTransform(actionID: String, frameID: UUID) {
        guard let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == actionID }),
              let frameIndex = document.projects[projectIndex].actions[actionIndex].frames.firstIndex(where: { $0.id == frameID }) else { return }

        var frame = document.projects[projectIndex].actions[actionIndex].frames[frameIndex]
        frame.scale = 1
        frame.scaleX = 1
        frame.scaleY = 1
        frame.offsetX = 0
        frame.offsetY = 0
        document.projects[projectIndex].actions[actionIndex].frames[frameIndex] = frame
    }

    func bakeFrameTransforms(actionID: String, frameIDs: Set<UUID>) {
        guard !frameIDs.isEmpty,
              let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == actionID }) else { return }
        let selectedFrames = document.projects[projectIndex].actions[actionIndex].frames.filter {
            frameIDs.contains($0.id)
        }
        guard selectedFrames.contains(where: frameHasDraftTransform) else { return }

        do {
            let project = document.projects[projectIndex]
            let path = try store.bakeFrameTransforms(in: project, frameIDs: frameIDs)
            document.projects[projectIndex].atlas.imagePath = path
            resetFrameTransformsInDocument(
                projectIndex: projectIndex,
                actionIndex: actionIndex,
                frameIDs: frameIDs
            )
            try refreshEditedAtlas(projectIndex: projectIndex)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetFrameTransforms(actionID: String, frameIDs: Set<UUID>) {
        guard !frameIDs.isEmpty,
              let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == actionID }) else { return }
        resetFrameTransformsInDocument(
            projectIndex: projectIndex,
            actionIndex: actionIndex,
            frameIDs: frameIDs
        )
    }

    func draftTransformCount(projectID: String) -> Int {
        guard let project = document.projects.first(where: { $0.id == projectID }),
              !project.isReadOnlyTemplate else { return 0 }
        return project.actions.flatMap(\.frames).filter { frame in
            abs(frame.scale - 1) > 0.0001
                || abs(frame.scaleX - 1) > 0.0001
                || abs(frame.scaleY - 1) > 0.0001
                || abs(frame.offsetX) > 0.0001
                || abs(frame.offsetY) > 0.0001
        }.count
    }

    func bakeAllFrameTransforms(projectID: String) {
        guard let projectIndex = document.projects.firstIndex(where: { $0.id == projectID }),
              !document.projects[projectIndex].isReadOnlyTemplate,
              draftTransformCount(projectID: projectID) > 0 else { return }
        do {
            let project = document.projects[projectIndex]
            let path = try store.bakeAllFrameTransforms(in: project)
            document.projects[projectIndex].atlas.imagePath = path
            for actionIndex in document.projects[projectIndex].actions.indices {
                for frameIndex in document.projects[projectIndex].actions[actionIndex].frames.indices {
                    document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scale = 1
                    document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scaleX = 1
                    document.projects[projectIndex].actions[actionIndex].frames[frameIndex].scaleY = 1
                    document.projects[projectIndex].actions[actionIndex].frames[frameIndex].offsetX = 0
                    document.projects[projectIndex].actions[actionIndex].frames[frameIndex].offsetY = 0
                }
            }
            try refreshEditedAtlas(projectIndex: projectIndex)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetAllFrameTransforms(projectID: String) {
        guard let projectIndex = document.projects.firstIndex(where: { $0.id == projectID }),
              !document.projects[projectIndex].isReadOnlyTemplate,
              draftTransformCount(projectID: projectID) > 0 else { return }
        var project = document.projects[projectIndex]
        for actionIndex in project.actions.indices {
            for frameIndex in project.actions[actionIndex].frames.indices {
                project.actions[actionIndex].frames[frameIndex].scale = 1
                project.actions[actionIndex].frames[frameIndex].scaleX = 1
                project.actions[actionIndex].frames[frameIndex].scaleY = 1
                project.actions[actionIndex].frames[frameIndex].offsetX = 0
                project.actions[actionIndex].frames[frameIndex].offsetY = 0
            }
        }
        document.projects[projectIndex] = project
    }

    func bindingForAction(id: String) -> Binding<PetActionDefinition>? {
        guard let projectIndex = currentProjectIndex,
              !document.projects[projectIndex].isReadOnlyTemplate,
              let actionIndex = document.projects[projectIndex].actions.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                guard let self else { return PetActionDefinition.blank(index: 0) }
                return self.document.projects[projectIndex].actions[actionIndex]
            },
            set: { [weak self] newValue in
                guard let self,
                      self.document.projects.indices.contains(projectIndex),
                      !self.document.projects[projectIndex].isReadOnlyTemplate,
                      self.document.projects[projectIndex].actions.indices.contains(actionIndex) else { return }
                self.document.projects[projectIndex].actions[actionIndex] = newValue
            }
        )
    }

    func bindingForCurrentProject() -> Binding<PetProjectDefinition>? {
        guard let index = currentProjectIndex else { return nil }
        return Binding(
            get: { [weak self] in
                self?.document.projects[index] ?? self!.document.projects[0]
            },
            set: { [weak self] newValue in
                guard let self,
                      self.document.projects.indices.contains(index),
                      !self.document.projects[index].isReadOnlyTemplate else { return }
                self.document.projects[index] = newValue
            }
        )
    }

    func bindingForProject(id: String) -> Binding<PetProjectDefinition>? {
        guard let index = document.projects.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in self?.document.projects[index] ?? self!.document.projects[0] },
            set: { [weak self] newValue in
                guard let self,
                      self.document.projects.indices.contains(index),
                      !self.document.projects[index].isReadOnlyTemplate else { return }
                self.document.projects[index] = newValue
            }
        )
    }

    func bindingForGeneral<Value>(_ keyPath: WritableKeyPath<GeneralSettings, Value>) -> Binding<Value> {
        Binding(
            get: { [weak self] in self!.document.general[keyPath: keyPath] },
            set: { [weak self] in self?.document.general[keyPath: keyPath] = $0 }
        )
    }

    func bindingForProjectVisibility(id: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.document.projects.first(where: { $0.id == id })?.showsOnDesktop ?? false
            },
            set: { [weak self] isVisible in
                guard let self,
                      let index = document.projects.firstIndex(where: { $0.id == id }) else { return }
                document.projects[index].isVisibleOnDesktop = isVisible
            }
        )
    }

    var visibleProjects: [PetProjectDefinition] {
        document.projects.filter(\.showsOnDesktop)
    }

    func importProject() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex v2 工程的 pet.json"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let sourceID = try store.projectIdentifier(in: url)
            let targetID = document.projects.contains(where: { $0.id == sourceID })
                ? uniqueProjectID(base: "\(sourceID)-imported")
                : sourceID
            var project = try store.importProject(from: url, as: targetID)
            project.isVisibleOnDesktop = false
            project.desktopOriginX = nil
            project.desktopOriginY = nil
            let embedded = project.effectiveAtlasConfiguration
            if let library = document.atlasConfigurations.first(where: { $0.id == embedded.id }),
               library == embedded {
                project.configurationLibraryID = library.id
            } else if embedded.id == CodexV2Schema.configuration.id {
                project.atlasConfiguration = CodexV2Schema.configuration
                project.configurationLibraryID = CodexV2Schema.configuration.id
            } else {
                let alert = NSAlert()
                alert.messageText = "这个工程使用配置库之外的图集配置"
                alert.informativeText = "“\(embedded.name)”可以加入配置库供其他工程复用，也可以只作为这个工程的临时配置。"
                alert.addButton(withTitle: "加入配置库")
                alert.addButton(withTitle: "临时使用")
                alert.addButton(withTitle: "取消")
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    var saved = embedded
                    saved.isBuiltIn = false
                    if document.atlasConfigurations.contains(where: { $0.id == saved.id }) {
                        saved.id = uniqueConfigurationID(base: saved.id)
                    }
                    document.atlasConfigurations.append(saved)
                    project.atlasConfiguration = saved
                    project.configurationLibraryID = saved.id
                case .alertSecondButtonReturn:
                    project.configurationLibraryID = nil
                default:
                    try? store.deleteProjectData(project)
                    return
                }
            }
            document.projects.append(project)
            document.selectedProjectID = project.id
            resetAllTriggerEngines()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportCurrentProject() {
        guard let project = currentProject else { return }
        let panel = NSOpenPanel()
        panel.title = "选择导出目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportProject(project, to: url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteCurrentProject() {
        guard let project = currentProject, !project.isBuiltIn else { return }
        do {
            try store.deleteProjectData(project)
        } catch {
            lastError = error.localizedDescription
            return
        }
        document.projects.removeAll { $0.id == project.id }
        document.selectedProjectID = document.projects.first?.id ?? ""
        resetAllTriggerEngines()
    }

    @discardableResult
    func duplicateProject(id: String) -> String? {
        guard let source = document.projects.first(where: { $0.id == id }) else { return nil }
        let newID = uniqueProjectID(base: "\(source.id)-copy")
        do {
            let copy = try store.duplicateProject(
                source,
                id: newID,
                name: "\(source.name) 副本"
            )
            document.projects.append(copy)
            document.selectedProjectID = copy.id
            return copy.id
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func createBlankProject(
        name: String,
        description: String,
        configurationID: String
    ) -> String? {
        guard let configuration = document.atlasConfigurations.first(where: { $0.id == configurationID }) else {
            lastError = "找不到所选图集配置。"
            return nil
        }
        let id = uniqueProjectID(base: slug(name))
        do {
            let project = try store.createBlankProject(
                id: id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名工程" : name,
                description: description,
                configuration: configuration,
                configurationLibraryID: configuration.id
            )
            document.projects.append(project)
            document.selectedProjectID = project.id
            resetAllTriggerEngines()
            return project.id
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func addConfiguration() -> String {
        let id = uniqueConfigurationID(base: "new-layout")
        let configuration = AtlasConfiguration(
            id: id,
            name: "新图集配置",
            configurationDescription: "自定义动作与格位布局",
            isBuiltIn: false,
            compatibility: .spritePetStudio,
            cellWidth: 192,
            cellHeight: 208,
            actions: [
                AtlasActionConfiguration(
                    name: "常态",
                    key: "idle",
                    frameCount: 1,
                    occupiedRows: 1
                )
            ]
        )
        document.atlasConfigurations.append(configuration)
        return id
    }

    func duplicateConfiguration(id: String) -> String? {
        guard var copy = document.atlasConfigurations.first(where: { $0.id == id }) else { return nil }
        copy.id = uniqueConfigurationID(base: "\(copy.id)-copy")
        copy.name += " 副本"
        copy.isBuiltIn = false
        copy.compatibility = .spritePetStudio
        document.atlasConfigurations.append(copy)
        return copy.id
    }

    @discardableResult
    func saveConfiguration(_ configuration: AtlasConfiguration) -> Bool {
        guard !configuration.isBuiltIn else {
            lastError = "内置 Codex v2 配置不可覆盖，请先复制一份再编辑。"
            return false
        }
        let keys = configuration.actions.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !keys.contains(where: { $0.isEmpty }),
              Set(keys).count == keys.count,
              !configuration.actions.isEmpty else {
            lastError = "配置至少需要一个动作，名称和标签键不能为空，标签键不能重复。"
            return false
        }

        var sanitized = configuration
        sanitized.cellWidth = max(1, sanitized.cellWidth)
        sanitized.cellHeight = max(1, sanitized.cellHeight)
        for index in sanitized.actions.indices {
            sanitized.actions[index].key = keys[index]
            sanitized.actions[index].frameCount = max(1, sanitized.actions[index].frameCount)
            sanitized.actions[index].occupiedRows = max(1, sanitized.actions[index].occupiedRowCount)
        }

        do {
            for index in document.projects.indices
                where document.projects[index].configurationLibraryID == sanitized.id
                    && !document.projects[index].isReadOnlyTemplate {
                document.projects[index] = try store.reconfigureProject(
                    document.projects[index],
                    using: sanitized,
                    libraryID: sanitized.id
                )
            }
            if let index = document.atlasConfigurations.firstIndex(where: { $0.id == sanitized.id }) {
                document.atlasConfigurations[index] = sanitized
            } else {
                document.atlasConfigurations.append(sanitized)
            }
            resetAllTriggerEngines()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteConfiguration(id: String) {
        guard let configuration = document.atlasConfigurations.first(where: { $0.id == id }),
              !configuration.isBuiltIn else { return }
        document.atlasConfigurations.removeAll { $0.id == id }
        for index in document.projects.indices where document.projects[index].configurationLibraryID == id {
            document.projects[index].configurationLibraryID = nil
        }
    }

    func configurationStatus(for project: PetProjectDefinition) -> String {
        guard let id = project.configurationLibraryID,
              let configuration = document.atlasConfigurations.first(where: { $0.id == id }),
              configuration == project.effectiveAtlasConfiguration else {
            return "临时配置"
        }
        return configuration.name
    }

    func usesTemporaryConfiguration(_ project: PetProjectDefinition) -> Bool {
        guard let id = project.configurationLibraryID,
              let configuration = document.atlasConfigurations.first(where: { $0.id == id }) else {
            return true
        }
        return configuration != project.effectiveAtlasConfiguration
    }

    func addProjectConfigurationToLibrary(projectID: String) {
        guard let projectIndex = document.projects.firstIndex(where: { $0.id == projectID }) else { return }
        var configuration = document.projects[projectIndex].effectiveAtlasConfiguration
        configuration.isBuiltIn = false
        if document.atlasConfigurations.contains(where: { $0.id == configuration.id }) {
            configuration.id = uniqueConfigurationID(base: configuration.id)
        }
        document.atlasConfigurations.append(configuration)
        document.projects[projectIndex].atlasConfiguration = configuration
        document.projects[projectIndex].configurationLibraryID = configuration.id
    }

    func resetWindowPosition() {
        let visibleIDs = document.projects.filter(\.showsOnDesktop).map(\.id)
        for (index, id) in visibleIDs.enumerated() {
            guard let origin = petWindows[id]?.resetPosition(defaultPositionIndex: index),
                  let projectIndex = document.projects.firstIndex(where: { $0.id == id }) else { continue }
            document.projects[projectIndex].desktopOriginX = origin.x
            document.projects[projectIndex].desktopOriginY = origin.y
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            document.general.launchAtLogin = enabled
        } catch {
            lastError = error.localizedDescription
            document.general.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        refreshLoginItemStatus()
    }

    func openProjectFolder() {
        NSWorkspace.shared.open(store.applicationSupportURL)
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: self)
        }
        settingsWindowController?.present()
    }

    private func refreshLoginItemStatus() {
        switch SMAppService.mainApp.status {
        case .enabled: loginItemStatusText = "已允许开机启动"
        case .requiresApproval: loginItemStatusText = "需要在系统设置中批准"
        case .notFound: loginItemStatusText = "请先将 App 放入“应用程序”文件夹"
        case .notRegistered: loginItemStatusText = "未启用"
        @unknown default: loginItemStatusText = "状态未知"
        }
    }

    private func documentDidChange(_ document: AppDocument) {
        do {
            try store.save(document)
            systemMonitor.mousePollingRate = document.general.mousePollingRate
            try synchronizePetSessions(with: document, postLaunchForNewSessions: true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshEditedAtlas(projectIndex: Int) throws {
        let project = document.projects[projectIndex]
        try store.save(document)
        try petWindows[project.id]?.reloadProject(project)
        triggerEngines[project.id]?.reset()
        atlasContentRevision &+= 1
    }

    private func frameHasDraftTransform(_ frame: PetFrameDefinition) -> Bool {
        abs(frame.scale - 1) > 0.0001
            || abs(frame.scaleX - 1) > 0.0001
            || abs(frame.scaleY - 1) > 0.0001
            || abs(frame.offsetX) > 0.0001
            || abs(frame.offsetY) > 0.0001
    }

    private func resetFrameTransformsInDocument(
        projectIndex: Int,
        actionIndex: Int,
        frameIDs: Set<UUID>
    ) {
        var action = document.projects[projectIndex].actions[actionIndex]
        for frameIndex in action.frames.indices where frameIDs.contains(action.frames[frameIndex].id) {
            action.frames[frameIndex].scale = 1
            action.frames[frameIndex].scaleX = 1
            action.frames[frameIndex].scaleY = 1
            action.frames[frameIndex].offsetX = 0
            action.frames[frameIndex].offsetY = 0
        }
        document.projects[projectIndex].actions[actionIndex] = action
    }

    private func synchronizePetSessions(
        with document: AppDocument,
        postLaunchForNewSessions: Bool
    ) throws {
        let activeProjects = document.general.isPetVisible
            ? document.projects.filter(\.showsOnDesktop)
            : []
        let activeIDs = Set(activeProjects.map(\.id))

        for id in Set(petWindows.keys).subtracting(activeIDs) {
            triggerEngines[id]?.stop()
            triggerEngines.removeValue(forKey: id)
            petWindows[id]?.hide()
            petWindows.removeValue(forKey: id)
        }

        for (index, project) in activeProjects.enumerated() {
            let isNewSession = petWindows[project.id] == nil
            let window: PetWindowController
            if let existing = petWindows[project.id] {
                window = existing
            } else {
                window = makePetWindow(projectID: project.id)
                petWindows[project.id] = window
            }

            if triggerEngines[project.id] == nil {
                let engine = makeTriggerEngine(projectID: project.id, window: window)
                triggerEngines[project.id] = engine
                engine.start()
            }

            try window.apply(
                project: project,
                general: document.general,
                defaultPositionIndex: index
            )
            if isNewSession && postLaunchForNewSessions {
                bus.post(.simple(.appLaunch, projectID: project.id))
            }
        }
    }

    private func makePetWindow(projectID: String) -> PetWindowController {
        let window = PetWindowController(store: store, bus: bus, projectID: projectID)
        window.onWindowMoved = { [weak self] origin in
            guard let self,
                  let index = document.projects.firstIndex(where: { $0.id == projectID }) else { return }
            document.projects[index].desktopOriginX = origin.x
            document.projects[index].desktopOriginY = origin.y
        }
        window.onInteraction = { [weak self] in
            self?.systemMonitor.recordPetInteraction()
        }
        window.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        return window
    }

    private func makeTriggerEngine(
        projectID: String,
        window: PetWindowController
    ) -> TriggerEngine {
        let engine = TriggerEngine(bus: bus, projectID: projectID)
        engine.projectProvider = { [weak self] in
            self?.document.projects.first(where: { $0.id == projectID })
        }
        engine.petCenterProvider = { [weak window] in
            window?.centerInScreenCoordinates()
        }
        engine.playAction = { [weak window] action, restart, force in
            window?.play(action, restart: restart, force: force)
        }
        engine.controlAngle = { [weak window] action, angle in
            window?.controlAngle(action, angleDegrees: angle)
        }
        engine.stopAngleControl = { [weak window] actionID in
            window?.stopAngleAction(actionID)
        }
        return engine
    }

    private func resetAllTriggerEngines() {
        for engine in triggerEngines.values { engine.reset() }
    }

    private func uniqueConfigurationID(base: String) -> String {
        var candidate = base.isEmpty ? "layout" : base
        var suffix = 2
        let ids = Set(document.atlasConfigurations.map(\.id))
        while ids.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func uniqueProjectID(base: String) -> String {
        var candidate = base.isEmpty ? "pet" : base
        var suffix = 2
        let ids = Set(document.projects.map(\.id))
        while ids.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func slug(_ value: String) -> String {
        let lowered = value.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber { return character }
            return "-"
        }
        let compact = String(mapped).split(separator: "-").joined(separator: "-")
        return compact.isEmpty ? "pet" : compact
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = semanticVersionParts(candidate)
        let currentParts = semanticVersionParts(current)
        guard !candidateParts.isEmpty else { return false }
        guard !currentParts.isEmpty else { return true }

        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart { return candidatePart > currentPart }
        }
        return false
    }

    private static func semanticVersionParts(_ value: String) -> [Int] {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        return normalized.split(separator: ".").compactMap { Int($0) }
    }
}
