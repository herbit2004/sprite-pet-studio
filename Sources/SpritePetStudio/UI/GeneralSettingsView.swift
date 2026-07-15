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

                versionCard

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
                                StudioSlider(
                                    value: model.bindingForGeneral(\.petScale),
                                    in: 0.35...1.6,
                                    step: 0.01
                                )
                                    .frame(width: 300)
                                Text("\(Int(model.document.general.petScale * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        Button("将所有可见桌宠错开移回主屏幕右下角") { model.resetWindowPosition() }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(StudioTheme.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var versionCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Label("版本与更新", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                    Spacer()
                    StudioPill(text: "v\(model.currentAppVersion)")
                }

                Text("点击检查后，应用会读取产品网站发布的固定版本清单；不会上传工程或设备信息。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                updateStatus

                HStack(spacing: 10) {
                    Button {
                        model.checkForUpdates()
                    } label: {
                        Label(
                            model.updateCheckState == .checking ? "正在检查…" : "检查更新",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .disabled(model.updateCheckState == .checking)

                    if case .updateAvailable(let published) = model.updateCheckState {
                        Button("下载 v\(published.version)") {
                            model.openPublishedUpdate(published)
                        }
                        Button("查看发布说明") {
                            model.openPublishedReleaseNotes(published)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch model.updateCheckState {
        case .idle:
            Label("尚未检查更新", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text("正在连接 GitHub Pages…")
            }
            .foregroundStyle(.secondary)
        case .upToDate(let latestVersion):
            Label("已经是最新版本（v\(latestVersion)）", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .updateAvailable(let published):
            Label("发现新版本 v\(published.version)", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.orange)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("暂时无法检查更新", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
