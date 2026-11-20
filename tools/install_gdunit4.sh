#!/bin/bash
# Installs gdUnit4, the test library, into addons/gdUnit4 (not committed).
set -euo pipefail

VERSION="6.2.3"
SHA256="42dc61721b1b6bc40dac0ff34a71d2b0811ca92109add0b923ad01f96f04abf8"
URL="https://github.com/MikeSchulze/gdUnit4/archive/refs/tags/v$VERSION.tar.gz"

root="$(cd "$(dirname "$0")/.." && pwd)"
target="$root/addons/gdUnit4"

if [ -f "$target/plugin.cfg" ] && grep -q "version=\"$VERSION\"" "$target/plugin.cfg"; then
	echo "gdUnit4 $VERSION already installed."
	exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -sSLf -o "$work/gdunit4.tar.gz" "$URL"
echo "$SHA256  $work/gdunit4.tar.gz" | shasum -a 256 -c - > /dev/null
tar -xzf "$work/gdunit4.tar.gz" -C "$work" "gdUnit4-$VERSION/addons/gdUnit4"

rm -rf "$target"
cp -R "$work/gdUnit4-$VERSION/addons/gdUnit4" "$target"
echo "gdUnit4 $VERSION installed."
