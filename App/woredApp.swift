//
//  woredApp.swift
//  wored
//
//  Created by Tercan Keskin on 3.01.2026.
//

import SwiftUI
import AppKit
import Combine
import Darwin

// Color palette is in Extensions/Color+App.swift
// WindowManager is in App/WindowManager.swift
// Window accessors are in App/WindowAccessors.swift
// MenuBarView is in Views/MenuBarView.swift

@main
struct woredApp: App {
    @NSApplicationDelegateAdaptor(WoredAppDelegate.self) private var appDelegate
    @StateObject private var viewModel: AudioPlayerViewModel

    init() {
        WoredAppDelegate.claimInstance()
        _viewModel = StateObject(wrappedValue: AudioPlayerViewModel.shared)
    }
    
    var body: some Scene {
        // Main Player Window
        Window("Wored", id: "player") {
            PlayerView(viewModel: viewModel)
                .background(PlayerWindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
    }
}

final class WoredAppDelegate: NSObject, NSApplicationDelegate {
    private static let instanceLock = SingleInstanceLock()
    private static var hasClaimedInstance = false
    private static let activationNotification = Notification.Name("gupse.wored.activateExistingInstance")

    static func claimInstance() {
        guard !hasClaimedInstance else { return }
        let current = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "gupse.wored")
            .filter { $0.processIdentifier != current.processIdentifier && !$0.isTerminated }
        // Also recognize older installed builds that do not yet acquire the lock.
        if let earlier = others.first(where: {
            let otherDate = $0.launchDate ?? .distantPast
            let currentDate = current.launchDate ?? .distantPast
            return otherDate < currentDate || (otherDate == currentDate && $0.processIdentifier < current.processIdentifier)
        }) {
            activateAndExit(earlier)
        }

        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Wored", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard try instanceLock.acquire(at: directory.appendingPathComponent("instance.lock")) else {
                activateAndExit(others.first)
            }
            hasClaimedInstance = true
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.t(.errorTitle)
            alert.informativeText = L10n.t(.singleInstanceUnavailable)
            alert.addButton(withTitle: L10n.t(.ok))
            alert.runModal()
            exit(EXIT_FAILURE)
        }
    }

    private static func activateAndExit(_ application: NSRunningApplication?) -> Never {
        application?.activate(options: [.activateAllWindows])
        DistributedNotificationCenter.default().postNotificationName(activationNotification, object: nil, userInfo: nil, deliverImmediately: true)
        exit(EXIT_SUCCESS)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarController.shared.install()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showPlayer), name: Self.activationNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPlayer()
        return true
    }

    @objc private func showPlayer() {
        MenuBarController.shared.showPlayer()
    }
}
