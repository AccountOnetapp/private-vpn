#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "ios", "Runner.xcodeproj")
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == "Runner" }
abort("Runner target not found") unless runner

runner.build_configurations.each do |configuration|
  configuration.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
end

tunnel = project.targets.find { |target| target.name == "PacketTunnel" }
unless tunnel
  tunnel = project.new_target(:app_extension, "PacketTunnel", :ios, "15.0")
  group = project.main_group.find_subpath("PacketTunnel", true)
  group.set_source_tree("<group>")
  source = group.new_file("PacketTunnel/PacketTunnelProvider.swift")
  tunnel.source_build_phase.add_file_reference(source)

  runner_team = runner.build_configurations.first.build_settings["DEVELOPMENT_TEAM"]
  tunnel.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.accountonetapp.privateVpn.PacketTunnel"
    settings["PRODUCT_NAME"] = "PacketTunnel"
    settings["INFOPLIST_FILE"] = "PacketTunnel/Info.plist"
    settings["CODE_SIGN_ENTITLEMENTS"] = "PacketTunnel/PacketTunnel.entitlements"
    settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
    settings["SKIP_INSTALL"] = "YES"
    settings["SWIFT_VERSION"] = "5.0"
    settings["MARKETING_VERSION"] = "0.1.0"
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["TARGETED_DEVICE_FAMILY"] = "1,2"
    settings["DEVELOPMENT_TEAM"] = runner_team if runner_team
  end

  runner.add_dependency(tunnel)
  embed_phase = runner.copy_files_build_phases.find { |phase| phase.name == "Embed Foundation Extensions" }
  embed_phase ||= runner.new_copy_files_build_phase("Embed Foundation Extensions")
  embed_phase.dst_subfolder_spec = "13"
  build_file = embed_phase.add_file_reference(tunnel.product_reference)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy", "CodeSignOnCopy"] }
end

# Re-apply settings on every run so the script also repairs projects generated
# by a newer Flutter template.
runner_team = runner.build_configurations.first.build_settings["DEVELOPMENT_TEAM"]
tunnel.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.accountonetapp.privateVpn.PacketTunnel"
  settings["PRODUCT_NAME"] = "PacketTunnel"
  settings["INFOPLIST_FILE"] = "PacketTunnel/Info.plist"
  settings["CODE_SIGN_ENTITLEMENTS"] = "PacketTunnel/PacketTunnel.entitlements"
  settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  settings["SKIP_INSTALL"] = "YES"
  settings["SWIFT_VERSION"] = "5.0"
  settings["MARKETING_VERSION"] = "0.1.0"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  settings["DEVELOPMENT_TEAM"] = runner_team if runner_team
end

# Flutter's Thin Binary phase reads the final app bundle. Xcode 15+ reports a
# dependency cycle when the extension copy phase follows it, so embed the
# extension immediately before Thin Binary.
embed_phase = runner.copy_files_build_phases.find { |phase| phase.name == "Embed Foundation Extensions" }
thin_phase = runner.shell_script_build_phases.find { |phase| phase.name == "Thin Binary" }
if embed_phase && thin_phase
  embed_index = runner.build_phases.index(embed_phase)
  thin_index = runner.build_phases.index(thin_phase)
  runner.build_phases.move(embed_phase, thin_index) if embed_index > thin_index
end

project.save
puts "PacketTunnel target is configured in #{project_path}"
