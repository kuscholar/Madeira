# Isolated Steam UI diagnostics

No Steam/Valve binaries, account data or game content are distributed here.

## Host checks

From the repository root (Python 3, Swift and a host C compiler):

```sh
python3 tests/host/check-steam-ui.py
python3 tests/host/check-dock-contract.py
python3 tests/host/check-frontend.py
```

The first compiles the production Swift launch policy with synthetic PE
headers and the production C child-event function under ASan/UBSan. It checks
flag-off, app isolation, missing/mismatched client architecture, symlink refusal,
bounded desktop size, a fixed credential-free command and categorical log
output. It neither contacts Steam nor runs the Windows client.

## x86-64 Windows process/shared-memory probe

```sh
export LLVM_MINGW=/path/to/llvm-mingw-20260421-ucrt-macos-universal
"$LLVM_MINGW/bin/x86_64-w64-mingw32-clang" -O2 -municode -static \
  -Wl,--no-insert-timestamp tests/steam-ui/process-shared-memory.c \
  -o /tmp/steam-ui-process-probe.exe
"$LLVM_MINGW/bin/llvm-readobj" --file-headers --coff-imports \
  /tmp/steam-ui-process-probe.exe
```

Run the PE on an authorized Windows/Wine control first, then from an isolated
Madeira experimental prefix. The parent creates a named mapping, launches its
own child, waits 15 seconds, checks child exit and shared-memory content. Pass:
`steam-ui-process-probe wait=0 child_exit=0 shared_match=1`, process exit 0.
Nonzero is a test failure, not proof of a particular Wine/FEX defect. No child is
forcibly terminated on timeout. Keep the experiment separate from a game session.
The PE was compiled and inspected locally; Windows/iPhone execution is pending.
This is a process-plumbing test, not a Skia raster test or CEF simulation.

## Build and activate the real-client experiment

1. Read docs/BUILDING.md and docs/LOCAL_IPHONE_REPAIR.md, initialize the pinned
   submodules and build required dependencies. Reuse a prepared native archive
   only when its corresponding source is unchanged. For this change rebuild
   `bash build/ntdll-unix/build.sh`; the host ObjC bridge recompiles with the app.
   Preserve licence notices and stage them with `bash build/stage-licenses.sh`.
2. Build an unsigned local validation target (existing dependencies required):

   ```sh
   xcodebuild -project app/Madeira.xcodeproj -scheme Madeira \
     -configuration Debug -destination 'generic/platform=iOS' \
     -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
     MADEIRA_BUNDLE_IDENTIFIER=com.example.madeira.steamui \
     CURRENT_PROJECT_VERSION=9 IPHONEOS_DEPLOYMENT_TARGET=26.0 build
   ```

3. Inspect the FINAL Mach-O, including Madeira.debug.dylib in Debug builds:

   ```sh
   strings build/DerivedData/Build/Products/Debug-iphoneos/Madeira.app/Madeira.debug.dylib \
     | rg 'steam-ui-process|experiment-begin login-only|payload-wide debug channels'
   nm build/DerivedData/Build/Products/Debug-iphoneos/Madeira.app/Madeira.debug.dylib \
     | rg 'SteamUIExperiment|SteamUIEvidence'
   shasum -a 256 build/DerivedData/Build/Products/Debug-iphoneos/Madeira.app/Madeira.debug.dylib
   ```

4. Use Xcode's normal account/provisioning flow for this DISTINCT bundle ID and
   its `.JITHelper` extension. Do not rename/reuse the working application's
   provisioning profiles, uninstall it, or copy its Keychain/login caches. The
   target suffix `.steamui` is an intentional runtime isolation check.
5. Populate only the experiment's own Wine prefix with a complete legitimate
   64-bit Windows Steam installation. Required: steam.exe, steamclient64.dll,
   and matching bin/cef/cef.win7x64 (or cef.win64 / cef) webhelper and libcef.
   Headless Dock components alone are insufficient. Inspect hashes/PE versions
   before the run. Do not copy config/loginusers.vdf/ssfn files or credentials
   from another installation. Valve authentication remains mandatory.
6. In the EXPERIMENT'S Documents/madeira.cfg set:

   ```ini
   env.MADEIRA_FRONTEND = 0
   env.MADEIRA_EXPERIMENTAL_STEAM_UI = 1
   pool-split = 1
   ```

   Restart the experiment, enable JIT with its existing workflow and press
   `Steam UI Experiment` in the developer interface. The old `Steam Testing`
   button is NOT the controlled experiment: it arms extra historical probes.
   The new button starts a fixed login-only command through services and the
   virtual desktop. No -bigpicture flag is passed at this stage.
