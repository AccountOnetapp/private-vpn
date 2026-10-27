#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
frameworks_dir="$project_root/ios/Frameworks"
target="$frameworks_dir/LibXray.xcframework"
version=v26.10.21
archive_name=libxray-apple-cgo.zip
url="https://github.com/XTLS/libXray/releases/download/$version/$archive_name"
expected_sha256=f318d216bb3b16b18d7b04c54789d1feaa6b7571433ed5582c1fe776e3776ef1

if [[ -d $target ]]; then
  echo "LibXray $version is already installed."
  exit 0
fi

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/private-vpn-libxray.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT
archive="$temp_dir/$archive_name"

curl --fail --location --retry 3 --output "$archive" "$url"
actual_sha256=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ $actual_sha256 != "$expected_sha256" ]]; then
  echo "libXray checksum mismatch: expected $expected_sha256, got $actual_sha256" >&2
  exit 1
fi

unzip -q "$archive" -d "$temp_dir/unpacked"
source_framework="$temp_dir/unpacked/libxray-apple-cgo/LibXray.xcframework"
if [[ ! -d $source_framework ]]; then
  echo "The libXray archive did not contain the expected XCFramework." >&2
  exit 1
fi

mkdir -p "$frameworks_dir"
ditto "$source_framework" "$target"
echo "Installed libXray $version at $target"
