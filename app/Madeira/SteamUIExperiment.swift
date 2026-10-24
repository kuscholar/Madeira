// SPDX-License-Identifier: GPL-3.0-or-later
// Madeira Converter Exception: see LICENSE-EXCEPTION.md
import Foundation

// Experimental genuine Windows Steam UI. No Dock token transfer and no UI replica.
enum SteamUIExperiment {
    static let flag = "env.MADEIRA_EXPERIMENTAL_STEAM_UI"
    static let bigPictureFlag = "env.MADEIRA_EXPERIMENTAL_BIG_PICTURE"
    static let sessionKey = "MADEIRA_STEAM_UI_SESSION"
    static func callbackScheme(bundleID: String?) -> String {
        bundleID?.hasSuffix(".steamui") == true ? "madeira-steamui" : "madeira"
    }
    static var callbackScheme: String { callbackScheme(bundleID: Bundle.main.bundleIdentifier) }
    static func allowed(flag: String?, bundleID: String?) -> Bool {
        flag == "1" && bundleID?.hasSuffix(".steamui") == true
    }
    static var enabled: Bool {
        let productDefault = Bundle.main.object(forInfoDictionaryKey: "IDeckEnabled") as? Bool == true ? "1" : nil
        return allowed(flag: MadeiraConfig.get(flag) ?? productDefault, bundleID: Bundle.main.bundleIdentifier)
    }
    static func prepareProbe(prefix: URL, flag: String?, bundleID: String?, fls: Bool = false, reservation: Bool = false, x86CEF: Bool = false) throws -> String {
        guard allowed(flag: flag, bundleID: bundleID) else { throw Failure.disabled }
        let drive = prefix.appendingPathComponent("drive_c")
        if reservation {
            guard isX64PE(drive.appendingPathComponent("steam-ui-reservation-probe.exe")) else { throw Failure.incompleteProbe }
            let batch = "@echo off\r\necho reservation-diagnostic-begin > C:\\madeira-reservation-results.txt\r\nC:\\steam-ui-reservation-probe.exe --isolated-reserve-only >> C:\\madeira-reservation-results.txt 2>&1\r\necho reservation-exit=%errorlevel% >> C:\\madeira-reservation-results.txt\r\n"
            try batch.write(to: drive.appendingPathComponent("madeira-reservation-probe.cmd"), atomically: true, encoding: .utf8)
            return "/c C:\\madeira-reservation-probe.cmd"
        }
        if x86CEF {
            guard isX86PE(drive.appendingPathComponent("Steam32Probe/bin/cef/cef.win7/madeira-chrome-elf32-probe.exe")) else { throw Failure.incompleteProbe }
            guard ["chrome_elf.dll", "libcef.dll"].allSatisfy({ isX86PE(drive.appendingPathComponent("Steam32Probe/bin/cef/cef.win7/" + $0)) }) else { throw Failure.incompleteProbe }
            let batch = "@echo off\r\necho x86-cef-diagnostic-begin > C:\\madeira-x86-cef-results.txt\r\nC:\\Steam32Probe\\bin\\cef\\cef.win7\\madeira-chrome-elf32-probe.exe >> C:\\madeira-x86-cef-results.txt 2>&1\r\necho x86-cef-exit=%errorlevel% >> C:\\madeira-x86-cef-results.txt\r\n"
            try batch.write(to: drive.appendingPathComponent("madeira-x86-cef-probe.cmd"), atomically: true, encoding: .utf8)
            return "/c C:\\madeira-x86-cef-probe.cmd"
        }
        if fls {
            guard isX64PE(drive.appendingPathComponent("steam-ui-fls-probe.exe")) else { throw Failure.incompleteProbe }
            let batch = "@echo off\r\necho fls-diagnostic-begin > C:\\madeira-fls-results.txt\r\nC:\\steam-ui-fls-probe.exe >> C:\\madeira-fls-results.txt 2>&1\r\necho fls-exit=%errorlevel% >> C:\\madeira-fls-results.txt\r\n"
            try batch.write(to: drive.appendingPathComponent("madeira-fls-probe.cmd"), atomically: true, encoding: .utf8)
            return "/c C:\\madeira-fls-probe.cmd"
        }
        guard ["steam-ui-atomic-probe.exe", "steam-ui-process-probe.exe"].allSatisfy({ isX64PE(drive.appendingPathComponent($0)) })
        else { throw Failure.incompleteProbe }
        let elfProbe = "Program Files (x86)/Steam/bin/cef/cef.win64/madeira-chrome-elf-probe.exe"
        guard isX64PE(drive.appendingPathComponent(elfProbe)) else { throw Failure.incompleteProbe }
        let lines = ["@echo off", "echo diagnostic-begin > C:\\madeira-probe-results.txt",
            "C:\\steam-ui-atomic-probe.exe >> C:\\madeira-probe-results.txt 2>&1",
            "echo atomic-exit=%errorlevel% >> C:\\madeira-probe-results.txt",
            "C:\\steam-ui-process-probe.exe >> C:\\madeira-probe-results.txt 2>&1",
            "echo process-exit=%errorlevel% >> C:\\madeira-probe-results.txt",
            "\"C:\\\(elfProbe.replacingOccurrences(of: "/", with: "\\"))\" >> C:\\madeira-probe-results.txt 2>&1",
            "echo elf-exit=%errorlevel% >> C:\\madeira-probe-results.txt"]
        try (lines.joined(separator: "\r\n") + "\r\n").write(to: drive.appendingPathComponent("madeira-runtime-probes.cmd"), atomically: true, encoding: .utf8)
        return "/c C:\\madeira-runtime-probes.cmd"
    }
    struct Plan {
        let windowsDirectory: String
        let width: Int
        let height: Int
        let bigPicture: Bool
        var batch: String {
            ["@echo off", "start \"\" \"C:\\windows\\system32\\services.exe\"",
             "cd /d \"\(windowsDirectory)\"",
             "\"\(windowsDirectory)\\steam.exe\" -no-cef-sandbox -cef-disable-gpu -nocrashmonitor\(bigPicture ? " -bigpicture" : "")"]
                .joined(separator: "\r\n") + "\r\n"
        }
        var arguments: String { "/desktop=steamui,\(width)x\(height) cmd /c C:\\madeira-steam-ui.cmd" }
    }
    enum Failure: LocalizedError {
        case disabled, incompleteClient, incompleteProbe, invalidSize
        var errorDescription: String? {
            switch self {
            case .disabled: return "Steam UI requires the experimental .steamui app and its feature flag."
            case .incompleteClient: return "A complete 64-bit Windows Steam client, steamwebhelper and libcef are required in this experimental app's own prefix."
            case .incompleteProbe: return "All x64 runtime probes must be present in the experimental app's own drive_c and matching CEF directory."
            case .invalidSize: return "Unsupported experimental desktop size."
            }
        }
    }
    static func isX64PE(_ url: URL) -> Bool { isPE(url, machine: 0x8664) }
    static func isX86PE(_ url: URL) -> Bool { isPE(url, machine: 0x014c) }
    private static func isPE(_ url: URL, machine: UInt16) -> Bool {
        guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096), data.count >= 64,
              data[0] == 0x4d, data[1] == 0x5a else { return false }
        let p = Int(data[60]) | Int(data[61]) << 8 | Int(data[62]) << 16 | Int(data[63]) << 24
        guard p >= 64, p <= data.count - 6 else { return false }
        return data[p..<p+4].elementsEqual([0x50, 0x45, 0, 0]) && data[p+4] == UInt8(machine & 255) && data[p+5] == UInt8(machine >> 8)
    }
    static func importBundledX86(source: URL, prefix: URL, flag: String?, bundleID: String?) throws {
        guard allowed(flag: flag, bundleID: bundleID) else { throw Failure.disabled }
        guard source.standardizedFileURL.path == source.resolvingSymlinksInPath().standardizedFileURL.path,
              ["steam.exe", "steamclient.dll", "bin/cef/cef.win7/steamwebhelper.exe", "bin/cef/cef.win7/libcef.dll"].allSatisfy({ isX86PE(source.appendingPathComponent($0)) }) else { throw Failure.incompleteClient }
        let target = prefix.appendingPathComponent("drive_c/Steam32BundleLab")
        // Never overwrite a previous client, prefix, login cache or save.
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        guard target.deletingLastPathComponent().standardizedFileURL.path == target.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path else { throw Failure.incompleteClient }
        let temporary = target.deletingLastPathComponent().appendingPathComponent(".steam32-import-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.copyItem(at: source, to: temporary)
        try FileManager.default.moveItem(at: temporary, to: target)
    }
    static func prepare(prefix: URL, width: Int, height: Int, flag: String?, bundleID: String?, x86Client: Bool = false, bigPicture: Bool = false, bigPictureFlag: String? = nil) throws -> Plan {
        guard allowed(flag: flag, bundleID: bundleID) else { throw Failure.disabled }
        guard !bigPicture || bigPictureFlag == "1" else { throw Failure.disabled }
        guard (640...3840).contains(width), (360...2160).contains(height) else { throw Failure.invalidSize }
        let drive = prefix.appendingPathComponent("drive_c")
        for relative in (x86Client ? ["Steam32BundleLab", "Steam32Lab"] : ["Program Files (x86)/Steam", "Program Files/Steam"]) {
            let root = drive.appendingPathComponent(relative)
            guard root.standardizedFileURL.path == root.resolvingSymlinksInPath().standardizedFileURL.path,
                  isPE(root.appendingPathComponent("steam.exe"), machine: x86Client ? 0x014c : 0x8664),
                  isPE(root.appendingPathComponent(x86Client ? "steamclient.dll" : "steamclient64.dll"), machine: x86Client ? 0x014c : 0x8664) else { continue }
            let hasCEF = (x86Client ? ["bin/cef/cef.win7"] : ["bin/cef/cef.win7x64", "bin/cef/cef.win64", "bin/cef"]).contains { folder in
                let cef = root.appendingPathComponent(folder)
                return isPE(cef.appendingPathComponent("steamwebhelper.exe"), machine: x86Client ? 0x014c : 0x8664) && isPE(cef.appendingPathComponent("libcef.dll"), machine: x86Client ? 0x014c : 0x8664)
            }
            guard hasCEF else { continue }
            let plan = Plan(windowsDirectory: "C:\\" + relative.replacingOccurrences(of: "/", with: "\\"), width: width, height: height, bigPicture: bigPicture)
            try plan.batch.write(to: drive.appendingPathComponent("madeira-steam-ui.cmd"), atomically: true, encoding: .utf8)
            return plan
        }
        throw Failure.incompleteClient
    }
    // Only categorical new-log evidence leaves the reader, never raw lines.
    static func milestones(in text: String) -> Set<String> {
        var found = Set<String>()
        if text.contains("ChromeMainDelegate") { found.insert("cef-initialization-reported") }
        if text.contains("BrowserReady") { found.insert("browser-ready-reported") }
        return found
    }
}

