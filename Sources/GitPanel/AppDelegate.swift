import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var repoManager: RepoManager!
    private var viewModel: EnvironmentViewModel!
    private var appSettings: AppSettings!
    private var settingsWindow: NSWindow?
    private var settingsDelegate: SettingsWindowDelegate?
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    private func activateForUI() {
        if let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
            dock.activate()
        }
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        repoManager = RepoManager()
        appSettings = AppSettings()
        viewModel = EnvironmentViewModel(repoManager: repoManager, settings: appSettings)

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

        observeViewModel()
        setupKeyboardShortcuts()
    }

    deinit {
        if let m = localEventMonitor { NSEvent.removeMonitor(m) }
        if let m = globalEventMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Keyboard shortcuts

    private func setupKeyboardShortcuts() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event) ?? event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)

        guard isCmd else { return nil }

        switch event.keyCode {
        case 15: // Cmd+R
            viewModel.refresh()
            return nil
        case 36: // Enter
            if isShift {
                viewModel.commitAndPush()
            } else {
                viewModel.commit()
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Tooltip

    private func updateTooltip() {
        guard let button = statusItem.button else { return }
        let s = viewModel.snapshot
        guard s.isGitRepo else {
            button.toolTip = "GitPanel — not a git repo"
            return
        }
        var parts = ["\(s.name) — \(s.branch)"]
        if s.ahead > 0 { parts.append("\(s.ahead) ahead") }
        if s.behind > 0 { parts.append("\(s.behind) behind") }
        parts.append(s.state.label)
        button.toolTip = parts.joined(separator: " · ")
    }

    // MARK: - Observation

    private func observeViewModel() {
        viewModel.$snapshot
            .combineLatest(viewModel.$isRefreshing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updateIcon()
                self?.updateTooltip()
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let snapshot = viewModel.snapshot

        let symbolName: String
        if snapshot.isGitRepo {
            switch snapshot.state {
            case .clean:
                symbolName = "command.circle"
            case .dirty, .detachedHEAD:
                symbolName = "arrow.up.circle.fill"
            case .mergeConflict:
                symbolName = "exclamationmark.circle.fill"
            case .rebasing, .cherryPicking, .reverting, .bisecting:
                symbolName = "arrow.triangle.branch.circlepath"
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
        viewModel.refresh()
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
        NSApp.terminate(nil)
    }
}

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
