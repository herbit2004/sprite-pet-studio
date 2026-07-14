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
    @ObservedObject var model: AppModel
    @State private var destination: SettingsDestination = .projects

    var body: some View {
        VStack(spacing: 0) {
            topNavigation
            Divider()
            ZStack {
                StudioPageBackground()
                detail
                    .padding(StudioTheme.pagePadding)
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
        HStack(spacing: 8) {
            ForEach([SettingsDestination.projects, .configurations, .general, .events]) { item in
                navigationButton(item)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func navigationButton(_ item: SettingsDestination) -> some View {
        Button {
            destination = item
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.callout.weight(destination == item ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(destination == item ? StudioTheme.accent : Color.primary)
                .background(
                    destination == item ? StudioTheme.accent.opacity(0.12) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
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
