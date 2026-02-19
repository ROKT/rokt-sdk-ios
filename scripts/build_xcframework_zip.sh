#!/bin/bash
#
# Builds the Rokt_Widget.xcframework.zip for CocoaPods distribution.
#
# This is the main entry point for producing the binary framework.
# It resolves SPM dependencies, archives for device and simulator,
# creates the xcframework, and packages it as a zip.
#
# Output: vendor/Rokt_Widget.xcframework.zip
#
# Usage: ./scripts/build_xcframework_zip.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/vendor"

mkdir -p "${VENDOR_DIR}"
rm -rf "${VENDOR_DIR}/Rokt_Widget.xcframework" "${VENDOR_DIR}/Rokt_Widget.xcframework.zip"

cd "${ROOT_DIR}"
swift package update

"${SCRIPT_DIR}/archive_and_create_xcframework.sh" "${ROOT_DIR}" Rokt-Widget Rokt_Widget "${VENDOR_DIR}"

plutil -replace CFBundleIdentifier -string 'Rokt-Widget' \
	"${VENDOR_DIR}/Rokt_Widget.xcframework/ios-arm64/Rokt_Widget.framework/Info.plist"
plutil -replace CFBundleIdentifier -string 'Rokt-Widget' \
	"${VENDOR_DIR}/Rokt_Widget.xcframework/ios-arm64_x86_64-simulator/Rokt_Widget.framework/Info.plist"

cd "${VENDOR_DIR}"
zip -r Rokt_Widget.xcframework.zip Rokt_Widget.xcframework

echo "Framework built and zipped at ${VENDOR_DIR}/Rokt_Widget.xcframework.zip"
