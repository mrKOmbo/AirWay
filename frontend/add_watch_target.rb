#!/usr/bin/env ruby
# Script to add AirWayWatch target to the existing Xcode project.
# Uses xcodeproj gem to safely manipulate the pbxproj file.

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'AcessNet.xcodeproj')
WATCH_APP_DIR = 'AirWayWatch Watch App'

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Check if Watch target already exists
if project.targets.any? { |t| t.name == 'AirWayWatch Watch App' }
  puts "Watch target already exists, skipping creation."
  exit 0
end

puts "Creating Watch App target..."

# --- 1. Create the Watch App target ---
watch_target = project.new_target(
  :application,
  'AirWayWatch Watch App',
  :watchos,
  '10.0'
)

# --- 2. Create a file system synced root group for the Watch app ---
watch_group = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
watch_group.path = WATCH_APP_DIR
watch_group.source_tree = '<group>'

# Add to main group
project.main_group.children << watch_group

# Link synced group to Watch target
watch_target.file_system_synchronized_groups << watch_group

# --- 3. Configure build settings for Debug ---
watch_target.build_configurations.each do |config|
  s = config.build_settings

  # Basic watchOS settings
  s['SDKROOT'] = 'watchos'
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  s['SWIFT_VERSION'] = '5.0'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = 'QF2R75VM2Y'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'xyz.KOmbo.AirWay.watchkitapp'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['ENABLE_PREVIEWS'] = 'YES'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'

  # HealthKit
  s['INFOPLIST_KEY_NSHealthShareUsageDescription'] = 'AirWay reads your health data to measure how air pollution affects your body.'
  s['INFOPLIST_KEY_NSHealthUpdateUsageDescription'] = 'AirWay saves your PPI Score to track pollution impact over time.'

  # Background modes for workout processing
  s['INFOPLIST_KEY_WKBackgroundModes'] = 'workout-processing'

  # Swift concurrency (match iOS target)
  s['SWIFT_APPROACHABLE_CONCURRENCY'] = 'YES'

  # Runpath
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']

  if config.name == 'Debug'
    s['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
    s['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
    s['ONLY_ACTIVE_ARCH'] = 'YES'
  else
    s['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
    s['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    s['VALIDATE_PRODUCT'] = 'YES'
  end
end

# --- 4. Add HealthKit framework ---
healthkit_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
healthkit_ref.name = 'HealthKit.framework'
healthkit_ref.path = 'System/Library/Frameworks/HealthKit.framework'
healthkit_ref.source_tree = 'SDKROOT'
healthkit_ref.last_known_file_type = 'wrapper.framework'

# Find or create Frameworks group
frameworks_group = project.main_group.children.find { |g| g.respond_to?(:name) && g.name == 'Frameworks' }
unless frameworks_group
  frameworks_group = project.main_group.new_group('Frameworks')
end
frameworks_group.children << healthkit_ref

# Add to frameworks build phase
watch_target.frameworks_build_phase.add_file_reference(healthkit_ref)

# --- 5. Add WatchConnectivity framework ---
wc_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
wc_ref.name = 'WatchConnectivity.framework'
wc_ref.path = 'System/Library/Frameworks/WatchConnectivity.framework'
wc_ref.source_tree = 'SDKROOT'
wc_ref.last_known_file_type = 'wrapper.framework'
frameworks_group.children << wc_ref
watch_target.frameworks_build_phase.add_file_reference(wc_ref)

# --- 6. Register target in project attributes ---
attributes = project.root_object.attributes
target_attributes = attributes['TargetAttributes'] || {}
target_attributes[watch_target.uuid] = {
  'CreatedOnToolsVersion' => '26.0',
}
attributes['TargetAttributes'] = target_attributes

# --- 7. Add embed watch app phase to iOS target (dependency) ---
ios_target = project.targets.find { |t| t.name == 'AirWay' }
if ios_target
  # Add dependency
  ios_target.add_dependency(watch_target)

  # Add embed watch content phase
  embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.dst_subfolder_spec = '16' # Watch content
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'

  build_file = embed_phase.add_file_reference(watch_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# --- 8. Save ---
project.save
puts "Watch target 'AirWayWatch Watch App' added successfully!"
puts "Targets: #{project.targets.map(&:name).join(', ')}"
