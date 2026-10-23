# Genuine Steam UI PoC results

Updated 2026-10-23. Current phase: Phase 0 complete; Phase 1 controlled launcher
implemented and exercised; first CEF load failed due to JIT pool capacity. Build 10 rejected fixed secondary preparation and later exhausted image space. Build 11 validated region C but hit a chrome_elf refcount assertion before pool exhaustion. Build 13 isolated diagnostics pass; real CEF login remains blocked. Main remains
the playable Build 8 baseline. This document is the recurring task's resume point.

## What has actually been established

- Baseline ee9fd2f; Phase 0 audit committed as f3d1e92. Exact current and historical
  submodule revisions, publication checks, architecture and missing resources:
  BIG_PICTURE_ARCHITECTURE.md.
- The historical handoff reports an interactive real Steam login window. This
  branch has NOT independently reproduced it and has not fixed its open bugs.
- The current native process source already permits initial CEF startup in
  single-process mode. Dock intentionally takes a different headless path.
- A separate off-by-default Steam UI route now requires a `.steamui` bundle,
  flag exactly 1, a fresh/JIT-enabled session and complete x64 client files. It
  rejects symlinked client resources rather than using the working prefix.
- It closes the native library's competing Steam connection through the existing
  gate, without transferring a token. It launches Valve's real steam.exe through
  existing services/explorer/cmd, without fixed game identity or Big Picture yet.
- New pseudo-process start/end events contain only fixed role, slot and machine;
  the experiment disables Wine's payload-wide debug channels. A bounded reader
  emits categorical new Steam-log readiness events, never raw credential text.
  Window presentation continues through existing Winios/Metal, not a UI replica.

## Experiment 1: isolated launch-policy feasibility

Observed gap: the existing Steam Testing action starts real Steam but enables
unrelated historical probes and shares the ordinary application's context.
Hypothesis: reuse current startup machinery with a fixed isolated launch policy
before modifying low-level CEF compatibility code.
Discriminating tests: flag-off and normal bundle refuse; complete synthetic x64
client passes; missing/32-bit/symlinked client fails; only fixed arguments and
categorical milestones are emitted. Compile actual native lifecycle diagnostic
function with private-looking paths/arguments and assert none are emitted.
Evidence: both production policy and C diagnostics pass; C uses ASan/UBSan.
Minimal patch: SteamUIExperiment.swift, ContentView route, scoped bridge identity/
logging handling and scoped native child events. No Dock/FEX/DXMT edits.
Regression: Dock contract and frontend host checks pass.

## Build evidence (not execution evidence)

Native ntdll: 37 compile units succeeded, 0 failed; the changed process object is
in the newly built experimental archive. Full iOS Debug target built successfully
with bundle ID com.kuschqin.madeira.steamui and version 9. The first attempt found
missing fmt headers in the new worktree; the pinned fmt/range-v3/unordered_dense
sources were then checked out independently and compilation succeeded.
Final Mach-O markers and symbols were checked in Madeira.debug.dylib, not just
in the intermediate archive or small executable trampoline. Artifact hashes and
commands are recorded in STEAM_UI_LOCAL_EVIDENCE.json and the reproducibility guide.
The source/worktree dependency reuse is described in tests/steam-ui/README.md.

The synthetic x86-64 CreateProcess/shared-map/child-exit diagnostic was compiled
and its AMD64 PE headers/imports inspected in the initial local-only milestone.
It subsequently passed on device in Build 12/13, recorded below; Windows
control is still unavailable.

## Actual device gate (updated after Xcode account sign-in)

Official Xcode UI provisioning generated matching isolated app and helper
profiles. Code signatures and embedded profile IDs were checked, and final
Build 9 was successfully installed and launched as Steam UI Lab. Its unique
`madeira-steamui` scheme also receives LocalDevVPN and Shortcuts callbacks,
so the working Madeira app does not receive the experiment's JIT callbacks.
The first installation was rejected by the free-profile three-app limit. The
user chose to back up/remove LongDine themselves; subsequent device inventory
no longer showed it and installation succeeded. No app was uninstalled by us.
Main and the original Madeira app/data remain unchanged.

An on-device startup log confirms `v0.1.3 (9)`, developer interface from config,
and increased-memory-limit granted. `allow-jit` and extended-VA were false at
startup; the existing debugger workflow is still required. A launch is NOT a
CEF or JIT success. The user has been asked to enable JIT and press the new
Steam UI Experiment button; runtime/interaction results are pending.

