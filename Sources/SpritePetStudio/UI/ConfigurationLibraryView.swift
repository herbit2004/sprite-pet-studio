import SwiftUI

struct ConfigurationLibraryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedID: String?
    @State private var draft: AtlasConfiguration?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            configurationList
                .frame(width: 260, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.trailing, 22)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(width: 1)
                }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
                        Color.clear
                            .frame(height: 1)
                            .id("configuration-detail-top")

                        StudioPageHeader(
                            eyebrow: "Layout Presets",
                            title: "配置库",
                            subtitle: "集中管理动作标签、帧数与图集网格；Codex v2 是默认只读模板。"
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

                        if let draft {
                            ConfigurationDetailEditor(
                                configuration: Binding(
                                    get: { self.draft ?? draft },
                                    set: { self.draft = $0 }
                                ),
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
                        } else {
                            ContentUnavailableView("选择一个配置", systemImage: "square.grid.3x3")
                                .frame(maxWidth: .infinity, minHeight: 320)
                        }
                    }
                    .padding(.leading, 26)
                    .padding(.trailing, 6)
                    .padding(.bottom, StudioTheme.pagePadding)
                }
                .scrollContentBackground(.hidden)
                .onAppear { scrollToTop(proxy) }
                .onChange(of: selectedID) { _, _ in scrollToTop(proxy) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedID == nil { select(model.document.atlasConfigurations.first?.id) }
        }
    }

    private var configurationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("配置列表")
                    .font(.headline)
                Text("选择一个布局预设进行编辑")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                .padding(.vertical, 2)
            }
            .scrollContentBackground(.hidden)

            Divider()

            Button(role: .destructive) {
                guard let selectedID else { return }
                model.deleteConfiguration(id: selectedID)
                select(model.document.atlasConfigurations.first?.id)
            } label: {
                Label("删除配置", systemImage: "trash")
            }
            .disabled(draft?.isBuiltIn != false)
        }
    }

    private func select(_ id: String?) {
        selectedID = id
        draft = model.document.atlasConfigurations.first { $0.id == id }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("configuration-detail-top", anchor: .top)
        }
    }
}

private struct ConfigurationDetailEditor: View {
    @Binding var configuration: AtlasConfiguration
    let linkedProjectCount: Int
    let save: () -> Void
    let duplicate: () -> Void

    var body: some View {
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
