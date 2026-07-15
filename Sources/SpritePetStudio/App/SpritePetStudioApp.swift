import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        model.start()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu(title: "桌宠工坊")
        let settingsItem = NSMenuItem(
            title: "打开设置…",
            action: #selector(openSettingsFromDock),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        return menu
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        model.openSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func openSettingsFromDock() {
        model.openSettings()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: value),
              url.scheme == "spritepet",
              url.host == "trigger" else { return }
        let name = url.pathComponents.dropFirst().joined(separator: "/").removingPercentEncoding ?? ""
        guard !name.isEmpty else { return }
        model.postExternalTrigger(name)
    }
}

@main
struct SpritePetStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("桌宠工坊", systemImage: "pawprint.fill") {
            MenuBarContent(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Toggle("启用桌宠显示（总开关）", isOn: model.bindingForGeneral(\.isPetVisible))
        Menu("立即播放") {
            if model.visibleProjects.isEmpty {
                Text("工程库中没有启用显示的工程")
            } else {
                ForEach(model.visibleProjects) { project in
                    Menu(project.name) {
                        ForEach(project.actions.filter(\.isEnabled)) { action in
                            Button(action.name) {
                                model.playAction(id: action.id, projectID: project.id)
                            }
                        }
                    }
                }
            }
        }
        Divider()
        Button("设置…") { model.openSettings() }
        Button("将所有可见桌宠移回屏幕") { model.resetWindowPosition() }
        Divider()
        Button("退出桌宠工坊") { NSApp.terminate(nil) }
    }
}
