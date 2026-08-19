import SwiftUI
import Cocoa
import ApplicationServices
import ServiceManagement
// Combine provides ObservableObject and @Published; member import visibility is
// enabled, so SwiftUI does not re-export them implicitly.
import Combine

/// Marketing version from the generated Info.plist, so the menu never drifts from the build.
private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

/// NX_SYSDEFINED / NSEvent.EventType.systemDefined. Carries the media keys
/// (play/pause, brightness, volume), which `CGEventType` has no case for.
private let nxSysDefinedEventType: UInt32 = 14

/// NX_SUBTYPE_AUX_CONTROL_BUTTONS — marks a system-defined event as a media key.
private let nxAuxControlButtonsSubtype: Int16 = 8

/// System Settings renamed the Accessibility pane to "Device Control and Data
/// Access" in macOS 27. Both names come from the pane's own localization table
/// (`SecurityPrivacyExtension.appex`, key `ACCESSIBILITY`).
private var accessibilityPaneName: String {
    if #available(macOS 27, *) {
        return String(
            localized: "permissions.accessibility.current",
            defaultValue: "Device Control and Data Access",
            comment: "Name of the Accessibility privacy pane in macOS 27 and later."
        )
    }
    return String(
        localized: "permissions.accessibility.legacy",
        defaultValue: "Accessibility",
        comment: "Name of the Accessibility privacy pane in macOS 26 and earlier."
    )
}

/// German and Spanish also received new Input Monitoring labels in macOS 27.
private var inputMonitoringPaneName: String {
    if #available(macOS 27, *) {
        return String(
            localized: "permissions.inputMonitoring.current",
            defaultValue: "Input Monitoring",
            comment: "Name of the Input Monitoring privacy pane in macOS 27 and later."
        )
    }
    return String(
        localized: "permissions.inputMonitoring.legacy",
        defaultValue: "Input Monitoring",
        comment: "Name of the Input Monitoring privacy pane in macOS 26 and earlier."
    )
}

private enum PrivacyPane { case inputMonitoring, accessibility }

private enum SystemSettingsOpener {
    static func open(_ pane: PrivacyPane) {
        // NSWorkspace.open() reports success for any x-apple.systempreferences URL,
        // even when the anchor is unknown — an unknown anchor just lands on the
        // generic Privacy & Security page. So there is no way to detect a bad anchor
        // and fall back; it has to be correct the first time.
        // Input Monitoring's anchor is Privacy_ListenEvent. There is no
        // Privacy_InputMonitoring anchor.
        let anchor: String
        switch pane {
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .accessibility: anchor = "Privacy_Accessibility"
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A titled switch row, matching the panel's layout for both toggles.
private struct ToggleRow: View {
    let title: LocalizedStringKey
    let isOn: Bool
    let set: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)

            Spacer()

            Toggle(isOn: Binding(get: { isOn }, set: set)) {
                EmptyView()
            }
                .labelsHidden()
                .toggleStyle(.switch)
                // Matches the switch size System Settings uses; SwiftUI's default
                // .regular switch is oversized for a menu bar panel.
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}

/// Secondary explanatory line shown under a row when something needs attention.
private struct HintText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
    }
}

/// Rounded highlight on hover, shared by every clickable row in the panel.
private struct HoverHighlight: ViewModifier {
    @State private var isHover = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .onHover { isHover = $0 }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHover ? Color.secondary.opacity(0.15) : Color.clear)
            )
    }
}

/// A settings row: full width and leading aligned, with one shared click and hover area.
/// Quit uses `hoverHighlight()` directly, since it sits right aligned in the footer.
private struct SettingsRow: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(HoverHighlight())
    }
}

private extension View {
    func settingsRow() -> some View { buttonStyle(SettingsRow()) }
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}

@main
struct CleankeyApp: App {
    @StateObject private var blocker = KeyboardBlocker()
    @StateObject private var loginItem = LoginItem()
    @StateObject private var updates = UpdateChecker()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Cleankey", systemImage: blocker.isBlocking ? "keyboard.fill" : "keyboard") {
            VStack(alignment: .leading, spacing: 8) {
                ToggleRow(title: "Keyboard Cleaning", isOn: blocker.isBlocking) {
                    blocker.setBlocking($0)
                }

                if let failureMessage = blocker.failureMessage {
                    HintText(text: failureMessage)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        SystemSettingsOpener.open(.inputMonitoring)
                    } label: {
                        HStack {
                            Text(verbatim: "\(inputMonitoringPaneName)…")
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: blocker.hasInputMonitoringPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(blocker.hasInputMonitoringPermission ? Color.green : Color.red)
                                .imageScale(.medium)
                                .fixedSize()
                                .accessibilityLabel(
                                    blocker.hasInputMonitoringPermission ? Text("Granted") : Text("Not granted")
                                )
                        }
                    }
                    .settingsRow()

                    Button {
                        SystemSettingsOpener.open(.accessibility)
                    } label: {
                        HStack {
                            Text(verbatim: "\(accessibilityPaneName)…")
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: blocker.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(blocker.hasAccessibilityPermission ? Color.green : Color.red)
                                .imageScale(.medium)
                                .fixedSize()
                                .accessibilityLabel(
                                    blocker.hasAccessibilityPermission ? Text("Granted") : Text("Not granted")
                                )
                        }
                    }
                    .settingsRow()
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(title: "Open at Login", isOn: loginItem.isEnabled) {
                        loginItem.setEnabled($0)
                    }

                    if let message = loginItem.message {
                        HintText(text: message)
                    }

                    Button(updates.title) { updates.act() }
                        .foregroundStyle(updates.isInformational ? Color.secondary : Color.primary)
                        .settingsRow()
                        .disabled(updates.isChecking)
                }

