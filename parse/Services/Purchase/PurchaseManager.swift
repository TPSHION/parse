import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private static let trialStartKey = "purchase_trial_start_date"
    private static let localUnlockKey = "purchase_local_unlock"
    private static let lifetimeProductID = "cn.tpshion.parse.lifetime"
    private static let trialDuration: TimeInterval = 15 * 24 * 60 * 60
    #if DEBUG
    private static let debugExpireTrialArgument = "-debug-expire-trial"
    private static let debugResetTrialArgument = "-debug-reset-trial"
    private static let debugIgnoreEntitlementsArgument = "-debug-ignore-purchase-entitlements"
    #endif

    private(set) var lifetimeProduct: Product?
    private(set) var hasUnlockedLifetime: Bool
    private(set) var hasPrepared = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var trialStartDate: Date
    var lastErrorMessage: String?

    private init() {
        trialStartDate = Self.loadOrCreateTrialStartDate()
        hasUnlockedLifetime = UserDefaults.standard.bool(forKey: Self.localUnlockKey)
    }

    var isTrialActive: Bool {
        !hasUnlockedLifetime && Date() < trialEndDate
    }

    var hasActiveAccess: Bool {
        hasUnlockedLifetime || isTrialActive
    }

    var requiresPaywall: Bool {
        !hasActiveAccess
    }

    var remainingTrialDays: Int {
        guard !hasUnlockedLifetime else { return 0 }

        let remaining = trialEndDate.timeIntervalSinceNow
        guard remaining > 0 else { return 0 }

        return max(1, Int(ceil(remaining / 86_400)))
    }

    var trialEndDate: Date {
        trialStartDate.addingTimeInterval(Self.trialDuration)
    }

    var purchasePriceText: String {
        lifetimeProduct?.displayPrice ?? AppLocalizer.localized("待获取")
    }

    var trialEndDateText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalizer.currentLanguage.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: trialEndDate)
    }

    var accessTitle: String {
        if hasUnlockedLifetime {
            return AppLocalizer.localized("已解锁完整版")
        }

        if isTrialActive {
            return AppLocalizer.formatted("免费试用剩余 %d 天", remainingTrialDays)
        }

        return AppLocalizer.localized("试用已结束")
    }

    var accessDetail: String {
        if hasUnlockedLifetime {
            return AppLocalizer.localized("已完成一次性购买，可继续使用全部功能。")
        }

        if isTrialActive {
            return AppLocalizer.localized("15 天后需一次性购买才能继续使用全部功能。")
        }

        return AppLocalizer.localized("试用期已结束，请完成一次性购买后继续使用。")
    }

    func prepareIfNeeded() async {
        if !hasPrepared {
            await loadProduct()
            hasPrepared = true
        }

        await refreshEntitlements()
    }

    func purchaseLifetime() async {
        lastErrorMessage = nil

        if lifetimeProduct == nil {
            await loadProduct()
        }

        guard let product = lifetimeProduct else {
            lastErrorMessage = AppLocalizer.localized("商品暂不可用，请稍后重试。")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = AppLocalizer.localized("购买结果未知，请稍后重试。")
                    return
                }

                persistUnlock(true)
                hasUnlockedLifetime = true
                await transaction.finish()
            case .pending:
                lastErrorMessage = AppLocalizer.localized("购买正在等待确认，请稍后再试。")
            case .userCancelled:
                break
            @unknown default:
                lastErrorMessage = AppLocalizer.localized("购买结果未知，请稍后重试。")
            }
        } catch {
            lastErrorMessage = AppLocalizer.formatted("购买失败：%@", error.localizedDescription)
        }
    }

    func restorePurchases() async {
        lastErrorMessage = nil
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()

            if !hasUnlockedLifetime {
                lastErrorMessage = AppLocalizer.localized("未找到可恢复的购买记录。")
            }
        } catch {
            lastErrorMessage = AppLocalizer.formatted("恢复购买失败：%@", error.localizedDescription)
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func canUseCoreFeatures() async -> Bool {
        await prepareIfNeeded()
        return hasActiveAccess
    }

    private func loadProduct() async {
        do {
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
        } catch {
            lifetimeProduct = nil
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.debugIgnoreEntitlementsArgument) {
            persistUnlock(false)
            hasUnlockedLifetime = false
            return
        }
        #endif

        var isUnlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                isUnlocked = true
                break
            }
        }

        persistUnlock(isUnlocked)
        hasUnlockedLifetime = isUnlocked
    }

    private func persistUnlock(_ isUnlocked: Bool) {
        UserDefaults.standard.set(isUnlocked, forKey: Self.localUnlockKey)
    }

    private static func loadOrCreateTrialStartDate() -> Date {
        let defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(debugResetTrialArgument) {
            let now = Date()
            defaults.set(now, forKey: trialStartKey)
            defaults.set(false, forKey: localUnlockKey)
            return now
        }

        if ProcessInfo.processInfo.arguments.contains(debugExpireTrialArgument) {
            let expiredDate = Date().addingTimeInterval(-(trialDuration + 60))
            defaults.set(expiredDate, forKey: trialStartKey)
            defaults.set(false, forKey: localUnlockKey)
            return expiredDate
        }
        #endif

        if let storedDate = defaults.object(forKey: trialStartKey) as? Date {
            return storedDate
        }

        let now = Date()
        defaults.set(now, forKey: trialStartKey)
        return now
    }
}
