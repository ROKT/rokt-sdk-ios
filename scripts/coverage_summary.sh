#!/usr/bin/env bash
#
# Prints line coverage per target from an Xcode result bundle as a Markdown table.
#
# CI appends the output to each test job's summary. Locally, run it on any .xcresult built with
# -enableCodeCoverage YES, including one downloaded from a CI run's artifacts.
#
# Arguments:
#   $1    - Path to the .xcresult bundle
#   $2... - Targets to report (e.g. Rokt-Widget); every target when omitted
#
# Usage: ./scripts/coverage_summary.sh TestResult.xcresult Rokt-Widget

set -euo pipefail

RESULT_BUNDLE=${1:?Usage: $0 <path.xcresult> [target...]}
shift

# No bundle means the test step failed before writing one, and that step already reports it.
[[ -d ${RESULT_BUNDLE} ]] || exit 0

xcrun xccov view --report --only-targets --json "${RESULT_BUNDLE}" |
	jq -r '
		$ARGS.positional as $targets
		| "### Code coverage", "",
		  "| Target | Covered lines | Coverage |",
		  "| --- | ---: | ---: |",
		  (.[]
		   | select(($targets | length) == 0 or (.name | IN($targets[])))
		   | "| \(.name) | \(.coveredLines)/\(.executableLines) | \(.lineCoverage * 10000 | round / 100)% |")
	' --args "$@"
