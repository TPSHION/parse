import SwiftUI

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // 图标背景的微发光效果
                Circle()
                    .fill(LinearGradient(
                        colors: [color.opacity(0.4), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
        }
        .padding(20)
        .background(
            ZStack {
                AppColors.cardBackground
                // 微弱的渐变覆盖增加质感
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ContentView: View {
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 更具层次感的深色背景
                LinearGradient(
                    colors: [AppColors.background, Color(hex: "#050B14")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 顶部氛围光晕
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -100, y: -250)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 欢迎文案区
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome to Parse")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.accentBlue)
                                .textCase(.uppercase)
                                .tracking(1.5)
                            
                            Text("超级转换工具箱")
                                .font(.system(size: 32, weight: .heavy))
                                .foregroundColor(.white)
                            
                            Text("本地处理，安全高效，极简体验。")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 4)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        
                        // 图片格式转换入口
                        NavigationLink(destination: ImageConverterView()) {
                            FeatureCard(
                                icon: "photo.badge.arrow.down.fill",
                                title: "图片格式转换",
                                description: "支持极速批量转换 JPEG, PNG, HEIC, TIFF",
                                color: AppColors.accentBlue
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        
                        // 视频格式转换入口
                        NavigationLink(destination: VideoConverterView()) {
                            FeatureCard(
                                icon: "video.fill.badge.ellipsis",
                                title: "视频格式转换",
                                description: "支持 MP4, MOV, GIF, AVI, MKV 等格式互转",
                                color: AppColors.accentGreen
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 40)
                        
                        // 媒体压缩入口 (敬请期待)
                        FeatureCard(
                            icon: "arrow.down.right.and.arrow.up.left.circle.fill",
                            title: "媒体智能压缩",
                            description: "即将支持自定义分辨率和码率，智能缩减文件体积",
                            color: .orange
                        )
                        .opacity(appearAnimation ? 0.6 : 0)
                        .offset(y: appearAnimation ? 0 : 50)
                        .overlay(alignment: .topTrailing) {
                            Text("COMING SOON")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.orange.opacity(0.3), radius: 5, x: 0, y: 2)
                                .offset(x: -16, y: 16)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
