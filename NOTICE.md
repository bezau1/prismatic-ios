# Third-party notices

Prismatic is licensed under the **GNU AGPL-3.0** (see `LICENSE`).

## Included code
- **ZSign** (`Prismatic/Vendor/ZSign`): copied unmodified from [LiveContainer](https://github.com/LiveContainer/livecontainer) (AGPL-3.0, Copyright the LiveContainer authors). LiveContainer's ZSign is based on [zhlynn/zsign](https://github.com/zhlynn/zsign) (MIT) through [Feather's Zsign-Package fork](https://github.com/khcrysalis/Zsign-Package); the upstream notices are retained in the source files where present.
- **dyld library-validation bypass** (`Prismatic/Vendor/DyldBypass`): copied from LiveContainer (AGPL-3.0); it is based on xpn's [DyldDeNeuralyzer](https://github.com/xpn/DyldDeNeuralyzer) / "Restoring dyld memory loading".
- **litehook** (`Prismatic/Vendor/litehook`): MIT, Copyright (c) 2022-2024 Lars Fröder (see its `LICENSE`).
- **ApplePackage** ([Lakr233/ApplePackage](https://github.com/Lakr233/ApplePackage), MIT, Copyright (c) 2025 Lakr233): App Store login/SAP signing, version lookup and downloads. Used as a Swift package dependency pinned to a commit, not copied.
- **OpenSSL** (`krzyzanowskim/OpenSSL` xcframework, fetched at build time): Apache-2.0 / OpenSSL licenses.

## Referenced designs
- [LiveContainer](https://github.com/LiveContainer/livecontainer) (AGPL-3.0): in-process guest loading approach.
- [geode-sdk/ios-launcher](https://github.com/geode-sdk/ios-launcher) (Boost-1.0, with Apache-2.0 LiveContainer-derived parts): Geode install/patch flow.
- [TrollDecrypt](https://github.com/donato-fiore/TrollDecrypt): decrypt-from-memory method.
