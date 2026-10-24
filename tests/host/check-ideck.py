#!/usr/bin/env python3
"""Exercise production iDeck readiness and auto-start gates against real files."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
s = (root / 'app/Madeira/SteamUIExperiment.swift').read_text()
policy = s[s.index('enum SteamUIExperiment {'):s.index('\n@MainActor\nfinal class SteamUIEvidence')]
test = r'''
let args = ["/Applications/iDeck"]
assert(IDeckRules.shouldAutoStart(setup: true, ready: true, automatic: true, arguments: args))
for probe in ["madeira-runtime-diagnostics", "madeira-steam-big-picture-x86-experiment", "madeira-fls-diagnostics"] {
 assert(!IDeckRules.shouldAutoStart(setup: true, ready: true, automatic: true, arguments: args + [probe]))
}
for setup in [false, true] { for ready in [false, true] { for automatic in [false, true] {
 assert(IDeckRules.shouldAutoStart(setup: setup, ready: ready, automatic: automatic, arguments: args) == (setup && ready && automatic))
}}}
let prefix = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: prefix) }
let client = prefix.appendingPathComponent("drive_c/Steam32BundleLab")
try FileManager.default.createDirectory(at: client, withIntermediateDirectories: true)
assert(!IDeckRules.clientReady(prefix: prefix))
try Data().write(to: prefix.appendingPathComponent("system.reg"))
let files = ["steam.exe", "steamclient.dll", "bin/cef/cef.win7/steamwebhelper.exe", "bin/cef/cef.win7/libcef.dll"]
func pe(_ name: String, machine: UInt16) throws {
 let file = client.appendingPathComponent(name)
 try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
 var d = Data(repeating: 0, count: 256)
 d[0] = 77; d[1] = 90; d[60] = 128; d[128] = 80; d[129] = 69
 d[132] = UInt8(machine & 255); d[133] = UInt8(machine >> 8)
 try d.write(to: file)
}
for file in files.dropLast() { try pe(file, machine: 0x14c) }
assert(!IDeckRules.clientReady(prefix: prefix))
try pe(files.last!, machine: 0x8664)
assert(!IDeckRules.clientReady(prefix: prefix))
try pe(files.last!, machine: 0x14c)
assert(IDeckRules.clientReady(prefix: prefix))
try FileManager.default.removeItem(at: prefix.appendingPathComponent("system.reg"))
assert(!IDeckRules.clientReady(prefix: prefix))
'''
with tempfile.TemporaryDirectory() as temp:
    p = Path(temp); (p/'main.swift').write_text('import Foundation\nenum MadeiraConfig { static func get(_ key: String) -> String? { nil } }\n' + policy + test)
    subprocess.run(['swiftc',str(p/'main.swift'),'-o',str(p/'check')],check=True)
    subprocess.run([str(p/'check')],check=True)
print('PASS: production iDeck complete-client readiness, architecture and no-overlap auto-start gates')
