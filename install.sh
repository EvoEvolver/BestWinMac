#!/bin/zsh
set -euo pipefail

root=${0:A:h}
build="$root/build"
finder_app="$build/RightOpen.app"
extension="$finder_app/Contents/PlugIns/FinderExt.appex"
utility_app="$build/WinDesktop.app"
target="$(uname -m)-apple-macos11"
launch_agent="$HOME/Library/LaunchAgents/local.zijian.WinDesktop.plist"

mkdir -p "$finder_app/Contents/MacOS" "$extension/Contents/MacOS" "$utility_app/Contents/MacOS"

swiftc "$root/finder/src/HostMain.swift" -o "$finder_app/Contents/MacOS/RightOpen" \
    -target "$target" -framework Cocoa
swiftc "$root/finder/src/FinderExt.swift" "$root/finder/src/DesktopAlias.swift" \
    -o "$extension/Contents/MacOS/FinderExt" -target "$target" -parse-as-library \
    -framework Cocoa -framework FinderSync -Xlinker -e -Xlinker _NSExtensionMain
swiftc -O "$root/utility/WinDesktop.swift" "$root/utility/FinderCutInterceptor.swift" \
    "$root/utility/CutPasteboardState.swift" \
    -o "$utility_app/Contents/MacOS/WinDesktop" -framework AppKit \
    -framework ApplicationServices -framework Carbon

cp "$root/finder/src/Host-Info.plist" "$finder_app/Contents/Info.plist"
cp "$root/finder/src/Ext-Info.plist" "$extension/Contents/Info.plist"
cp "$root/utility/Info.plist" "$utility_app/Contents/Info.plist"
plutil -lint "$finder_app/Contents/Info.plist" "$extension/Contents/Info.plist" "$utility_app/Contents/Info.plist"

codesign --force --sign - --entitlements "$root/finder/src/FinderExt.entitlements" "$extension"
codesign --force --sign - --entitlements "$root/finder/src/FinderExt.entitlements" "$finder_app"
codesign --force --sign - "$utility_app"
codesign --verify --deep --strict "$finder_app"
codesign --verify --deep --strict "$utility_app"

killall WinDesktop >/dev/null 2>&1 || true
killall RightOpen >/dev/null 2>&1 || true
ditto "$finder_app" /Applications/RightOpen.app
ditto "$utility_app" /Applications/WinDesktop.app
codesign --verify --deep --strict /Applications/RightOpen.app
codesign --verify --deep --strict /Applications/WinDesktop.app

lsregister=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$lsregister" -f /Applications/RightOpen.app
pluginkit -e use -i com.gs.RightOpen.FinderExt

cp "$root/utility/local.zijian.WinDesktop.plist" "$launch_agent"
if ! launchctl print "gui/$(id -u)/local.zijian.WinDesktop" >/dev/null 2>&1; then
    launchctl bootstrap "gui/$(id -u)" "$launch_agent"
fi

open -g /Applications/RightOpen.app
open -g /Applications/WinDesktop.app
killall Finder >/dev/null 2>&1 || true
echo "BestWinMac installed. Check Accessibility for WinDesktop and Finder Extensions for RightOpen."
