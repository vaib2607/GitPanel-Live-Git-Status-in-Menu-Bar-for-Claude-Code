import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var repoManager: RepoManager!
    private var viewModel: GitPanelViewModel!
    private var appSettings: AppSettings!
    private var settingsWindow: NSWindow?
    private var settingsDelegate: SettingsWindowDelegate?
    private var localEventMonitor: Any?
    private var observationTask: Task<Void, Never>?

    public override init() {
        super.init()
    }

    private func activateForUI() {
        if let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
            dock.activate()
        }
        NSApp.setActivationPolicy(.regular)
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        repoManager = RepoManager()
        appSettings = AppSettings()
        viewModel = GitPanelViewModel(repoManager: repoManager, settings: appSettings)

        let hosting = NSHostingController(
            rootView: EnvironmentPanel(viewModel: viewModel, repoManager: repoManager)
        )
        hosting.view.wantsLayer = true
        popover = NSPopover()
        popover.contentViewController = hosting
        popover.behavior = .transient

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            updateIcon()
            button.action = #selector(toggleOrMenu(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        startObservation()
        setupKeyboardShortcuts()
        viewModel.startWatching()
    }

    deinit {
        observationTask?.cancel()
        if let m = localEventMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Keyboard shortcuts

    private func setupKeyboardShortcuts() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.popover.isShown else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCmd = flags.contains(.command)
            let isShift = flags.contains(.shift)

            if isCmd {
                switch event.keyCode {
                case 15: // Cmd+R
                    Task { await self.viewModel.refresh() }
                    return nil
                case 36: // Enter
                    if isShift {
                        Task { await self.viewModel.commitAndPush() }
                    } else {
                        Task { await self.viewModel.commit() }
                    }
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    // MARK: - Tooltip

    private func updateTooltip() {
        guard let button = statusItem.button else { return }
        let s = viewModel.state
        guard s.isGitRepo else {
            button.toolTip = "GitPanel — not a git repo"
            return
        }
        var tip = s.branchName
        if s.isAheadOfRemote {
            tip += " ↑\(s.commitCount)"
        }
        button.toolTip = tip
    }

    // MARK: - Observation

    private func startObservation() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                withObservationTracking {
                    self.updateIcon()
                    self.updateTooltip()
                } onChange: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.startObservation()
                    }
                }
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let s = viewModel.state

        let symbolName: String
        if s.isGitRepo {
            switch s.repoState {
            case .clean:
                symbolName = "checkmark.circle.fill"
            case .dirty, .staging:
                symbolName = "arrow.up.circle.fill"
            case .pushing:
                symbolName = "arrow.up.circle.fill"
            case .pulling:
                symbolName = "arrow.down.circle.fill"
            case .merging, .rebasing, .resolving:
                symbolName = "arrow.triangle.branch.circlepath"
            case .mergeConflict:
                symbolName = "exclamationmark.triangle.fill"
            case .cherryPicking, .reverting, .bisecting:
                symbolName = "arrow.triangle.branch.circlepath"
            case .detachedHEAD:
                symbolName = "arrow.triangle.merge"
            }
        } else {
            symbolName = "command.circle"
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "GitPanel")
        button.image?.isTemplate = true
        button.appearsDisabled = viewModel.isRefreshing
    }

    @objc func toggleOrMenu(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let repoItem = NSMenuItem(
            title: "Repository: \(repoManager.repoURL.lastPathComponent)",
            action: nil,
            keyEquivalent: ""
        )
        repoItem.isEnabled = false
        menu.addItem(repoItem)
        menu.addItem(.separator())

        // Switch Repository Submenu
        let switchMenu = NSMenu()
        for path in repoManager.history {
            let url = URL(fileURLWithPath: path)
            let item = NSMenuItem(
                title: url.lastPathComponent,
                action: #selector(switchRepoAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = url
            item.state = (url.path == repoManager.repoURL.path) ? .on : .off
            switchMenu.addItem(item)
        }
        if repoManager.history.isEmpty {
            let emptyItem = NSMenuItem(title: "No History", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            switchMenu.addItem(emptyItem)
        }
        let switchItem = NSMenuItem(title: "Switch Repository", action: nil, keyEquivalent: "")
        switchItem.submenu = switchMenu
        menu.addItem(switchItem)

        // Remove from History Submenu
        let removeMenu = NSMenu()
        for path in repoManager.history {
            let url = URL(fileURLWithPath: path)
            let item = NSMenuItem(
                title: url.lastPathComponent,
                action: #selector(removeRepoAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = path
            removeMenu.addItem(item)
        }
        if repoManager.history.isEmpty {
            let emptyItem = NSMenuItem(title: "No History", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            removeMenu.addItem(emptyItem)
        }
        let removeItem = NSMenuItem(title: "Remove from History", action: nil, keyEquivalent: "")
        removeItem.submenu = removeMenu
        menu.addItem(removeItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit GitPanel", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshAction() {
        Task { await viewModel.refresh() }
    }

    @objc private func switchRepoAction(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            try? repoManager.setRepo(url)
            Task {
                await viewModel.refresh()
                viewModel.startWatching()
            }
        }
    }

    @objc private func removeRepoAction(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String {
            repoManager.removeRepoFromHistory(path)
        }
    }

    @objc func showSettings() {
        activateForUI()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: appSettings))
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable]
            win.title = "GitPanel Settings"
            win.isReleasedWhenClosed = false
            win.center()
            let delegate = SettingsWindowDelegate()
            win.delegate = delegate
            settingsDelegate = delegate
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        viewModel.stopWatching()
        NSApp.terminate(nil)
    }
}

public final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