                Divider()

                HStack {
                    Text(verbatim: "v\(appVersion)")
                        .font(.body)
                        .padding(.horizontal, 6)

                    Spacer()

                    Button("Quit Cleankey") { NSApp.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.body)
                        .hoverHighlight()
                }
            }
            .padding(8)
            .frame(width: 256)
            .onAppear {
                blocker.refreshPermissionStatus()
                blocker.requestPermissionsIfNeeded()
                // The user can change this in System Settings, so re-read it
                // every time the panel opens rather than trusting cached state.
                loginItem.refresh()
                updates.reset()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we live only in the menu bar (no Dock icon/app switcher)
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
}

/// Compares the running version against the latest GitHub release. Deliberately
/// installs nothing: the user downloads and replaces the app. That keeps Cleankey
/// free of an update framework, its XPC services, and their signing requirements.
///
/// The row's label *is* the state, so there is no separate status line, and the
/// button always performs the sensible next action for that state.
final class UpdateChecker: ObservableObject {
    enum State {
        case idle
        case checking
        case upToDate
        case available(String)
        case failed
    }

    @Published private(set) var state: State = .idle

    private let apiURL = URL(string: "https://api.github.com/repos/kcin1107/Cleankey/releases/latest")!
    private static let releasesURL = URL(string: "https://github.com/kcin1107/Cleankey/releases/latest")!

    var title: String {
        switch state {
        case .idle: return String(localized: "Check for Updates…")
        case .checking: return String(localized: "Checking…")
        case .upToDate: return String(localized: "Cleankey is up to date!")
        case .available(let version):
            return String(
                localized: "updates.download",
                defaultValue: "Download \(version)…",
                comment: "Action to download the available version. The argument is a version number."
            )
        case .failed: return String(localized: "Couldn\u{2019}t check for updates")
        }
    }

    var isChecking: Bool {
        if case .checking = state { return true }
        return false
    }

    var isInformational: Bool {
        switch state {
        case .checking, .upToDate: return true
        default: return false
        }
    }

    /// Download when one is waiting, otherwise check — or check again, so the
    /// up-to-date and failed states double as a retry.
    func act() {
        if case .available = state {
            NSWorkspace.shared.open(Self.releasesURL)
        } else {
            check()
        }
    }

    /// Called when the panel opens so a stale result doesn't linger as the label.
    func reset() {
        if !isChecking { state = .idle }
    }

    private func check() {
        guard !isChecking else { return }
        state = .checking

        Task {
            do {
                var request = URLRequest(url: apiURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)
                let tag = try JSONDecoder().decode(GitHubRelease.self, from: data).tagName
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

                // Numeric compare so 1.10 sorts above 1.9.
                state = latest.compare(appVersion, options: .numeric) == .orderedDescending
                    ? .available(latest)
                    : .upToDate
            } catch {
                state = .failed
            }
        }
    }
}

/// Wraps `SMAppService.mainApp` so the menu can show and change whether Cleankey
/// launches at login.
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var message: String?

    init() { refresh() }

    /// Reads the live status. `.requiresApproval` means the user has switched
    /// Cleankey off in System Settings, which the app cannot override.
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        if status == .requiresApproval {
            if #available(macOS 15, *) {
                message = String(
                    localized: "loginItem.approval.current",
                    defaultValue: "Allow Cleankey in System Settings › General › Login Items & Extensions.",
                    comment: "Tells the user where to approve Cleankey as a login item in macOS 15 and later."
                )
            } else {
                message = String(
                    localized: "loginItem.approval.legacy",
                    defaultValue: "Allow Cleankey in System Settings › General › Login Items.",
                    comment: "Tells the user where to approve Cleankey as a login item in macOS 13 and 14."
                )
            }
        } else if isEnabled || status == .notRegistered {
            message = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            message = nil
        } catch {
            message = String(
                localized: "loginItem.changeError",
                defaultValue: "Couldn't change Open at Login: \(error.localizedDescription)",
                comment: "Error shown when changing the login item fails. The argument is the system error."
            )
        }
        refresh()
    }
}

