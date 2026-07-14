import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
                StudioPageHeader(
                    eyebrow: "Playback & System",
                    title: "通用设置",
                    subtitle: "调整当前桌宠的显示、渲染与系统行为。"
                )

                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("桌宠显示", systemImage: "pawprint.fill").font(.headline)
                        Text("各工程是否显示由“工程库”单独控制；这里的开关用于临时隐藏或恢复所有已启用工程。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("启用桌宠显示（总开关）", isOn: model.bindingForGeneral(\.isPetVisible))
                        Toggle("始终置顶", isOn: model.bindingForGeneral(\.alwaysOnTop))
                        LabeledContent("显示尺寸") {
                            HStack {
                                Slider(value: model.bindingForGeneral(\.petScale), in: 0.35...1.6, step: 0.01)
                                    .frame(width: 300)
                                Text("\(Int(model.document.general.petScale * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        Button("将所有可见桌宠错开移回主屏幕右下角") { model.resetWindowPosition() }
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("动画与输入", systemImage: "waveform.path").font(.headline)
                        Picker("渲染帧率", selection: model.bindingForGeneral(\.preferredFramesPerSecond)) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                            Text("120 FPS").tag(120)
                        }
                        Picker("鼠标采样率", selection: model.bindingForGeneral(\.mousePollingRate)) {
                            Text("15 次/秒").tag(15)
                            Text("30 次/秒").tag(30)
                            Text("60 次/秒").tag(60)
                        }
                        Text("渲染帧率控制窗口刷新；动作自身的 FPS 决定原画切帧速度。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("系统", systemImage: "macbook").font(.headline)
                        Toggle("登录时自动启动", isOn: Binding(
                            get: { model.document.general.launchAtLogin },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                        Text(model.loginItemStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("打开用户工程与配置目录") { model.openProjectFolder() }
                    }
                }
            }
            .padding(StudioTheme.pagePadding)
        }
    }
}
