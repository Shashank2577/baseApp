#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint base_ai_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'base_ai_native'
  s.version          = '0.0.1'
  s.summary          = 'Native LiteRT-LM and Desert Ant bridges.'
  s.description      = <<-DESC
Native LiteRT-LM and Desert Ant bridges.
                       DESC
  s.homepage         = 'https://github.com/shashank2577/baseapp'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Base platform' => 'dev@baseplatform.dev' }
  s.source           = { :path => '.' }
  # LiteRT-LM and Desert Ant ship as Swift packages only; under CocoaPods the
  # bridges compile without them and report the engines as unavailable. Use
  # Swift Package Manager (Package.swift) for real inference.
  s.source_files = 'base_ai_native/Sources/base_ai_native/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '18.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'base_ai_native_privacy' => ['base_ai_native/Sources/base_ai_native/PrivacyInfo.xcprivacy']}
end
