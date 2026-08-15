import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var proStore: ProStore
    @State private var showPaywall = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    NavigationLink {
                        FlowCalculatorView()
                    } label: {
                        HomeToolCard(
                            icon: "arrow.left.arrow.right.circle.fill",
                            title: "home.flow.title",
                            text: "home.flow.text",
                            pro: false
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PressureConverterView()
                    } label: {
                        HomeToolCard(
                            icon: "gauge.with.dots.needle.50percent",
                            title: "home.pressure.title",
                            text: "home.pressure.text",
                            pro: false
                        )
                    }
                    .buttonStyle(.plain)

                    proTool(
                        icon: "drop.circle.fill",
                        title: "home.pipe.title",
                        text: "home.pipe.text"
                    ) {
                        PipeSizingView()
                    }

                    proTool(
                        icon: "slider.horizontal.3",
                        title: "home.kv.title",
                        text: "home.kv.text"
                    ) {
                        KvCalculatorView()
                    }

                    disclaimer
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("HydroCalc")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(Text("settings.title"))
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
                    .environmentObject(proStore)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(proStore)
            }
        }
        .tint(AppTheme.accent)
    }

    private var header: some View {
        HStack(spacing: 16) {
            HydroMark(size: 58, badge: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("home.eyebrow")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("home.title")
                    .font(.title2.bold())
                Text("home.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .hydroCard()
    }

    @ViewBuilder
    private func proTool<Destination: View>(
        icon: String,
        title: LocalizedStringKey,
        text: LocalizedStringKey,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        if proStore.isPro {
            NavigationLink {
                destination()
            } label: {
                HomeToolCard(icon: icon, title: title, text: text, pro: true)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showPaywall = true
            } label: {
                HomeToolCard(icon: icon, title: title, text: text, pro: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var disclaimer: some View {
        Text("common.disclaimer")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

private struct HomeToolCard: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let pro: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    if pro { ProBadge() }
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .hydroCard()
    }
}
