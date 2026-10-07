# BestWinMac

为 macOS 添加一些 Windows 风格的小功能，集中在一个菜单栏 App 和 Finder 扩展中。构建只需 Apple Command Line Tools，不需要完整的 Xcode。

[English](README.md)

| 功能 | 入口 | 行为 |
| --- | --- | --- |
| Show Desktop / Restore Windows | 全局 `⌘D` | 最小化当前桌面的窗口；用 `⌘Tab` 选中 App 时恢复该 App 的窗口，点击桌面则不会自动恢复 |
| 显示桌面触发角 | 主显示器右下角 | 停留 300ms 后切换同一套显示桌面状态；离开角落不会恢复窗口 |
| 窗口切换器 | 全局 `⌘Tab` / `⌘⇧Tab` | 用所有单独窗口（包括最小化窗口）的平铺界面替代 App 切换器；松开 `⌘` 时只将选中窗口带到最前 |
| Finder 剪切 / 移动 | Finder 中的 `⌘X` 和 `⌘V` | 使用 Finder 原生的复制与移动命令，不影响其他 App |
| Open with VS Code | 文件、文件夹和文件夹替身的顶层右键菜单 | 使用 VS Code 打开选中项 |
| Copy Path | Finder 顶层右键菜单 | 复制完整路径，多选时每行一条 |
| Create Desktop Shortcut | Finder 顶层右键菜单 | 创建 macOS 替身，不移动源文件 |
| New Markdown File | Finder 顶层右键菜单 | 在文件夹内、文件同级或当前文件夹新建空白 `.md` 文件；重名时自动编号 |

## 安装

```sh
./install.sh
```

脚本会构建并安装 `/Applications/BestWinMac.app`，注册 Finder 扩展及登录启动项。点击菜单栏中的 BestWinMac 图标，选择 **Settings...**，可以分别开关各项功能；设置立即生效，重启后仍会保留。

键盘和窗口功能需要在 **系统设置 > 隐私与安全性 > 辅助功能** 中允许 BestWinMac。安装脚本使用临时签名，因此更新后旧授权可能失效。如果 `⌘D` 或 Finder 剪切停止工作，运行 `tccutil reset Accessibility local.zijian.BestWinMac`，再在辅助功能设置中重新添加 `/Applications/BestWinMac.app`。

窗口级前置使用 macOS 的私有 SkyLight framework，因为公开激活 API 的操作对象是整个 App，而不是跨 App 的单个窗口。这个方案适合本地安装的小工具，但 macOS 大版本更新后需要重新测试。

Finder 剪切的快捷键转换思路参考采用 MIT 许可证的 [YONN2222/cmdX](https://github.com/YONN2222/cmdX)，许可证见 `third_party/cmdX-LICENSE`。RightOpen 的来源和 MIT 许可证见 `finder/LICENSE`。

## 目录

- `app/`：菜单栏 App、窗口切换器、显示桌面和 Finder 剪切快捷键。
- `finder/`：Finder Sync 扩展及文件、替身测试。
- `shared/`：两个进程共用的功能设置。
- `install.sh`：构建、签名、安装和注册。
- `tools/render_icon.swift`：可重建的 App 和菜单栏图标源码；运行 `./tools/build_icon.sh` 更新 `assets/`。

## 本地测试

运行 [英文 README](README.md#local-tests) 中的命令。
