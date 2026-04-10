import SwiftUI

struct SettingsHomeView: View {
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage: String = AppLanguage.automaticValue
    
    @State private var cacheSize: String = "..."
    @State private var isClearingCache: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppShellBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        preferencesSection
                        storageSection
                        supportSection
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                calculateCache()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalizer.localized("Parse 设置"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.accentPurple)
                .textCase(.uppercase)
                .tracking(1.5)
            
            Text(AppLocalizer.localized("设置"))
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)
            
            Text(AppLocalizer.localized("管理语言、偏好设置和缓存数据。"))
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 10)
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
}
