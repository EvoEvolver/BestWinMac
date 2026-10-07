#!/bin/zsh
set -euo pipefail

root=${0:A:h}
bundle="$root/build/BestWinMac.app"
extension="$bundle/Contents/PlugIns/FinderExt.appex"
target="$(uname -m)-apple-macos11"
launch_agent="$HOME/Library/LaunchAgents/local.zijian.BestWinMac.plist"

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources" "$extension/Contents/MacOS"

swiftc -O "$root/app/BestWinMac.swift" "$root/app/FinderCutInterceptor.swift" \
    "$root/app/CutPasteboardState.swift" "$root/app/HotCornerController.swift" \
    "$root/app/WindowSwitcherController.swift" \
    "$root/app/SettingsPanel.swift" \
    "$root/shared/FeatureSettings.swift" -o "$bundle/Contents/MacOS/BestWinMac" \
    -F /System/Library/PrivateFrameworks -framework SkyLight \
    -framework AppKit -framework ApplicationServices -framework Carbon -framework SwiftUI
swiftc "$root/finder/src/FinderExt.swift" "$root/finder/src/DesktopAlias.swift" \
    "$root/finder/src/NewFile.swift" \
    "$root/shared/FeatureSettings.swift" -o "$extension/Contents/MacOS/FinderExt" -target "$target" -parse-as-library \
    -framework Cocoa -framework FinderSync -Xlinker -e -Xlinker _NSExtensionMain

cp "$root/app/Info.plist" "$bundle/Contents/Info.plist"
cp "$root/finder/src/Ext-Info.plist" "$extension/Contents/Info.plist"
cp "$root/assets/BestWinMac.icns" "$bundle/Contents/Resources/BestWinMac.icns"
cp "$root/assets/BestWinMacMenuBar.png" "$bundle/Contents/Resources/BestWinMacMenuBar.png"
plutil -lint "$bundle/Contents/Info.plist" "$extension/Contents/Info.plist"

codesign --force --sign - --entitlements "$root/finder/src/FinderExt.entitlements" "$extension"
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"

killall BestWinMac >/dev/null 2>&1 || true
ditto "$bundle" /Applications/BestWinMac.app
codesign --verify --deep --strict /Applications/BestWinMac.app

lsregister=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$lsregister" -f /Applications/BestWinMac.app
for attempt in {1..10}; do
    if pluginkit -m -p com.apple.FinderSync | /usr/bin/grep -Eq 'local\.zijian\.BestWinMac\.FinderExt'; then
        break
    fi
    sleep 1
done
pluginkit -e use -i local.zijian.BestWinMac.FinderExt
pluginkit -m -p com.apple.FinderSync | /usr/bin/grep -Eq '^\+[[:space:]]+local\.zijian\.BestWinMac\.FinderExt'

cp "$root/app/local.zijian.BestWinMac.plist" "$launch_agent"
if ! launchctl print "gui/$(id -u)/local.zijian.BestWinMac" >/dev/null 2>&1; then
    launchctl bootstrap "gui/$(id -u)" "$launch_agent"
fi

open -g /Applications/BestWinMac.app
killall Finder >/dev/null 2>&1 || true
echo "BestWinMac installed. Enable its Finder extension and Accessibility permission if macOS requests them."
