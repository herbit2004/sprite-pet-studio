import SwiftUI

enum StudioTheme {
    static let accent = Color(nsColor: .controlAccentColor)
    static let accentSoft = Color(red: 0.38, green: 0.58, blue: 0.98)
    static let cardRadius: CGFloat = 16
    static let pageSpacing: CGFloat = 18
    static let pagePadding: CGFloat = 24
}
struct StudioPageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StudioTheme.accent)
                    .tracking(0.8)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
    }
}

extension StudioPageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct StudioCard<Content: View>: View {
    var isSelected = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.cardRadius, style: .continuous)
                    .fill(.background.opacity(0.86))
                    .shadow(color: .black.opacity(0.06), radius: 14, y: 5)
            )
            .overlay {
                RoundedRectangle(cornerRadius: StudioTheme.cardRadius, style: .continuous)
                    .stroke(
                        isSelected ? StudioTheme.accent : Color.secondary.opacity(0.13),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
    }
}

struct StudioPill: View {
    let text: String
    var color: Color = StudioTheme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct StudioPageBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
        .ignoresSafeArea()
    }
}

struct StudioPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [StudioTheme.accentSoft, StudioTheme.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct StudioGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.84))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12))
        }
    }
}
