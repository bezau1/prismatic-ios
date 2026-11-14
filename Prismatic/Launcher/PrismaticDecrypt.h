#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Path of the App Store install of `bundleId` (the .app dir), or nil.
NSString *_Nullable PrismaticInstalledAppPath(NSString *bundleId);
/// TrollDecrypt method: copy the .app, spawn the real binary suspended, task_for_pid it,
/// read the FairPlay-decrypted pages out of its memory, patch them into the copy, set cryptid=0.
BOOL PrismaticDecryptBundle(NSString *srcApp, NSString *dstApp, NSString *_Nullable *_Nullable err);
/// Privileged builds: install an original (sinf-carrying) IPA through installd so FairPlay is intact.
BOOL PrismaticInstallIPA(NSString *ipaPath, NSString *_Nullable *_Nullable err);
/// Remove an installed app by bundle id (used to drop the App Store copy once it is decrypted).
BOOL PrismaticUninstallApp(NSString *bundleId, NSString *_Nullable *_Nullable err);
NS_ASSUME_NONNULL_END
