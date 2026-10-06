# BestWinMac

本机 macOS 的 Windows 风格小功能，集中在一个 App 和这个仓库。构建只需 Command Line Tools，不需要完整 Xcode。

| 功能 | 使用方式 | 实现 |
| --- | --- | --- |
| 显示桌面 / 恢复窗口 | 全局 `⌘D` | 最小化当前桌面窗口；点击桌面不会自动恢复 |
| Finder 剪切 / 移动 | Finder 中 `⌘X`、目标文件夹中 `⌘V` | Finder 原生复制及“移动项目”操作；其他 App 的快捷键不受影响 |
| 用 VS Code 打开 | Finder 文件、文件夹、文件夹替身的顶层右键菜单 | Finder Sync 扩展 |
| Copy Path | Finder 顶层右键菜单 | 复制完整路径，多选时每行一个 |
| 发送到桌面快捷方式 | Finder 顶层右键菜单 | 创建 macOS 替身，不移动源文件 |
| 新建 Markdown 文件 | Finder 顶层右键菜单 | 文件夹内、文件同级或空白处当前目录新建空白 `.md` 文件，重名时自动编号 |

## 安装

```sh
./install.sh
```

安装脚本编译并安装 `/Applications/BestWinMac.app`，注册内含的 Finder 扩展与登录启动项。首次使用窗口和键盘功能时，需要在“系统设置 → 隐私与安全性 → 辅助功能”允许 BestWinMac。点击菜单栏中的 BestWinMac 图标，再选“设置…”可分别开关上述六项功能；设置立即生效并持久保存。

原 cmdX 项目采用 MIT 许可证。Finder 剪切的快捷键转换思路参考了 [YONN2222/cmdX](https://github.com/YONN2222/cmdX)，许可证见 `third_party/cmdX-LICENSE`。RightOpen 来源及其 MIT 许可证见 `finder/LICENSE`。

## 目录

- `finder/`: Finder Sync 扩展和桌面替身测试。
- `app/`: 菜单栏 App、全局显示桌面与 Finder 剪切。
- `shared/`: App 和 Finder 扩展共用的功能设置。
- `install.sh`: 本机编译、签名、安装与注册。
- `tools/render_icon.swift`: App 与菜单栏图标的可重建绘制源码；运行 `./tools/build_icon.sh` 更新 `assets/`。

## 本地测试

```sh
mkdir -p build
swiftc finder/src/DesktopAlias.swift finder/tests/DesktopAliasTests.swift -o build/DesktopAliasTests
./build/DesktopAliasTests --desktop
swiftc app/CutPasteboardState.swift app/tests/CutPasteboardStateTests.swift -o build/CutPasteboardStateTests
./build/CutPasteboardStateTests
swiftc shared/FeatureSettings.swift shared/tests/FeatureSettingsTests.swift -o build/FeatureSettingsTests
./build/FeatureSettingsTests
swiftc finder/src/DesktopAlias.swift finder/src/NewFile.swift finder/tests/NewFileTests.swift -o build/NewFileTests
./build/NewFileTests
```
