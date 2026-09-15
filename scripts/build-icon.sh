#!/bin/zsh
set -eu
readonly PROJECT_ROOT=${0:A:h:h}
readonly BUILD_ROOT=${CODEX_UPDATE_HELPER_BUILD_ROOT:-$PROJECT_ROOT/build}
readonly ICONSET="$BUILD_ROOT/AppIcon.iconset"
/bin/mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$PROJECT_ROOT/assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$(( size * 2 ))
  /usr/bin/sips -z "$retina" "$retina" "$PROJECT_ROOT/assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$BUILD_ROOT/AppIcon.icns"
