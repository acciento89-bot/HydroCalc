import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var proStore: ProStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.language") {
                    Picker("settings.language", selection: $appLanguage) {
                        Text("settings.language.system").tag("system")
                        Text("Deutsch").tag("de")
                        Text("English").tag("en")
                    }
                }

                Section("settings.pro") {
                    HStack {
                        Text("settings.status")
                        Spacer()
                        Text(proStore.isPro ? "settings.pro.active" : "settings.pro.free")
                            .foregroundStyle(proStore.isPro ? AppTheme.accent : .secondary)
                    }

                    if !proStore.isPro {
                        Button("pro.buy") {
                            showPaywall = true
                        }
                    }

                    Button("pro.restore") {
                        Task { await proStore.restore() }
                    }
                }

                Section("settings.links") {
                    Link("settings.support", destination: URL(string: "https://kamilunavo.com/support")!)
                    Link("settings.privacy", destination: URL(string: "https://kamilunavo.com/hydrocalc/privacy")!)
                }

                Section("settings.about") {
                    LabeledContent("settings.version", value: "1.0.0 (1)")
                    LabeledContent("settings.developer", value: "Kamilunavo")
                }

                Section {
                    Text("common.disclaimer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
                    .environmentObject(proStore)
            }
        }
        .tint(AppTheme.accent)
    }
}
