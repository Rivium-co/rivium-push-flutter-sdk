Pod::Spec.new do |s|
  s.name             = 'rivium_push'
  s.version          = '0.1.26'
  s.summary          = 'Rivium Push notification plugin for Flutter'
  s.description      = 'Real-time push notifications, in-app messages, inbox, A/B testing, and more for Flutter apps'
  s.homepage         = 'https://rivium.co/cloud/rivium-push'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Rivium' => 'support@rivium.co' }
  s.source           = { :path => '.' }

  s.source_files     = 'rivium_push/Sources/rivium_push/**/*.swift', 'rivium_push/Sources/rivium_push_objc/**/*.{h,m}'
  s.public_header_files = 'rivium_push/Sources/rivium_push_objc/include/**/*.h'

  s.dependency 'Flutter'
  # Rivium Push iOS SDK (published on CocoaPods)
  s.dependency 'RiviumPushSDK', '~> 0.1.18'

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'UIKit', 'UserNotifications', 'PushKit', 'CallKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
