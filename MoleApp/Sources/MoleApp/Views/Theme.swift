import SwiftUI

// MARK: - Premium Color Palette

enum MacMartinColors {
    // Primary brand
    static let accent = Color(red: 0.40, green: 0.52, blue: 1.0)
    static let accentLight = Color(red: 0.55, green: 0.65, blue: 1.0)

    // Semantic
    static let danger = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let success = Color(red: 0.30, green: 0.82, blue: 0.50)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.28)

    // Surface
    static let cardBg = Color.white.opacity(0.035)
    static let cardBgHover = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.07)
    static let subtleText = Color.white.opacity(0.4)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.40, blue: 0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let proGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.85, blue: 0.3)],
        startPoint: .leading, endPoint: .trailing
    )
    static let headerGradient = LinearGradient(
        colors: [Color.white.opacity(0.04), Color.clear],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Glass Card

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MacMartinColors.cardBg)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MacMartinColors.cardBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Category Helpers

func categoryIcon(_ name: String) -> String {
    switch name {
    case "System": return "gearshape.2"
    case "User essentials": return "person.crop.circle"
    case "App caches": return "square.stack.3d.up"
    case "Browsers": return "globe"
    case "Cloud & Office": return "cloud"
    case "Developer tools": return "hammer"
    case "Applications": return "app.badge"
    case "Virtualization": return "desktopcomputer"
    case "Application Support": return "folder.badge.gearshape"
    case "Orphaned data": return "trash.slash"
    case "Apple Silicon": return "cpu"
    case "Time Machine": return "clock.arrow.circlepath"
    default: return "folder"
    }
}

func categoryColor(_ name: String) -> Color {
    switch name {
    case "System": return Color(red: 0.65, green: 0.45, blue: 0.95)
    case "User essentials": return Color(red: 0.40, green: 0.52, blue: 1.0)
    case "App caches": return Color(red: 0.30, green: 0.75, blue: 0.85)
    case "Browsers": return Color(red: 1.0, green: 0.60, blue: 0.30)
    case "Cloud & Office": return Color(red: 0.45, green: 0.40, blue: 0.90)
    case "Developer tools": return Color(red: 0.35, green: 0.80, blue: 0.50)
    case "Applications": return Color(red: 0.95, green: 0.45, blue: 0.55)
    case "Virtualization": return Color(red: 0.40, green: 0.80, blue: 0.70)
    case "Application Support": return Color(red: 0.35, green: 0.70, blue: 0.75)
    case "Orphaned data": return Color(red: 0.55, green: 0.55, blue: 0.60)
    case "Apple Silicon": return Color(red: 0.90, green: 0.75, blue: 0.30)
    case "Time Machine": return Color(red: 0.45, green: 0.55, blue: 0.95)
    default: return .secondary
    }
}

// MARK: - Size Bar

struct SizeBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, geo.size.width * min(fraction, 1.0)))
                    .animation(.easeOut(duration: 0.5), value: fraction)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Ring Gauge

struct RingGauge: View {
    let value: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let label: String
    var sublabel: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(value, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * min(value, 1.0))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: value)
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: size * 0.11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Premium Header Bar

struct ViewHeader<Trailing: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    @ViewBuilder let trailing: () -> Trailing

    init(icon: String, title: String, iconColor: Color = MacMartinColors.accent, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.title3.bold())
                Spacer()
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(MacMartinColors.headerGradient)
            Divider()
        }
    }
}
