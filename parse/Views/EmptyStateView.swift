import SwiftUI
import PhotosUI

struct EmptyStateView: View {
    @Binding var isFileImporterPresented: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(AppColors.accentBlue)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("开始转换图片")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("支持多张图片同时转换为 JPEG、PNG 或 HEIC 格式")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.title3)
                        Text("从相册选择")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    isFileImporterPresented = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.title3)
                        Text("从文件夹选择")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.cardBackground)
                    .foregroundColor(AppColors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.secondaryBackground, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            
            Spacer()
            Spacer()
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
    }
}
