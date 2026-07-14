import SwiftUI

struct ProjectSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("宠物工程")
                    .font(.title2.bold())
                Spacer()
                Button("导入 Codex 工程…") { model.importProject() }
                Button("导出 Codex 工程…") { model.exportCurrentProject() }
                Button("删除") { model.deleteCurrentProject() }
                    .disabled(model.currentProject?.isBuiltIn != false)
            }

            if let project = model.bindingForCurrentProject() {
                Form {
                    Section("基本信息") {
                        TextField("工程名称", text: project.name)
                        TextField("作者", text: project.author)
                        TextField("工程 ID", text: project.id)
                            .disabled(project.wrappedValue.isBuiltIn)
                        TextField("说明", text: project.projectDescription, axis: .vertical)
                            .lineLimit(2...5)
                        LabeledContent("默认动作", value: "常态（idle）")
                    }

                    Section("Codex v2 固定图集") {
                        LabeledContent("整张 PNG", value: "1536 × 2288 px")
                        LabeledContent("固定格位", value: "横向 8 个，纵向 11 组")
                        LabeledContent("每个格位", value: "192 × 208 px")
                        LabeledContent("动作顺序", value: "固定 9 套动作 + 16 方向视线")
                        Picker("缩放预览方式", selection: project.atlas.filtering) {
                            ForEach(TextureFiltering.allCases) { filtering in
                                Text(filtering.displayName).tag(filtering)
                            }
                        }
                        Text("这些取图参数与 Codex v2 完全一致，在设置中不可修改。动作库会按固定顺序列出动作，每套动作里的缩略图顺序就是实际播放顺序。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("导入与导出") {
                        Text("导入时选择 Codex 工程目录里的 pet.json。应用会读取同目录的图集，并在内部统一保存为一张 spritesheet.png。")
                        Text("导出目录包含 pet.json、spritesheet.png 和 studio.json。前两者可直接供 Codex 使用；studio.json 保存本软件的触发器、播放方式，以及尚未归一化的逐帧调整。")
                        Text("单帧 PNG 只作为编辑入口：导入后会立即写入大图对应格位，不会在工程里留下独立帧文件。")
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView("没有宠物工程", systemImage: "shippingbox")
            }

            Text("若要把大小或位置调整带回 Codex，请先在动作库中对对应帧执行“归一化并写入图集”，再导出工程。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
