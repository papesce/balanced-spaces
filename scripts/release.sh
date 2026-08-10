#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CHANGELOG="CHANGELOG.md"
PLIST="Info.plist"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>  e.g. $0 0.1.2" >&2
    exit 1
fi
VERSION="$1"

if ! grep -q '^## \[Unreleased\]' "$CHANGELOG"; then
    echo "Error: no [Unreleased] section found in $CHANGELOG" >&2
    exit 1
fi

DATE=$(date +%Y-%m-%d)
BUILD=$(($(plutil -extract CFBundleVersion raw "$PLIST") + 1))

sed -i '' "s|^## \[Unreleased\]|## [$VERSION] - $DATE|" "$CHANGELOG"
sed -i '' -e "/<key>CFBundleShortVersionString<\/key>/,+1 s|<string>[^<]*</string>|<string>$VERSION</string>|" \
          -e "/<key>CFBundleVersion<\/key>/,+1 s|<string>[^<]*</string>|<string>$BUILD</string>|" \
          "$PLIST"

git add "$CHANGELOG" "$PLIST"
git commit -m "Bump version to $VERSION"
git tag "v$VERSION"

echo "Released v$VERSION"