Read-only inventory showed the working headless client's bin directory had no
CEF tree. It was not used as a full-client source. Instead, 18 matching public
Valve win64 packages from saved manifest version 1792618285 were fetched over
HTTPS and checked against every listed size and SHA-256. The staged set has
6,558 files, 829,728,769 expanded bytes. Core binaries have AMD64 PE headers.
Manifest signatures were NOT independently verified. See
STEAM_UI_CLIENT_EVIDENCE.json and the saved manifest. No client binaries or
account caches are committed. The complete client and synthetic PE were copied
into the isolated app's prefix; device file inventory confirms webhelper and
libcef presence, but device file hashes have not been independently read back.
Valve's updater can subsequently change these resources; re-inventory after a run.

Before authentication, an inherited logging issue was found: the existing
webhelper path forced Chromium VLOG and echoed the inherited command tail.
The experimental-session-only policy now uses warning-level logging and a fixed
categorical policy event instead. Ordinary launches retain their existing
behavior. The native archive was rebuilt and the final linked Mach-O checked.
Steam's own logs remain app-private; the evidence observer never exports raw
lines. Human Steam Guard completion is required if Valve requests it. No claimed
networking, pixel, controller, login, Big Picture, library, persistence or
game-return validation yet. The synthetic PE is staged but NOT executed.

## Experiment 2: first real-client device run and allocation failure

Build 9 / source 4293afb ran the controlled Steam UI route on Kusch. The user
captured Steam's real "steamwebhelper is not responding" dialog. The private
host log confirms the route and repeated helper creation/termination. This is
NOT an interactive CEF/login success. No libcef fault RVA or KERN_MEMORY_ERROR
was observed in this run: CEF's code image failed to load before initialization.

Observed failure: primary JIT pool shrank from the requested 896 MiB to 464 MiB.
The upper run existed (325 MiB), but the second debugger allocation returned a
lower address and was released by the existing placement guard. At first CEF
failure the image allocator requested 0xd3d0000 bytes (about 212 MiB), while
main virgin space was 0x8134000 (about 129 MiB), with only small reusable ranges.
The loader returned STATUS_NO_MEMORY. Steam's own subsequent retries did not
change this. cef_log.txt was empty. Raw logs remain outside Git; hashes and
categorical findings are in STEAM_UI_RUN1_EVIDENCE.json.

Hypothesis: precise reservation of the measured upper run, followed by the
existing debugger's supported non-null-address prepare operation, will retain
the second region instead of relying on first-fit allocation and temporary
plugs. This addresses capacity/placement, not CEF memory-protection faults.

Discriminating test: on Build 10 require an exact-secondary RX verification
line and retained split-pool capacity; check whether libcef's image loads rather
than failing STATUS_NO_MEMORY. If it still fails, retain the new evidence and
do not treat a dialog/restart as progress. No protection overrides or retries
were added. A failed exact reservation, mismatched response or non-RX mapping
is released and rejected; occupied mappings are never overwritten.

Minimal patch: only SteamUIExperiment.enabled selects the exact secondary
reservation in StikJITHelper; the normal game allocation path is unchanged.
The entire returned region is queried for actual READ+EXECUTE permission before
acceptance. Local tests exercise real host Mach VM with a mock debugger:
occupied mappings retain their bytes and invoke no debugger; null/mismatched/
non-RX preparations release their allocations; a complete RX preparation passes.
These tests do not prove iOS debugserver will prepare caller-reserved memory.
Pool split/placement tests, JIT integration and Steam UI policy checks pass.
Build 10 compiled, was signed/verified, installed and launched. Its final linked
Mach-O contains the new diagnostic. Device execution of this candidate is
pending; the user has been asked to repeat Enable JIT and Steam UI Experiment.
The original working app/main remain unchanged.

## Experiment 3: Build 10 rejects fixed reservation; test existing region C

Build 10 / source 29f5f6f confirms that the requested exact secondary region did
NOT satisfy the complete RX verification. It was correctly released. The
caller-reserved-memory hypothesis is not supported on this device; the host
mock-debugger test did not predict iOS preparation. Build 11 removes that path
and its obsolete mock test, restoring the prior allocator. The rejected
candidate/test remain reproducible at commit 29f5f6f; no mprotect override or
relaxed permission check was added.

