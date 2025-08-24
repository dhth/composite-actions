#!/usr/bin/env bash

# VirusTotal file scanning utility
#
# - Requires VTCLI_APIKEY environment variable and 'vt' CLI tool
# - Scans multiple files using 'vt' and reports security issues
# - Exits with non-zero status if any of the following occurs:
#   - Analysis suggests malicious/suspicious content in one or more files
#   - Analysis times out
#   - Analysis fails
#   - Analysis not found

set -euo pipefail

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] FILE [FILE...]

Scan files using VirusTotal.

Arguments:
  FILE                 One or more files to scan

Options:
  -h, --help           Show this help message

Environment:
  VTCLI_APIKEY         VirusTotal API key (required)

Requirements:
  - vt CLI tool must be installed

Examples:
  $0 ./dist/hours_linux_amd64_v1/hours
  $0 ./dist/hours_*/hours
EOF
}

# Check for help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [ -z "${VTCLI_APIKEY:-}" ]; then
    echo 'Error: $VTCLI_APIKEY is not set'
    exit 1
fi

tools=("vt")

for tool in "${tools[@]}"; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "Error: \"$tool\" not found"
        exit 1
    fi
done

if [ $# -eq 0 ]; then
    echo "Error: No files provided"
    echo "Use -h or --help for usage information"
    exit 1
fi

temp_dir=$(mktemp -d -t vt-scan-XXXXX)
trap 'rm -rf "$temp_dir"' EXIT

exit_code=0
failed_files=()

for file in "$@"; do
    echo -e "\n"
    file_hash=$(echo -n "$file" | shasum -a 256 | cut -d' ' -f1 | head -c 8)
    results_file_name=$(echo "$file" | tr '/' '-' | sed 's/^[.-]*//')
    result_file="$temp_dir/${results_file_name}-${file_hash}.yml"

    echo "🔎 Scanning: $file"

    if ! vt scan file --silent --wait --include '_id,last_analysis_stats' "$file" >"$result_file"; then
        echo "❌ Failed to scan: $file"
        failed_files+=("$file")
        exit_code=1
        continue
    fi

    # analysis file looks like this:
    # - _id: "db70c2d83295fece9592acae7a54b49ca9687078541e630a4637c52a78e04e32"
    #   last_analysis_stats:
    #     confirmed-timeout: 0
    #     failure: 0
    #     harmless: 0
    #     malicious: 0
    #     suspicious: 0
    #     timeout: 0
    #     type-unsupported: 12
    #     undetected: 64

    if ! grep -q "last_analysis_stats:" "$result_file"; then
        echo "⚠️  No analysis stats found for: $file"
        cat "$result_file"
        failed_files+=("$file")
        exit_code=1
    elif grep -qE "(confirmed-timeout|timeout): [1-9]" "$result_file"; then
        echo "⚠️  Analysis timed out for: $file"
        cat "$result_file"
        failed_files+=("$file")
        exit_code=1
    elif grep -qE "failure: [1-9]" "$result_file"; then
        echo "⚠️  Analysis failed for: $file"
        cat "$result_file"
        failed_files+=("$file")
        exit_code=1
    elif grep -qE "(malicious|suspicious): [1-9]" "$result_file"; then
        echo "⚠️  Issues detected in: $file"
        cat "$result_file"
        failed_files+=("$file")
        exit_code=1
    else
        echo "✅ No issues found in: $file"
    fi

    file_id=$(grep -o '_id: "[^"]*"' "$result_file" | cut -d'"' -f2)
    if [ -n "$file_id" ]; then
        echo "Details: https://www.virustotal.com/gui/file/${file_id}"
    fi
done

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "❌ Failed files: ${failed_files[*]}"
fi

exit $exit_code
