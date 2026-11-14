# Prismatic

A Minecraft-launcher-style manager for Geometry Dash on iOS (min iOS 14). Create **instances** (one per GD version), pull builds from Apple's servers with the Apple ID that bought the game, and run them in-process LiveContainer-style, with optional **Geode mode** (GD 2.2 – 2.2081) .

## Three builds
| Build | File | How it gets a runnable (decrypted) binary |
|---|---|---|
| Standard | `Prismatic.ipa` | Sideload (SideStore/AltStore). Needs JIT + you import a decrypted IPA |
| TrollStore | `Prismatic-TrollStore.tipa` | Installs the exact pulled version through installd (FairPlay intact), dumps it from memory (TrollDecrypt method), deletes the installed app, then runs the decrypted copy. One-time per instance |
| Jailbreak | `Prismatic-Jailbreak-{rootful,rootless}.deb` | Same flow, triggered automatically on first launch |

Both privileged builds uninstall the App Store copy of GD (and its save data) when they install an instance's version.

**Export:** once an instance is decrypted (TrollStore/Jailbreak build, or an import), long-press it → *Export decrypted IPA* to share a normal IPA that non-TrollStore devices can import in the Standard build. The FairPlay receipt (`SC_Info`) is stripped.

## Layout
- `Services/AppStoreClient.swift` – Apple ID login (+2FA), version list, IPA download (ipatool protocol)
- `Launcher/PrismaticDecrypt.m` – installed-app lookup, TrollDecrypt-style dump, jailbreak installd install
- `Launcher/PrismaticLoader.m` – guest loader: HOME redirect, `NSBundle` spoofing, header patch + `dlopen`, jump to `main`
- `Services/GeodeManager.swift` / `JIT.swift` – Geode install + gate, JIT detection / request
- CI: `.github/workflows/build.yml` builds all three

## Status: scaffold, not compiled or tested
Nothing has been built or run on a device. Known gaps:
1. Re-signing is ported (LiveContainer's ZSign, ad-hoc) but LiveContainer's dyld validation bypass and Mach-O utils aren't yet, so `dlopen` of the re-signed binary may still be refused in the standard build.
2. Loader needs real-device work (fat→thin, dylib conversion, dyld validation bypass, more hooks).
3. The installd install/uninstall calls (`PackageType`, entitlements, whether installd accepts the sinf IPA on-device) are best guesses.
4. `GeodeManager.repo` is a placeholder. Tokens are in UserDefaults; move to Keychain.
5. Prismatic is AGPL-3.0 (see `LICENSE`, `NOTICE.md`) because it includes LiveContainer code.

Local builds: `git clone --depth 1 --branch 3.6.5000 --filter=blob:none --sparse https://github.com/krzyzanowskim/OpenSSL && git -C OpenSSL sparse-checkout set Frameworks` before `xcodegen`.