The first helper got further because this launch's primary region was 592 MiB
rather than 464 MiB, NOT because the candidate succeeded. libcef.dll loaded and
cef_log reported Chrome 126.0.6478.183. Later libglesv2.dll requested 0x7c8000
bytes with only 0x134000 main virgin bytes available, failing STATUS_NO_MEMORY;
more image failures followed. A helper then raised breakpoint 0x80000003 at
libcef+0x59ef905. Allocation failures precede this, but their causal relationship
to the breakpoint is not proved. No BrowserReady or interactive login observed.
See STEAM_UI_RUN2_EVIDENCE.json; raw logs stay outside Git.

The JIT badge turned orange because it only queried debugger attachment. The
log shows intentional early detach AFTER pool readiness; this is distinct from
losing the prepared executable pool. Background thread/FEX statistics continuing
to update are not Steam UI readiness. Build 11's badge accepts either an attached
debugger or the existing successfully prepared poolTaken state.

Next single-hypothesis test: enable existing `pool-low = 1` only in the lab cfg,
keeping the previous `pool-split = 1`. Region C already supports placing FEX
code buffers in a separate debugger-created region below the executable window,
leaving more main-pool room for images. No allocator, Chromium or FEX source
change is introduced for this experiment. Require actual region-C RX/RW alias
acceptance, reduced main-pool tail consumption and successful libglesv2/import
loads. A missing C region or fresh memory exhaustion rejects this hypothesis;
further CEF errors must be diagnosed separately. Do not assume smaller primary
layouts will fit. The default 128 MiB low-image margin is unchanged.

Host pool-low/split, JIT-method, Steam policy and frontend regressions pass.
Build 11 compiled, passed strict signature verification, and was installed and
launched. Region-C execution remains pending. This experiment
still has no interactive login, authentication, Big Picture or controller result.

## Experiment 4: capacity confirmed, first failure is a refcount assertion

Build 11 / source bbcd7ce accepted region C (352 MiB, matching RX/RW alias),
624+256 = 880 MiB in A/B, and actual FEX EC_CODE carves in C. The main image
pool's code tail reservation stayed zero. This validates this run's capacity
mechanism; it does not guarantee the same A/B sizes under another address slide.

The first helper still raised 0x80000003 at chrome_elf.dll+0xd7e3e. The existing
brp-contain diagnostic reports offender=0 and caller=chrome_elf+0x65bb4.
The first assertion is at log line 14776 (zero based); first EXHAUSTED is 17529.
Later automatic helper restarts fragment/exhaust the pool. Do not mistake this
secondary exhaustion for the cause of the first assertion.

The actual device chrome_elf.dll was read back: SHA-256 matches the downloaded
binary (6358830f96f36efa7516b3277cf69c1f132f97d4d93c365ccf061a7cf11e1e39).
Offline disassembly confirms a locked cmpxchg clear-bit loop in the caller,
which branches to a helper recording the fixed string refcount, then executes
int3/int3/ud2. The refcount is not held by the allocator at that check (zero in
the saved diagnostic). The stack includes a non-null-pointer free callback at
chrome_elf+0x9c1e0 and ntdll teardown. This is a lifetime/FLS lead, NOT proof of
an incorrect atomic, a Wine double-free or a FEX defect. Do not remove the check.
This resembles the historical chrome_elf assertion family; it is not the
historical libcef+0x41258FB KERN_MEMORY_ERROR signature.

## Experiments 5 and 6: actual device diagnostic results

Build 12 added an isolated orange Runtime Diagnostics route. It requires the
experimental app/flag, fresh JIT session and x64 test executables. Fixed batch
commands redirect stdout and exit codes to drive_c/madeira-probe-results.txt;
no Steam client, login or credentials are involved. The user started this run:

- Atomic probe: 4 threads, 200,000 successful shared-counter increments, plus
  failed CAS result/ZF and private clear-held-bit CAS checks; failures=0, exit=0.
- Process probe: CreateProcess, named shared mapping, child write, parent wait
  and child exit all pass: wait=0 child_exit=0 shared_match=1, exit=0.

Build 13 added a PE importing the user's matching official chrome_elf.dll. It
ran beside that DLL, reached entry/GetHandleVerifier, and completed four rounds
of four worker threads with Win32/CRT heap writes/frees and teardown: failures=0,
exit=0. Atomic and process tests passed again in that run. The DLL is not embedded
in the probe or committed. Source, import definition and build commands are in
tests/steam-ui. This covers import/heap/thread plumbing; it does NOT reproduce
all CEF allocator or FLS lifetimes, so a pass cannot exonerate those generally.

