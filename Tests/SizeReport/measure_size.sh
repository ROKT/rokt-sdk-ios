#!/bin/bash
#
# SDK Size Measurement Script
#
# This script builds both the baseline and with-SDK test apps,
# and measures their sizes to determine the SDK's size impact.
#
# The with-SDK app uses a local SPM package reference to the SDK,
# so source changes are automatically included when building.
#
# The SDK framework is embedded in the app bundle, so the app bundle
# size delta directly reflects the SDK's total size impact.
#
# Usage: ./measure_size.sh [--json] [--with-sdk-only]
#
# Options:
#   --json           Output results as JSON
#   --with-sdk-only  Only build and measure the with-SDK app
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"

# Parse arguments
OUTPUT_JSON=false
WITH_SDK_ONLY=false
for arg in "$@"; do
	case ${arg} in
	--json)
		OUTPUT_JSON=true
		;;
	--with-sdk-only)
		WITH_SDK_ONLY=true
		;;
	*)
		echo "Unknown argument: ${arg}" >&2
		exit 1
		;;
	esac
done

# Clean build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${DERIVED_DATA_DIR}"

# Function to get directory size in KB
get_dir_size_kb() {
	local dir_path="$1"
	local size_output
	if [[ -d ${dir_path} ]]; then
		# Get size in KB
		size_output=$(du -sk "${dir_path}" 2>/dev/null) || true
		echo "${size_output}" | cut -f1
	else
		echo "0"
	fi
}

# Function to get file size in bytes
get_file_size_bytes() {
	local file_path="$1"
	if [[ -f ${file_path} ]]; then
		stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null || echo "0"
	else
		echo "0"
	fi
}

# Function to get app size from the built .app bundle
get_app_size() {
	local app_path="$1"
	get_dir_size_kb "${app_path}"
}

# Function to get executable size from the main binary
get_executable_size() {
	local app_path="$1"
	local app_name
	app_name=$(basename "${app_path}" .app)
	local binary_path="${app_path}/${app_name}"
	get_file_size_bytes "${binary_path}"
}

# Function to build an app with custom DerivedData
# All xcodebuild output is redirected to stderr to keep stdout clean for JSON output
build_app() {
	local project_path="$1"
	local scheme="$2"
	local archive_path="$3"
	local derived_data_path="$4"

	echo "Building ${scheme}..." >&2

	xcodebuild archive \
		-project "${project_path}" \
		-scheme "${scheme}" \
		-configuration Release \
		-destination "generic/platform=iOS" \
		-archivePath "${archive_path}" \
		-derivedDataPath "${derived_data_path}" \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		ONLY_ACTIVE_ARCH=NO \
		-quiet >&2 2>&1 || {
		echo "Warning: Archive failed, trying build instead..." >&2
		# Fallback to regular build if archive fails
		xcodebuild build \
			-project "${project_path}" \
			-scheme "${scheme}" \
			-configuration Release \
			-destination "generic/platform=iOS" \
			-derivedDataPath "${derived_data_path}" \
			CODE_SIGN_IDENTITY="-" \
			CODE_SIGNING_REQUIRED=NO \
			CODE_SIGNING_ALLOWED=NO \
			ONLY_ACTIVE_ARCH=NO \
			-quiet >&2 2>&1
	}
}

# Build baseline app (if not with-sdk-only)
BASELINE_SIZE_KB=0
BASELINE_EXECUTABLE_SIZE=0
if [[ ${WITH_SDK_ONLY} == "false" ]]; then
	build_app \
		"${SCRIPT_DIR}/SizeTestApp/SizeTestApp.xcodeproj" \
		"SizeTestApp" \
		"${BUILD_DIR}/SizeTestApp.xcarchive" \
		"${DERIVED_DATA_DIR}/SizeTestApp"

	# Find the .app in archive or DerivedData
	if [[ -d "${BUILD_DIR}/SizeTestApp.xcarchive" ]]; then
		BASELINE_APP="${BUILD_DIR}/SizeTestApp.xcarchive/Products/Applications/SizeTestApp.app"
	else
		BASELINE_APP=$(find "${DERIVED_DATA_DIR}/SizeTestApp" -name "SizeTestApp.app" -type d 2>/dev/null | head -1 || true)
	fi

	if [[ -d ${BASELINE_APP} ]]; then
		# shellcheck disable=SC2311
		BASELINE_SIZE_KB=$(get_app_size "${BASELINE_APP}")
		# shellcheck disable=SC2311
		BASELINE_EXECUTABLE_SIZE=$(get_executable_size "${BASELINE_APP}")
	fi
