import Foundation
import StoreKit

@MainActor
final class ProStore: ObservableObject {
    static let productID = "de.kamilunavo.hydrocalc.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
            await updateEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else {
            await refresh()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await updateEntitlement()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func updateEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            if transaction.productID == Self.productID && transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