Build 13 also accepts the explicit developer launch argument
madeira-runtime-diagnostics only when the Steam UI isolation flag is enabled.
It reuses the existing paired JIT coordinator and starts only these diagnostics.
The remote launch successfully enabled built-in JIT and completed the tests
without another phone tap. Ordinary app launch and real Steam launch do not
change. The baseline app/main were not changed. Future controlled diagnostics
can use this path while pairing/VPN/device availability remain valid.

Host launch/isolation/privacy tests, JIT-method and frontend checks pass. The
x86-64 PE files and actual final signed Mach-O were inspected/hashed. A macOS
x86-64 control compiled but could not execute (Bad CPU type); no Windows
control was available. Device passes are real, narrow results, not a general
emulator/allocator correctness claim. See STEAM_UI_RUN3_EVIDENCE.json for hashes
and exact output categories. The user still has no working real Steam login UI.

## Experiment 7: FLS callback lifetime and process isolation (Build 14)

On 2026-10-23 the user explicitly requested direct phone operation. The existing
paired automatic JIT route is reused; no repeated app-button interaction is
required. A new explicit `madeira-fls-diagnostics` developer argument selects
one FLS-only probe. It checks worker teardown once, no repeated callback on
freeing an empty slot, and parent/child FLS namespace isolation while the child
is alive. Static records track PID/call counts without freeing foreign memory.

This discriminator tests the basic lifetime/ownership lead from the actual
chrome_elf free-callback stack before any Wine/FEX runtime modification. The
expectation is Microsoft's documented per-process FLS contract, not an actual
Windows control result. Probe source and commands: tests/steam-ui/README.md.

Host launch/isolation/privacy checks, JIT-method and frontend regressions pass.
Build 14 compiled, passed strict signing verification, installed and received
the x64 probe. The first automated launch was refused by iOS: device Locked,
passcodeRequired=true. Device execution is PENDING; a native unlock is required.
The user was asked only to unlock/keep the phone awake, not to operate app
buttons. Do not count installation or the probe's compilation as a pass. Exact
artifact hashes and current gate: STEAM_UI_FLS_EVIDENCE.json. No security setting,
lock bypass, Wine/FEX implementation change or baseline app change occurred.

## Heartbeat state check: 2026-10-23 04:46 UTC

Resumed at experiment commit 1b9016b70df0a95b9329292c4b6a1bff0071ddf5.
Origin branch matches that exact remote revision; origin/main and the clean
primary checkout remain ee9fd2f4c21229dfce31a25c211d44df267336d8. No overlapping
experiment or unrelated local change found. Phase remains real CEF login;
Build 14 FLS device execution is still pending.

One read-only lock-state check still reports passcodeRequired=true and
unlockedSinceBoot=true. Evidence: ignored artifact
.madeira-install/steam-ui-fls-run1/heartbeat-lock.json and heartbeat-lock.log.
No launch, reinstall, signing retry or runtime modification attempted. Previous
regression/build results remain unchanged; no new device pass claimed. The
user already received the unlock request, so no duplicate notification is needed.

The recurring prompt was refreshed from the obsolete Build 9 signing gate to
the installed Build 14/FLS gate, preserving its 305-minute schedule and target
thread. Next: after native unlock, run the staged FLS-only diagnostic and collect
its result file before changing the runtime. No source/build/test result changed.

## Heartbeat state check: 2026-10-23 09:50 UTC

Resumed at e39e42bb3cb45abe55453ed3c8f9daf5618a9fa6, matching the fork's
remote experiment branch. Both worktrees are clean; primary/main and remote
main remain ee9fd2f4c21229dfce31a25c211d44df267336d8. Phase 1's current
uncompleted discriminator is still the installed Build 14 FLS probe.

A single read-only device check again returned passcodeRequired=true,
unlockedSinceBoot=true. Private evidence:
.madeira-install/steam-ui-fls-run1/heartbeat-0950-lock.json (SHA-256
d846bec12141d5e86463c54a5a8a91401198e6cc4fe1ac87e9bff3af7395235d) and heartbeat-0950-lock.log.
No launch/install/signing retry was attempted. No new device result or code
change exists; previous tests are unchanged. The probe's parent/child handshake
and bounded waits were reviewed without altering its contract or treating that
review as execution. No independent Windows control is available locally.