// Foundation-only lifecycle policy, shared by the launcher and host checks.
enum IDeckRules {
    static func shouldAutoStart(setup: Bool, ready: Bool, automatic: Bool, arguments: [String]) -> Bool {
        setup && ready && automatic && !arguments.contains { $0.hasPrefix("madeira-") }
    }
    static func clientReady(prefix: URL) -> Bool {
        let client = prefix.appendingPathComponent("drive_c/Steam32BundleLab")
        return FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) &&
            ["steam.exe", "steamclient.dll", "bin/cef/cef.win7/steamwebhelper.exe", "bin/cef/cef.win7/libcef.dll"]
                .allSatisfy { SteamUIExperiment.isX86PE(client.appendingPathComponent($0)) }
    }
}

@MainActor
final class SteamUIEvidence {
    static let shared = SteamUIEvidence()
    private var timer: Timer?
    private var offsets: [URL: UInt64] = [:]
    private var reported = Set<String>()
    private var ticks = 0
    private var firstPresent: UInt64 = 0
    private var sawRunning = false
    func start(prefix: URL, bigPicture: Bool = false) {
        timer?.invalidate(); offsets = [:]; reported = []; ticks = 0; sawRunning = false
        firstPresent = winios_surface_present_count()
        for base in ["Program Files (x86)/Steam", "Program Files/Steam", "Steam32Lab", "Steam32BundleLab"] {
            for file in ["logs/cef_log.txt", "logs/webhelper.txt", "logs/console_log.txt"] {
                let url = prefix.appendingPathComponent("drive_c/" + base + "/" + file)
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
                offsets[url] = size
            }
        }
        LogStore.shared.log(bigPicture ? "[steam-ui] experiment-begin genuine Big Picture; evidence excludes credential payloads" : "[steam-ui] experiment-begin login-only; evidence excludes credential payloads")
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }
    private func poll() {
        ticks += 1
        let running = wine_process_is_running() != 0
        if running { sawRunning = true }
        for (url, offset) in Array(offsets) {
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            guard let end = try? handle.seekToEnd() else { continue }
            let begin = end < offset ? 0 : offset
            guard end > begin else { continue }
            // Read a bounded tail; it is not a complete CEF trace or success oracle.
            try? handle.seek(toOffset: max(begin, end > 65536 ? end - 65536 : 0))
            if let bytes = try? handle.read(upToCount: 65536) {
                for event in SteamUIExperiment.milestones(in: String(decoding: bytes, as: UTF8.self)) where reported.insert(event).inserted {
                    LogStore.shared.log("[steam-ui] " + event)
                }
            }
            offsets[url] = end
        }
        if winios_surface_present_count() > firstPresent, reported.insert("host-surface-present").inserted {
            LogStore.shared.log("[steam-ui] host-surface-present (not proof of CEF content or interaction)")
        }
        if (sawRunning && !running) || ticks >= 600 {
            timer?.invalidate(); timer = nil
            LogStore.shared.log("[steam-ui] observation-ended running=\(running ? 1 : 0) seconds=\(ticks)")
        }
    }
}

