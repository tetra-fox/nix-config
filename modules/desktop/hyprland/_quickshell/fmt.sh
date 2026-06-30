#!/usr/bin/env bash
QMLFORMAT="$(nix build nixpkgs#kdePackages.qtdeclarative --no-link --print-out-paths 2>/dev/null)/bin/qmlformat"

DIR="$(dirname "$0")/shell"
FILES=$(find "$DIR" -name "*.qml" | sort)
COUNT=$(echo "$FILES" | wc -l)

echo "formatting $COUNT QML files..."
echo "$FILES" | while read -r f; do
    echo "  $(realpath --relative-to="$DIR" "$f")"
    "$QMLFORMAT" -i "$f"
done
echo "done"
