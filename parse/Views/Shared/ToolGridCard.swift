import SwiftUI

struct ToolGridCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isComingSoon: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                // 将 arrow.up.right 替换为 chevron.right.circle.fill，显得更精致和柔和
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.3))
            }
            
            Spacer(minLength: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isComingSoon ? AppColors.textSecondary : .white)
                
                if isComingSoon {
                    Text("即将推出")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                } else {
                    Text(description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 136) // 稍微增加高度以容纳两行说明文字
        .background(
            ZStack {
                AppColors.cardBackground
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
