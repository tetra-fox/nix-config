#!/usr/bin/env bash
QMLLINT="$(nix build nixpkgs#kdePackages.qtdeclarative --no-link --print-out-paths 2>/dev/null)/bin/qmllint"

DIR="$(dirname "$0")/shell"
FILES=$(find "$DIR" -name "*.qml" | sort)
COUNT=$(echo "$FILES" | wc -l)

echo "linting $COUNT QML files..."
FAILED=0
echo "$FILES" | while read -r f; do
    REL="$(realpath --relative-to="$DIR" "$f")"
    OUTPUT=$("$QMLLINT" "$f" 2>&1)
    if [ $? -ne 0 ]; then
        echo "  FAIL  $REL"
        echo "$OUTPUT" | sed 's/^/    /'
        FAILED=$((FAILED + 1))
    else
        echo "  OK    $REL"
    fi
done
echo "done"
