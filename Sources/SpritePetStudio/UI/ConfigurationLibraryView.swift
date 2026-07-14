import SwiftUI

struct ConfigurationLibraryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedID: String?
    @State private var draft: AtlasConfiguration?
    @State private var isHeaderCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
            StudioCollapsiblePageHeader(
                eyebrow: "Layout Presets",
                title: "配置库",
                subtitle: "集中管理动作标签、帧数与图集网格；Codex v2 是默认只读模板。",
                isCollapsed: isHeaderCollapsed
            ) {
                HStack {
                    Button {
                        let id = model.addConfiguration()
                        select(id)
                    } label: {
                        Label("新建配置", systemImage: "plus")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())

                    Button {
                        guard let selectedID, let id = model.duplicateConfiguration(id: selectedID) else { return }
                        select(id)
                    } label: {
                        Label("复制", systemImage: "plus.square.on.square")
                    }
                    .disabled(selectedID == nil)
                }
            }
            .padding(.horizontal, StudioTheme.pagePadding)
            .padding(.top, StudioTheme.pagePadding)

            HStack(alignment: .top, spacing: 18) {
                configurationList
                    .frame(width: 260)
                    .padding(.leading, StudioTheme.pagePadding)
                    .padding(.bottom, StudioTheme.pagePadding)

                if let draft {
                    ConfigurationDetailEditor(
                        configuration: Binding(
                            get: { self.draft ?? draft },
                            set: { self.draft = $0 }
                        ),
                        isHeaderCollapsed: $isHeaderCollapsed,
                        linkedProjectCount: model.document.projects.filter { $0.configurationLibraryID == draft.id }.count,
                        save: {
                            if model.saveConfiguration(self.draft ?? draft) {
                                self.draft = model.document.atlasConfigurations.first { $0.id == draft.id }
                            }
                        },
                        duplicate: {
                            if let id = model.duplicateConfiguration(id: draft.id) { select(id) }
                        }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("选择一个配置", systemImage: "square.grid.3x3")
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if selectedID == nil { select(model.document.atlasConfigurations.first?.id) }
        }
    }

    private var configurationList: some View {
        StudioCard {
            VStack(spacing: 10) {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.document.atlasConfigurations) { configuration in
                            Button {
                                select(configuration.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(configuration.name).font(.headline)
                                        Spacer()
                                        if configuration.isBuiltIn {
                                            StudioPill(text: "默认", color: .blue)
                                        }
                                    }
                                    Text("\(configuration.actions.count) 个动作 · \(configuration.cellsPerRow) × \(configuration.rowCount) 格")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    selectedID == configuration.id
                                        ? StudioTheme.accent.opacity(0.12)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()
                HStack {
                    Button(role: .destructive) {
                        guard let selectedID else { return }
                        model.deleteConfiguration(id: selectedID)
                        select(model.document.atlasConfigurations.first?.id)
                    } label: {
                        Label("删除配置", systemImage: "trash")
                    }
                    .disabled(draft?.isBuiltIn != false)
                    Spacer()
                }
            }
        }
    }

    private func select(_ id: String?) {
        selectedID = id
        draft = model.document.atlasConfigurations.first { $0.id == id }
        isHeaderCollapsed = false
    }
}

private struct ConfigurationDetailEditor: View {
    @Binding var configuration: AtlasConfiguration
    @Binding var isHeaderCollapsed: Bool
    let linkedProjectCount: Int
    let save: () -> Void
    let duplicate: () -> Void

    var body: some View {
        HeaderPriorityScrollView(
            isHeaderCollapsed: $isHeaderCollapsed,
            resetKey: configuration.id
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        HStack {
                            StudioPill(
                                text: configuration.compatibility.displayName,
                                color: configuration.compatibility == .codexV2 ? .blue : StudioTheme.accent
                            )
                            StudioPill(text: "\(configuration.atlasWidth) × \(configuration.atlasHeight) px", color: .secondary)
                            if linkedProjectCount > 0 {
                                StudioPill(text: "\(linkedProjectCount) 个关联工程", color: .purple)
                            }
                        }
                    }
                    Spacer()
                    if configuration.isBuiltIn {
                        Button("复制后编辑", action: duplicate)
                            .buttonStyle(StudioPrimaryButtonStyle())
                    } else {
                        Button("保存配置", action: save)
                            .buttonStyle(StudioPrimaryButtonStyle())
                    }
                }

                if configuration.isBuiltIn {
                    Label("内置配置保持 Codex 兼容性，因此不可直接修改。复制后可以自由调整。", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基本信息").font(.headline)
                        TextField("配置名称", text: $configuration.name)
                        TextField("说明", text: $configuration.configurationDescription, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .disabled(configuration.isBuiltIn)

                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("图集网格").font(.headline)
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                            GridRow {
                                Text("单格宽度")
                                Stepper("\(configuration.cellWidth) px", value: $configuration.cellWidth, in: 16...2048, step: 8)
                            }
                            GridRow {
                                Text("单格高度")
                                Stepper("\(configuration.cellHeight) px", value: $configuration.cellHeight, in: 16...2048, step: 8)
                            }
                            GridRow {
                                Text("自动计算")
                                Text("每排 \(configuration.cellsPerRow) 格 · 共 \(configuration.rowCount) 排 · 整图 \(configuration.atlasWidth) × \(configuration.atlasHeight) px")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .disabled(configuration.isBuiltIn)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("动作布局").font(.title3.bold())
                        Spacer()
                        Button {
                            addAction()
                        } label: {
                            Label("添加动作", systemImage: "plus")
                        }
                        .disabled(configuration.isBuiltIn)
                    }
                    Text("只需设置总帧数和占用排数；每排格位数会取所有动作中“单排所需格位”的最大值。标签键用于工程动作 ID 和事件映射。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(configuration.actions.indices, id: \.self) { index in
                        actionEditor(index: index)
                            .disabled(configuration.isBuiltIn)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.leading, 6)
            .padding(.trailing, StudioTheme.pagePadding)
            .padding(.bottom, StudioTheme.pagePadding)
        }
    }

    private func actionEditor(index: Int) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("动作 \(index + 1)").font(.headline)
                    StudioPill(text: configuration.rowLabel(for: configuration.actions[index].key), color: .secondary)
                    Spacer()
                    Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0)
                    Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == configuration.actions.count - 1)
                    Button(role: .destructive) {
                        configuration.actions.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(configuration.actions.count <= 1)
                }
                HStack {
                    TextField("动作名称", text: $configuration.actions[index].name)
                    TextField("标签键，例如 idle", text: $configuration.actions[index].key)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 18) {
                    Stepper(
                        "总帧数：\(configuration.actions[index].frameCount)",
                        value: $configuration.actions[index].frameCount,
                        in: 1...256
                    )
                    Stepper(
                        "占用排数：\(configuration.actions[index].occupiedRowCount)",
                        value: occupiedRowsBinding(index),
                        in: 1...64
                    )
                    Text("本动作要求每排至少 \(framesPerOccupiedRow(index)) 格")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func addAction() {
        let number = configuration.actions.count + 1
        configuration.actions.append(AtlasActionConfiguration(
            name: "新动作 \(number)",
            key: "action-\(number)",
            frameCount: 1,
            occupiedRows: 1
        ))
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard configuration.actions.indices.contains(destination) else { return }
        configuration.actions.swapAt(index, destination)
    }

    private func occupiedRowsBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { configuration.actions[index].occupiedRowCount },
            set: { configuration.actions[index].occupiedRows = max(1, $0) }
        )
    }

    private func framesPerOccupiedRow(_ index: Int) -> Int {
        let action = configuration.actions[index]
        return Int(ceil(Double(max(1, action.frameCount)) / Double(action.occupiedRowCount)))
    }

}
