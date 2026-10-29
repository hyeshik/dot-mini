import AppKit
import SwiftUI
import YourDotMiniCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(settings: SettingsStore, hotKey: GlobalHotKeyService, login: LaunchAtLoginService,
         fallback: BrowserFallbackCoordinator, openDot: @escaping () -> Void,
         applyEntry: @escaping () -> Void, clearData: @escaping () -> Void) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 680),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "YourDotMini Settings"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 540, height: 480)
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: DotSettingsView(settings: settings, hotKey: hotKey, login: login,
            fallback: fallback, chooseBrowser: { [weak window] in fallback.chooseApp(for: window) },
            openDot: { [weak window] in window?.orderOut(nil); openDot() },
            applyEntry: applyEntry, clearData: clearData))
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    func present() { NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
}

// Use the macOS 14-compatible property wrapper rather than the newer State
// macro, whose compiler plugin is not included in Command Line Tools.
private typealias ViewState<Value> = SwiftUI.State<Value>

private struct DotSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hotKey: GlobalHotKeyService
    @ObservedObject var login: LaunchAtLoginService
    @ObservedObject var fallback: BrowserFallbackCoordinator
    let chooseBrowser: () -> Void
    let openDot: () -> Void
    let applyEntry: () -> Void
    let clearData: () -> Void
    @ViewState private var urlDraft = ""
    @ViewState private var urlConfirmed = false
    @ViewState private var entryMessage: String?
    @ViewState private var shortcutDraft = GlobalShortcut.default
    @ViewState private var shortcutEnabled = true

    var body: some View {
        Form {
            Section {
                Text(settings.value.hasCompletedOnboarding ? "YourDotMini" : "Welcome to YourDotMini").font(.title2.bold())
                Text("An independent, unofficial shortcut to your ChatGPT dot. Sign in only through the website. Local-computer access still requires the official ChatGPT desktop app.")
                    .font(.callout).foregroundStyle(.secondary)
                Link("Dot setup and troubleshooting", destination:
                    URL(string: "https://help.openai.com/en/articles/20001530-getting-started-with-your-dot")!)
                if !settings.value.hasCompletedOnboarding {
                    HStack {
                        Button("Use Embedded Window") {
                            settings.update { $0.browsingMode = .embedded; $0.hasCompletedOnboarding = true }
                            openDot()
                        }.buttonStyle(.borderedProminent)
                        Button("Configure Browser Window…", action: chooseBrowser)
                    }
                }
                if let error = settings.saveError { Text(error).foregroundStyle(.red) }
            }
            Section("Window") {
                Toggle("Hide when switching to another window", isOn: flag(\.hideOnFocusLoss))
                Toggle("Keep open", isOn: flag(\.keepOpen))
                Toggle("Focus message input when the window appears", isOn: flag(\.focusComposerOnShow))
                Toggle("Preload the embedded page when YourDotMini starts", isOn: flag(\.preloadAtLaunch))
                Text("Starts with a 480 × 720 web viewport, then remembers your resized window. ⌘1 restores the default; ⌘2 selects 420 × 520.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Global shortcut") {
                Toggle("Enable global shortcut", isOn: $shortcutEnabled)
                HStack {
                    modifier("Control", GlobalShortcut.control)
                    modifier("Option", GlobalShortcut.option)
                    modifier("Shift", GlobalShortcut.shift)
                    modifier("Command", GlobalShortcut.command)
                    Picker("Key", selection: $shortcutDraft.keyCode) {
                        ForEach(GlobalShortcut.keys, id: \.code) { key in Text(key.name).tag(key.code) }
                    }.frame(width: 100)
                }.disabled(!shortcutEnabled)
                Button("Apply Shortcut") {
                    let candidate = shortcutEnabled ? shortcutDraft : nil
                    if hotKey.apply(candidate) { settings.update { $0.shortcut = candidate } }
                }
                Text(hotKey.message).font(.caption).foregroundStyle(.secondary)
                Text("Use Control or Command. If another app also responds, choose another combination.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Launch at login") {
                Toggle("Launch YourDotMini when I log in", isOn: Binding(get: { login.requested }, set: { enabled in
                    Task { await login.setEnabled(enabled) }
                })).disabled(login.isUpdating)
                Text(login.description).font(.caption).foregroundStyle(.secondary)
                if let error = login.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                Button("Open macOS Login Items", action: login.openSystemSettings)
            }
            Section("Dot destination") {
                TextField("https://chatgpt.com/dots", text: $urlDraft).textFieldStyle(.roundedBorder)
                Toggle("I verified this link opens my dot", isOn: $urlConfirmed)
                Button("Save and Open Dot") {
                    guard let url = DotEntryURL.validate(urlDraft) else { entryMessage = "Use an HTTPS link on chatgpt.com without embedded credentials."; return }
                    guard url == DotIdentity.entryURL || urlConfirmed else { entryMessage = "Verify that the link opens your dot, then confirm above."; return }
                    settings.update { $0.entryURL = url.absoluteString }
                    entryMessage = "Saved."
                    applyEntry()
                }
                if let entryMessage { Text(entryMessage).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Browsing mode") {
                Picker("Open with", selection: Binding(get: { settings.value.browsingMode }, set: { mode in
                    settings.update { $0.browsingMode = mode }
                })) {
                    Text("Embedded window").tag(BrowsingMode.embedded)
                    Text("Dedicated browser web app").tag(BrowsingMode.browserApp).disabled(settings.value.browserAppBookmark == nil)
                }
                Text("For browser mode, create a dedicated web app for your dot in your browser, then select it here. Browser mode uses that app's window and separate sign-in.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Choose Web App…", action: chooseBrowser)
                    Button("Test Open") { fallback.open() }.disabled(settings.value.browserAppBookmark == nil)
                }
                if let name = settings.value.browserAppName { Text("Selected: \(name)").font(.caption) }
                if let message = fallback.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("Open My Dot") {
                    settings.update { $0.hasCompletedOnboarding = true }
                    openDot()
                }
            }
            Section("Website data") {
                Button("Clear YourDotMini Website Data…", role: .destructive, action: clearData)
                Text("Requires confirmation. Signs out only this app; it does not delete ChatGPT history or browser data.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, minHeight: 480)
        .onAppear {
            urlDraft = settings.value.entryURL
            shortcutDraft = settings.value.shortcut ?? .default
            shortcutEnabled = settings.value.shortcut != nil
            login.refresh()
        }
    }

    private func flag(_ path: WritableKeyPath<DotPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { settings.value[keyPath: path] }, set: { value in settings.update { $0[keyPath: path] = value } })
    }
    private func modifier(_ label: String, _ mask: UInt32) -> some View {
        Toggle(label, isOn: Binding(get: { shortcutDraft.modifiers & mask != 0 }, set: { enabled in
            if enabled { shortcutDraft.modifiers |= mask } else { shortcutDraft.modifiers &= ~mask }
        })).toggleStyle(.checkbox)
    }
}
