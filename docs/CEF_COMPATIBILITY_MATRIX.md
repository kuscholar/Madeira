# Steam CEF compatibility matrix

Revision scope: experimental branch based on ee9fd2f, audited in
BIG_PICTURE_ARCHITECTURE.md. Updated 2026-10-23. Historical evidence refers to
published notes at deezhizyu/madeira 97e2ce2, not a new device run.

| Area | Historical report | Current source/local evidence | Current-device status / next discriminator |
|---|---|---|---|
| Real Steam login | Interactive login/QR refresh reported | Existing services + desktop + steam.exe route; new isolated opt-in launch policy compiles | Build 11 blank desktop; first chrome_elf assertion precedes later exhaustion; no login UI |
| CEF child model | Single-process CEF needed for VA capacity | Initial webhelper allowed, --single-process injected; --type children refused | Build 11 CEF initializes, then chrome_elf refcount assertion; no BrowserReady |
| dwrite/text | Missing unixlib, then text rendered | dwrite object compiled and explicitly archived by native build script | Current Steam text not observed |
| JIT provisioning | Early detach avoided a historical stall | Existing StikJIT/pool setup; no new entitlement requested | Build 11 accepted 880 MiB A/B + 352 MiB C; Build 13 automatic paired JIT diagnostics passed |
| libcef+0x41258FB | kr=10 on mapped RW data; cause open | Later owner/backing probes present; no new retry/protection workaround | Not reproduced; collect Mach return code and mapping/backing lifetime first |
| Skia tile displacement | 254px tile-related displacement; FEX hypothesis unproved | Existing surface/compositor path; new observer reports only host present, never correctness | Need paired SRC/SURF checksums and isolated raster PE/control; not yet implemented |
| CM networking | TCP connected; some TLS; WebSocket/auth failed | Existing native network stack and true Valve auth remain | CEF load failed before UI; CM/TLS/WS/auth behavior not yet evaluated |
| Auth/licensing | Genuine client sign-in, not bypass | New route does not use Dock token transfer or fabricated game identity | Human login/Steam Guard and license validation pending |
| Isolation | All guest children share one Mach task | New mode requires .steamui bundle suffix and flag=1; symlinked client files rejected | Separate Steam UI Lab installed; working app retained |
| Lifecycle | Fatal helper can kill app; guest process != Mach process | Per-child categorical events added behind session flag; no retries/forced termination | Actual Build 12/13 x64 child/shared-map/exit tests PASS; basic chrome_elf import/heap/thread and Build 15 FLS lifetime/isolation tests PASS |
| Rendering/UI | Login had corrupt tiles | Real UI still goes through existing GDI/DXMT/Metal; no UI replacement | Steam error dialog/desktop captured; no real CEF content |
| Big Picture | No reliable end-to-end evidence in handoff | Deliberately absent from first login-only command | Gate until interactive login and CEF stability established |
| Bluetooth/navigation | No applicable current test | Existing GameController/XInput input path unchanged | Backbone game success is not Bluetooth/Steam UI validation |
| Game and return | Ordinary games can run in baseline | One-session-per-app and shared task remain | Launch-from-Big-Picture and return not tested |

No row marked source/local evidence is a device success claim. The experiment
has not fixed the three historical fault families. Source-level instrumentation
and a successful link only make the next test possible.


Build 16 actual CEF ownership trace: the failing CRT PTD has one observed set
and its first callback faults at chrome_elf+0xd7e3e; no earlier FLS delivery for
that pointer. Synthetic FLS still PASS with observer loaded. This narrows the
investigation to pre-callback allocation/free/corruption or translation, without
proving any of them. See STEAM_UI_FLS_TRACE_EVIDENCE.json; interactive CEF remains
unverified. Callback/refcount behavior was not changed.