7. Keep raw Steam/device logs app-private or in ignored local artifacts. The
   observer starts at each log's existing EOF and emits only categorical
   ChromeMainDelegate/BrowserReady evidence from a bounded new-log tail. Missing
   observer output is inconclusive (rotation, file locations and a bounded tail
   can miss events). Host-surface-present includes non-CEF windows and is NOT a
   login/interaction success result. Existing Winios window logs provide window
   census evidence; pixel correctness and interaction need independent capture.
8. Record exact installed artifact hashes, helper/client versions, pseudo-process
   lifecycle, CEF startup, BrowserReady, window pixels and physical interaction.
   Never log sign-in tokens/passwords. Do not claim the CEF milestone before that
   evidence exists. Only then investigate Big Picture, Bluetooth and game return.

Local build note: the audited experiment reused unchanged baseline FEX/DXMT,
crypto/media/pairing archives and optional i386 resources, and rebuilt ntdll.
It was not a clean-machine dependency rebuild. The independent app and helper
were subsequently provisioned through Xcode, signed, installed and launched.
CEF and guest-probe execution remain pending; installation does not validate them.


## Stage the public full client reproducibly

This branch defaults to the owner's independent `com.kuschqin.madeira.steamui`
ID/team and displays Steam UI Lab. For your own device override
`MADEIRA_BUNDLE_IDENTIFIER` (retain `.steamui`) and `DEVELOPMENT_TEAM`; provision
both app and helper through Xcode. Its registered callback scheme is
`madeira-steamui`, distinct from the working app.

The existing Dock-only runtime lacks CEF. Do not copy its account directory.
Fetch the complete matching public package set into a NEW local staging folder:

```sh
python3 tools/fetch-steam-ui-client.py \
  --manifest tests/steam-ui/manifests/steam_client_win64_1792618285.vdf \
  --cache /path/outside-git/steam-packages \
  --output /path/outside-git/Steam
```

The tool selects the standard steamrow bootstrap, verifies each package's
size/SHA-256 against the explicitly saved HTTPS manifest, refuses path traversal
and symlink ZIP entries, and emits a full local inventory beside the output.
It does not independently validate Valve's manifest signatures. Keep packages
and output outside Git; the output must not already exist. Do not point it at a
live installation. Steam authentication/licensing remain Steam's responsibility.

Copy this new Steam directory only to the experimental app's
`Documents/wine/drive_c/Program Files (x86)/Steam`, using the normal device file
service. For a developer-only first run, also set `env.MADEIRA_ONBOARDING = 0`
in the experiment's cfg, so Dock's setup downloader does not replace this
separate full client. No pairing files or account caches need be copied.
The synthetic probe belongs at `Documents/wine/drive_c/steam-ui-process-probe.exe`;
copying it there does not execute it. Normal manual library/desktop launching
can be used for this diagnostic in a separate session.

Experimental CEF policy now overrides inherited VLOG with warning severity and
suppresses command-tail echoes. Raw Steam logs must stay app-private. The
categorical observer can miss initialization messages at this severity; missing
markers remain inconclusive. Interactive pixels and device crash evidence are
still required before declaring the login milestone.


## Current capacity experiment (Build 11)

Build 10's exact secondary-region approach failed actual iOS RX verification
and has been removed. Its host mock test and candidate remain at commit
29f5f6f, for diagnosis only. See docs/STEAM_UI_RUN2_EVIDENCE.json.

Use `tests/steam-ui/lab-madeira.cfg` only in the isolated app. Its sole new
capacity option is `pool-low = 1`; existing region C moves FEX buffers out of
the image pool. Do not copy it to the working baseline. No default allocator
or FEX change is needed. Relevant host regression checks:

```sh
python3 tests/host/check-pool-low.py
python3 tests/host/check-pool-split.py
python3 tests/host/check-jit-method.py
python3 tests/host/check-steam-ui.py
python3 tests/host/check-frontend.py
```

Require accepted region-C RX/RW mappings, main-pool tail consumption and
libglesv2/import results from the next device run. The JIT badge now remains
green after intentional debugger detach when a pool was successfully prepared;
it does not imply CEF rendering or game success.
