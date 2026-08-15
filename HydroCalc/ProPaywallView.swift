import SwiftUI
import Foundation

struct ProPaywallView: View {
    @EnvironmentObject private var proStore: ProStore
    @Environment(\.dismiss) private var dismiss

    private var purchaseTitle: String {
        if let product = proStore.product {
            return String(format: String(localized: "pro.buy.price"), product.displayPrice)
        }
        return String(localized: "pro.buy")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HydroMark(size: 86, badge: true)

                    VStack(spacing: 8) {
                        Text("pro.title")
                            .font(.largeTitle.bold())
                        Text("pro.subtitle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        feature("drop.circle.fill", "pro.feature.pipe")
                        feature("slider.horizontal.3", "pro.feature.kv")
                        feature("lock.open.fill", "pro.feature.once")
                    }
                    .hydroCard()

                    Button {
                        Task { await proStore.purchase() }
                    } label: {
                        HStack {
                            if proStore.isLoading { ProgressView().tint(.white) }
                            Text(purchaseTitle)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(proStore.isLoading)

                    Button("pro.restore") {
                        Task { await proStore.restore() }
                    }
                    .disabled(proStore.isLoading)

                    if let error = proStore.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("pro.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
        }
        .tint(AppTheme.accent)
        .onChange(of: proStore.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)
        }
    }
}
