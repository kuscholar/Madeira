# Genuine Steam UI PoC results

Updated 2026-10-22. Current phase: Phase 0 complete; Phase 1 controlled launcher
implemented and locally built, physical-device validation pending. Main remains
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

## Actual device gate

No new experiment was installed and no Steam login was attempted. Existing
profiles do not match the isolated .steamui app/extension. An official Xcode
`-allowProvisioningUpdates` build failed with No Accounts and No profiles for
both bundle IDs. User was asked to log into Xcode Settings > Accounts; no
credential entry or provisioning bypass was attempted. Continue verifiable local
work while waiting. The working application's files, installed data and main
branch were not changed.

A complete legitimate matching Steam/CEF tree in the experiment's OWN prefix is
also required. Do not substitute the baseline's sign-in cache. Human Steam Guard
completion is required if Valve requests it. No claimed networking, pixel,
controller, login, Big Picture, library, persistence or game-return validation.

## Assessment

GO to continue the controlled Phase 1 experiment: architecture and local build
support a real-client test without rewriting the engine. NO-GO for claiming a
working Big Picture PoC or distributing this experiment as usable. Technical
feasibility on this device remains UNDETERMINED until runtime evidence exists.
Do not infer impossibility from a missing signing account, or success from a
successful build. The three historical failure families remain untested here.

## Next discriminating experiments

1. After official isolated provisioning is available, run the synthetic PE in the
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
