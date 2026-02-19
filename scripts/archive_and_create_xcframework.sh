#!/bin/bash -x
#
# Archives an SPM package for iOS device and simulator, then creates an xcframework.
#
# This is a generic helper that can build any SPM package into an xcframework.
# It handles the xcodebuild archive, Swift header/module copying, and
# xcframework creation with debug symbols.
#
# Arguments:
#   $1 - Package directory (root of the SPM package)
#   $2 - Scheme name (e.g. Rokt-Widget)
#   $3 - Target/module name (e.g. Rokt_Widget)
#   $4 - Output directory for the xcframework
#
# Usage: ./scripts/archive_and_create_xcframework.sh /path/to/package Rokt-Widget Rokt_Widget /path/to/output

PACKAGE_DIRECTORY=$1
SCHEME=$2
TARGET=$3
FRAMEWORK_RELATIVE_DIRECTORY=$4

CONFIGURATION=Release

export SPM_GENERATE_FRAMEWORK=1

function buildframework {
	local SCHEME_NAME=$1
	local TARGET_NAME=$2
	local DESTINATION=$3
	local SDK=$4

	(cd "${PACKAGE_DIRECTORY}" && xcodebuild -skipPackagePluginValidation archive \
		-scheme "${SCHEME_NAME}" -destination "${DESTINATION}" -sdk "${SDK}" \
		-derivedDataPath "${FRAMEWORK_DIRECTORY}/.build" \
		-archivePath "${FRAMEWORK_DIRECTORY}/${SDK}.xcarchive" \
		-configuration "${CONFIGURATION}" \
		SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
		OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface) || exit 1

	BUILD_PATH=${FRAMEWORK_DIRECTORY}/${SDK}.xcarchive
	DERIVED_DATA_PATH=${FRAMEWORK_DIRECTORY}/.build/Build/Intermediates.noindex/ArchiveIntermediates/${SCHEME_NAME}
	ORIGINAL_FRAMEWORK_PATH=${BUILD_PATH}/Products/usr/local/lib/${SCHEME_NAME}.framework
	BUILD_FRAMEWORK_PATH=${BUILD_PATH}/Products/usr/local/lib/${TARGET_NAME}.framework

	# Normalize the packaged framework name to target/module name to keep
	# CocoaPods binary distribution naming compatible with previous releases.
	if [[ "${SCHEME_NAME}" != "${TARGET_NAME}" ]]; then
		rm -rf "${BUILD_FRAMEWORK_PATH}"
		mv "${ORIGINAL_FRAMEWORK_PATH}" "${BUILD_FRAMEWORK_PATH}"
	else
		BUILD_FRAMEWORK_PATH="${ORIGINAL_FRAMEWORK_PATH}"
	fi

	if [[ -f "${BUILD_FRAMEWORK_PATH}/${SCHEME_NAME}" && "${SCHEME_NAME}" != "${TARGET_NAME}" ]]; then
		mv "${BUILD_FRAMEWORK_PATH}/${SCHEME_NAME}" "${BUILD_FRAMEWORK_PATH}/${TARGET_NAME}"
	fi

	if [[ -f "${BUILD_FRAMEWORK_PATH}/Info.plist" ]]; then
		plutil -replace CFBundleExecutable -string "${TARGET_NAME}" "${BUILD_FRAMEWORK_PATH}/Info.plist"
		plutil -replace CFBundleName -string "${TARGET_NAME}" "${BUILD_FRAMEWORK_PATH}/Info.plist"
	fi

	if [[ -f "${BUILD_FRAMEWORK_PATH}/${TARGET_NAME}" ]]; then
		install_name_tool -id "@rpath/${TARGET_NAME}.framework/${TARGET_NAME}" "${BUILD_FRAMEWORK_PATH}/${TARGET_NAME}"
	fi

	SOURCE_DSYM_PATH="${BUILD_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM"
	TARGET_DSYM_PATH="${BUILD_PATH}/dSYMs/${TARGET_NAME}.framework.dSYM"
	if [[ -d "${SOURCE_DSYM_PATH}" && "${SCHEME_NAME}" != "${TARGET_NAME}" ]]; then
		rm -rf "${TARGET_DSYM_PATH}"
		mv "${SOURCE_DSYM_PATH}" "${TARGET_DSYM_PATH}"
	fi

	if [[ -f "${TARGET_DSYM_PATH}/Contents/Resources/DWARF/${SCHEME_NAME}" && "${SCHEME_NAME}" != "${TARGET_NAME}" ]]; then
		mv "${TARGET_DSYM_PATH}/Contents/Resources/DWARF/${SCHEME_NAME}" "${TARGET_DSYM_PATH}/Contents/Resources/DWARF/${TARGET_NAME}"
	fi

	BUILD_FRAMEWORK_HEADERS=${BUILD_FRAMEWORK_PATH}/Headers

	mkdir -p "${BUILD_FRAMEWORK_HEADERS}"
	SWIFT_HEADER="${DERIVED_DATA_PATH}/IntermediateBuildFilesPath/${SCHEME_NAME}.build/${CONFIGURATION}-${SDK}/${TARGET_NAME}.build/Objects-normal/arm64/${TARGET_NAME}-Swift.h"

	if [[ -f ${SWIFT_HEADER} ]]; then
		cp -p "${SWIFT_HEADER}" "${BUILD_FRAMEWORK_HEADERS}" || exit 2
	fi

	PACKAGE_INCLUDE_DIRS=$(find "${PACKAGE_DIRECTORY}" -path "*/Sources/*/include" -type d)
	if [[ -n ${PACKAGE_INCLUDE_DIRS} ]]; then
		cp -prv "${PACKAGE_DIRECTORY}"/Sources/*/include/* "${BUILD_FRAMEWORK_HEADERS}" || exit 2
	fi

	mkdir -p "${BUILD_FRAMEWORK_PATH}"/Modules

	SWIFT_MODULE_DIRECTORY="${DERIVED_DATA_PATH}/BuildProductsPath/${CONFIGURATION}-${SDK}/${TARGET_NAME}.swiftmodule"

	if [[ -d ${SWIFT_MODULE_DIRECTORY} ]]; then
		cp -prv "${SWIFT_MODULE_DIRECTORY}" "${BUILD_FRAMEWORK_PATH}"/Modules
	else
		echo "framework module ${TARGET_NAME} {
umbrella \"Headers\"
export *

module * { export * }
}" >"${BUILD_FRAMEWORK_PATH}"/Modules/module.modulemap
	fi

	BUNDLE_DIRECTORY="${DERIVED_DATA_PATH}/IntermediateBuildFilesPath/UninstalledProducts/${SDK}/${TARGET_NAME}_${TARGET_NAME}.bundle"
	if [[ -d ${BUNDLE_DIRECTORY} ]]; then
		cp -prv "${BUNDLE_DIRECTORY}" "${BUILD_FRAMEWORK_PATH}"
	fi
}

mkdir -p "${FRAMEWORK_RELATIVE_DIRECTORY}"
FRAMEWORK_DIRECTORY="$(cd "${FRAMEWORK_RELATIVE_DIRECTORY}" && pwd -P)"
rm -rf "${FRAMEWORK_DIRECTORY}/${TARGET}.xcframework" \
	"${FRAMEWORK_DIRECTORY}/iphoneos.xcarchive" \
	"${FRAMEWORK_DIRECTORY}/iphonesimulator.xcarchive"

buildframework "${SCHEME}" "${TARGET}" "generic/platform=iOS" "iphoneos"
buildframework "${SCHEME}" "${TARGET}" "generic/platform=iOS Simulator" "iphonesimulator"

xcodebuild -create-xcframework \
	-framework "${FRAMEWORK_DIRECTORY}/iphoneos.xcarchive/Products/usr/local/lib/${TARGET}.framework" \
	-debug-symbols "${FRAMEWORK_DIRECTORY}/iphoneos.xcarchive/dSYMs/${TARGET}.framework.dSYM" \
	-framework "${FRAMEWORK_DIRECTORY}/iphonesimulator.xcarchive/Products/usr/local/lib/${TARGET}.framework" \
	-debug-symbols "${FRAMEWORK_DIRECTORY}/iphonesimulator.xcarchive/dSYMs/${TARGET}.framework.dSYM" \
	-output "${FRAMEWORK_DIRECTORY}/${TARGET}.xcframework"
