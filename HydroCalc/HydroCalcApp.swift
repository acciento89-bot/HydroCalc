import SwiftUI

@main
struct HydroCalcApp: App {
    @StateObject private var proStore = ProStore()
    @StateObject private var projectStore = ProjectStore()
    @AppStorage("appLanguage") private var appLanguage = "system"

    private var locale: Locale {
        switch appLanguage {
        case "de": return Locale(identifier: "de")
        case "en": return Locale(identifier: "en")
        default: return .autoupdatingCurrent
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(proStore)
                .environmentObject(projectStore)
                .environment(\.locale, locale)
        }
    }
}