The native unlock gate is unchanged and was already reported; no repeat user
notification. The next step remains the staged FLS-only launch after native
unlock, followed by result-file and private-log capture. Do not claim a runtime
fix, remove the refcount check, or start another CEF retry while this test is
unexecuted. No further build/tests warranted for this documentation-only update.

## Manual test handoff candidate (Build 15)

The user asked to operate the test manually. Build 15 adds an explicit orange
FLS Diagnostics button to the isolated developer interface; it calls the same
FLS-only route as the Build 14 command-line argument. Ordinary manual launch
does not auto-run diagnostics or Steam. Probe/runtime code and previous
validation results are unchanged.

The full iOS build succeeded; strict signing verification passed and the
FLS Diagnostics marker was checked in the final linked debug dylib. Hash is
recorded in STEAM_UI_FLS_EVIDENCE.json under manual_candidate. This two-line
UI addition required no new runtime tests; it has no new device execution claim.
Initial install failed with IXRemoteErrorDomain 6 / Connection interrupted;
the subsequent app-list query timed out after 15 seconds. A single install
retry then succeeded (install-retry.json/log). The actual device probe was read
back and its SHA-256 matched the recorded Build 14 PE. Build 15 is installed,
with manual execution still pending; no FLS result is inferred from installation.
The prepared Build 14/probe state must not be erased to work around the link.

Verified-install handoff: open Steam UI Lab, Enable JIT, then orange FLS
Diagnostics; collect madeira-fls-results.txt and private device log. Do not
instruct the user to start full Steam or the earlier three-test Runtime
Diagnostics route for this discriminator. Working baseline remains untouched.

## Experiment 7 result: Build 15 FLS test passes on device

The user manually started FLS Diagnostics on installed Build 15 / source
c11d633. The private device log identifies version 15, successful paired JIT,
and the FLS-only launch. Result file reports thread-exit-once=PASS,
parent_once=1 wrong_owner=0 child_exit=0 wait=0, result=PASS and fls-exit=0.
Hashes and exact categorical output are in STEAM_UI_FLS_EVIDENCE.json; raw
artifacts are outside Git at .madeira-install/steam-ui-fls-run2/.

This rejects a simple always-repeated worker callback or basic parent/child
FLS namespace interference in the tested configuration. It does not exclude
CEF-specific allocator/FLS lifetime issues, callback reentrancy or another
owner/context error. No Windows control has executed. No Wine/FEX implementation
patch or assertion suppression is justified by this pass. No Steam login/UI
success is claimed. Previous host regressions are unchanged; this run changed
only recorded results/docs, with no rebuild or overlapping guest experiment.

A follow-up read-only attempt to retrieve the prefix's sysx64/ntdll.dll through
CoreDevice failed to open the path (POSIX 62). It did not produce a device PE
hash, so source/bundle-version equivalence is not asserted. Existing loaded
module metadata and official chrome_elf readback remain the available evidence.

Next: obtain bounded allocation/release and callback ownership evidence in the
actual CEF workload, accounting for the existing zero-refcount/free-callback
stack, before changing lifetime behavior. Reproduce a specific suspected
condition in an isolated PE/control when possible. Do not repeat the now-passing
basic FLS test or the locked-device gate. main/baseline app remain untouched.


## Build 16: actual CEF FLS ownership trace (2026-10-23)

Phase 1, based on parent `29643eea314284c2d5888f29a3eda73fe441edb9`;
Wine remains pinned to `9129e9684daaeae70da9435e7c6060e59392634e`.
Observed failure: real Steam still reaches the chrome_elf +0xd7e3e refcount
assertion (caller +0x65bb4, recorded offender=0), before interactive login.
Hypothesis: the CRT PTD destructor could receive a repeated FLS callback.
Discriminating test: observe alloc/set/callback begin/end, with PID, TID,
PEB/TEB and pointer identities, during the actual CEF workload. Do not change
callback ordering or suppress the assertion.

Minimal patch: a separate Wine PE observer patch, gated by BOTH
MADEIRA_STEAM_UI_SESSION=1 and MADEIRA_STEAM_UI_FLS_TRACE=1; at most 4096
metadata records per loaded observer instance, no dereferenced payload.
The pinned original Wine checkout and the primary baseline are unchanged.
ContentView additionally accepts explicit `madeira-steam-ui-experiment` to
reuse the already-paired JIT coordinator in the isolated flagged lab.