fi

# Build with-SDK app
build_app \
	"${SCRIPT_DIR}/SizeTestAppWithSDK/SizeTestAppWithSDK.xcodeproj" \
	"SizeTestAppWithSDK" \
	"${BUILD_DIR}/SizeTestAppWithSDK.xcarchive" \
	"${DERIVED_DATA_DIR}/SizeTestAppWithSDK"

# Find the .app in archive or DerivedData
if [[ -d "${BUILD_DIR}/SizeTestAppWithSDK.xcarchive" ]]; then
	WITHSDK_APP="${BUILD_DIR}/SizeTestAppWithSDK.xcarchive/Products/Applications/SizeTestAppWithSDK.app"
else
	WITHSDK_APP=$(find "${DERIVED_DATA_DIR}/SizeTestAppWithSDK" -name "SizeTestAppWithSDK.app" -type d 2>/dev/null | head -1 || true)
fi

WITHSDK_SIZE_KB=0
WITHSDK_EXECUTABLE_SIZE=0
if [[ -d ${WITHSDK_APP} ]]; then
	# shellcheck disable=SC2311
	WITHSDK_SIZE_KB=$(get_app_size "${WITHSDK_APP}")
	# shellcheck disable=SC2311
	WITHSDK_EXECUTABLE_SIZE=$(get_executable_size "${WITHSDK_APP}")
fi

# Get the embedded framework size from the app bundle
FRAMEWORK_PATH="${WITHSDK_APP}/Frameworks/Rokt_Widget.framework"
FRAMEWORK_SIZE_KB=0
FRAMEWORK_BINARY_SIZE=0
if [[ -d ${FRAMEWORK_PATH} ]]; then
	# shellcheck disable=SC2311
	FRAMEWORK_SIZE_KB=$(get_dir_size_kb "${FRAMEWORK_PATH}")
	# shellcheck disable=SC2311
	FRAMEWORK_BINARY_SIZE=$(get_file_size_bytes "${FRAMEWORK_PATH}/Rokt_Widget")
fi

# Calculate SDK impact (with-SDK app minus baseline)
SDK_IMPACT_KB=$((WITHSDK_SIZE_KB - BASELINE_SIZE_KB))
SDK_EXECUTABLE_IMPACT=$((WITHSDK_EXECUTABLE_SIZE - BASELINE_EXECUTABLE_SIZE))

# Output results
if [[ ${OUTPUT_JSON} == "true" ]]; then
	# Output compact single-line JSON for CI compatibility
	echo "{\"baseline_app_size_kb\":${BASELINE_SIZE_KB},\"baseline_executable_size_bytes\":${BASELINE_EXECUTABLE_SIZE},\"with_sdk_app_size_kb\":${WITHSDK_SIZE_KB},\"with_sdk_executable_size_bytes\":${WITHSDK_EXECUTABLE_SIZE},\"sdk_framework_size_kb\":${FRAMEWORK_SIZE_KB},\"sdk_framework_binary_bytes\":${FRAMEWORK_BINARY_SIZE},\"sdk_impact_kb\":${SDK_IMPACT_KB},\"sdk_executable_impact_bytes\":${SDK_EXECUTABLE_IMPACT}}"
else
	echo ""
	echo "=== SDK Size Measurement Results ==="
	echo ""
	if [[ ${WITH_SDK_ONLY} == "false" ]]; then
		echo "Baseline App (no SDK):"
		echo "  App bundle size: ${BASELINE_SIZE_KB} KB"
		echo "  Executable size: ${BASELINE_EXECUTABLE_SIZE} bytes"
		echo ""
	fi
	echo "With SDK App:"
	echo "  App bundle size: ${WITHSDK_SIZE_KB} KB"
	echo "  Executable size: ${WITHSDK_EXECUTABLE_SIZE} bytes"
	echo ""
	if [[ ${FRAMEWORK_SIZE_KB} -gt 0 ]]; then
		echo "Embedded Framework (Rokt_Widget.framework):"
		echo "  Framework size: ${FRAMEWORK_SIZE_KB} KB"
		echo "  Binary size: ${FRAMEWORK_BINARY_SIZE} bytes"
		echo ""
	fi
	if [[ ${WITH_SDK_ONLY} == "false" ]]; then
		echo "SDK Impact (app bundle delta):"
		echo "  Total: ${SDK_IMPACT_KB} KB"
		echo "  Executable delta: ${SDK_EXECUTABLE_IMPACT} bytes"
	fi
	echo ""
fi
