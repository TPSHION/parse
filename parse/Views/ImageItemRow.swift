import SwiftUI

struct ImageItemRow: View {
    let item: ImageItem
    let onFormatChange: (ImageFormat) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(uiImage: item.originalImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.originalName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 原始格式标签
                    Text(item.originalFormat)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.secondaryBackground)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    
                    Picker("Format", selection: Binding(
                        get: { item.targetFormat },
                        set: { onFormatChange($0) }
                    )) {
                        ForEach(ImageFormat.allCases) { format in
                            Text(format.rawValue)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.accentBlue)
                    .font(.system(size: 10, weight: .bold))
                    .fixedSize() // 防止文字因为空间挤压而竖向换行
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                statusView(for: item.status)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func statusView(for status: ImageItem.ConversionStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textSecondary)
        case .converting:
            ProgressView()
                .tint(AppColors.accentBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.accentGreen)
        case .failed(let error):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.accentRed)
                .help(error)
        }
    }
}
