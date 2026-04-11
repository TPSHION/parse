import SwiftUI

struct TrialPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager
    var allowsDismissal = false

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if allowsDismissal {
                        dismissButtonRow
                    }

                    headerSection
                    featureSection
                    pricingSection

                    if let errorMessage = purchaseManager.lastErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(AppColors.accentRed)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.cardBackground.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    actionSection
                }
                .padding(24)
                .padding(.top, allowsDismissal ? 0 : 24)
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled(!allowsDismissal)
        .task {
            await purchaseManager.prepareIfNeeded()
        }
        .onChange(of: purchaseManager.hasActiveAccess) { _, hasAccess in
            if allowsDismissal && hasAccess {
                dismiss()
            }
        }
    }

    private var dismissButtonRow: some View {
        HStack {
            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground.opacity(0.92))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.accentOrange)

                Text(AppLocalizer.localized("终身解锁"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.accentOrange)
                    .textCase(.uppercase)
                    .tracking(1.4)
            }

            Text(AppLocalizer.localized("15 天免费试用已结束"))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)

            Text(AppLocalizer.localized("完成一次性购买后，即可继续使用全部转换、压缩与传输能力。"))
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(
                icon: "sparkles",
                title: AppLocalizer.localized("全部转换与压缩工具"),
                detail: AppLocalizer.localized("图片、视频、音频与文档工具全部可用。")
            )
            featureRow(
                icon: "paperplane.circle.fill",
                title: AppLocalizer.localized("局域网传输与结果管理"),
                detail: AppLocalizer.localized("继续使用网页传输、结果下载与批量管理。")
            )
            featureRow(
                icon: "lock.shield.fill",
                title: AppLocalizer.localized("一次买断，无订阅"),
                detail: AppLocalizer.localized("本地处理体验保持不变，无需持续订阅。")
            )
        }
        .padding(18)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.localized("当前价格"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)

                    Text(purchaseManager.purchasePriceText)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(AppLocalizer.localized("一次买断"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.accentGreen.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(AppLocalizer.formatted("试用截止 %@", purchaseManager.trialEndDateText))
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(18)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchaseManager.purchaseLifetime()
                }
            } label: {
                HStack {
                    Spacer()
                    if purchaseManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(AppLocalizer.localized("一次性购买"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(AppColors.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)

            Button {
                Task {
                    await purchaseManager.restorePurchases()
                }
            } label: {
                HStack {
                    Spacer()
                    if purchaseManager.isRestoring {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(AppLocalizer.localized("恢复购买"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(AppColors.cardBackground.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    TrialPaywallView()
        .environment(PurchaseManager.shared)
}
