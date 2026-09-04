#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLASSIFIER="${SCRIPT_DIR}/classify-pr-changes.sh"

assert_selection() {
	local name="$1"
	local expected_true="$2"
	shift 2

	local output
	if [[ $# -eq 0 ]]; then
		output=$(printf '' | "${CLASSIFIER}" 2>/dev/null)
	else
		output=$(printf '%s\n' "$@" | "${CLASSIFIER}" 2>/dev/null)
	fi

	local key expected actual
	for key in docs root_sdk package ui manifest contract periphery size full; do
		expected=false
		if [[ ",${expected_true}," == *",${key},"* ]]; then
			expected=true
		fi
		actual=$(printf '%s\n' "${output}" | awk -F= -v key="${key}" '$1 == key { print $2 }')
		if [[ ${actual:-missing} != "${expected}" ]]; then
			printf 'FAIL: %s expected %s=%s, got %s\n' \
				"${name}" "${key}" "${expected}" "${actual:-missing}" >&2
			exit 1
		fi
	done

	printf 'PASS: %s\n' "${name}"
}

assert_selection "documentation only" "docs" $'M\tREADME.md' $'A\tdocs/integration.md'
assert_selection "root SDK source" "root_sdk,ui,periphery,size" $'M\tSources/Rokt_Widget/Rokt.swift'
assert_selection "contract source" "root_sdk,ui,contract,periphery,size" $'M\tSources/Rokt_Widget/Networking/OffersClient.swift'
assert_selection "contract tests" "contract" $'M\tTests/ContractTests/OffersClientPactTests.swift'
assert_selection "payment package" "package" $'M\tPackages/rokt-payment-extension-ios/Sources/Payment.swift'
assert_selection "UI tests" "ui" $'M\tExample/Tests/PlacementUITests.swift'
assert_selection "example source" "ui,periphery" $'M\tExample/rokt/AppDelegate.swift'
assert_selection "mixed docs and package" "docs,package" $'M\tREADME.md' $'M\tPackages/rokt-payment-extension-ios/Tests/PaymentTests.swift'
assert_selection "manifest is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'M\tPackage.swift'
assert_selection "workflow is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'M\t.github/workflows/pull-request.yml'
assert_selection "unknown path is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'A\tunexpected/config.toml'
assert_selection "root source renamed to docs is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'R100\tSources/Rokt_Widget/Rokt.swift\tdocs/Rokt.md'
assert_selection "docs renamed to root source is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'R100\tdocs/Rokt.md\tSources/Rokt_Widget/Rokt.swift'
assert_selection "copy is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'C100\tREADME.md\tdocs/README.md'
assert_selection "type change is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'T\tREADME.md'
assert_selection "unknown status is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" $'X\tREADME.md'
assert_selection "malformed record is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full" README.md
assert_selection "empty diff is conservative" "docs,root_sdk,package,ui,manifest,contract,periphery,size,full"
