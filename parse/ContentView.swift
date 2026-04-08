import SwiftUI

struct ContentView: View {
    @State private var appearAnimation = false
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
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
                
                // 顶部氛围光晕 (混合蓝色和紫色)
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -150, y: -250)
                    
                Circle()
                    .fill(AppColors.accentPurple.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: 150, y: -100)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
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
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        
                        // 媒体处理分类
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(title: "媒体处理", icon: "photo.on.rectangle.angled", color: AppColors.accentBlue)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                NavigationLink(destination: ImageConverterView()) {
                                    ToolGridCard(icon: "photo.badge.arrow.down.fill", title: "图片转换", description: "极速批量转换主流图片格式", color: AppColors.accentBlue)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: VideoConverterView()) {
                                    ToolGridCard(icon: "video.fill.badge.ellipsis", title: "视频转换", description: "高效互转 MP4, MOV, GIF, AVI, MKV 等格式", color: AppColors.accentGreen)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: AudioConverterView()) {
                                    ToolGridCard(icon: "waveform.circle.fill", title: "音频转换", description: "提取音频，或互转 MP3, WAV, M4A 等", color: AppColors.accentOrange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        
                        // 文档处理分类
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(title: "文档处理", icon: "doc.on.doc.fill", color: AppColors.accentPurple)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                NavigationLink(destination: PDFConverterView()) {
                                    ToolGridCard(icon: "doc.text.viewfinder", title: "PDF 转换", description: "支持转为 DOCX, TXT, MD, PNG 等", color: AppColors.accentPurple)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: DocumentToolDetailView(toolType: .imageToText)) {
                                    ToolGridCard(icon: "text.viewfinder", title: "图片转文字", description: "精准提取图片中的文字内容", color: AppColors.accentPurple)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: DocumentToolDetailView(toolType: .ebookConvert)) {
                                    ToolGridCard(icon: "book.closed.fill", title: "电子书转换", description: "EPUB, MOBI 等格式完美互转", color: AppColors.accentPurple)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: DocumentToolDetailView(toolType: .textWebConvert)) {
                                    ToolGridCard(icon: "network", title: "网页转文档", description: "输入链接一键生成 PDF", color: AppColors.accentPurple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 40)
                    }
                    .padding(24)
                    .padding(.bottom, 40)
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
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ContentView()
}
