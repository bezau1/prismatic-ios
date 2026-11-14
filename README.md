# Prismatic

A Minecraft-launcher-style manager for Geometry Dash on iOS. Create **instances** (one per GD version), pull builds from Apple's servers with the Apple ID that bought the game, and run them in-process LiveContainer-style, with an optional **Geode mode**.

## Layout
- `Services/AppStoreClient.swift` – Apple ID login (+2FA), version list, IPA download (ipatool protocol)
- `Services/IPAInstaller.swift` – download/unzip into `Documents/Instances/<id>/`
- `Launcher/PrismaticLoader.m` – guest loader: HOME redirect, `NSBundle` spoofing, header patch + `dlopen`, jump to `main`
- `Services/GeodeManager.swift` – Geode iOS dylib install, GD 2.2–2.2081 gate
- `Services/JIT.swift` – CS_DEBUGGED check, asks StikJIT/SideStore to attach

## Build
`brew install xcodegen && xcodegen && open Prismatic.xcodeproj` (macOS + Xcode required; sideload the IPA with a dev cert).

## Status: scaffold, not compiled or tested
Written on Linux, so nothing has been built or run. Known gaps:
1. **FairPlay**: App Store IPAs are encrypted to the device. Re-signed, they can't run. Prismatic detects `cryptid` and requires a decrypted IPA of the same version for launching. This is the biggest blocker and no loader design removes it.
2. Loader needs real-device work: guest re-signing (zsign), fat→thin, proper dylib conversion, dyld/entitlement tweaks, more hooks (`NSUserDefaults`, `Keychain`, `UIApplicationMain` handling).
3. `GeodeManager.repo` is a placeholder; point it to the real Geode iOS release source.
4. Token storage uses UserDefaults; move to Keychain.
5. LiveContainer is GPL-3: this is written independently, but borrowing its code would make Prismatic GPL-3.
