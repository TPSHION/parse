source 'https://cdn.cocoapods.org/'

platform :ios, '18.6'

target 'parse' do
  use_frameworks!

  # Pinned to an LGPL-licensed community-maintained podspec to avoid GPL-enabled forks.
  pod 'ffmpeg-kit-ios-full', :podspec => 'Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json'
  pod 'GCDWebServer/WebUploader', '~> 3.0'
  pod 'ZIPFoundation', '~> 0.9.20'
end

post_install do |installer|
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
      config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
    end
  end
  project.save
end
