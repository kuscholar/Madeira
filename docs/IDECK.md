# iDeck

User-directed product integration, 2026-10-23. iDeck runs Valve's genuine Windows
Steam Big Picture locally through Madeira/Wine/FEX. It does not install Linux
SteamOS, stream another computer, replace Steam UI, or bypass authentication or
licensing. Madeira's licenses, exception and component attribution still apply.

## User flow

1. Open iDeck. Prepare its runtime/official Steam resources once in the launcher.
2. Configure the existing Madeira device pairing/JIT flow. Credentials, passcodes
   and pairing approval remain the user's responsibility.
3. Choose **Launch Steam Big Picture**. iDeck requests JIT for the current app
   process, then starts Valve's client with `-bigpicture` in its own Wine prefix.
4. Sign in inside genuine Steam. Steam owns its Remember me state; iDeck never
   copies passwords, refresh tokens or another app's authentication cache.
5. Automatic startup is on by default after setup. Disabling it returns future
   launches to the launcher. JIT must still be obtained for each new process.
6. Use an iPhone controller directly, or tap the guest interface at the touch
   position (existing direct-touch mode, rather than relative trackpad mode).
7. The floating menu offers keyboard, virtual Xbox controls, layout editing,
   settings and automatic-start preference. Home / Back+Start opens it through
   the existing controller routing. Menus consume controller input while open.

## Isolation and data

Build30 upgrades the existing `com.kuschqin.madeira.steamui` installation and
changes its display name to iDeck, preserving the prefix, login state, games and
saves. Retaining this identifier avoids a new free-signing slot and destructive
migration. It is separate from the working Madeira app and main checkout.

The product shell defaults on through `IDeckEnabled` in this branch's Info.plist,
requires the existing `.steamui` bundle isolation, and can be disabled with
`env.MADEIRA_IDECK = 0`. Explicit diagnostics never run concurrently with automatic
startup. Incomplete existing prefixes are preserved, not overwritten by setup.
No Valve executable, game, profile, credential or private log is committed.

## Build

Follow BUILDING.md for the pinned submodules and native dependencies. Source
checkouts alone do not include all required runtime assets. For the research
client resource preparation, use tests/steam-ui/README.md and the verified
`tools/fetch-steam-ui-client.py --architecture win32` flow. Stage that complete,
authentication-free official tree as the private generated app resource
`Steam32OfficialClient`, alongside the existing `prefix-template.tar.gz` and
runtime binaries. Setup copies it once to `wine/drive_c/Steam32BundleLab`.
Missing resources produce an actionable setup error, never a fake ready status.
Do not redistribute Valve components without satisfying their terms.

This PoC currently uses the frozen official 32-bit Steam client. Valve ended its
32-bit Windows client support in January2026; a maintained production solution
is not demonstrated. The 64-bit CEF address-space and intermittent Crashpad
failures remain documented separately.

Example local unsigned compile:

```sh
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath /path/to/private/build \
  CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION=30 build
python3 tests/host/check-ideck.py
python3 tests/host/check-steam-ui.py
python3 tests/host/check-steam-ui-keyboard.py
```

Use an authorized development identity/profile for the exact app/helper IDs.
Verify the linked Mach-O (Debug uses Madeira.debug.dylib), signature, install,
launch and phone behavior separately. A successful compile is not device proof.

## Evidence and remaining acceptance

Build29 showed real authenticated Big Picture, a Hot Roads details/download page,
Unity splash and the actual game's menu. Official Steam log tracks app1819280's
`hr.exe`; its manifest reports installed state4. User explicitly reports game
execution works. These do not establish return-to-Steam, Bluetooth input, or
reliable repeated startups. Build29's read-only fatal probe did not reproduce the
Build28 failure; no causal stability fix is claimed.

Build30 launcher/setup/full-screen/menu integration has local compile and host
policy evidence. Installation and all product UI/device acceptance are pending
until the phone is available. Test: launcher on normal open; setup preservation;
JIT handoff; true full-screen Big Picture; controller and direct touch navigation;
floating menu keyboard/overlay/settings; licensed game play and return; app
restart with saved login/auto-start. Do not mark the whole product complete from
these source or host checks.
