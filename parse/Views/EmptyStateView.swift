import SwiftUI
import PhotosUI

struct EmptyStateView: View {
    @Binding var isFileImporterPresented: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    let onImportFromLink: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.cardBackground, Color.black.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 220)
                        
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.18))
                            .frame(width: 180, height: 180)
                            .blur(radius: 10)
                            .offset(x: 90, y: -40)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Image Lab", systemImage: "photo.on.rectangle.angled")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.accentBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.accentBlue.opacity(0.12))
                                    .clipShape(Capsule())
                                Spacer()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppLocalizer.localized("开始图片格式转换"))
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(AppLocalizer.localized("支持从相册、文件或链接导入图片，统一转换为 JPEG、PNG、HEIC 或 TIFF。"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(22)
                    }
                    
                    HStack(spacing: 12) {
                        featureChip(icon: "bolt.fill", text: AppLocalizer.localized("本地处理"))
                        featureChip(icon: "square.stack.3d.up.fill", text: AppLocalizer.localized("批量导入"))
                        featureChip(icon: "sparkles", text: AppLocalizer.localized("原画质导出"))
                    }
                }
                
                VStack(spacing: 14) {
                    PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                        actionCard(
                            icon: "photo.stack.fill",
                            title: AppLocalizer.localized("从相册导入"),
                            detail: AppLocalizer.localized("适合批量挑选近期拍摄或已保存的图片"),
                            accent: AppColors.accentBlue,
                            filled: true
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        isFileImporterPresented = true
                    }) {
                        actionCard(
                            icon: "folder.fill.badge.plus",
                            title: AppLocalizer.localized("从文件导入"),
                            detail: AppLocalizer.localized("支持从 iCloud Drive 或本地目录选择图片文件"),
                            accent: AppColors.accentGreen,
                            filled: false
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onImportFromLink) {
                        actionCard(
                            icon: "link",
                            title: AppLocalizer.localized("从链接导入"),
                            detail: AppLocalizer.localized("粘贴公开图片链接，先识别真实格式和尺寸，再确认导入"),
                            accent: AppColors.accentOrange,
                            filled: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
    }
    
    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
    }
    
    private func actionCard(icon: String, title: String, detail: String, accent: Color, filled: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? accent.opacity(0.18) : AppColors.secondaryBackground.opacity(0.35))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(filled ? .white : accent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(filled ? .white : AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(filled ? Color.white.opacity(0.86) : AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(filled ? Color.white.opacity(0.78) : AppColors.textSecondary.opacity(0.6))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(filled ? accent.opacity(0.92) : AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(filled ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
        )
        .foregroundColor(filled ? .white : AppColors.textPrimary)
        .shadow(color: filled ? accent.opacity(0.18) : Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}
