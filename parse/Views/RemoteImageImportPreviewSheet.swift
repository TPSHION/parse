import SwiftUI

struct RemoteImageImportPreviewSheet: View {
    let preview: RemoteImageImportPreview
    let onImport: () -> Void
    let onCancel: () -> Void
    
    @State private var isLargeFileAlertPresented = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    previewPanel
                    infoContent
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)

                HStack(spacing: 12) {
                    Button("取消") {
                        onCancel()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    Button(action: handleImport) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("导入列表")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("导入确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .interactiveDismissDisabled()
        .alert("继续导入大图片？", isPresented: $isLargeFileAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("继续导入") {
                onImport()
            }
        } message: {
            Text("当前图片大小约为 \(preview.fileSizeText)，导入后会占用更多空间，并可能增加后续转换耗时。")
        }
    }
    
    private var previewPanel: some View {
        Group {
            if let image = preview.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.secondaryBackground.opacity(0.5))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if preview.requiresLargeFileConfirmation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.accentOrange)
                    
                    Text("图片较大，导入和转换可能更慢。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.accentOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accentOrange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.accentOrange.opacity(0.3), lineWidth: 1)
                )
            }
            
            VStack(spacing: 10) {
                // Filename as prominent header
                Text(preview.displayFilename)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Badges for specs
                VStack(alignment: .leading, spacing: 8) {
                    infoBadge(icon: "photo.fill", text: "格式：\(preview.detectedFormat)", color: AppColors.accentBlue)
                    infoBadge(icon: "ruler.fill", text: "尺寸：\(preview.dimensionsText)", color: AppColors.textSecondary)
                    infoBadge(icon: "externaldrive.fill", text: "大小：\(preview.fileSizeText)", color: AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
    
    private func infoBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 14) // 强制对齐图标
            Text(text)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func handleImport() {
        if preview.requiresLargeFileConfirmation {
            isLargeFileAlertPresented = true
        } else {
            onImport()
        }
    }
}