// iDeck is an isolated product shell around the genuine local Steam runtime.
// Authentication remains entirely inside Valve's client and its existing prefix.
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

@MainActor final class IDeckState: ObservableObject {
    static let shared = IDeckState()
    static var enabled: Bool {
        SteamUIExperiment.enabled && MadeiraConfig.flag("MADEIRA_IDECK", fallback: Bundle.main.object(forInfoDictionaryKey: "IDeckEnabled") as? Bool == true)
    }
    @Published var running = false
    @Published var preparing = false
    @Published var error: String?
    @Published var menu = false
    var menuRect = CGRect.zero
    @Published var ready = false
    @Published var autoStart = UserDefaults.standard.object(forKey: "iDeckAutoStart") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoStart, forKey: "iDeckAutoStart") }
    }
    var setupDone: Bool { UserDefaults.standard.bool(forKey: "iDeckSetupComplete") }
    var prefix: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("wine") }
    func refresh() {
        ready = IDeckRules.clientReady(prefix: prefix)
    }
    func prepare() {
        guard Self.enabled, !preparing, !running, wine_process_is_running() == 0 else { return }
        preparing = true; error = nil
        let target = prefix
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: target.appendingPathComponent("system.reg").path) {
                        guard let archive = Bundle.main.path(forResource: "prefix-template", ofType: "tar.gz") else {
                            throw NSError(domain: "iDeck", code: 1, userInfo: [NSLocalizedDescriptionKey: "The runtime template is missing from this build."])
                        }
                        // Never extract over an existing prefix with user data.
                        if fm.fileExists(atPath: target.path), !(try fm.contentsOfDirectory(atPath: target.path)).isEmpty {
                            throw NSError(domain: "iDeck", code: 2, userInfo: [NSLocalizedDescriptionKey: "An incomplete runtime exists. It has been preserved; use diagnostics before repairing it."])
                        }
                        try fm.createDirectory(at: target, withIntermediateDirectories: true)
                        guard madeira_extract_prefix_tgz(archive, target.path) == 0 else {
                            throw NSError(domain: "iDeck", code: 3, userInfo: [NSLocalizedDescriptionKey: "Runtime preparation failed. Your files have been preserved."])
                        }
                    }
                    guard let source = Bundle.main.resourceURL?.appendingPathComponent("Steam32OfficialClient"), fm.fileExists(atPath: source.path) else {
                        throw NSError(domain: "iDeck", code: 4, userInfo: [NSLocalizedDescriptionKey: "This build needs the verified official Steam client resources. See iDeck build instructions."])
                    }
                    try SteamUIExperiment.importBundledX86(source: source, prefix: target,
                        flag: MadeiraConfig.get(SteamUIExperiment.flag) ?? "1", bundleID: Bundle.main.bundleIdentifier)
                }.value
                for (key, value) in [SteamUIExperiment.flag: "1", SteamUIExperiment.bigPictureFlag: "1",
                    "env.MADEIRA_GDI_SHARED_SECTION": "1", "env.MADEIRA_STEAM_UI_ALLOW_CRASHPAD": "1",
                    "env.MADEIRA_STEAM_UI_STRICT_RESERVATIONS": "1", "env.MADEIRA_FRONTEND": "0",
                    "env.MADEIRA_CONTROLS_XBOX_DEFAULT": "1", "pool-split": "1", "pool-low": "1"] {
                    guard MadeiraConfig.set(key, value) else {
                        throw NSError(domain: "iDeck", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not save runtime settings."])
                    }
                }
                refresh()
                if ready { UserDefaults.standard.set(true, forKey: "iDeckSetupComplete") }
            } catch { self.error = error.localizedDescription }
            preparing = false
        }
    }
}

