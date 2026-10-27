#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
go_bridge_dir="$repo_root/ios/Packages/amneziawg-apple/Sources/WireGuardKitGo"

if ! command -v go >/dev/null 2>&1; then
  echo "error: Go is required to build the AmneziaWG packet tunnel." >&2
  exit 1
fi

if [ ! -f "$go_bridge_dir/Makefile" ]; then
  echo "error: AmneziaWG sources are missing. Run git submodule update --init --recursive." >&2
  exit 1
fi

platform_name=${PLATFORM_NAME:-iphoneos}
architectures=${ARCHS:-arm64}
sdk_root=${SDKROOT:-$(xcrun --sdk "$platform_name" --show-sdk-path)}
build_key=$(printf '%s-%s' "$platform_name" "$architectures" | tr ' /' '__')
temporary_root="/tmp/privatevpn-amneziawg-$build_key"
temporary_dir="$temporary_root/tmp"
output_dir="$temporary_root/out"

# Upstream's Makefile predates the iphonesimulator platform spelling, but Go
# uses GOOS=ios for both device and simulator builds.
env \
  ARCHS="$architectures" \
  PLATFORM_NAME="$platform_name" \
  SDKROOT="$sdk_root" \
  CONFIGURATION_BUILD_DIR="$output_dir" \
  CONFIGURATION_TEMP_DIR="$temporary_dir" \
  GOOS_iphonesimulator=ios \
  make -C "$go_bridge_dir" build

mkdir -p "$go_bridge_dir/out"
cp "$output_dir/libwg-go.a" "$go_bridge_dir/out/libwg-go.a"
