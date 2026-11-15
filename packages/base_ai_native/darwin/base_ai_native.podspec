# CocoaPods fallback. LiteRT-LM and Desert Ant ship as Swift packages only, so
# under CocoaPods the bridges compile without them and report the engines as
# unavailable. Swift Package Manager (Package.swift) is what real builds use.
Pod::Spec.new do |s|
  s.name             = 'base_ai_native'
  s.version          = '1.0.0'
  s.summary          = 'Native LiteRT-LM and Desert Ant bridges for iOS and macOS.'
  s.homepage         = 'https://github.com/Shashank2577/baseApp'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Base platform' => 'dev@baseplatform.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'base_ai_native/Sources/base_ai_native/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '18.0'
  s.osx.deployment_target = '14.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
