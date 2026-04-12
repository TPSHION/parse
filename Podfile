source 'https://github.com/readium/podspecs'
source 'https://cdn.cocoapods.org/'
require 'fileutils'

platform :ios, '18.6'

target 'parse' do
  use_frameworks!

  pod 'ffmpeg-kit-ios-full', :podspec => 'https://raw.githubusercontent.com/luthviar/ffmpeg-kit-ios-full/main/ffmpeg-kit-ios-full.podspec'
  pod 'GCDWebServer/WebUploader', '~> 3.0'
  pod 'ZIPFoundation', '~> 0.9.20'
  pod 'ReadiumShared', '~> 3.5.0'
  pod 'ReadiumStreamer', '~> 3.5.0'
  pod 'ReadiumNavigator', '~> 3.5.0'
end

post_install do |installer|
  def patch_readium_bundle_lookup(path, bundle_name)
    content = File.read(path)
    owner_class = case bundle_name
                  when 'ReadiumNavigator' then 'EPUBNavigatorViewController'
                  when 'ReadiumShared' then 'Publication'
                  else 'PublicationOpener'
                  end
    pattern = %r{
                let\ rootBundle\ =\ Bundle\(for:\ #{owner_class}\.self\)\s+
                guard\ let\ resourceBundleUrl\ =\ rootBundle\.url\(forResource:\ "#{bundle_name}",\ withExtension:\ "bundle"\)\ else\ \{\s+
                    fatalError\("Unable\ to\ locate\ #{bundle_name}\.bundle"\)\s+
                \}\s+
                guard\ let\ bundle\ =\ Bundle\(url:\ resourceBundleUrl\)\ else\ \{\s+
                    fatalError\("Unable\ to\ load\ #{bundle_name}\.bundle"\)\s+
                \}\s+

                return\ bundle
              }mx
    replacement = <<~SWIFT.chomp
                let rootBundle = Bundle(for: #{owner_class}.self)
                let candidateURLs = [
                    rootBundle.url(forResource: "#{bundle_name}", withExtension: "bundle"),
                    Bundle.main.url(forResource: "#{bundle_name}", withExtension: "bundle"),
                ]

                guard let resourceBundleURL = candidateURLs.compactMap({ $0 }).first else {
                    fatalError("Unable to locate #{bundle_name}.bundle")
                }
                guard let bundle = Bundle(url: resourceBundleURL) else {
                    fatalError("Unable to load #{bundle_name}.bundle")
                }

                return bundle
    SWIFT

    patched = content.sub(pattern, replacement)
    if patched != content
      FileUtils.chmod('u+w', path)
      File.write(path, patched)
    end
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.6'
    end
  end
  
  project_path = 'parse.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
    end
  end
  project.save

  patch_readium_bundle_lookup('Pods/ReadiumNavigator/Sources/Navigator/Toolkit/Extensions/Bundle.swift', 'ReadiumNavigator')
  patch_readium_bundle_lookup('Pods/ReadiumShared/Sources/Shared/Toolkit/Extensions/Bundle.swift', 'ReadiumShared')
  patch_readium_bundle_lookup('Pods/ReadiumStreamer/Sources/Streamer/Toolkit/Extensions/Bundle.swift', 'ReadiumStreamer')
end
