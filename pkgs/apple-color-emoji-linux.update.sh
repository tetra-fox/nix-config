#!/usr/bin/env bash
set -euo pipefail

REPO="samuelngs/apple-emoji-ttf"
ASSET="AppleColorEmoji-Linux.ttf"
NIX_FILE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/apple-color-emoji-linux.nix"

release=$(gh release view --repo "$REPO" --json tagName,assets)
tag=$(jq -r '.tagName' <<<"$release")
url=$(jq -r --arg name "$ASSET" '.assets[] | select(.name == $name) | .url' <<<"$release")

# release tags look like macos-26-20260219-<shorthash>, strip trailing -<shorthash> for the version
version="${tag%-*}"
current=$(grep -oP 'version = "\K[^"]+' "$NIX_FILE")

if [[ "$current" == "$version" ]]; then
  echo "already at $version"
  exit 0
fi

hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r '.hash')

sed -i -E "
  s|version = \".*\";|version = \"$version\";|
  s|url = \".*\";|url = \"$url\";|
  s|hash = \".*\";|hash = \"$hash\";|
" "$NIX_FILE"

echo "updated $current -> $version"
