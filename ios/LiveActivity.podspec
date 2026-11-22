Pod::Spec.new do |s|
  s.name           = 'LiveActivity'
  s.version        = '0.1.0'
  s.summary        = 'LiveActivity SDK for Expo'
  s.description    = 'Reports Live Activity tokens and state to LiveActivity.'
  s.homepage       = 'https://liveactivity.dev'
  s.license        = 'MIT'
  s.author         = 'LiveActivity'
  s.platforms      = { :ios => '16.2' }
  s.source         = { :git => '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.swift_version  = '5.9'
  s.source_files   = '**/*.{h,m,swift}'
end
