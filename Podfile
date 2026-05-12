platform :ios, '16.0'
use_frameworks!
inhibit_all_warnings!

target 'KiviFit' do
  # MediaPipe Pose Landmarker (includes GPU/Metal support)
  pod 'MediaPipeTasksVision', '~> 0.10.14'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
      # Required for MediaPipe GPU delegates
      config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
      config.build_settings['OTHER_LDFLAGS'] << '-ObjC'
    end
  end
end