final class KeyboardBlocker: ObservableObject {
    /// Owned here rather than written by the view: it turns true only once the tap is
    /// installed, so the switch can never show a lock that isn't actually in effect.
    @Published private(set) var isBlocking: Bool = false

    /// Set when the event tap could not be created, so the menu can explain why the
    /// switch stayed off instead of leaving the user guessing.
    @Published private(set) var failureMessage: String?

    /// Live preflight results shown beside the System Settings shortcuts.
    @Published private(set) var hasAccessibilityPermission = AXIsProcessTrusted()
    @Published private(set) var hasInputMonitoringPermission = CGPreflightListenEventAccess()

    // Event tap state
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Public control

    /// Single entry point for the menu's switch.
    func setBlocking(_ shouldBlock: Bool) {
        refreshPermissionStatus()
        if shouldBlock {
            startBlocking()
        } else {
            stopBlocking()
        }
    }

    func startBlocking() {
        guard eventTap == nil else { return }
        // CGEvent.tapCreate can silently remove event types the process may not
        // monitor while still returning a tap for the remaining mask. Refuse to
        // report success unless both permissions required for keyboard events exist.
        let missing = missingPermissions
        guard missing.isEmpty else {
            failureMessage = missingPermissionsMessage(missing)
            requestPermissionsIfNeeded()
            return
        }

        // Key down, key up, modifier changes, and the system-defined events that
        // carry media keys (play/pause, brightness, volume).
        let eventTypes: [UInt64] = [
            UInt64(CGEventType.keyDown.rawValue),
            UInt64(CGEventType.keyUp.rawValue),
            UInt64(CGEventType.flagsChanged.rawValue),
            UInt64(nxSysDefinedEventType)
        ]
        let mask = eventTypes.reduce(into: UInt64(0)) { $0 |= 1 << $1 }

        // Create the event tap at the HID level so we can suppress events system-wide.
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: KeyboardBlocker.eventTapCallback,
            userInfo: refcon
        ) else {
            // Stay unblocked and name what is actually missing. Both privileges
            // granted but the tap still failing means the grant predates this
            // process and needs a relaunch to take effect.
            let missing = missingPermissions
            failureMessage = missing.isEmpty
                ? String(localized: "Couldn't lock the keyboard. Quit and reopen Cleankey, then try again.")
                : missingPermissionsMessage(missing)
            requestPermissionsIfNeeded()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)

        failureMessage = nil
        isBlocking = true
    }

    func stopBlocking() {
        teardownTap()
        isBlocking = false
    }

    /// Tears the tap down without touching published state, so `deinit` can reuse it.
    private func teardownTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            // Invalidate the Mach port so it isn't leaked on every toggle cycle.
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
    }

    // MARK: - Permissions

    /// Re-reads both privileges because they can be changed outside the app.
    func refreshPermissionStatus() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        hasInputMonitoringPermission = CGPreflightListenEventAccess()
    }

    /// Privileges the tap needs but doesn't have. A suppressing tap requires both:
    /// Accessibility to drop events, Input Monitoring to receive them at all.
    private var missingPermissions: [String] {
        var missing: [String] = []
        if !AXIsProcessTrusted() { missing.append(accessibilityPaneName) }
        if !CGPreflightListenEventAccess() { missing.append(inputMonitoringPaneName) }
        return missing
    }

    private func missingPermissionsMessage(_ missing: [String]) -> String {
        if missing.count == 1 {
            return String(
                localized: "permissions.missing.one",
                defaultValue: "\(missing[0]) not granted. Enable below, then reopen Cleankey.",
                comment: "Shown when one required permission is missing. The argument is its localized name."
            )
        }
        return String(
            localized: "permissions.missing.multiple",
            defaultValue: "\(missing[0]) and \(missing[1]) not granted. Enable both below, then reopen Cleankey.",
            comment: "Shown when both required permissions are missing. The arguments are their localized names."
        )
    }

    /// Prompts for whichever privileges are missing, each via its own system alert.
    /// Granting either one does not affect the running process — macOS applies it
    /// only after the app is relaunched.
    func requestPermissionsIfNeeded() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    // MARK: - Tap Callback

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        let passThrough = Unmanaged.passUnretained(event)

        // Without the refcon there is no way to know whether we should be blocking,
        // so let the event through.
        guard let refcon = refcon else { return passThrough }
        let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(refcon).takeUnretainedValue()

        // If the tap gets disabled by the system (e.g., timeout), re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = blocker.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return passThrough
        }

        guard blocker.isBlocking else { return passThrough }

        // System-defined events cover more than media keys, so drop only the aux
        // control button subtype and let the rest through.
        if type.rawValue == nxSysDefinedEventType {
            let isMediaKey = NSEvent(cgEvent: event)?.subtype.rawValue == nxAuxControlButtonsSubtype
            return isMediaKey ? nil : passThrough
        }

        return nil
    }

    deinit {
        teardownTap()
    }
}
