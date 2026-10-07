# BestWinMac

Small Windows-style conveniences for macOS, packaged as one menu bar app with a Finder extension. Building requires only Apple's Command Line Tools, not the full Xcode app.

[Chinese version](README.zh-CN.md)

| Feature | Where | Behavior |
| --- | --- | --- |
| Show Desktop / Restore Windows | Global `⌘D` | Minimizes windows on the current desktop; selecting an app with `⌘Tab` restores that app's windows, while clicking the desktop does not restore them |
| Show Desktop hot corner | Bottom-right corner of the primary display | Toggles the same desktop state after a 300 ms dwell; leaving the corner does not restore windows |
| Cut / move files | `⌘X` and `⌘V` in Finder | Uses Finder's native Copy and Move Item commands; other apps are unaffected |
| Open with VS Code | Top-level Finder context menu for files, folders, and folder aliases | Opens the selected item in VS Code |
| Copy Path | Top-level Finder context menu | Copies full paths, one per line for multiple items |
| Create Desktop Shortcut | Top-level Finder context menu | Creates a macOS alias without moving the source |
| New Markdown File | Top-level Finder context menu | Creates an empty `.md` file inside a folder, beside a file, or in the current folder; numbers duplicate names |

## Install

```sh
./install.sh
```

The script builds and installs `/Applications/BestWinMac.app`, registers its Finder extension, and sets it to launch at login. Open **Settings...** from the BestWinMac menu bar icon to toggle each feature independently. Changes take effect immediately and persist across launches.

The keyboard and window features need BestWinMac enabled in **System Settings > Privacy & Security > Accessibility**. The installer uses ad-hoc signing, so rebuilding the app can invalidate its previous approval. If `⌘D` or Finder cut stops working after an update, reset only this app's approval with `tccutil reset Accessibility local.zijian.BestWinMac`, then add `/Applications/BestWinMac.app` in Accessibility settings again.

Finder cut follows the shortcut-conversion approach of the MIT-licensed [YONN2222/cmdX](https://github.com/YONN2222/cmdX); see `third_party/cmdX-LICENSE`. RightOpen's origin and MIT license are recorded in `finder/LICENSE`.

## Layout

- `app/`: Menu bar app, Show Desktop shortcut, and Finder cut shortcut.
- `finder/`: Finder Sync extension and file/alias tests.
- `shared/`: Feature settings used by both processes.
- `install.sh`: Build, sign, install, and register the app.
- `tools/render_icon.swift`: Reproducible app and menu bar icon source; run `./tools/build_icon.sh` to update `assets/`.

## Local Tests

```sh
mkdir -p build
swiftc finder/src/DesktopAlias.swift finder/tests/DesktopAliasTests.swift -o build/DesktopAliasTests
./build/DesktopAliasTests --desktop
swiftc app/CutPasteboardState.swift app/tests/CutPasteboardStateTests.swift -o build/CutPasteboardStateTests
./build/CutPasteboardStateTests
swiftc app/HotCornerController.swift app/tests/HotCornerTriggerTests.swift -o build/HotCornerTriggerTests -framework AppKit
./build/HotCornerTriggerTests
swiftc shared/FeatureSettings.swift shared/tests/FeatureSettingsTests.swift -o build/FeatureSettingsTests
./build/FeatureSettingsTests
swiftc finder/src/DesktopAlias.swift finder/src/NewFile.swift finder/tests/NewFileTests.swift -o build/NewFileTests
./build/NewFileTests
```
