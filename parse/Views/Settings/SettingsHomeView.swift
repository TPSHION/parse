import SwiftUI

struct SettingsHomeView: View {
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage: String = AppLanguage.automaticValue
    @Environment(PurchaseManager.self) private var purchaseManager
    
    @State private var cacheSize: String = "..."
    @State private var isClearingCache: Bool = false
    
    var body: some View {
        ZStack {
            AppShellBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    purchaseSection
                    preferencesSection
                    storageSection
                    supportSection
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            calculateCache()
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumAccessCard(
                purchaseManager: purchaseManager,
                onPurchase: {
                    Task {
                        await purchaseManager.purchaseLifetime()
                    }
                },
                onRestore: {
                    Task {
                        await purchaseManager.restorePurchases()
                    }
                }
            )
        }
        .task {
            await purchaseManager.prepareIfNeeded()
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.localized("偏好设置"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 24)
                    
                    Text(AppLocalizer.localized("语言切换"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Picker("", selection: $selectedLanguage) {
                        Text(AppLocalizer.localized("跟随系统")).tag(AppLanguage.automaticValue)
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    .tint(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(AppColors.cardBackground.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
    
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.localized("存储"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: clearCache) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(AppColors.accentRed)
                            .frame(width: 24)
                        
                        Text(AppLocalizer.localized("清除缓存"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isClearingCache {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(cacheSize)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isClearingCache)
            }
            .background(AppColors.cardBackground.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.localized("关于"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                NavigationLink(destination: AboutUsView()) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.accentTeal)
                            .frame(width: 24)
                        
                        Text(AppLocalizer.localized("关于我们"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 16)
                
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(AppColors.accentPurple)
                        .frame(width: 24)
                    
                    Text(AppLocalizer.localized("版本"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(appVersion)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(AppColors.cardBackground.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
    
    private func calculateCache() {
        CacheManager.shared.calculateCacheSize { size in
            self.cacheSize = size
        }
    }
    
    private func clearCache() {
        isClearingCache = true
        CacheManager.shared.clearCache {
            self.calculateCache()
            self.isClearingCache = false
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsHomeView()
        .environment(PurchaseManager.shared)
}

private struct PremiumAccessCard: View {
    let purchaseManager: PurchaseManager
    let onPurchase: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            compactSummary

            if let errorMessage = purchaseManager.lastErrorMessage, !errorMessage.isEmpty {
                messageRow(
                    text: errorMessage,
                    color: AppColors.accentRed,
                    icon: "exclamationmark.triangle.fill",
                    backgroundOpacity: 0.14
                )
            } else if purchaseManager.hasUnlockedLifetime {
                messageRow(
                    text: AppLocalizer.localized("已完成一次性购买，可继续使用全部功能。"),
                    color: AppColors.accentGreen,
                    icon: "checkmark.seal.fill",
                    backgroundOpacity: 0.16
                )
            }

            actionButtons
        }
        .padding(18)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(purchaseManager.accessTitle)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var compactSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            infoRow(
                title: AppLocalizer.localized("当前价格"),
                value: purchaseManager.hasUnlockedLifetime ? AppLocalizer.localized("已解锁") : purchaseManager.purchasePriceText
            )

            infoRow(
                title: AppLocalizer.localized("试用截止"),
                value: purchaseManager.hasUnlockedLifetime ? AppLocalizer.localized("无限制") : purchaseManager.trialEndDateText
            )
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !purchaseManager.hasUnlockedLifetime {
                Button(action: onPurchase) {
                    HStack(spacing: 10) {
                        if purchaseManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 15, weight: .semibold))

                            Text(AppLocalizer.localized("一次性购买"))
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(AppColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)

                Button(action: onRestore) {
                    HStack(spacing: 10) {
                        if purchaseManager.isRestoring {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))

                            Text(AppLocalizer.localized("恢复购买"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.cardBackground.opacity(0.98),
                    AppColors.secondaryBackground.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppColors.accentBlue.opacity(0.16))
                .frame(width: 180, height: 180)
                .blur(radius: 70)
                .offset(x: 110, y: -80)

            Circle()
                .fill(AppColors.accentOrange.opacity(0.12))
                .frame(width: 140, height: 140)
                .blur(radius: 60)
                .offset(x: -80, y: 90)
        }
    }

    private func messageRow(text: String, color: Color, icon: String, backgroundOpacity: Double) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
