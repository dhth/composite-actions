#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Error: Version parameter is required"
    echo "Usage: $0 <version>"
    exit 1
fi

VT_VERSION="$1"

case "$(uname -s)" in
Linux*)
    case "$(uname -m)" in
    x86_64) PLATFORM="Linux64" ;;
    *) echo "Unsupported architecture: $(uname -m). Only x86_64 is supported." && exit 1 ;;
    esac
    ;;
Darwin*)
    PLATFORM="MacOSX"
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

echo "Installing vt-cli ${VT_VERSION} for ${PLATFORM}..."

temp_dir=$(mktemp -d)
cd "$temp_dir"

curl -sSLf "https://github.com/VirusTotal/vt-cli/releases/download/${VT_VERSION}/${PLATFORM}.zip" -o vt.zip
unzip -q vt.zip

install_dir="$HOME/.local/bin"
mkdir -p "$install_dir"
mv vt "$install_dir/"
chmod +x "$install_dir/vt"

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$install_dir" >>"$GITHUB_PATH"
fi

cd - >/dev/null
rm -rf "$temp_dir"

echo "✅ vt-cli installed successfully to $install_dir/vt"
