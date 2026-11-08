import Foundation
import StoreKit

@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()

    /// Non-consumable In-App Purchase product identifier (configurable in App Store Connect)
    nonisolated public static let defaultProProductID = "app.zest.pro.lifetime"

    @Published public private(set) var isProUnlocked: Bool = false
    @Published public private(set) var proProduct: Product?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // Fast start from persisted cache
        self.isProUnlocked = UserDefaults.standard.bool(forKey: "zest_isProUnlocked")

        // Listen for external purchase transactions (e.g. family sharing, out-of-app purchases)
        startTransactionListener()

        Task {
            await refreshPurchaseStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    private func startTransactionListener() {
        updateListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handle(transaction: transaction)
                    await transaction.finish()
                } catch {
                    print("StoreKit Transaction update unverified: \(error)")
                }
            }
        }
    }

    /// Checks both in-app non-consumable lifetime purchases and upfront App Store purchase receipt
    public func refreshPurchaseStatus() async {
        isLoading = true
        defer { isLoading = false }

        var unlocked = false

        // 1. Check StoreKit 2 Non-Consumable In-App Entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    unlocked = true
                    break
                }
            }
        }

        // 2. Check App Store Upfront Purchase (if app is sold as a Paid App upfront)
        if !unlocked {
            do {
                let verificationResult = try await AppTransaction.shared
                if case .verified = verificationResult {
                    unlocked = true
                }
            } catch {
                // If running locally in development without receipt, retain prior state
            }
        }

        #if DEBUG
        unlocked = true
        #endif

        self.isProUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: "zest_isProUnlocked")
    }

    /// Loads the Lifetime Product from App Store Connect
    public func loadProducts(productID: String = defaultProProductID) async {
        do {
            let products = try await Product.products(for: [productID])
            self.proProduct = products.first
        } catch {
            self.errorMessage = "Failed to load product: \(error.localizedDescription)"
        }
    }

    /// Initiates the one-time purchase flow
    public func purchaseLifetime(product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await handle(transaction: transaction)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Restores prior purchases (e.g., when moving to a new Mac)
    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        try await AppStore.sync()
        await refreshPurchaseStatus()
    }

    private func handle(transaction: Transaction) async {
        if transaction.revocationDate == nil {
            isProUnlocked = true
            UserDefaults.standard.set(true, forKey: "zest_isProUnlocked")
        } else {
            isProUnlocked = false
            UserDefaults.standard.set(false, forKey: "zest_isProUnlocked")
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
