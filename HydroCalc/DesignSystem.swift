import SwiftUI

struct AppTheme {
    static let accent = Color(red: 0.10, green: 0.72, blue: 0.76)
    static let accentDeep = Color(red: 0.05, green: 0.38, blue: 0.48)
    static let water = Color(red: 0.18, green: 0.57, blue: 0.90)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)

    static let gradient = LinearGradient(
        colors: [accentDeep, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct HydroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

extension View {
    func hydroCard() -> some View {
        modifier(HydroCardModifier())
    }
}

struct HydroMark: View {
    var size: CGFloat = 46
    var badge = false

    var body: some View {
        ZStack {
            if badge {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(AppTheme.gradient)
                    .frame(width: size, height: size)
            }

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                    .stroke(Color.white.opacity(badge ? 0.95 : 0.85), lineWidth: size * 0.10)
                    .frame(width: size * 0.62, height: size * 0.54)

                Image(systemName: "arrow.right")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(badge ? Color.white : AppTheme.accent)
                    .offset(y: -size * 0.17)

                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.25, weight: .semibold))
                    .foregroundStyle(badge ? Color.white : AppTheme.water)
                    .offset(y: size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct NumberField: View {
    let title: LocalizedStringKey
    let unit: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80, maxWidth: 130)
                .textFieldStyle(.roundedBorder)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .leading)
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.accent.opacity(0.16))
            .foregroundStyle(AppTheme.accent)
            .clipShape(Capsule())
    }
}
