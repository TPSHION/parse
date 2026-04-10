import SwiftUI

struct AboutUsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // App Icon & Version
                VStack(spacing: 16) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(AppColors.accentBlue)
                        .padding(.top, 40)
                    
                    Text("Parse")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(AppLocalizer.localized("版本")) \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.localized("关于应用"))
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(AppLocalizer.localized("Parse 是一款专注本地处理的转换与传输工具。所有操作都在设备上完成，帮助你更安全地处理文件。"))
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(6)
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Contact
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.localized("联系我们"))
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Button {
                        if let url = URL(string: "mailto:tpshion@163.com"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("tpshion@163.com")
                                .font(.body)
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Copyright
                Text("© \(currentYear) TPSHION. \(AppLocalizer.localized("保留所有权利。"))")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationTitle(AppLocalizer.localized("关于我们"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
}

#Preview {
    AboutUsView()
}
