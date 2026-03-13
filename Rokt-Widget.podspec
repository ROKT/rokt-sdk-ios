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
  s.source           = { :http => 'https://github.com/ROKT/rokt-sdk-ios/releases/download/' + s.version.to_s + '/Rokt_Widget.xcframework.zip' }

  s.ios.deployment_target = '15.0'
  s.ios.vendored_frameworks = 'Rokt_Widget.xcframework'
end
