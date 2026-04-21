Pod::Spec.new do |s|
  s.name             = 'Rokt-Widget'
  s.version          = '5.0.0'
  s.summary          = 'Rokt Mobile SDK for iOS'
  s.swift_version    = '5.9'

  s.description      = <<-DESC
  Rokt Mobile SDK to integrate Rokt into your iOS application.
                       DESC

  s.homepage         = 'https://docs.rokt.com'
  s.license          = { :type => 'Rokt SDK Terms of Use 2.0', :file => 'LICENSE' }
  s.author           = { 'ROKT DEV' => 'nativeappsdev@rokt.com' }
  s.source           = { :git => 'https://github.com/ROKT/rokt-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files     = 'Sources/Rokt_Widget/**/*.swift'
  s.resource_bundles = { 'Rokt_Widget' => ['Sources/Rokt_Widget/PrivacyInfo.xcprivacy'] }
  s.frameworks       = 'Foundation', 'UIKit', 'SwiftUI', 'Combine'

  s.dependency 'RoktContracts', '~> 1.0'
  s.dependency 'RoktUXHelper', '~> 0.10'
end