struct IDeckLauncher: View {
    let start: () -> Void
    let setupJIT: () -> Void
    let diagnostics: () -> Void
    @ObservedObject private var state = IDeckState.shared
    @ObservedObject private var jit = JITCoordinator.shared
    @State private var selection = 2
    private func accept() {
        switch selection {
        case 0: if !state.ready { state.prepare() }
        case 1: setupJIT()
        case 2: if state.ready && !jit.busy { start() }
        default: state.autoStart.toggle()
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "gamecontroller.fill").font(.largeTitle).foregroundStyle(.cyan)
                    VStack(alignment: .leading) {
                        Text("iDeck").font(.largeTitle.bold())
                        Text("Your Steam library. On your iPhone.").foregroundStyle(.secondary)
                    }
                }
                Text("Complete setup once, then launch Steam Big Picture locally. Steam handles sign-in and remembers this device when you choose Remember me.")
                GroupBox("1 · Runtime & Steam") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(state.ready ? "Runtime ready" : "Prepare the local runtime", systemImage: state.ready ? "checkmark.circle.fill" : "shippingbox")
                        if !state.ready {
                            Button(state.preparing ? "Preparing…" : "Prepare iDeck") { state.prepare() }
                                .disabled(state.preparing).buttonStyle(.borderedProminent)
                            if state.preparing { ProgressView() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("2 · Device & JIT") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use Madeira’s existing device pairing and JIT setup. iDeck requests JIT again when a new session needs it.")
                        Button("Configure pairing & JIT", action: setupJIT).buttonStyle(.bordered)
                        if let message = jit.status { Text(message).font(.caption).foregroundStyle(.secondary) }
                        if let message = jit.error { Text(message).foregroundStyle(.orange) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: start) {
                    Label(jit.busy ? "Enabling JIT…" : "Launch Steam Big Picture", systemImage: "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.borderedProminent).disabled(!state.ready || state.preparing || jit.busy)
                Toggle("Open Big Picture automatically next time", isOn: $state.autoStart)
                if let error = state.error { Text(error).foregroundStyle(.orange) }
                Text("Connect a controller, or tap directly on Steam. The floating iDeck button opens the keyboard, virtual controller and options.").foregroundStyle(.secondary)
                Text("Powered by Madeira · Genuine Windows Steam, not Linux SteamOS. This proof of concept uses Valve’s legacy 32-bit client; compatibility is experimental.").font(.caption).foregroundStyle(.secondary)
                Button("Advanced diagnostics", action: diagnostics).font(.caption)
            }.padding(24).frame(maxWidth: 660)
                .frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground))
        .onAppear {
            state.refresh()
            LibraryController.shared.configure(enabled: true, ownsInput: true)
        }
        .onDisappear { LibraryController.shared.configure(enabled: true, ownsInput: false) }
        .onReceive(LibraryController.shared.commands) { command in
            if command == "up" { selection = max(0, selection - 1) }
            if command == "down" { selection = min(3, selection + 1) }
            if command == "accept" { accept() }
        }
        .overlay(alignment: .bottom) {
            Text(["Controller: Prepare runtime", "Controller: Pairing & JIT", "Controller: Launch Big Picture", "Controller: Auto-start"][selection])
                .font(.caption).padding(8).background(.regularMaterial, in: Capsule()).padding(8)
        }
    }
}

