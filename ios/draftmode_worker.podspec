Pod::Spec.new do |s|
  s.name             = 'draftmode_worker'
  s.version          = '0.1.0'
  s.summary          = 'Lightweight timed worker for Flutter on iOS.'
  s.description      = 'Runs a short timed worker with background assertion & optional BGProcessing resume.'
  s.homepage         = 'https://draftmode.io/dev/flutter/worker'
  s.license          = { :type => 'MIT' }
  s.author           = { 'hashTag' => 'it@draftmode.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
  s.static_framework = true
  s.dependency 'Flutter'
end