Validation: host policy/JIT/frontend checks PASS. Observer patch behavior
comparison and gating/bounds/privacy checks PASS under ASan/UBSan. Full unsigned
Build 16 PASS; final debug dylib contains the explicit launch marker. The custom
ARM64EC ntdll has the same 1473 named exports/order as the baseline, was placed
ONLY in the generated app, and the resulting app was re-signed and passed strict
verification. Device install and both explicit launch routes succeeded.
The synthetic FLS test with this actual observer-loaded PE still PASSes
(thread-exit-once; parent_once=1, wrong_owner=0, child_exit=0, wait=0, exit=0).

Actual CEF trace contains 3821 records; the failing pseudo-process reaches seq
1301, below the cap. For its FLS index 2, value 0x7800280200: one set at seq60
by tid012c, then its first recorded thread-exit-begin at seq1301 by the same
thread, with the same PEB and FLS storage. Callback resolves to
chrome_elf.dll+0x9c1e0. The refcount assertion occurs inside this callback;
there is no corresponding end or earlier callback for that value. An adjacent
thread's different PTD value completes the same callback normally. This argues
against simple repeated FLS delivery in this run. It does not rule out an earlier
non-FLS free, an invalid allocation, corruption or a translation defect.

Raw artifacts remain private at `.madeira-install/steam-ui-trace-build16`;
redacted metadata, exact component hashes and evidence file hashes are in
`docs/STEAM_UI_FLS_TRACE_EVIDENCE.json`. Two live-file downloads failed with
CoreDevice socket closure; after terminating only the lab process, the stable
2.3 MB log downloaded successfully. No app reinstall/restart loop was used.
The installed PE was not independently read back: final signed bundle hash plus
actual device observer records establish inclusion, not device byte equivalence.
Instrumentation changes timing/layout; no Windows control or allocator history
exists. BrowserReady, interactive login and Big Picture remain unverified.

Next: bounded metadata for chrome_elf CRT PTD allocation/free on this same thread,
compared with the FIRST FLS callback. Preserve the assertion; do not repeat the
basic FLS probe without a new instrumentation change. Reproduction is documented
in tests/steam-ui/README.md. main and the installed working game app are preserved.


## Builds 17–19: allocator metadata and overlapping pool grants (2026-10-23)

Phase 1, parent a10687c64f525b4aadfa99faad7403167ad525c1. Submodule pins
are unchanged. Observed failure/hypothesis: an official CRT path requests a
128-byte PTD, but the previous fatal site's preserved metadata-register points
to PTD+8192-4. Test whether allocator metadata is already inconsistent before
its FIRST FLS callback, rather than suppressing that callback or its assertion.

Build 17 adds fault-reporting, exact-length metadata reads to the separate Wine
PE observer. Exact 31-byte callback fingerprint pins interpretation to the
inspected official chrome_elf. No PTD contents are read. Its 33-second real CEF
run has no refcount assertion, and presents continue through #1219. However,
there are NO metadata snapshots, no BrowserReady and no interaction artifact;
this is not a fix/login success. Its PE SHA256 is
a94a82c58591e8a81d3f40a043a764c77b140790de8ed7228f8e2dcbedc6faa5.
The first sandboxed Xcode attempt could not query Metal; the normal authorized
Xcode toolchain build succeeded. JIT/frontend/policy and observer host tests pass.

Build 18 reuses Build 17's compiled Mach-O and changes only the diagnostic PE
and version, then re-signs/installs. It adds bounded categorical read exclusions.
At tid012c's callback begin, actual metadata reports slot_size=8192,
ref=0x78002821fc and ref_value=0 for PTD 0x7800280200; the original
chrome_elf+0xd7e3e assertion then occurs. Initial metadata for THIS object is
not recorded, so no claim that its state was correct at allocation is supported.
Some nearby callbacks report BRP root flag 0. Trace gaps/initial missing records
also limit chronology. No allocation/free history or Windows control exists.

More direct evidence: the native log first grants a REAL 16 GiB pool at
0x7800000000, then grants an unbacked soft guard-prefixed range returned at
0x77ffff0000, size 0x400010000, covering the same pool. Source inspection finds
that the emergency soft-grant path only excludes prior SOFT entries/furniture;
the comment claiming a real-pool probe remains, but its probe was removed.
Thus two allocator requests can own overlapping intervals. This supports a
specific aliasing hypothesis; Build 17 also had duplicate grants without the
same assertion inside its capture, so overlap alone is not a deterministic
proof of that crash's sole cause.

