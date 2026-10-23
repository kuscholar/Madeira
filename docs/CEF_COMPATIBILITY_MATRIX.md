# Steam CEF compatibility matrix

Revision scope: experimental branch based on ee9fd2f, audited in
BIG_PICTURE_ARCHITECTURE.md. Updated 2026-10-22. Historical evidence refers to
published notes at deezhizyu/madeira 97e2ce2, not a new device run.

| Area | Historical report | Current source/local evidence | Current-device status / next discriminator |
|---|---|---|---|
| Real Steam login | Interactive login/QR refresh reported | Existing services + desktop + steam.exe route; new isolated opt-in launch policy compiles | Not run; requires isolated signed app and complete matching client |
| CEF child model | Single-process CEF needed for VA capacity | Initial webhelper allowed, --single-process injected; --type children refused | Validate child start/end and BrowserReady in new run |
| dwrite/text | Missing unixlib, then text rendered | dwrite object compiled and explicitly archived by native build script | Current Steam text not observed |
| JIT provisioning | Early detach avoided a historical stall | Existing StikJIT/pool setup; no new entitlement requested | Independent experiment profile absent; normal Xcode signing failed No Accounts |
| libcef+0x41258FB | kr=10 on mapped RW data; cause open | Later owner/backing probes present; no new retry/protection workaround | Not reproduced; collect Mach return code and mapping/backing lifetime first |
| Skia tile displacement | 254px tile-related displacement; FEX hypothesis unproved | Existing surface/compositor path; new observer reports only host present, never correctness | Need paired SRC/SURF checksums and isolated raster PE/control; not yet implemented |
| CM networking | TCP connected; some TLS; WebSocket/auth failed | Existing native network stack and true Valve auth remain | No client connection attempted; distinguish TCP/TLS/WS/auth with private raw logs |
| Auth/licensing | Genuine client sign-in, not bypass | New route does not use Dock token transfer or fabricated game identity | Human login/Steam Guard and license validation pending |
| Isolation | All guest children share one Mach task | New mode requires .steamui bundle suffix and flag=1; symlinked client files rejected | Host tests pass; no experiment installed over working app |
| Lifecycle | Fatal helper can kill app; guest process != Mach process | Per-child categorical events added behind session flag; no retries/forced termination | x64 CreateProcess/shared-map probe compiled, not executed |
| Rendering/UI | Login had corrupt tiles | Real UI still goes through existing GDI/DXMT/Metal; no UI replacement | No real CEF framebuffer captured |
| Big Picture | No reliable end-to-end evidence in handoff | Deliberately absent from first login-only command | Gate until interactive login and CEF stability established |
| Bluetooth/navigation | No applicable current test | Existing GameController/XInput input path unchanged | Backbone game success is not Bluetooth/Steam UI validation |
| Game and return | Ordinary games can run in baseline | One-session-per-app and shared task remain | Launch-from-Big-Picture and return not tested |

No row marked source/local evidence is a device success claim. The experiment
has not fixed the three historical fault families. Source-level instrumentation
and a successful link only make the next test possible.
