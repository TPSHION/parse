//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

#if !SWIFT_PACKAGE
    extension Bundle {
        #if !COCOAPODS
            /// Returns ReadiumStreamer's bundle by querying an arbitrary type.
            static let module = Bundle(for: PublicationOpener.self)
        #else
            /// Returns ReadiumStreamer's bundle by querying for the cocoapods bundle.
            static let module = Bundle.getCocoaPodsBundle()
            static func getCocoaPodsBundle() -> Bundle {
                let rootBundle = Bundle(for: PublicationOpener.self)
let candidateURLs = [
    rootBundle.url(forResource: "ReadiumStreamer", withExtension: "bundle"),
    Bundle.main.url(forResource: "ReadiumStreamer", withExtension: "bundle"),
]

guard let resourceBundleURL = candidateURLs.compactMap({ $0 }).first else {
    fatalError("Unable to locate ReadiumStreamer.bundle")
}
guard let bundle = Bundle(url: resourceBundleURL) else {
    fatalError("Unable to load ReadiumStreamer.bundle")
}

return bundle
            }
        #endif
    }
#endif