Minimal experimental patch: dual-gated by MADEIRA_STEAM_UI_SESSION=1 and
MADEIRA_STEAM_UI_STRICT_RESERVATIONS=1, inspect the whole returned soft range
against current Wine views under virtual_mutex; reject intersecting candidates
and retain allocation failure if no candidate remains. No remap, extra backing,
protection workaround or Chromium change. Default gaming path is unchanged.
This check is not a complete broker for native/soft/cage future allocations.

Build 19: all 37 native units and full Xcode build pass. The final Mach-O contains
the reject-soft-overlap marker; the unchanged Build 18 diagnostic PE is staged
ONLY into the generated app, which passes strict signing and device install.
The real-device ~57.79-second trace records 12 rejected overlaps, zero soft pool
grants, and STATUS_NO_MEMORY for 16 GiB/~32 GiB fallback reservations. CEF now
fails at libcef.dll+0x6923404 after allocation failure, before interactive login.
The earlier chrome_elf+0xd7e3e site is not observed. The existing [brp-contain]
message also labels this unrelated fatal pattern as a refcount assertion:
its generic CC CC 0F 0B matcher is NOT a reliable classifier. Module/RVA and
context distinguish these failures. Pool/JIT layout also varies between runs;
this result exposes the capacity gate, not a proven final repair.

Regression: actual overlap lookup/grant code exercised with partial/interior,
guard-prefix, boundary/disjoint, tree-branch, exact dual-flag and balanced-lock
tests under ASan/UBSan; PASS. Observer fingerprint/partial-read/privacy tests
PASS. Policy/JIT/frontend checks PASS. No FEX or original Wine checkout edits.
Private raw artifacts: .madeira-install/steam-ui-pa-build17,
steam-ui-pa-build18 and steam-ui-reserve-build19. Redacted evidence and hashes:
docs/STEAM_UI_ALLOCATOR_EVIDENCE.json. A first stable-log download after SIGTERM
closed its socket; one retry succeeded. Only lab processes were terminated;
working main at ee9fd2f and playable app/data are preserved.

Next: inventory actual real/soft/cage interval ownership, reproduce the overlap
contract in an isolated reservation test, and determine a disjoint backed layout
before any new broker patch. Do not restore silent aliasing to make initialization
appear successful. No interactive login/Big Picture milestone is achieved.


## Offline interval audit and reservation probe (2026-10-23 14:53 UTC run)

Phase 1, parent 026dfde456f9b5015ba5d9ab38d3d4dbb14a194f. Origin/remote
experiment and main match; both working trees are clean at the start. All four
submodule pins remain those of the architecture audit. No concurrent build or
device launch was found. One device availability check fails with CoreDevice
4016: required trusted-connectivity/power assertions unavailable. It does NOT
establish that Kusch is locked. No install, launch, repeated poll or credential
operation follows. The installed latest candidate is still Build 19.

Observed failure: Build 19's honest overlap rejection exposes reservation
capacity failure. Hypothesis: even before furniture, the current high-band
policy cannot pack all four full advertised pool claims disjointly with its
existing FEX and cage ranges. Discriminating test: inventory numeric intervals
from already-hashed Build 18/19 logs, distinguish historical intersections from
live-view blockers, calculate reservation extent, and prepare an independent
reserve-only PE contract test before designing a broker.

Evidence: tools/analyze-steam-ui-pools.py extracts only known numeric fields;
docs/STEAM_UI_POOL_INVENTORY.json records original artifact hashes/line numbers.
Build 18 has two real pool claims and two soft claims with three historical
intersections (one is a 64 KiB guard-prefix intersection). Build 19 has two real
pool claims, zero soft grants and 12 live-view rejections. Lifecycle/releases
are NOT reconstructed by this parser; historical intersections alone do not
prove simultaneous ownership. Source definitions and observed boot holds are
inventoried in docs/STEAM_UI_ADDRESS_SPACE.md.

The full four requests total 64 GiB+128 KiB. Existing FEX (16 GiB) plus cage
(8 GiB-64 KiB) give at least 88 GiB+64 KiB of disjoint address claims before
furniture, against a 64 GiB current high-band policy. This invalidates simple
packing or FEX-shrinking alone under those assumptions; it does not establish
that genuine UI is impossible on this iPhone. Lower gaps, native capabilities,
actual backing and allocator-instance lifetimes remain incompletely measured.
The Social Club partial-backing layout is not automatically applicable to Steam.

