// SPDX-License-Identifier: GPL-3.0-or-later
// Madeira Converter Exception: see LICENSE-EXCEPTION.md
import Foundation

// Experimental genuine Windows Steam UI. No Dock token transfer and no UI replica.
enum SteamUIExperiment {
    static let flag = "env.MADEIRA_EXPERIMENTAL_STEAM_UI"
    static let sessionKey = "MADEIRA_STEAM_UI_SESSION"
    static func callbackScheme(bundleID: String?) -> String {
        bundleID?.hasSuffix(".steamui") == true ? "madeira-steamui" : "madeira"
    }
    static var callbackScheme: String { callbackScheme(bundleID: Bundle.main.bundleIdentifier) }
    static func allowed(flag: String?, bundleID: String?) -> Bool {
        flag == "1" && bundleID?.hasSuffix(".steamui") == true
    }
    static var enabled: Bool { allowed(flag: MadeiraConfig.get(flag), bundleID: Bundle.main.bundleIdentifier) }
    static func prepareProbe(prefix: URL, flag: String?, bundleID: String?, fls: Bool = false) throws -> String {
        guard allowed(flag: flag, bundleID: bundleID) else { throw Failure.disabled }
        let drive = prefix.appendingPathComponent("drive_c")
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
        var batch: String {
            ["@echo off", "start \"\" \"C:\\windows\\system32\\services.exe\"",
             "cd /d \"\(windowsDirectory)\"",
             "\"\(windowsDirectory)\\steam.exe\" -no-cef-sandbox -cef-disable-gpu -nocrashmonitor"]
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
    static func isX64PE(_ url: URL) -> Bool {
        guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096), data.count >= 64,
              data[0] == 0x4d, data[1] == 0x5a else { return false }
        let p = Int(data[60]) | Int(data[61]) << 8 | Int(data[62]) << 16 | Int(data[63]) << 24
        guard p >= 64, p <= data.count - 6 else { return false }
        return data[p..<p+4].elementsEqual([0x50, 0x45, 0, 0]) && data[p+4] == 0x64 && data[p+5] == 0x86
    }
    static func prepare(prefix: URL, width: Int, height: Int, flag: String?, bundleID: String?) throws -> Plan {
        guard allowed(flag: flag, bundleID: bundleID) else { throw Failure.disabled }
        guard (640...3840).contains(width), (360...2160).contains(height) else { throw Failure.invalidSize }
        let drive = prefix.appendingPathComponent("drive_c")
        for relative in ["Program Files (x86)/Steam", "Program Files/Steam"] {
            let root = drive.appendingPathComponent(relative)
            guard root.standardizedFileURL.path == root.resolvingSymlinksInPath().standardizedFileURL.path,
                  isX64PE(root.appendingPathComponent("steam.exe")),
                  isX64PE(root.appendingPathComponent("steamclient64.dll")) else { continue }
            let hasCEF = ["bin/cef/cef.win7x64", "bin/cef/cef.win64", "bin/cef"].contains { folder in
                let cef = root.appendingPathComponent(folder)
                return isX64PE(cef.appendingPathComponent("steamwebhelper.exe")) && isX64PE(cef.appendingPathComponent("libcef.dll"))
            }
            guard hasCEF else { continue }
            let plan = Plan(windowsDirectory: "C:\\" + relative.replacingOccurrences(of: "/", with: "\\"), width: width, height: height)
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

@MainActor
final class SteamUIEvidence {
    static let shared = SteamUIEvidence()
    private var timer: Timer?
    private var offsets: [URL: UInt64] = [:]
    private var reported = Set<String>()
    private var ticks = 0
    private var firstPresent: UInt64 = 0
    private var sawRunning = false
    func start(prefix: URL) {
        timer?.invalidate(); offsets = [:]; reported = []; ticks = 0; sawRunning = false
        firstPresent = winios_surface_present_count()
        for base in ["Program Files (x86)/Steam", "Program Files/Steam"] {
            for file in ["logs/cef_log.txt", "logs/webhelper.txt", "logs/console_log.txt"] {
                let url = prefix.appendingPathComponent("drive_c/" + base + "/" + file)
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
                offsets[url] = size
            }
        }
        LogStore.shared.log("[steam-ui] experiment-begin login-only; evidence excludes credential payloads")
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
