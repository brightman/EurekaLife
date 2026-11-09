require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'
require 'open3'
require 'xcodeproj'

class BuildFeaturesSmoke < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def pod_dependencies(enabled)
    Dir.mktmpdir('wiselife-build-features') do |root|
      FileUtils.cp(File.join(ROOT, 'Podfile'), root)
      FileUtils.mkdir_p(File.join(root, 'Config'))
      FileUtils.mkdir_p(File.join(root, 'scripts'))
      helper = File.join(ROOT, 'scripts/build_features.rb')
      FileUtils.cp(helper, File.join(root, 'scripts')) if File.file?(helper)
      File.write(File.join(root, 'Config/BuildFeatures.json'), JSON.generate('eurekaRing' => enabled))
      output, error, status = Open3.capture3('pod', 'ipc', 'podfile', File.join(root, 'Podfile'))
      assert status.success?, error + output
      collect_dependencies(YAML.load(output))
    end
  end

  def collect_dependencies(node)
    case node
    when Hash
      own = Array(node['dependencies']).flat_map { |dependency| dependency.is_a?(Hash) ? dependency.keys : dependency }
      own + node.reject { |key, _| key == 'dependencies' }.values.flat_map { |value| collect_dependencies(value) }
    when Array then node.flat_map { |value| collect_dependencies(value) }
    else []
    end
  end

  # Catches restoring an unconditional native dependency in the default build.
  def test_disabled_build_does_not_resolve_native_ring_pods
    assert_empty pod_dependencies(false)
  end

  # Catches a switch that hides Swift code but cannot restore native SDK dependencies.
  def test_enabled_build_uses_one_packaged_native_sdk
    assert_equal %w[br_flutter_plugin_ble/Native], pod_dependencies(true).uniq.sort
  end

  # Xcode permits TEMP_DIR but denies its DerivedSources child unless declared
  # as an output. Exercise creation, reading and cleanup under that policy.
  def test_resource_copy_list_works_in_the_xcode_script_sandbox
    require File.join(ROOT, 'scripts/build_features.rb')
    %w[PODS_ROOT DERIVED_FILE_DIR TEMP_DIR].each do |original_directory|
      Dir.mktmpdir('wiselife pod resources') do |directory|
        root = File.realpath(directory)
        path = File.join(root, 'Pods/Target Support Files/Pods-WristNotes/Pods-WristNotes-resources.sh')
        temp = File.join(root, 'WristNotes.build')
        derived = File.join(temp, 'DerivedSources')
        source_bundle = File.join(root, 'PodProducts/Privacy.bundle')
        destination = File.join(root, 'WiseLife.app')
        FileUtils.mkdir_p([File.dirname(path), derived, source_bundle, destination])
        File.write(File.join(source_bundle, 'Info.plist'), 'generated bundle metadata')
        File.write(File.join(source_bundle, 'PrivacyInfo.xcprivacy'), 'privacy manifest')

        app = Xcodeproj::Project.new(File.join(root, 'App.xcodeproj'))
        phone = app.new_target(:application, 'WristNotes', :ios, '26.0')
        resources = phone.new_shell_script_build_phase('[CP] Copy Pods Resources')
        resources.output_paths = [File.join(destination, 'Privacy.bundle')]
        pods = Xcodeproj::Project.new(File.join(root, 'Pods.xcodeproj'))
        bundle = pods.new_target(:bundle, 'br_flutter_plugin_ble-Privacy', :ios, '15.0')
        bundle.product_reference.path = 'Privacy.bundle'
        bundle.add_resources([pods.new_file(File.join(source_bundle, 'PrivacyInfo.xcprivacy'))])
        WristNotesBuildFeatures.prepare_resource_outputs(app, pods_project: pods)
        outputs = resources.output_paths.dup
        WristNotesBuildFeatures.prepare_resource_outputs(app, pods_project: pods)
        assert_equal outputs, resources.output_paths, 'Output declarations must be idempotent'
        File.write(path, <<~SH)
          set -eu
          RESOURCES_TO_COPY=${#{original_directory}}/resources-to-copy-${TARGETNAME}.txt
          > "$RESOURCES_TO_COPY"
          echo "$SOURCE_BUNDLE" >> "$RESOURCES_TO_COPY"
          rsync -avr --copy-links --no-relative --files-from="$RESOURCES_TO_COPY" / "$TARGET_BUILD_DIR"
          rm -f "$RESOURCES_TO_COPY"
        SH
        WristNotesBuildFeatures.prepare_resource_scripts(root)
        prepared = File.read(path)
        WristNotesBuildFeatures.prepare_resource_scripts(root)
        assert_equal prepared, File.read(path), 'Repeated pod integration must be idempotent'

        profile = <<~SB
          (version 1)
          (allow default)
          (deny file-write* (subpath #{root.dump}))
          (allow file-write* (subpath #{temp.dump}))
          (deny file-read* file-write* (subpath #{derived.dump}))
          #{outputs.map { |output| "(allow file-read* file-write* (literal #{output.dump}))" }.join("\n")}
        SB
        environment = {
          'PODS_ROOT' => File.join(root, 'Pods'), 'TEMP_DIR' => temp,
          'DERIVED_FILE_DIR' => derived, 'TARGETNAME' => 'WristNotes',
          'SOURCE_BUNDLE' => source_bundle, 'TARGET_BUILD_DIR' => destination
        }
        output, error, status = Open3.capture3(environment, '/usr/bin/sandbox-exec', '-p', profile, '/bin/bash', path)
        assert status.success?, "#{original_directory}: #{error}#{output}"
        assert_equal 'generated bundle metadata', File.read(File.join(destination, 'Privacy.bundle/Info.plist'))
        assert_equal 'privacy manifest', File.read(File.join(destination, 'Privacy.bundle/PrivacyInfo.xcprivacy'))
        assert_empty Dir.glob(File.join(root, '**/resources-to-copy-*')), 'Transient resource list must be removed'
      end
    end
  end

  # Catches non-reversible exclusions or overwriting unrelated developer build settings.
  def test_switch_round_trip_preserves_other_flags_and_watch_configuration
    helper = File.join(ROOT, 'scripts/build_features.rb')
    assert File.file?(helper), 'Shared build-feature configuration has not been implemented'
    require helper
    Dir.mktmpdir('wiselife-feature-project') do |root|
      project = Xcodeproj::Project.new(File.join(root, 'App.xcodeproj'))
      phone = project.new_target(:application, 'WristNotes', :ios, '26.0')
      tests = project.new_target(:unit_test_bundle, 'RingIntegrationTests', :ios, '26.0')
      watch = project.new_target(:application, 'WristNotesWatch', :watchos, '10.0')
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) DEBUG ANOTHER_FEATURE'
          config.build_settings['EXCLUDED_SOURCE_FILE_NAMES'] = ['Unrelated.swift']
        end
      end
      original_watch = Marshal.load(Marshal.dump(watch.build_configurations.map(&:build_settings)))
      [false, true, false].each do |enabled|
        WristNotesBuildFeatures.apply(project, enabled: enabled)
        [phone, tests].each do |target|
          target.build_configurations.each do |config|
            flags = Array(config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'])
            assert_includes flags, 'ANOTHER_FEATURE'
            assert_equal enabled, flags.include?('WISELIFE_EUREKA_RING')
            if target == tests
              assert_equal enabled, Array(config.build_settings['OTHER_LDFLAGS']).each_cons(2).include?(%w[-framework BRRecorderOpus])
            end
            excluded = Array(config.build_settings['EXCLUDED_SOURCE_FILE_NAMES'])
            assert_includes excluded, 'Unrelated.swift'
            names = target == phone ? %w[EurekaRingModel.swift RingTransferStore.swift] : %w[RingIntegrationTests.swift]
            names.each { |name| assert_equal !enabled, excluded.include?(name) }
          end
        end
      end
      assert_equal original_watch, watch.build_configurations.map(&:build_settings)
    end
  end
end
