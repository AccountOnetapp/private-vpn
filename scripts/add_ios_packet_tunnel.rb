#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "ios", "Runner.xcodeproj")
PROJECT = Xcodeproj::Project.open(PROJECT_PATH)
RUNNER = PROJECT.targets.find { |target| target.name == "Runner" }
abort("Runner target not found") unless RUNNER

def configure_extension(target, name:, bundle_identifier:, info_plist:, entitlements:)
  runner_team = RUNNER.build_configurations.first.build_settings["DEVELOPMENT_TEAM"]
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_identifier
    settings["PRODUCT_NAME"] = name
    settings["INFOPLIST_FILE"] = info_plist
    settings["CODE_SIGN_ENTITLEMENTS"] = entitlements
    settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
    settings["SKIP_INSTALL"] = "YES"
    settings["SWIFT_VERSION"] = "5.0"
    settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    settings["MARKETING_VERSION"] = "0.2.0"
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["TARGETED_DEVICE_FAMILY"] = "1,2"
    settings["DEVELOPMENT_TEAM"] = runner_team if runner_team
  end
end

def ensure_extension(name:, sources:, bundle_identifier:, info_plist:, entitlements:)
  target = PROJECT.targets.find { |candidate| candidate.name == name }
  target ||= PROJECT.new_target(:app_extension, name, :ios, "15.0")

  group = PROJECT.main_group.find_subpath(name, true)
  group.set_source_tree("<group>")
  sources.each do |source_path|
    reference = PROJECT.files.find { |file| file.path == source_path }
    reference ||= group.new_file(source_path)
    unless target.source_build_phase.files_references.include?(reference)
      target.source_build_phase.add_file_reference(reference)
    end
  end

  configure_extension(
    target,
    name: name,
    bundle_identifier: bundle_identifier,
    info_plist: info_plist,
    entitlements: entitlements
  )
  target
end

def ensure_runner_embedding(target)
  unless RUNNER.dependencies.any? { |dependency| dependency.target == target }
    RUNNER.add_dependency(target)
  end

  embed_phase = RUNNER.copy_files_build_phases.find do |phase|
    phase.name == "Embed Foundation Extensions"
  end
  embed_phase ||= RUNNER.new_copy_files_build_phase("Embed Foundation Extensions")
  embed_phase.dst_subfolder_spec = "13"
  return if embed_phase.files_references.include?(target.product_reference)

  build_file = embed_phase.add_file_reference(target.product_reference)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy", "CodeSignOnCopy"] }
end

RUNNER.build_configurations.each do |configuration|
  configuration.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
end

xray_tunnel = ensure_extension(
  name: "PacketTunnel",
  sources: ["PacketTunnel/PacketTunnelProvider.swift"],
  bundle_identifier: "com.accountonetapp.privateVpn.PacketTunnel",
  info_plist: "PacketTunnel/Info.plist",
  entitlements: "PacketTunnel/PacketTunnel.entitlements"
)
xray_tunnel.build_configurations.each do |configuration|
  configuration.build_settings["OTHER_LDFLAGS"] = "$(inherited) -lresolv"
end

libxray = PROJECT.files.find { |file| file.path == "Frameworks/LibXray.xcframework" }
libxray ||= PROJECT.main_group.new_file("Frameworks/LibXray.xcframework")
unless xray_tunnel.frameworks_build_phase.files_references.include?(libxray)
  xray_tunnel.frameworks_build_phase.add_file_reference(libxray)
end

amnezia_tunnel = ensure_extension(
  name: "AmneziaPacketTunnel",
  sources: [
    "AmneziaPacketTunnel/AmneziaPacketTunnelProvider.swift",
    "AmneziaPacketTunnel/AmneziaConfigParser.swift",
  ],
  bundle_identifier: "com.accountonetapp.privateVpn.AmneziaPacketTunnel",
  info_plist: "AmneziaPacketTunnel/Info.plist",
  entitlements: "AmneziaPacketTunnel/AmneziaPacketTunnel.entitlements"
)
amnezia_tunnel.build_configurations.each do |configuration|
  configuration.build_settings["LIBRARY_SEARCH_PATHS"] = [
    "$(inherited)",
    "$(SRCROOT)/Packages/amneziawg-apple/Sources/WireGuardKitGo/out",
  ]
end

local_package = PROJECT.root_object.package_references.find do |package|
  package.respond_to?(:relative_path) && package.relative_path == "Packages/amneziawg-apple"
end
unless local_package
  local_package = PROJECT.new(
    Xcodeproj::Project::Object::XCLocalSwiftPackageReference
  )
  local_package.relative_path = "Packages/amneziawg-apple"
  PROJECT.root_object.package_references << local_package
end

wireguard_product = amnezia_tunnel.package_product_dependencies.find do |dependency|
  dependency.product_name == "WireGuardKit"
end
unless wireguard_product
  wireguard_product = PROJECT.new(
    Xcodeproj::Project::Object::XCSwiftPackageProductDependency
  )
  wireguard_product.product_name = "WireGuardKit"
  amnezia_tunnel.package_product_dependencies << wireguard_product
end
# Xcode resolves products from local packages by name. Setting the `package`
# field is valid for remote references but prevents local module discovery.
wireguard_product.package = nil
unless amnezia_tunnel.frameworks_build_phase.files.any? do |file|
  file.product_ref == wireguard_product
end
  build_file = PROJECT.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = wireguard_product
  amnezia_tunnel.frameworks_build_phase.files << build_file
end

go_phase = amnezia_tunnel.shell_script_build_phases.find do |phase|
  phase.name == "Build AmneziaWG Go bridge"
end
go_phase ||= amnezia_tunnel.new_shell_script_build_phase("Build AmneziaWG Go bridge")
go_phase.shell_path = "/bin/sh"
go_phase.shell_script = '"$SRCROOT/../scripts/build_amneziawg_go.sh"'
go_phase.always_out_of_date = "1"
amnezia_tunnel.build_phases.move(go_phase, 0)

ensure_runner_embedding(xray_tunnel)
ensure_runner_embedding(amnezia_tunnel)

# Flutter's Thin Binary phase reads the final app bundle. Xcode reports a
# dependency cycle when extension embedding follows it, so embed first.
embed_phase = RUNNER.copy_files_build_phases.find do |phase|
  phase.name == "Embed Foundation Extensions"
end
thin_phase = RUNNER.shell_script_build_phases.find { |phase| phase.name == "Thin Binary" }
if embed_phase && thin_phase
  embed_index = RUNNER.build_phases.index(embed_phase)
  thin_index = RUNNER.build_phases.index(thin_phase)
  RUNNER.build_phases.move(embed_phase, thin_index) if embed_index > thin_index
end

PROJECT.save
{
  "XrayPacketTunnel" => xray_tunnel,
  "AmneziaWGPacketTunnel" => amnezia_tunnel,
}.each do |scheme_name, target|
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.save_as(PROJECT_PATH, scheme_name, true)
end
puts "Xray and AmneziaWG packet tunnel targets are configured in #{PROJECT_PATH}"
