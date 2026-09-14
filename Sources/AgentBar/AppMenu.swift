import AppKit

/// The app runs as an accessory (menu bar only), so its menu bar is never shown.
/// It still needs a main menu: AppKit dispatches ⌘X / ⌘C / ⌘V / ⌘A through menu key
/// equivalents, so without an Edit menu those shortcuts do nothing inside the
/// settings text fields. Items keep a `nil` target so they travel the responder chain
/// to whichever field editor is first responder.
enum AppMenu {
    static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(applicationMenuItem())
        mainMenu.addItem(editMenuItem())
        return mainMenu
    }

    static func editMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "编辑")
        menu.addItem(withTitle: "撤销", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
        menu.addItem(withTitle: "重做", action: NSSelectorFromString("redo:"), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item.submenu = menu
        return item
    }

    private static func applicationMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "AgentBar")
        menu.addItem(
            withTitle: "隐藏 AgentBar",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出 AgentBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.submenu = menu
        return item
    }
}
