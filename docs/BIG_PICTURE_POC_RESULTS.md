# Genuine Steam UI PoC results

Updated 2026-10-22. Current phase: Phase 0 complete; Phase 1 controlled launcher
implemented and exercised; first CEF load failed due to JIT pool capacity. Build 10 rejected fixed secondary preparation and later exhausted image space. Build 11 tests existing region C, pending execution. Main remains
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
and its AMD64 PE headers/imports inspected. It has NOT been executed on Windows
or iOS. Do not count this as a passing pseudo-process integration test.

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

## Assessment

GO to continue the controlled Phase 1 experiment: architecture and local build
support a real-client test without rewriting the engine. NO-GO for claiming a
working Big Picture PoC or distributing this experiment as usable. Technical
feasibility on this device remains UNDETERMINED until runtime evidence exists.
Do not infer impossibility from a missing signing account, or success from a
successful build. The three historical failure families remain untested here.

## Next discriminating experiments

0. Collect Build 11 region-C RX/RW acceptance, pool sizes/tail usage, and
   libglesv2/CEF startup evidence. Build 10 rejected exact preparation; do not
   retry that path or attribute ASLR capacity changes to it.
1. With the isolated app now provisioned and installed, run the synthetic PE in the
   separate app/prefix and record child exit plus shared-match, with Windows
   control if available. Record exact installed Mach-O hashes.
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
