import SwiftUI

struct ProjectLibraryView: View {
    @ObservedObject var model: AppModel
    @State private var showsNewProject = false
    @State private var renameProject: PetProjectDefinition?
    @State private var editingProjectID: String?
    @State private var projectPendingNormalization: PetProjectDefinition?

    private let columns = [GridItem(.adaptive(minimum: 285), spacing: 16)]

    var body: some View {
        Group {
            if let editingProjectID,
               let project = model.document.projects.first(where: { $0.id == editingProjectID }) {
                actionEditorSubpage(project: project)
            } else {
                projectLibrary
            }
        }
        .sheet(isPresented: $showsNewProject) {
            NewProjectSheet(model: model)
        }
        .sheet(item: $renameProject) { project in
            RenameProjectSheet(
                name: project.name,
                description: project.projectDescription,
                save: { value, description in
                    if let index = model.document.projects.firstIndex(where: { $0.id == project.id }) {
                        model.document.projects[index].name = value
                        model.document.projects[index].projectDescription = description
                    }
                    renameProject = nil
                },
                cancel: { renameProject = nil }
            )
        }
        .confirmationDialog(
            "归一化“\(projectPendingNormalization?.name ?? "本工程")”的全部帧？",
            isPresented: Binding(
                get: { projectPendingNormalization != nil },
                set: { if !$0 { projectPendingNormalization = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let project = projectPendingNormalization {
                Button("归一化 \(model.draftTransformCount(projectID: project.id)) 个已调整帧") {
                    model.bakeAllFrameTransforms(projectID: project.id)
                    projectPendingNormalization = nil
                }
            }
            Button("取消", role: .cancel) { projectPendingNormalization = nil }
        } message: {
            Text("全部逐帧缩放和 X/Y 位移会永久写入这个工程的 spritesheet.png，随后调整值统一复位。")
        }
    }

    private var projectLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
                StudioPageHeader(
                    eyebrow: "Workspace",
                    title: "工程库",
                    subtitle: "每个工程都能独立显示、移动和触发动作；可以同时显示任意数量的桌宠。"
                ) {
                    HStack {
                        Button("导入工程…") { model.importProject() }
                        Button {
                            showsNewProject = true
                        } label: {
                            Label("新建空工程", systemImage: "plus")
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(model.document.projects) { project in
                        projectCard(project)
                    }
                }
            }
            .padding(StudioTheme.pagePadding)
        }
    }

    private func actionEditorSubpage(project: PetProjectDefinition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    editingProjectID = nil
                } label: {
                    Label("返回工程库", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                Divider().frame(height: 22)
                Text(project.name)
                    .font(.headline)
                StudioPill(
                    text: project.showsOnDesktop ? "桌面显示中" : "未显示",
                    color: project.showsOnDesktop ? .green : .secondary
                )
                Button {
                    projectPendingNormalization = project
                } label: {
                    Label(
                        "一键归一化全部帧",
                        systemImage: "square.stack.3d.down.right"
                    )
                }
                .disabled(model.draftTransformCount(projectID: project.id) == 0)
                Spacer()
            }
            .padding(.horizontal, StudioTheme.pagePadding)
            .padding(.top, StudioTheme.pagePadding)
            ActionLibraryView(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func projectCard(_ project: PetProjectDefinition) -> some View {
        let isVisible = project.showsOnDesktop
        let isTemporary = model.usesTemporaryConfiguration(project)
        return StudioCard(isSelected: isVisible) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        LinearGradient(
                            colors: [Color.black.opacity(0.025), StudioTheme.accent.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        ProjectLivePreview(project: project, store: model.store)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    if isVisible {
                        StudioPill(text: "桌面显示中", color: .green)
                            .padding(9)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.name).font(.title3.bold()).lineLimit(1)
                        Text(project.projectDescription.isEmpty ? "暂无工程说明" : project.projectDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Menu {
                        Button("编辑名称与描述") {
                            renameProject = project
                        }
                        Button("复制完整工程") {
                            model.duplicateProject(id: project.id)
                        }
                        Button("一键归一化全部帧") {
                            projectPendingNormalization = project
                        }
                        .disabled(model.draftTransformCount(projectID: project.id) == 0)
                        Button("导出工程…") {
                            model.selectProject(project.id)
                            model.exportCurrentProject()
                        }
                        if isTemporary {
                            Button("将临时配置加入配置库") {
                                model.addProjectConfigurationToLibrary(projectID: project.id)
                            }
                        }
                        Divider()
                        Button("删除工程", role: .destructive) {
                            model.selectProject(project.id)
                            model.deleteCurrentProject()
                        }
                        .disabled(project.isBuiltIn)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }

                HStack {
                    StudioPill(
                        text: model.configurationStatus(for: project),
                        color: isTemporary ? .orange : .blue
                    )
                    StudioPill(text: "\(project.actions.count) 个动作", color: .secondary)
                    Spacer()
                }
                Text("图集 \(project.atlas.columns) × \(project.atlas.rows) 格 · 单格 \(project.atlas.cellWidth) × \(project.atlas.cellHeight) px")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack {
                        visibilityToggle(project)
                        editActionsButton(project)
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        visibilityToggle(project)
                        editActionsButton(project)
                    }
                }
            }
        }
    }

    private func visibilityToggle(_ project: PetProjectDefinition) -> some View {
        Toggle("在桌面显示", isOn: model.bindingForProjectVisibility(id: project.id))
            .toggleStyle(.switch)
    }

    private func editActionsButton(_ project: PetProjectDefinition) -> some View {
        Button("编辑动作") {
            model.selectProject(project.id)
            editingProjectID = project.id
        }
        .buttonStyle(StudioPrimaryButtonStyle())
    }
}

private struct NewProjectSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = "新桌宠"
    @State private var description = ""
    @State private var configurationID = CodexV2Schema.configuration.id

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StudioPageHeader(
                eyebrow: "New Project",
                title: "新建空工程",
                subtitle: "创建后所有图集格位都是全透明图片，可在动作库逐帧导入。"
            )
            StudioCard {
                Form {
                    TextField("工程名称", text: $name)
                    TextField("说明", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("图集配置", selection: $configurationID) {
                        ForEach(model.document.atlasConfigurations) { configuration in
                            Text(configuration.name).tag(configuration.id)
                        }
                    }
                }
                .formStyle(.grouped)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("创建") {
                    if model.createBlankProject(
                        name: name,
                        description: description,
                        configurationID: configurationID
                    ) != nil {
                        dismiss()
                    }
                }
                .buttonStyle(StudioPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(StudioPageBackground())
    }
}

private struct RenameProjectSheet: View {
    @State var name: String
    @State var description: String
    let save: (String, String) -> Void
    let cancel: () -> Void

    init(
        name: String,
        description: String,
        save: @escaping (String, String) -> Void,
        cancel: @escaping () -> Void
    ) {
        _name = State(initialValue: name)
        _description = State(initialValue: description)
        self.save = save
        self.cancel = cancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑工程信息").font(.title2.bold())
            TextField("工程名称", text: $name)
            TextField("工程描述", text: $description, axis: .vertical)
                .lineLimit(3...6)
            HStack {
                Spacer()
                Button("取消", action: cancel)
                Button("保存") { save(name, description) }
                    .buttonStyle(StudioPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
