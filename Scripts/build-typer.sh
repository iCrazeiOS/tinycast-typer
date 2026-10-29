#!/usr/bin/env bash
# Compiles Scripts/typer.swift into assets/typer as a universal, ad-hoc-signed binary.
# Universal so an installed extension works on both Apple silicon and Intel Macs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc is required to build assets/typer (install the Xcode command line tools)" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for arch in arm64 x86_64; do
  swiftc -O -target "${arch}-apple-macos14.0" "$root/Scripts/typer.swift" -o "$work/typer-$arch"
done

lipo -create "$work/typer-arm64" "$work/typer-x86_64" -output "$root/assets/typer"
chmod 755 "$root/assets/typer"
codesign --force --sign - "$root/assets/typer" >/dev/null 2>&1 || true

echo "Built assets/typer ($(lipo -archs "$root/assets/typer"))"
