import SwiftUI

struct SaveActionSheetView: View {
    let shareableURLs: [URL]
    let onSaveToAlbum: (() -> Void)? // 设为可选，如果为 nil 则不显示“保存到相册”选项
    let onSaveToFile: () -> Void
    let onOpenTransferGuide: (() -> Void)?
    @State private var isShareSheetPresented = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(AppLocalizer.localized("选择操作方式"))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 10)
            
            VStack(spacing: 12) {
                if !shareableURLs.isEmpty {
                    Button {
                        isShareSheetPresented = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text(AppLocalizer.localized("分享文件"))
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                if let onSaveToAlbum = onSaveToAlbum {
                    Button(action: onSaveToAlbum) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20))
                            Text(AppLocalizer.localized("保存到相册"))
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onSaveToFile) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                        Text(AppLocalizer.localized("保存为文件"))
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if let onOpenTransferGuide = onOpenTransferGuide {
                    Button(action: onOpenTransferGuide) {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppLocalizer.localized("网页下载"))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppLocalizer.localized("开启传输后，可在网页结果页下载"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityShareSheet(items: shareableURLs)
        }
    }
}
