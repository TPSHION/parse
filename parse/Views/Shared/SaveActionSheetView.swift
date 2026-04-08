import SwiftUI

struct SaveActionSheetView: View {
    let shareableURLs: [URL]
    let onSaveToAlbum: () -> Void
    let onSaveToFile: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择操作方式")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 10)
            
            VStack(spacing: 12) {
                if !shareableURLs.isEmpty {
                    ShareLink(items: shareableURLs) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text("分享文件")
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
                
                Button(action: onSaveToAlbum) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                        Text("保存到相册")
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
                
                Button(action: onSaveToFile) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                        Text("保存为文件")
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
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}
