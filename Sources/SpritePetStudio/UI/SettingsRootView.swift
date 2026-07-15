import SwiftUI

private enum SettingsDestination: String, Identifiable {
    case projects
    case configurations
    case general
    case events

    var id: String { rawValue }
    var title: String {
        switch self {
        case .projects: return "工程库"
        case .configurations: return "配置库"
        case .general: return "通用"
        case .events: return "事件接口"
        }
    }
    var icon: String {
        switch self {
        case .projects: return "square.stack.3d.up"
        case .configurations: return "square.grid.3x3"
        case .general: return "slider.horizontal.3"
        case .events: return "bolt.horizontal"
        }
    }
}

struct SettingsRootView: View {
    private static let websiteURL = URL(
        string: "https://herbit2004.github.io/sprite-pet-studio/"
    )!

    @ObservedObject var model: AppModel
    @State private var destination: SettingsDestination = .projects
    @State private var hoveredDestination: SettingsDestination?
    @State private var isWebsiteHovered = false

    private let destinations: [SettingsDestination] = [
        .projects, .configurations, .general, .events
    ]

    var body: some View {
        VStack(spacing: 0) {
            topNavigation
            Divider()
            ZStack {
                StudioPageBackground()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(StudioTheme.accent)
        .alert("桌宠工坊", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("好", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "未知错误")
        }
    }

    private var topNavigation: some View {
        HStack(spacing: 0) {
            ForEach(Array(destinations.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                        .frame(height: 18)
                        .padding(.horizontal, 4)
                }
                navigationButton(item)
            }
            Spacer(minLength: 12)
            Divider()
                .frame(height: 18)
                .padding(.horizontal, 8)
            Link(destination: Self.websiteURL) {
                Label("Website", systemImage: "globe")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 104, minHeight: 40)
                    .contentShape(Rectangle())
                    .background(
                        isWebsiteHovered ? Color.secondary.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isWebsiteHovered = $0 }
            .help("在浏览器中打开 SpritePet Studio 官网")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(StudioTheme.pageBackground)
    }

    private func navigationButton(_ item: SettingsDestination) -> some View {
        Button {
            destination = item
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.callout.weight(destination == item ? .semibold : .regular))
                .foregroundStyle(destination == item ? StudioTheme.accent : Color.primary)
                .frame(minWidth: 112, minHeight: 40)
                .contentShape(Rectangle())
                .background(
                    hoveredDestination == item ? Color.secondary.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(StudioTheme.accent)
                        .frame(width: 22, height: 2)
                        .opacity(destination == item ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredDestination = isHovered ? item : nil
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .projects:
            ProjectLibraryView(model: model)
        case .configurations:
            ConfigurationLibraryView(model: model)
        case .general:
            GeneralSettingsView(model: model)
        case .events:
            EventCatalogView()
        }
    }
}
