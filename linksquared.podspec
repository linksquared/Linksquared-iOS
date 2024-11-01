Pod::Spec.new do |s|
  s.name         = 'linksquared'
  s.version      = '1.1.14'
  s.summary      = 'Linksquared is a powerful SDK that enables deep linking and universal linking within your iOS applications.'
  s.homepage     = 'https://linksquared.io'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Linksquared' => 'support@linksquared.io' }
  s.source       = { :git => 'https://github.com/linksquared/ios-sdk.git', :tag => s.version.to_s }
  s.swift_version = '5.0'
  s.module_name  = 'Linksquared' 

  s.source_files = 'Sources/**/*.swift'  # Adjust this path to match your package structure

  s.platform     = :ios
  s.ios.deployment_target = "13.0"
  s.swift_version = '5.0'
end
