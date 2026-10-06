import Cocoa

// 宿主 App 没有界面，唯一职责是承载 PlugIns/ 里的 Finder 扩展，
// 让 pkd 能发现并注册它。启动后以 accessory 身份常驻，不占 Dock 和菜单栏。
final class AppDelegate: NSObject, NSApplicationDelegate {}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