struct IDeckHUD: View {
    @ObservedObject private var state = IDeckState.shared
    @ObservedObject private var controls = TouchControlsModel.shared
    @State private var showSettings = false
    @State private var selection = 0
    private func keyboard() { state.menu = false; MetalBackedView.toggleKeyboard() }
    private func accept() {
        switch selection {
        case 0: keyboard()
        case 1: controls.visible.toggle()
        case 2: controls.visible = true; controls.editing = true; state.menu = false
        case 3: state.autoStart.toggle()
        case 4: showSettings = true
        default: state.menu = false
        }
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                if state.menu {
                    Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { state.menu = false }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("iDeck").font(.title2.bold()); Spacer(); Button("Done") { state.menu = false } }
                        Button("Keyboard", systemImage: "keyboard") {
                            keyboard()
                        }
                        Toggle("Virtual controller", isOn: $controls.visible)
                        Button("Arrange virtual controls", systemImage: "slider.horizontal.3") {
                            controls.visible = true; controls.editing = true; state.menu = false
                        }
                        Toggle("Open Big Picture next time", isOn: $state.autoStart)
                        Button("Settings", systemImage: "gearshape") { showSettings = true }
                        Text(["Controller: Keyboard", "Controller: Virtual controller", "Controller: Arrange controls", "Controller: Auto-start", "Controller: Settings", "Controller: Done"][selection]).font(.caption).foregroundStyle(.cyan)
                        Button("Steam menu", systemImage: "line.3.horizontal") {
                            state.menu = false
                            winios_post_key(0x1B, 1); winios_post_key(0x1B, 0)
                        }
                        Text("Sign out in Steam to remove its saved login. Games and saves stay in this app.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: 390).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .padding(.top, max(geo.safeAreaInsets.top, 12)).padding(16)
                } else {
                    Button { state.menu = true } label: {
                        Image(systemName: "line.3.horizontal").font(.title3.bold()).frame(width: 48, height: 48)
                    }.buttonStyle(.plain).background(.regularMaterial, in: Circle())
                        .accessibilityLabel("iDeck options")
                        .padding(.top, max(geo.safeAreaInsets.top, 10)).padding(.trailing, max(geo.safeAreaInsets.trailing, 12))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { state.menuRect = $0 }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.preferredColorScheme(.dark)
        .onAppear { LibraryController.shared.configure(enabled: true, ownsInput: state.menu) }
        .onChange(of: state.menu) { _, open in LibraryController.shared.configure(enabled: true, ownsInput: open) }
        .onChange(of: controls.visible) { _, visible in
            if visible && controls.controls.isEmpty {
                ControlPresetsModel.shared.load(ControlPresetLayout.xboxID, screen: ControlPresetsModel.currentScreen(), reason: "ideck-first-overlay")
            }
        }
        .sheet(isPresented: $showSettings) { AllSettingsView() }
        .onReceive(LibraryController.shared.commands) { command in
            if command == "menu" { state.menu.toggle() }
            if command == "back" { state.menu = false }
            if state.menu && !showSettings {
                if command == "up" { selection = max(0, selection - 1) }
                if command == "down" { selection = min(5, selection + 1) }
                if command == "accept" { accept() }
            }
        }
    }
}
#endif
