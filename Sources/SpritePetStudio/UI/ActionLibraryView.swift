import AppKit
import SwiftUI

struct ActionLibraryView: View {
    @ObservedObject var model: AppModel
    /// When this editor is opened from a project card, its navigation controls
    /// live in the same collapsing page header as the action editor itself.
    /// Keeping them together prevents the editor from sliding underneath a
    /// second, independently-laid-out toolbar.
    let editedProject: PetProjectDefinition?
    let onBackToProjectLibrary: (() -> Void)?
    let onRequestNormalization: ((PetProjectDefinition) -> Void)?
    let onRequestReset: ((PetProjectDefinition) -> Void)?
    @State private var selectedActionID: String?
    @State private var isHeaderCollapsed = false

    init(
        model: AppModel,
        editedProject: PetProjectDefinition? = nil,
        onBackToProjectLibrary: (() -> Void)? = nil,
        onRequestNormalization: ((PetProjectDefinition) -> Void)? = nil,
        onRequestReset: ((PetProjectDefinition) -> Void)? = nil
    ) {
        self.model = model
        self.editedProject = editedProject
        self.onBackToProjectLibrary = onBackToProjectLibrary
        self.onRequestNormalization = onRequestNormalization
        self.onRequestReset = onRequestReset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionPageHeader
            .padding(.horizontal, StudioTheme.pagePadding)
            .padding(.top, StudioTheme.pagePadding)
            .padding(.bottom, StudioTheme.pageSpacing)

            HStack(alignment: .top, spacing: 18) {
                StudioCard {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(model.currentProject?.actions ?? []) { action in
                                let layout = model.currentProject?.effectiveAtlasConfiguration.actions.first { $0.key == action.id }
                                Button {
                                    selectedActionID = action.id
                                } label: {
                                    HStack(spacing: 9) {
                                        Circle()
                                            .fill(action.isEnabled ? StudioTheme.accent : Color.gray)
                                            .frame(width: 7, height: 7)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(layout?.name ?? action.name)
                                            Text("\(model.currentProject?.effectiveAtlasConfiguration.rowLabel(for: action.id) ?? "已配置") · \(action.frames.count) 帧")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        selectedActionID == action.id
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
                }
                .frame(width: 240)
                .padding(.leading, StudioTheme.pagePadding)
                .padding(.bottom, StudioTheme.pagePadding)

                Group {
                    if let selectedActionID,
                       let action = model.bindingForAction(id: selectedActionID),
                       let project = model.currentProject {
                        ActionEditorView(
                            model: model,
                            action: action,
                            project: project,
                            isHeaderCollapsed: $isHeaderCollapsed
                        )
                    } else {
                        ContentUnavailableView(
                            "选择一套动作",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("动作和帧按当前工程采用的图集配置排列。")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .groupBoxStyle(StudioGroupBoxStyle())
        .onAppear {
            if selectedActionID == nil {
                selectedActionID = model.currentProject?.actions.first?.id
            }
        }
        .onChange(of: model.document.selectedProjectID) { _, _ in
            selectedActionID = model.currentProject?.actions.first?.id
            isHeaderCollapsed = false
        }
    }

    @ViewBuilder
    private var actionPageHeader: some View {
        if let editedProject {
            if isHeaderCollapsed {
                projectNavigationRow(for: editedProject, includesEditorTitle: true)
                    .frame(minHeight: 42)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    projectNavigationRow(for: editedProject, includesEditorTitle: false)
                    StudioPageHeader(
                        eyebrow: "Animation Library",
                        title: "动作编辑",
                        subtitle: "逐帧调整当前工程的图片、播放方式和触发规则。动作结构来自工程采用的配置。"
                    )
                }
            }
        } else {
            StudioCollapsiblePageHeader(
                eyebrow: "Animation Library",
                title: "动作编辑",
                subtitle: "逐帧调整当前工程的图片、播放方式和触发规则。动作结构来自工程采用的配置。",
                isCollapsed: isHeaderCollapsed
            )
        }
    }

    private func projectNavigationRow(
        for project: PetProjectDefinition,
        includesEditorTitle: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                onBackToProjectLibrary?()
            } label: {
                Label("返回工程库", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)

            Divider().frame(height: 22)

            Text(project.name)
                .font(.headline)
                .lineLimit(1)
            StudioPill(
                text: project.showsOnDesktop ? "桌面显示中" : "未显示",
                color: project.showsOnDesktop ? .green : .secondary
            )

            if includesEditorTitle {
                Divider().frame(height: 22)
                Text("动作编辑")
                    .font(.title3.bold())
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    onRequestNormalization?(project)
                } label: {
                    Label("一键归一化全部帧", systemImage: "square.stack.3d.down.right")
                }
                .disabled(model.draftTransformCount(projectID: project.id) == 0)

                Button {
                    onRequestReset?(project)
                } label: {
                    Label("一键复原", systemImage: "arrow.uturn.backward")
                }
                .disabled(model.draftTransformCount(projectID: project.id) == 0)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isHeaderCollapsed)
    }
}

private struct ActionEditorView: View {
    @ObservedObject var model: AppModel
    @Binding var action: PetActionDefinition
    let project: PetProjectDefinition
    @Binding var isHeaderCollapsed: Bool
    @State private var selectedFrameIDs: Set<UUID> = []

    private var layout: AtlasActionConfiguration? {
        project.effectiveAtlasConfiguration.actions.first { $0.key == action.id }
    }

    var body: some View {
        HeaderPriorityScrollView(
            isHeaderCollapsed: $isHeaderCollapsed,
            resetKey: action.id,
            continuesScrollingAfterHeaderExpansion: true
        ) {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(layout?.name ?? action.name)
                            .font(.title2.bold())
                        Text("配置动作 · \(project.effectiveAtlasConfiguration.rowLabel(for: action.id))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("启用", isOn: $action.isEnabled)
                        .toggleStyle(.switch)
                    Button("播放整个动作") { model.playAction(id: action.id) }
                }

                playbackSettings
                playbackValidation
                frameEditor
                triggersEditor
            }
            .padding(.top, 8)
            .padding(.leading, 6)
            .padding(.trailing, StudioTheme.pagePadding)
            .padding(.bottom, StudioTheme.pagePadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .onAppear { selectAValidFrames() }
        .onChange(of: action.id) { _, _ in
            isHeaderCollapsed = false
            selectedFrameIDs = action.frames.first.map { Set([$0.id]) } ?? []
        }
        .onChange(of: action.frames.map(\.id)) { _, _ in selectAValidFrames() }
    }

    private var playbackSettings: some View {
        GroupBox("整套动作的播放方式") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("动作 ID")
                    Text(action.id).textSelection(.enabled).foregroundStyle(.secondary)
                }
                GridRow {
                    Text("播放模式")
                    Picker("", selection: $action.playback) {
                        ForEach(PlaybackMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                }
                if action.playback == .once {
                    GridRow {
                        Text("播放次数")
                        Stepper("\(action.repeatCount) 次", value: $action.repeatCount, in: 1...99)
                    }
                }
                GridRow {
                    Text("基础速度")
                    HStack {
                        StudioSlider(value: $action.framesPerSecond, in: 1...60, step: 1)
                        Text("\(Int(action.framesPerSecond)) FPS")
                            .monospacedDigit()
                            .frame(width: 58)
                    }
                }
                GridRow {
                    Text("动作优先级")
                    Stepper("\(action.priority)", value: $action.priority, in: 0...100)
                }
                GridRow {
                    Text("被打断规则")
                    Picker("", selection: $action.interruption) {
                        ForEach(InterruptionPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .labelsHidden()
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var playbackValidation: some View {
        let hasMouseLook = action.triggers.contains { $0.isEnabled && $0.kind == .mouseLook }
        if hasMouseLook && action.playback != .angleControlled {
            Label("“眼睛跟随鼠标”只会驱动“按角度选帧”模式；当前组合不会触发视线帧。", systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        } else if action.playback == .angleControlled && !hasMouseLook {
            Label("当前是按角度选帧，但还没有启用“眼睛跟随鼠标”触发器；手动播放时会停在首帧。", systemImage: "info.circle.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var frameEditor: some View {
        GroupBox("固定图集帧") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("缩略图顺序由“\(project.effectiveAtlasConfiguration.name)”配置决定。单击选择一帧，按住 ⌘ Command 单击可多选。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("已选 \(selectedFrameIDs.count) 帧")
                        .font(.caption.bold())
                        .foregroundStyle(selectedFrameIDs.count > 1 ? Color.accentColor : Color.secondary)
                }

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(action.frames.enumerated()), id: \.element.id) { index, frame in
                            FrameThumbnail(
                                index: index,
                                frame: frame,
                                image: model.frameImage(frame),
                                atlas: project.atlas,
                                isSelected: selectedFrameIDs.contains(frame.id)
                            )
                            .onTapGesture {
                                selectFrame(
                                    frame.id,
                                    extendingSelection: NSEvent.modifierFlags.contains(.command)
                                )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                if selectedFrameIDs.count > 1 {
                    MultiFrameEditor(
                        model: model,
                        action: $action,
                        selectedFrameIDs: selectedFrameIDs,
                        project: project
                    )
                } else if let frame = selectedFrameBinding,
                          let index = action.frames.firstIndex(where: { $0.id == frame.wrappedValue.id }) {
                    SelectedFrameEditor(
                        model: model,
                        actionID: action.id,
                        frameNumber: index + 1,
                        frame: frame,
                        actionFPS: action.framesPerSecond,
                        fixedAngle: action.playback == .angleControlled ? frame.wrappedValue.angleDegrees : nil,
                        project: project
                    )
                }
            }
        }
    }

    private var triggersEditor: some View {
        GroupBox("触发方式") {
            VStack(spacing: 10) {
                ForEach(action.triggers.indices, id: \.self) { index in
                    TriggerRuleEditor(
                        rule: Binding(
                            get: { action.triggers[index] },
                            set: { action.triggers[index] = $0 }
                        ),
                        remove: { action.triggers.remove(at: index) }
                    )
                }
                Button {
                    action.triggers.append(.blank())
                } label: {
                    Label("添加触发器", systemImage: "plus")
                }
            }
        }
    }

    private var selectedFrameBinding: Binding<PetFrameDefinition>? {
        guard let selectedFrameID = action.frames.first(where: { selectedFrameIDs.contains($0.id) })?.id,
              let index = action.frames.firstIndex(where: { $0.id == selectedFrameID }) else { return nil }
        return Binding(get: { action.frames[index] }, set: { action.frames[index] = $0 })
    }

    private func selectAValidFrames() {
        let validIDs = Set(action.frames.map(\.id))
        selectedFrameIDs.formIntersection(validIDs)
        if selectedFrameIDs.isEmpty, let firstID = action.frames.first?.id {
            selectedFrameIDs = [firstID]
        }
    }

    private func selectFrame(_ frameID: UUID, extendingSelection: Bool) {
        guard extendingSelection else {
            selectedFrameIDs = [frameID]
            return
        }
        if selectedFrameIDs.contains(frameID) {
            if selectedFrameIDs.count > 1 {
                selectedFrameIDs.remove(frameID)
            }
        } else {
            selectedFrameIDs.insert(frameID)
        }
    }
}

private struct SelectedFrameEditor: View {
    @ObservedObject var model: AppModel
    let actionID: String
    let frameNumber: Int
    @Binding var frame: PetFrameDefinition
    let actionFPS: Double
    let fixedAngle: Double?
    let project: PetProjectDefinition
    @State private var showsIdleReference = false

    private var hasDraftTransform: Bool {
        abs(frame.scale - 1) > 0.0001
            || abs(frame.scaleX - 1) > 0.0001
            || abs(frame.scaleY - 1) > 0.0001
            || abs(frame.offsetX) > 0.0001
            || abs(frame.offsetY) > 0.0001
    }

    private var idleReferenceFrame: PetFrameDefinition? {
        project.actions.first?.frames.first
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                previewPane
                controlsPane
            }

            VStack(alignment: .leading, spacing: 18) {
                previewPane
                controlsPane
            }
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            FrameCanvas(
                frame: frame,
                image: model.frameImage(frame),
                atlas: project.atlas,
                referenceFrame: showsIdleReference ? idleReferenceFrame : nil,
                referenceImage: showsIdleReference ? idleReferenceFrame.flatMap(model.frameImage) : nil,
                showsViewportGuide: true
            )
                .frame(width: 280, height: 304)
                .overlay(alignment: .topLeading) {
                    Text("第 \(frameNumber) 帧")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(7)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        showsIdleReference.toggle()
                    } label: {
                        Label(
                            showsIdleReference ? "关闭首帧参照" : "叠加常态首帧",
                            systemImage: showsIdleReference ? "square.stack.3d.up.fill" : "square.stack.3d.up"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(showsIdleReference ? .accentColor : nil)
                    .padding(7)
                    .help("将图集左上角的常态首帧半透明叠加在当前帧上")
                }
            Text("固定视口：\(project.atlas.cellWidth) × \(project.atlas.cellHeight) px；中心十字与外框不会随参数变化，超出部分按桌宠窗口效果裁切")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let fixedAngle {
                Text("固定视线角度：\(fixedAngle, format: .number.precision(.fractionLength(0...1)))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("这一帧的图片") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("导入单帧 PNG…") {
                            model.importFramePNG(actionID: actionID, frameID: frame.id)
                        }
                        Button("导出单帧 PNG…") {
                            model.exportFramePNG(actionID: actionID, frameID: frame.id)
                        }
                    }
                    Text("导入图片会等比居中放入 \(project.atlas.cellWidth) × \(project.atlas.cellHeight) 的固定格位，并立即写回整张图集。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("这一帧的大小与位置") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("整体缩放") {
                        StudioSlider(value: $frame.scale, in: 0.25...2, step: 0.01)
                            .frame(maxWidth: 210)
                        Text("\(Int(frame.scale * 100))%")
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                    LabeledContent("横向缩放") {
                        StudioSlider(value: $frame.scaleX, in: 0.25...2, step: 0.01)
                            .frame(maxWidth: 210)
                        Text("\(Int(frame.scaleX * 100))%")
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                    LabeledContent("纵向缩放") {
                        StudioSlider(value: $frame.scaleY, in: 0.25...2, step: 0.01)
                            .frame(maxWidth: 210)
                        Text("\(Int(frame.scaleY * 100))%")
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            offsetXStepper
                            offsetYStepper
                        }
                        VStack(alignment: .leading) {
                            offsetXStepper
                            offsetYStepper
                        }
                    }
                    Text("整体、横向和纵向缩放会叠加；X 为正向右，Y 为正向上。这些数值先作为工程草稿，不会改变原图。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            model.bakeFrameTransform(actionID: actionID, frameID: frame.id)
                        } label: {
                            Label("归一化并写入图集", systemImage: "square.and.arrow.down")
                        }
                        .disabled(!hasDraftTransform)

                        Button {
                            model.resetFrameTransform(actionID: actionID, frameID: frame.id)
                        } label: {
                            Label("复原参数", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!hasDraftTransform)
                    }
                    Text("归一化会把三组缩放与位移永久烘焙进这一个格位；复原参数会把缩放全部恢复为 100%、X/Y 恢复为 0，不会修改图集。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("这一帧的停留时间") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StudioSlider(value: $frame.durationMultiplier, in: 0.1...8, step: 0.05)
                        Text("× \(frame.durationMultiplier, format: .number.precision(.fractionLength(2)))")
                            .monospacedDigit()
                            .frame(width: 58)
                    }
                    Text("当前约 \(frame.durationMultiplier / max(1, actionFPS), format: .number.precision(.fractionLength(3))) 秒。时长属于 Studio 播放配置，不会写进 PNG。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var offsetXStepper: some View {
        Stepper(
            "水平 X：\(Int(frame.offsetX)) px",
            value: $frame.offsetX,
            in: -Double(project.atlas.cellWidth)...Double(project.atlas.cellWidth),
            step: 1
        )
    }

    private var offsetYStepper: some View {
        Stepper(
            "垂直 Y：\(Int(frame.offsetY)) px",
            value: $frame.offsetY,
            in: -Double(project.atlas.cellHeight)...Double(project.atlas.cellHeight),
            step: 1
        )
    }
}

private struct MultiFrameEditor: View {
    @ObservedObject var model: AppModel
    @Binding var action: PetActionDefinition
    let selectedFrameIDs: Set<UUID>
    let project: PetProjectDefinition

    @State private var showsIdleReference = false
    @State private var overallPercentDelta = 0
    @State private var horizontalPercentDelta = 0
    @State private var verticalPercentDelta = 0
    @State private var horizontalPixelDelta = 0
    @State private var verticalPixelDelta = 0

    private var orderedSelection: [(index: Int, frame: PetFrameDefinition)] {
        action.frames.enumerated().compactMap { index, frame in
            selectedFrameIDs.contains(frame.id) ? (index, frame) : nil
        }
    }

    private var previewSelection: (index: Int, frame: PetFrameDefinition)? {
        orderedSelection.first
    }

    private var idleReferenceFrame: PetFrameDefinition? {
        project.actions.first?.frames.first
    }

    private var selectionKey: String {
        orderedSelection.map { $0.frame.id.uuidString }.joined(separator: ",")
    }

    private var hasDraftTransform: Bool {
        orderedSelection.contains { item in
            let frame = item.frame
            return abs(frame.scale - 1) > 0.0001
                || abs(frame.scaleX - 1) > 0.0001
                || abs(frame.scaleY - 1) > 0.0001
                || abs(frame.offsetX) > 0.0001
                || abs(frame.offsetY) > 0.0001
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                previewPane
                controlsPane
            }

            VStack(alignment: .leading, spacing: 18) {
                previewPane
                controlsPane
            }
        }
        .onChange(of: selectionKey) { _, _ in resetDisplayedDeltas() }
    }

    @ViewBuilder
    private var previewPane: some View {
        if let previewSelection {
            VStack(alignment: .leading, spacing: 8) {
                FrameCanvas(
                    frame: previewSelection.frame,
                    image: model.frameImage(previewSelection.frame),
                    atlas: project.atlas,
                    referenceFrame: showsIdleReference ? idleReferenceFrame : nil,
                    referenceImage: showsIdleReference ? idleReferenceFrame.flatMap(model.frameImage) : nil,
                    showsViewportGuide: true
                )
                .frame(width: 280, height: 304)
                .overlay(alignment: .topLeading) {
                    Text("预览第 \(previewSelection.index + 1) 帧")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(7)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        showsIdleReference.toggle()
                    } label: {
                        Label(
                            showsIdleReference ? "关闭首帧参照" : "叠加常态首帧",
                            systemImage: showsIdleReference ? "square.stack.3d.up.fill" : "square.stack.3d.up"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(showsIdleReference ? .accentColor : nil)
                    .padding(7)
                }
                Text("固定视口只显示所选帧中最靠前的一帧；其余所选帧按各自原参数同步增减")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("批量相对调整 · \(orderedSelection.count) 帧") {
                VStack(alignment: .leading, spacing: 10) {
                    RelativeAdjustmentRow(
                        title: "整体缩放",
                        accumulatedValue: signed(overallPercentDelta, unit: "%"),
                        decrement: {
                            adjustScale(\.scale, steps: -1)
                            overallPercentDelta -= 1
                        },
                        increment: {
                            adjustScale(\.scale, steps: 1)
                            overallPercentDelta += 1
                        }
                    )
                    RelativeAdjustmentRow(
                        title: "横向缩放",
                        accumulatedValue: signed(horizontalPercentDelta, unit: "%"),
                        decrement: {
                            adjustScale(\.scaleX, steps: -1)
                            horizontalPercentDelta -= 1
                        },
                        increment: {
                            adjustScale(\.scaleX, steps: 1)
                            horizontalPercentDelta += 1
                        }
                    )
                    RelativeAdjustmentRow(
                        title: "纵向缩放",
                        accumulatedValue: signed(verticalPercentDelta, unit: "%"),
                        decrement: {
                            adjustScale(\.scaleY, steps: -1)
                            verticalPercentDelta -= 1
                        },
                        increment: {
                            adjustScale(\.scaleY, steps: 1)
                            verticalPercentDelta += 1
                        }
                    )
                    RelativeAdjustmentRow(
                        title: "水平 X",
                        accumulatedValue: signed(horizontalPixelDelta, unit: " px"),
                        decrement: {
                            adjustOffset(\.offsetX, steps: -1, limit: project.atlas.cellWidth)
                            horizontalPixelDelta -= 1
                        },
                        increment: {
                            adjustOffset(\.offsetX, steps: 1, limit: project.atlas.cellWidth)
                            horizontalPixelDelta += 1
                        }
                    )
                    RelativeAdjustmentRow(
                        title: "垂直 Y",
                        accumulatedValue: signed(verticalPixelDelta, unit: " px"),
                        decrement: {
                            adjustOffset(\.offsetY, steps: -1, limit: project.atlas.cellHeight)
                            verticalPixelDelta -= 1
                        },
                        increment: {
                            adjustOffset(\.offsetY, steps: 1, limit: project.atlas.cellHeight)
                            verticalPixelDelta += 1
                        }
                    )

                    Text("右侧数值是本次多选后的累计增量。每次操作都在每一帧现有参数上分别加减，不会把所选帧强制设为同一个值。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button {
                            model.bakeFrameTransforms(
                                actionID: action.id,
                                frameIDs: selectedFrameIDs
                            )
                            resetDisplayedDeltas()
                        } label: {
                            Label("归一化所选帧", systemImage: "square.and.arrow.down")
                        }
                        .disabled(!hasDraftTransform)

                        Button {
                            model.resetFrameTransforms(
                                actionID: action.id,
                                frameIDs: selectedFrameIDs
                            )
                            resetDisplayedDeltas()
                        } label: {
                            Label("复原所选参数", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!hasDraftTransform)
                    }
                }
            }

            Text("多选模式只批量调整变换参数；单帧 PNG、停留时间和视线角度请切回单选后编辑。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func adjustScale(
        _ keyPath: WritableKeyPath<PetFrameDefinition, Double>,
        steps: Int
    ) {
        var updated = action
        let delta = Double(steps) / 100
        for index in updated.frames.indices where selectedFrameIDs.contains(updated.frames[index].id) {
            let current = updated.frames[index][keyPath: keyPath]
            updated.frames[index][keyPath: keyPath] = min(2, max(0.25, current + delta))
        }
        action = updated
    }

    private func adjustOffset(
        _ keyPath: WritableKeyPath<PetFrameDefinition, Double>,
        steps: Int,
        limit: Int
    ) {
        var updated = action
        let bound = Double(max(1, limit))
        for index in updated.frames.indices where selectedFrameIDs.contains(updated.frames[index].id) {
            let current = updated.frames[index][keyPath: keyPath]
            updated.frames[index][keyPath: keyPath] = min(bound, max(-bound, current + Double(steps)))
        }
        action = updated
    }

    private func signed(_ value: Int, unit: String) -> String {
        value > 0 ? "+\(value)\(unit)" : "\(value)\(unit)"
    }

    private func resetDisplayedDeltas() {
        overallPercentDelta = 0
        horizontalPercentDelta = 0
        verticalPercentDelta = 0
        horizontalPixelDelta = 0
        verticalPixelDelta = 0
    }
}

private struct RelativeAdjustmentRow: View {
    let title: String
    let accumulatedValue: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: 12)
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.bordered)
            Text(accumulatedValue)
                .monospacedDigit()
                .frame(width: 62, alignment: .center)
            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct FrameThumbnail: View {
    let index: Int
    let frame: PetFrameDefinition
    let image: NSImage?
    let atlas: AtlasDefinition
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            FrameCanvas(frame: frame, image: image, atlas: atlas)
                .frame(width: 76, height: 82)
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
        }
        .padding(5)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(Rectangle())
    }
}

private struct FrameCanvas: View {
    let frame: PetFrameDefinition
    let image: NSImage?
    let atlas: AtlasDefinition
    var referenceFrame: PetFrameDefinition? = nil
    var referenceImage: NSImage? = nil
    var showsViewportGuide = false

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = CGFloat(max(1, atlas.cellWidth))
            let cellHeight = CGFloat(max(1, atlas.cellHeight))
            let fit = min(
                proxy.size.width / CGFloat(max(1, atlas.cellWidth)),
                proxy.size.height / CGFloat(max(1, atlas.cellHeight))
            )
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack(alignment: .topLeading) {
                Color(nsColor: .controlBackgroundColor)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                CheckerboardView()
                    .frame(width: cellWidth * fit, height: cellHeight * fit)
                    .overlay {
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .position(center)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(atlas.filtering == .nearest ? .none : .high)
                        .frame(
                            width: CGFloat(atlas.cellWidth) * fit * CGFloat(frame.scale * frame.scaleX),
                            height: CGFloat(atlas.cellHeight) * fit * CGFloat(frame.scale * frame.scaleY)
                        )
                        .position(
                            x: center.x + CGFloat(frame.offsetX) * fit,
                            y: center.y - CGFloat(frame.offsetY) * fit
                        )
                }
                if let referenceFrame, let referenceImage {
                    Image(nsImage: referenceImage)
                        .resizable()
                        .interpolation(atlas.filtering == .nearest ? .none : .high)
                        .frame(
                            width: CGFloat(atlas.cellWidth) * fit * CGFloat(referenceFrame.scale * referenceFrame.scaleX),
                            height: CGFloat(atlas.cellHeight) * fit * CGFloat(referenceFrame.scale * referenceFrame.scaleY)
                        )
                        .position(
                            x: center.x + CGFloat(referenceFrame.offsetX) * fit,
                            y: center.y - CGFloat(referenceFrame.offsetY) * fit
                        )
                        .opacity(0.42)
                        .allowsHitTesting(false)
                }
                if showsViewportGuide {
                    FixedViewportGuide()
                        .frame(width: cellWidth * fit, height: cellHeight * fit)
                        .position(center)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            .background(Color.clear)
        }
        .aspectRatio(CGFloat(atlas.cellWidth) / CGFloat(max(1, atlas.cellHeight)), contentMode: .fit)
        .overlay { Rectangle().stroke(Color.secondary.opacity(0.22)) }
    }
}

private struct FixedViewportGuide: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .stroke(Color.primary.opacity(0.38), lineWidth: 1)
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(
                    Color.accentColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                Circle()
                    .fill(Color.accentColor.opacity(0.72))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

private struct CheckerboardView: View {
    private static let tileImage: Image = {
        let square: CGFloat = 10
        let tileSize = NSSize(width: square * 2, height: square * 2)
        let image = NSImage(size: tileSize, flipped: false) { bounds in
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: bounds).fill()

            NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: square, height: square)).fill()
            NSBezierPath(rect: NSRect(x: square, y: square, width: square, height: square)).fill()
            return true
        }
        image.cacheMode = .always
        return Image(nsImage: image)
    }()

    var body: some View {
        Rectangle()
            .fill(
                ImagePaint(image: Self.tileImage, scale: 1)
            )
    }
}
