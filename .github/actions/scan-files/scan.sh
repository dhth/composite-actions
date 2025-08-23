#!/usr/bin/env bash

set -euo pipefail

temp_dir=$(mktemp -d -t vt-scan-XXXXX)
echo "Created temporary directory: ${temp_dir}"

exit_code=0
failed_files=()

for file in "$@"; do
    echo ""
    filename=$(basename "$file")
    result_file="$temp_dir/${filename}.yaml"

    echo "Scanning: $file"

    if ! vt scan file --silent --wait "$file" >"$result_file"; then
        echo "❌ Failed to scan: $file"
        failed_files+=("$file")
        exit_code=1
        continue
    fi

    echo "Saved analysis in: ${result_file}"

    if grep -qE "(confirmed-timeout|failure|harmless|malicious|suspicious|timeout): [1-9]" "$result_file"; then
        echo "⚠️  Issues detected in: $file"
        cat "$result_file"
        failed_files+=("$file")
        exit_code=1
    else
        echo "✅ No issues found in: $file"
    fi
done

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "❌ Failed files: ${failed_files[*]}"
    echo "Results saved in: $temp_dir"
fi

exit $exit_code
