//
//  parseApp.swift
//  parse
//
//  Created by chen on 2026/4/7.
//

import SwiftUI

@main
struct parseApp: App {
    @State private var router = RouterManager.shared
    @State private var tabRouter = TabRouter.shared
    @State private var purchaseManager = PurchaseManager.shared
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.automaticValue

    private var appLanguage: AppLanguage {
        AppLanguage.effective(from: appLanguageRawValue)
    }

    var body: some Scene {
        WindowGroup {
            @Bindable var bindableRouter = router

            NavigationStack(path: $bindableRouter.path) {
                ContentView()
                    .preferredColorScheme(.dark)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .imageConverter:
                            ImageConverterView()
                        case .videoConverter:
                            VideoConverterView()
                        case .audioConverter:
                            AudioConverterView()
                        case .mediaCompressor:
                            MediaCompressorView()
                        case .pdfConverter:
                            PDFConverterView()
                        case .documentTool(let toolType):
                            DocumentToolDetailView(toolType: toolType)
                        }
                    }
            }
            .environment(\.locale, appLanguage.locale)
            .environment(router)
            .environment(tabRouter)
            .environment(purchaseManager)
        }
    }
}
