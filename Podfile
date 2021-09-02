source 'https://cdn.cocoapods.org/'

install! 'cocoapods',
         :generate_multiple_pod_projects => true,
         :incremental_installation => true,
         :preserve_pod_file_structure => true

install! 'cocoapods', :disable_input_output_paths => true

use_frameworks!

target 'SharingElements macOS' do
  platform :osx, '11.0'
  pod 'Forge', :path => '../Forge'
  pod 'Satin', :path => '../Satin'
  pod 'Youi', :path => '../Youi'
end
