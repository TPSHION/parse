import SwiftUI
import PhotosUI

struct DocumentToolDetailView: View {
    let toolType: DocumentToolType
    
    @State private var isFileImporterPresented = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            LinearGradient(
                colors: [AppColors.accentPurple.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
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
                                .fill(AppColors.accentPurple.opacity(0.18))
                                .frame(width: 180, height: 180)
                                .blur(radius: 10)
                                .offset(x: 90, y: -40)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("Document Lab", systemImage: toolType.iconName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppColors.accentPurple)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppColors.accentPurple.opacity(0.12))
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(toolType.localizedTitle)
                                        .font(.system(size: 28, weight: .heavy))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(toolType.description)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(22)
                        }
                        
                        HStack(spacing: 12) {
                            featureChip(icon: "bolt.fill", text: AppLocalizer.localized("本地处理"))
                            featureChip(icon: "lock.fill", text: AppLocalizer.localized("隐私安全"))
                            featureChip(icon: "sparkles", text: AppLocalizer.localized("高保真"))
                        }
                    }
                    
                    VStack(spacing: 14) {
                        if toolType == .pdfToWord {
                            NavigationLink(destination: PDFConverterView()) {
                                actionCard(
                                    icon: "doc.text.viewfinder",
                                    title: AppLocalizer.localized("进入 PDF 转换工具"),
                                    detail: AppLocalizer.localized("支持转为 DOCX, TXT, MD, PNG, JPEG"),
                                    accent: AppColors.accentPurple,
                                    filled: true
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            // 针对不同的工具类型，显示不同的导入选项
                            if toolType == .imageToText || toolType == .imageToDoc {
                                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                                    actionCard(
                                        icon: "photo.stack.fill",
                                        title: AppLocalizer.localized("从相册导入"),
                                        detail: AppLocalizer.localized("适合批量挑选近期拍摄或已保存的图片"),
                                        accent: AppColors.accentPurple,
                                        filled: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if toolType == .textWebConvert {
                                Button(action: {
                                    // 网页转PDF/文字操作
                                }) {
                                    actionCard(
                                        icon: "link",
                                        title: AppLocalizer.localized("输入网址"),
                                        detail: AppLocalizer.localized("直接输入网页链接提取内容或转为 PDF"),
                                        accent: AppColors.accentPurple,
                                        filled: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: {
                                isFileImporterPresented = true
                            }) {
                                actionCard(
                                    icon: "folder.fill.badge.plus",
                                    title: AppLocalizer.localized("从文件导入"),
                                    detail: AppLocalizer.localized("支持从 iCloud Drive 或本地目录选择文件"),
                                    accent: toolType == .pdfToWord || toolType == .ebookConvert ? AppColors.accentPurple : AppColors.accentBlue,
                                    filled: toolType == .pdfToWord || toolType == .ebookConvert
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(toolType.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    NavigationStack {
        DocumentToolDetailView(toolType: .pdfToWord)
    }
}
