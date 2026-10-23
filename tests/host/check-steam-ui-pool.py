#!/usr/bin/env python3
"""Production fixed-region helper against host Mach VM and a mock debugger.
Not an iOS/debugserver/JIT execution test.
"""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
source = (root/'app/Madeira/StikJITHelper.swift').read_text()
a = source.index('    private static func prepareFixedSteamUIRegion(')
b = source.index('\n    /// madeira-bcd pool-low:', a)
helper = source[a:b].replace('private static func', 'static func')
fixture = r'''
import Foundation
import Darwin
final class LogStore {
    enum Level { case error }
    static let shared = LogStore()
    func log(_ s: String, level: Level? = nil) {}
}
var mode = 0
var requests: [(UInt,Int)] = []
func jit26_prepare_region(_ p: UnsafeMutableRawPointer?, _ size: Int) -> UnsafeMutableRawPointer? {
    guard let p else { fatalError("unexpected first-fit request") }
    requests.append((UInt(bitPattern: p),size))
    if mode == 1 { return nil }
    if mode == 2 { return p.advanced(by: 0x4000) }
    let prot = mode == 3 ? VM_PROT_READ : VM_PROT_READ | VM_PROT_EXECUTE
    assert(vm_protect(mach_task_self_, vm_address_t(UInt(bitPattern: p)), vm_size_t(size), 0, prot) == KERN_SUCCESS)
    return p
}
'''
checks = r'''
let size: vm_address_t = 0x10000
var base: vm_address_t = 0
assert(vm_allocate(mach_task_self_, &base, vm_size_t(size), 1) == KERN_SUCCESS)
// Occupied target must fail without asking the debugger or replacing its bytes.
let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(base))!
bytes.pointee = 73
assert(StikJITHelper.prepareFixedSteamUIRegion(base: base, size: size) == nil)
assert(requests.isEmpty && bytes.pointee == 73)
assert(vm_deallocate(mach_task_self_, base, vm_size_t(size)) == KERN_SUCCESS)
for failure in [1,2,3] {
    mode = failure
    assert(StikJITHelper.prepareFixedSteamUIRegion(base: base, size: size) == nil)
    // A rejected preparation must leave no allocation behind.
    var claim = base
    assert(vm_allocate(mach_task_self_, &claim, vm_size_t(size), 0) == KERN_SUCCESS && claim == base)
    assert(vm_deallocate(mach_task_self_, claim, vm_size_t(size)) == KERN_SUCCESS)
}
mode = 0
let result = StikJITHelper.prepareFixedSteamUIRegion(base: base, size: size)
assert(result == UnsafeMutableRawPointer(bitPattern: UInt(base)))
assert(requests.count == 4 && requests.allSatisfy { $0.0 == UInt(base) && $0.1 == Int(size) })
assert(vm_deallocate(mach_task_self_, base, vm_size_t(size)) == KERN_SUCCESS)
let before = requests.count
assert(StikJITHelper.prepareFixedSteamUIRegion(base: base+1, size: size) == nil)
assert(StikJITHelper.prepareFixedSteamUIRegion(base: base, size: 0) == nil)
assert(requests.count == before)
print("PASS: occupied mappings preserved, exact debugger address, failed/incorrect/non-RX preparation released, valid RX accepted")
'''
assert '? prepareFixedSteamUIRegion(base: best.base, size: size)' in source
assert ': jit26_prepare_region(nil, Int(size))' in source
with tempfile.TemporaryDirectory() as td:
    p=Path(td); (p/'main.swift').write_text(fixture+'\nenum StikJITHelper {\n'+helper+'\n}\n'+checks)
    subprocess.run(['swiftc',str(p/'main.swift'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
