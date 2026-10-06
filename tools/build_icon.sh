#!/bin/zsh
set -euo pipefail

root=${0:A:h:h}
mkdir -p "$root/assets" "$root/build"
iconset="$root/build/BestWinMac.iconset"
swift "$root/tools/render_icon.swift" "$iconset" \
    "$root/assets/BestWinMac-1024.png" "$root/assets/BestWinMacMenuBar.png"
iconutil -c icns "$iconset" -o "$root/assets/BestWinMac.icns"
