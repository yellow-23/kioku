#!/bin/bash
# Uso: ./release.sh 1.0.1
set -euo pipefail
V="${1:?uso: ./release.sh <version>}"
OUT=$(mktemp -d)

xcodebuild -project kioku.xcodeproj -scheme kioku -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUT/kioku.xcarchive" archive | cat
# ponytail: el | cat evita que xcodebuild vea un tty y le pase -fmessage-length=<ancho>
# a clang; ese flag cambia con el tamano de la ventana y rompe el cache de modulos

# ponytail: copia directa del .app del archive; -exportArchive solo hace falta si firmas/notarizas
ditto -c -k --keepParent "$OUT/kioku.xcarchive/Products/Applications/kioku.app" "$OUT/kioku-$V-macos.zip"

gh release create "v$V" "$OUT/kioku-$V-macos.zip" --title "v$V" --generate-notes --notes \
"## Instalacion

1. Descomprime el zip y arrastra \`kioku.app\` a \`/Applications\`.
2. Abre Terminal y corre:

\`\`\`
xattr -dr com.apple.quarantine /Applications/kioku.app
\`\`\`

3. Abre la app.

El paso 2 hace falta porque la app no esta notarizada por Apple. Solo se hace una vez.
"
echo "sha256: $(shasum -a 256 "$OUT/kioku-$V-macos.zip" | cut -d' ' -f1)"
