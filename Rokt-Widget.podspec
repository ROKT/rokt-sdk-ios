#
# Be sure to run `pod lib lint rokt.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Rokt-Widget'
  s.version          = '4.9.2'
  s.summary          = 'Rokt Mobile SDK to integrate ROKT Api into iOS application'
  s.swift_version    = '6.0'

  s.description      = <<-DESC
  Rokt Mobile SDK to integrate ROKT Api into iOS application. Available in cocoa pod.
                       DESC

  s.homepage = 'https://docs.rokt.com/docs/sdk/ios/overview.html'
  s.license          = { :type => 'Copyright 2020 Rokt Pte Ltd', :text=> '<<-DESC
      Licensed under the Rokt Software Development Kit (SDK) Terms of Use
      Version 2.0 (the "License");
      You may not use this file except in compliance with the License.
      You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/
      DESC' }
  s.author           = { 'ROKT DEV' => 'nativeappsdev@rokt.com' }
  s.source           = { :http => 'https://github.com/ROKT/rokt-sdk-ios/releases/download/' + s.version.to_s + '/Rokt_Widget.xcframework.zip' }

  s.ios.deployment_target = '12.0'
  s.ios.vendored_frameworks = 'Rokt_Widget.xcframework'

end
