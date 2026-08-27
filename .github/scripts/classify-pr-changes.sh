#!/usr/bin/env bash

set -euo pipefail

docs=false
root_sdk=false
package=false
ui=false
manifest=false
contract=false
periphery=false
size=false
full=false

set_full() {
	local reason="$1"
	docs=true
	root_sdk=true
	package=true
	ui=true
	manifest=true
	contract=true
	periphery=true
	size=true
	full=true
	printf 'Selecting the full validation suite: %s\n' "${reason}" >&2
}

select_contract_source() {
	root_sdk=true
	contract=true
	periphery=true
	size=true
}

classify_path() {
	local path="${1#./}"

	case "${path}" in
	Package.swift | Package.resolved | Rokt-Widget.podspec | VERSION | Packages/matrix.json | \
		.swiftformat | .swiftlint.yml | .periphery.yml | Gemfile | Gemfile.lock)
		set_full "build or release manifest changed: ${path}"
		;;
	.github/workflows/* | .github/actions/* | .github/dependabot.yml | \
		.github/scripts/* | .trunk/* | scripts/* | Example/*.xcodeproj/* | Example/*.xcworkspace/*)
		set_full "validation or build-system file changed: ${path}"
		;;
	Sources/Rokt_Widget/Networking/OffersClient.swift | \
		Sources/Rokt_Widget/Networking/TxnEventsClient.swift | \
		Sources/Rokt_Widget/Networking/TxnInitClient.swift | \
		Sources/Rokt_Widget/Networking/TxnRequestHeaders.swift | \
		Sources/Rokt_Widget/Networking/HTTPClient/* | \
		Sources/Rokt_Widget/Networking/HTTPHeader.swift | \
		Sources/Rokt_Widget/Models/SelectResponse.swift | \
		Sources/Rokt_Widget/Models/Event/TxnEventModels.swift)
		select_contract_source
		;;
	Sources/*)
		root_sdk=true
		periphery=true
		size=true
		;;
	Tests/ContractTests/*)
		contract=true
		;;
	Tests/Rokt_WidgetTests/*)
		root_sdk=true
		;;
	Tests/SizeReport/*)
		size=true
		;;
	Packages/*/Package.swift | Packages/*.podspec)
		set_full "package manifest changed: ${path}"
		;;
	Packages/*)
		package=true
		;;
	Example/Tests/*)
		ui=true
		;;
	Example/*.swift | Example/*.m | Example/*.mm)
		ui=true
		periphery=true
		;;
	Example/*)
		ui=true
		;;
	*.md | docs/* | documentation/* | .cortex/* | .github/ISSUE_TEMPLATE/* | \
		.github/CODEOWNERS | LICENSE | NOTICE | .gitignore | .editorconfig)
		docs=true
		;;
	*)
		set_full "unclassified path changed: ${path}"
		;;
	esac
}

if [[ ${1-} == "--full" ]]; then
	set_full "${2:-explicit full-validation request}"
else
	path_count=0
	while IFS= read -r path; do
		[[ -z ${path} ]] && continue
		path_count=$((path_count + 1))
		classify_path "${path}"
	done

	if [[ ${path_count} -eq 0 ]]; then
		set_full "no changed paths were available"
	fi
fi

printf 'docs=%s\n' "${docs}"
printf 'root_sdk=%s\n' "${root_sdk}"
printf 'package=%s\n' "${package}"
printf 'ui=%s\n' "${ui}"
printf 'manifest=%s\n' "${manifest}"
printf 'contract=%s\n' "${contract}"
printf 'periphery=%s\n' "${periphery}"
printf 'size=%s\n' "${size}"
printf 'full=%s\n' "${full}"
