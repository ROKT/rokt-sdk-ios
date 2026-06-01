Pod::Spec.new do |s|
  s.name             = 'RoktUXHelper'
  s.version          = '0.10.12'
  s.summary          = 'UX helper library for the Rokt SDK ecosystem.'
  s.swift_version    = '5.9'

  s.description      = <<-DESC
  Provides UI components, layout transformation, and rendering for the
  Dynamically Composable User Interface (DCUI) used across Rokt SDKs.
                       DESC

  s.homepage         = 'https://github.com/ROKT/rokt-ux-helper-ios'
  s.license          = { :type => 'Rokt SDK Terms of Use 2.0', :file => 'LICENSE.md' }
  s.author           = { 'Rokt' => 'nativeappsdev@rokt.com' }
  s.source           = { :git => 'https://github.com/ROKT/rokt-ux-helper-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files     = 'Sources/RoktUXHelper/**/*.swift'
  s.resource_bundles = { 'RoktUXHelper' => ['Sources/RoktUXHelper/PrivacyInfo.xcprivacy'] }
  s.frameworks       = 'Foundation', 'UIKit', 'SwiftUI', 'Combine'

  s.dependency 'DcuiSchema', '~> 2.6'
end
