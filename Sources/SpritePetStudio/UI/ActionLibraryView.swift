import AppKit
import SwiftUI

struct ActionLibraryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedActionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
            StudioPageHeader(
                eyebrow: "Animation Library",
                title: "动作编辑",
                subtitle: "逐帧调整当前工程的图片、播放方式和触发规则。动作结构来自工程采用的配置。"
            )

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

                Group {
                    if let selectedActionID,
                       let action = model.bindingForAction(id: selectedActionID),
                       let project = model.currentProject {
                        ActionEditorView(model: model, action: action, project: project)
                    } else {
                        ContentUnavailableView(
                            "选择一套动作",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("动作和帧按当前工程采用的图集配置排列。")
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .groupBoxStyle(StudioGroupBoxStyle())
        .onAppear {
            if selectedActionID == nil {
                selectedActionID = model.currentProject?.actions.first?.id
            }
        }
        .onChange(of: model.document.selectedProjectID) { _, _ in
            selectedActionID = model.currentProject?.actions.first?.id
        }
    }
}

private struct ActionEditorView: View {
    @ObservedObject var model: AppModel
    @Binding var action: PetActionDefinition
    let project: PetProjectDefinition
    @State private var selectedFrameID: UUID?

    private var layout: AtlasActionConfiguration? {
        project.effectiveAtlasConfiguration.actions.first { $0.key == action.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
            .padding(.trailing, 8)
        }
        .onAppear { selectAValidFrame() }
        .onChange(of: action.id) { _, _ in selectAValidFrame() }
        .onChange(of: action.frames.map(\.id)) { _, _ in selectAValidFrame() }
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
                GridRow {
                    Text("播放次数")
                    HStack(spacing: 8) {
                        Stepper("\(action.repeatCount) 次", value: $action.repeatCount, in: 1...99)
                        if action.playback == .loop {
                            Text("持续循环时不受此值限制")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(action.playback != .once)
                    .opacity(action.playback == .once ? 1 : 0.5)
                }
                GridRow {
                    Text("基础速度")
                    HStack {
                        Slider(value: $action.framesPerSecond, in: 1...60, step: 1)
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
                Text("缩略图顺序由“\(project.effectiveAtlasConfiguration.name)”配置决定。要改变动作或帧数，请到配置库编辑对应配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(action.frames.enumerated()), id: \.element.id) { index, frame in
                            FrameThumbnail(
                                index: index,
                                frame: frame,
                                image: model.frameImage(frame),
                                atlas: project.atlas,
                                isSelected: selectedFrameID == frame.id
                            )
                            .onTapGesture { selectedFrameID = frame.id }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                if let frame = selectedFrameBinding,
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
        guard let selectedFrameID,
              let index = action.frames.firstIndex(where: { $0.id == selectedFrameID }) else { return nil }
        return Binding(get: { action.frames[index] }, set: { action.frames[index] = $0 })
    }

    private func selectAValidFrame() {
        if let selectedFrameID, action.frames.contains(where: { $0.id == selectedFrameID }) { return }
        selectedFrameID = action.frames.first?.id
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
        abs(frame.scale - 1) > 0.0001 || abs(frame.offsetX) > 0.0001 || abs(frame.offsetY) > 0.0001
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
                adaptiveViewport: true
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
            Text("来源：工程中的 spritesheet.png 固定格位；超出格位时预览会自动缩小视野")
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
                    LabeledContent("相对大小") {
                        Slider(value: $frame.scale, in: 0.25...2, step: 0.01)
                            .frame(maxWidth: 210)
                        Text("\(Int(frame.scale * 100))%")
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
                    Text("X 为正向右，Y 为正向上；这些数值先作为工程草稿，不会改变原图。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button {
                        model.bakeFrameTransform(actionID: actionID, frameID: frame.id)
                    } label: {
                        Label("归一化并写入图集", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!hasDraftTransform)
                    Text("归一化会把当前大小和位移永久烘焙进这一个格位，再把数值复位。之后导出的图集可直接拿回 Codex 使用。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("这一帧的停留时间") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Slider(value: $frame.durationMultiplier, in: 0.1...8, step: 0.05)
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
    var adaptiveViewport = false

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = CGFloat(max(1, atlas.cellWidth))
            let cellHeight = CGFloat(max(1, atlas.cellHeight))
            let baseFit = min(
                proxy.size.width / CGFloat(max(1, atlas.cellWidth)),
                proxy.size.height / CGFloat(max(1, atlas.cellHeight))
            )
            let halfExtents = requiredHalfExtents(cellWidth: cellWidth, cellHeight: cellHeight)
            let adaptiveFit = min(
                max(1, proxy.size.width - 16) / max(1, halfExtents.width * 2),
                max(1, proxy.size.height - 16) / max(1, halfExtents.height * 2)
            )
            let fit = adaptiveViewport ? min(baseFit, adaptiveFit) : baseFit
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                CheckerboardView()
                    .frame(width: cellWidth * fit, height: cellHeight * fit)
                    .overlay {
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(atlas.filtering == .nearest ? .none : .high)
                        .frame(
                            width: CGFloat(atlas.cellWidth) * fit * CGFloat(frame.scale),
                            height: CGFloat(atlas.cellHeight) * fit * CGFloat(frame.scale)
                        )
                        .offset(
                            x: CGFloat(frame.offsetX) * fit,
                            y: -CGFloat(frame.offsetY) * fit
                        )
                }
                if let referenceFrame, let referenceImage {
                    Image(nsImage: referenceImage)
                        .resizable()
                        .interpolation(atlas.filtering == .nearest ? .none : .high)
                        .frame(
                            width: CGFloat(atlas.cellWidth) * fit * CGFloat(referenceFrame.scale),
                            height: CGFloat(atlas.cellHeight) * fit * CGFloat(referenceFrame.scale)
                        )
                        .offset(
                            x: CGFloat(referenceFrame.offsetX) * fit,
                            y: -CGFloat(referenceFrame.offsetY) * fit
                        )
                        .opacity(0.42)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(Color.clear)
        }
        .aspectRatio(CGFloat(atlas.cellWidth) / CGFloat(max(1, atlas.cellHeight)), contentMode: .fit)
        .overlay { Rectangle().stroke(Color.secondary.opacity(0.22)) }
    }

    private func requiredHalfExtents(cellWidth: CGFloat, cellHeight: CGFloat) -> CGSize {
        var horizontal = cellWidth / 2
        var vertical = cellHeight / 2

        func include(_ candidate: PetFrameDefinition) {
            horizontal = max(
                horizontal,
                abs(CGFloat(candidate.offsetX)) + cellWidth * max(0.01, CGFloat(candidate.scale)) / 2
            )
            vertical = max(
                vertical,
                abs(CGFloat(candidate.offsetY)) + cellHeight * max(0.01, CGFloat(candidate.scale)) / 2
            )
        }

        include(frame)
        if let referenceFrame { include(referenceFrame) }
        return CGSize(width: horizontal, height: vertical)
    }
}

private struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 10
            let horizontalCount = Int(ceil(size.width / square))
            let verticalCount = Int(ceil(size.height / square))
            for verticalIndex in 0..<verticalCount {
                for horizontalIndex in 0..<horizontalCount {
                    let color = (verticalIndex + horizontalIndex).isMultiple(of: 2)
                        ? Color(nsColor: .windowBackgroundColor)
                        : Color.secondary.opacity(0.12)
                    context.fill(
                        Path(CGRect(
                            x: CGFloat(horizontalIndex) * square,
                            y: CGFloat(verticalIndex) * square,
                            width: square,
                            height: square
                        )),
                        with: .color(color)
                    )
                }
            }
        }
    }
}