Minimal change: offline numeric-only inventory tool, isolated x64 PE
reservation-ownership probe and a fixed opted-in diagnostic launch route. No
allocator policy changed this run; strict Build 19 guard retained. Probe makes
at most four plain/guard-shaped
MEM_RESERVE/PAGE_NOACCESS calls with explicit opt-in. It never commits, accesses
or frees their ranges. Distinct results separate overlap (40), capacity gate
(70), overflow (41), opt-in refusal (64), and four reported disjoint grants (0).
A 0 result would not prove backing/CEF. Whole isolated Lab termination is required
afterward because pseudo-process exit can retain mappings.

Validation: actual probe logic passes host API fixtures for all five outcomes
under ASan/UBSan. It compiles as x86-64 PE with the prepared LLVM-MinGW toolchain.
Parser tests pass guard-prefix/interior/half-open boundaries, failure filtering,
redaction and explicit lifecycle limitations. Existing strict-reservation host
regression also passes. This is NOT a device or Windows control execution;
Build 20 full unsigned Xcode build and local strict signing PASS. Its final
Mach-O includes both `madeira-reservation-diagnostics` and
reject-soft-overlap markers. The original source-farm ARM64EC ntdll was explicitly
staged into the generated app, replacing the optional CEF observer, and hashed.
The fixed route uses paired automatic JIT, isolated bundle/flag and fresh-session
gates, validates x64 PE and writes drive_c/madeira-reservation-results.txt; no
Steam client is launched. Host policy checks include its explicit opt-in and
actual CRLF batch. No Build 20 install or device execution is claimed. Compiled
PE, signed candidate and private availability record are under .madeira-install;
run artifacts are in steam-ui-pool-inventory-20261023;
probe/evidence hashes are docs/STEAM_UI_RESERVATION_PROBE_EVIDENCE.json.

Next: install prepared Build 20 when device availability returns, stage the
compiled PE at the lab drive_c root and use madeira-reservation-diagnostics;
collect reserve/VirtualQuery result and end the whole Lab. Obtain independent Windows control if available. Then
measure disjoint native Mach mappings in unprobed gaps using non-overwriting
requests before any new layout/broker patch. Do not repeat the basic FLS suite,
re-enable aliases, infer UI success, or assume unavailable means locked.

## Assessment

GO to continue the controlled Phase 1 experiment: architecture and local build
support a real-client test without rewriting the engine. NO-GO for claiming a
working Big Picture PoC or distributing this experiment as usable. Technical
feasibility on this device remains UNDETERMINED until runtime evidence exists.
Do not infer impossibility from a missing signing account, or success from a
successful build. The three historical failure families remain untested here.

## Next discriminating experiments

0. Resume from the interval audit / reserve-only contract test above. Latest
   installed app remains Build 19; Build 20 is built/signed locally and includes
   madeira-reservation-diagnostics for the compiled reservation-ownership probe.
   Check availability once; CoreDevice 4016 did not determine lock state. After contract results,
   measure disjoint native intervals before attempting a broker/layout change.
1. Preserve the passing Build 12/13 synthetic results and artifact hashes.
   Obtain an independent Windows control when available; do not claim it ran.
2. Inventory a full legitimate x64 Steam/CEF set in that prefix; no login cache or
   arbitrary client flags. Launch the login-only route. Capture native role
   lifecycle, CEF initialization, BrowserReady, window creation, screenshots and
   actual hover/click responses. Record meaningful negative results too.
3. If it faults, record Mach exception class/code and the actual libcef build/RVA.
   For kr=10 inspect backing-object and section lifetime, not blind protection
   retries. If it draws wrongly, capture source/destination checksums before
   blaming FEX. If CM fails, separate TCP/TLS/WebSocket/auth layers.
4. Only after interactive reliable CEF, add a distinct Big Picture flag and test
   Bluetooth navigation, library/account persistence, game launch and return.

Keep all experiment commits on experiment/steam-big-picture; do not merge them
into main. Resume from these gates rather than redoing the completed audit.

The recurring 305-minute task was updated to resume Phase 1 from this document,
rather than restarting the completed audit. No Windows Wine executable was found
on this Mac for the guest probe control; that execution remains pending.
