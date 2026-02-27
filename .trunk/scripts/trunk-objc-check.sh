#!/bin/bash

set -euo pipefail

if [[ -z $1 ]]; then
	echo "Usage: $0 <file_path>"
	exit 1
fi

file="$1"
has_errors=0

if [[ ! -f ${file} ]]; then
	exit 0
fi

if grep -q "@objc public class" "${file}"; then
	class_name=$(grep "@objc public class" "${file}" | awk '{print $4}' | cut -d ':' -f 1)

	unannotated_props=$(grep -E "^\s*public (let|var)" "${file}" | grep -v "@objc" | grep -v "override" || true)

	if [[ -n ${unannotated_props} ]]; then
		echo "❌ Found public properties without @objc in class '${class_name}' (${file}):"
		echo "${unannotated_props}"
		echo ""
		has_errors=1
	fi
fi

exit "${has_errors}"
