#!/bin/bash
# Uso: ./release.sh 1.0.1
set -euo pipefail
V="${1:?uso: ./release.sh <version>}"
OUT=$(mktemp -d)

xcodebuild -project kioku.xcodeproj -scheme kioku -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUT/kioku.xcarchive" archive

# ponytail: copia directa del .app del archive; -exportArchive solo hace falta si firmas/notarizas
ditto -c -k --keepParent "$OUT/kioku.xcarchive/Products/Applications/kioku.app" "$OUT/kioku-$V-macos.zip"

gh release create "v$V" "$OUT/kioku-$V-macos.zip" --title "v$V" --generate-notes
echo "sha256: $(shasum -a 256 "$OUT/kioku-$V-macos.zip" | cut -d' ' -f1)"
