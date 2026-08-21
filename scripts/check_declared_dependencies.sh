#!/bin/bash
#
# Fails if Sources/Rokt_Widget references symbols from a Swift module that
# Package.swift does not declare as a dependency of the Rokt_Widget target.
#
# A type can reach this SDK implicitly, through a dependency's public API, without
# ever being imported here -- RoktUXHelper exposes DcuiSchema.PaymentProvider on
# RoktUXEvent.CartItemDevicePay, for example. Using such a type compiles, but the
# manifest never learns about the module, so it contributes nothing to the link
# line. That stays invisible in most build configurations and only breaks for a
# consumer who builds every package product as its own dynamic framework, where
# undeclared modules are simply absent and the symbols come back undefined.
#
# Swift mangles the defining module into every symbol name, so the undefined
# symbols in this target's object files name exactly which modules it links
# against. Comparing that set against the declared set catches the gap at PR time,
# independent of how the build happens to be linked.
#
# Usage: ./scripts/check_declared_dependencies.sh [derived-data-path]

set -euo pipefail

DERIVED=${1:-.build-depcheck}
TARGET_MODULE=Rokt_Widget

echo "==> Building ${TARGET_MODULE}"
xcodebuild -scheme Rokt-Widget \
	-destination 'generic/platform=iOS Simulator' \
	-derivedDataPath "${DERIVED}" \
	-skipPackagePluginValidation \
	-quiet build >/dev/null

OBJ_DIR=$(find "${DERIVED}" -type d -path "*${TARGET_MODULE}.build/Objects-normal/*" -print | head -1)
if [[ -z ${OBJ_DIR} ]]; then
	echo "error: no object directory for ${TARGET_MODULE} under ${DERIVED}" >&2
	exit 1
fi

# Modules built from the package graph. Anything referenced but outside this set is
# the Swift standard library or an Apple SDK module, which needs no manifest entry.
GRAPH_MODULES=$(find "${DERIVED}/Build/Products" -maxdepth 2 -name '*.swiftmodule' 2>/dev/null |
	while read -r m; do basename "${m}" .swiftmodule; done | sort -u || true)

if [[ -z ${GRAPH_MODULES} ]]; then
	echo "error: found no package modules under ${DERIVED}/Build/Products;" >&2
	echo "the build layout changed and this check would silently pass." >&2
	exit 1
fi

# Modules named by the undefined Swift symbols in this target's objects.
#
# A module name can appear anywhere in a demangled symbol, not just at the front:
#   DcuiSchema.PaymentProvider.rawValue.getter : Swift.String
#   type metadata for DcuiSchema.PaymentProvider
#   protocol conformance descriptor for DcuiSchema.PaymentProvider : ...
#   (extension in Rokt_Widget):RoktContracts.RoktConfig.getUXConfig() -> ...
# Anchoring on a leading identifier drops roughly 70% of the symbols, including
# every metadata, conformance-descriptor, thunk and extension form -- which left
# detection resting on whichever plain-form reference happened to exist. So match
# the known package module names wherever they occur instead.
#
# The boundary class keeps a short module name from matching inside a longer one.
# BSD grep on the macOS runners does not handle \b reliably, hence [^A-Za-z0-9_].
module_alternation=$(echo "${GRAPH_MODULES}" | paste -sd'|' -)
REFERENCED=$(find "${OBJ_DIR}" -name '*.o' -print0 |
	xargs -0 nm -u 2>/dev/null |
	grep -o '_[$]s[0-9A-Za-z_]*' | sort -u |
	xcrun swift-demangle --compact 2>/dev/null |
	grep -oE "(^|[^A-Za-z0-9_])(${module_alternation})([^A-Za-z0-9_]|$)" |
	sed -E 's/^[^A-Za-z0-9_]+//; s/[^A-Za-z0-9_]+$//' | sort -u || true)

if [[ -z ${REFERENCED} ]]; then
	echo "error: no Swift symbols found in ${OBJ_DIR}; check the nm/demangle parse" >&2
	exit 1
fi

# Products declared for the target in Package.swift.
#
# Caveat: these are product names, while REFERENCED holds module names. Every
# dependency here is 1:1 (product == target == module), so the comparison is
# sound today. If a future product is renamed away from its module, or vends
# several modules, this reports a module that IS declared -- a loud false
# failure rather than a missed violation, so it self-diagnoses.
DECLARED=$(swift package dump-package |
	TARGET="${TARGET_MODULE}" python3 -c '
import json, os, sys
pkg = json.load(sys.stdin)
for t in pkg["targets"]:
    if t["name"] == os.environ["TARGET"]:
        for d in t["dependencies"]:
            if "product" in d:
                print(d["product"][0])
            elif "byName" in d:
                print(d["byName"][0])
' | sort -u)

declared_oneline=$(echo "${DECLARED}" | tr '\n' ' ')
echo "==> declared:   ${declared_oneline}"

violations=""
for mod in ${REFERENCED}; do
	# Only modules from the package graph need a manifest entry.
	echo "${GRAPH_MODULES}" | grep -qx "${mod}" || continue
	[[ ${mod} == "${TARGET_MODULE}" ]] && continue
	echo "${DECLARED}" | grep -qx "${mod}" && continue
	violations="${violations}${mod}
"
done

if [[ -n ${violations} ]]; then
	first=$(printf '%s' "${violations}" | head -1)
	{
		echo
		echo "error: ${TARGET_MODULE} uses these modules without declaring them in Package.swift:"
		printf '%s' "${violations}" | sed 's/^/  - /'
		echo
		echo "Declare each as a target dependency, e.g.:"
		echo "  .product(name: \"${first}\", package: \"<package>\")"
		echo
		echo "They resolve in this build only because the module happens to be reachable."
		echo "A consumer building each package product as its own dynamic framework gets"
		echo "undefined symbols instead."
	} >&2
	exit 1
fi

echo "==> OK: every referenced package module is declared"
