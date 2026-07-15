import SwiftUI

struct EventCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.pageSpacing) {
                StudioPageHeader(
                    eyebrow: "Automation",
                    title: "统一事件接口",
                    subtitle: "任意动作都能绑定一个或多个事件；离散事件可设置触发延迟，普通鼠标交互不需要额外权限。"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), alignment: .top)], spacing: 12) {
                    ForEach(TriggerKind.allCases) { kind in
                        StudioCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(kind.displayName, systemImage: icon(for: kind))
                                    .font(.headline)
                                Text(kind.helpText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("外部控制", systemImage: "terminal").font(.headline)
                        Text("open 'spritepet://trigger/task-running'")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Text("spritepetctl trigger task-running")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("鼠标角度帧", systemImage: "scope").font(.headline)
                        Text("动作必须同时满足：播放模式为“按角度选帧”，并启用“眼睛跟随鼠标”触发器。若只设置其中一个，编辑器会显示提示，运行时不会误播。距离条件可以选择以内或以外。")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(StudioTheme.pagePadding)
        }
    }

    private func icon(for kind: TriggerKind) -> String {
        switch kind {
        case .random: return "dice"
        case .mouseNear, .mouseLook, .mouseEnter, .mouseExit: return "cursorarrow.rays"
        case .singleClick, .doubleClick, .rightClick: return "computermouse"
        case .dragStart, .dragLeft, .dragRight, .dragEnd: return "hand.draw"
        case .systemWake, .systemSleep, .screenLocked, .screenUnlocked: return "desktopcomputer"
        case .scheduled: return "clock"
        case .external: return "terminal"
        default: return "bolt"
        }
    }
}
