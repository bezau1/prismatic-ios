#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// YES when a debugger has been attached (CS_DEBUGGED), i.e. JIT is usable.
BOOL PrismaticIsJITEnabled(void);
/// LiveContainer's dyld library-validation bypass (needs JIT). Safe to call repeatedly.
void init_bypassDyldLibValidation(void);
/// Loads the guest app's executable into this process and jumps to its main().
/// If geodePath is non-nil, Geode's dylib is loaded first so it can hook the game at startup.
void PrismaticLaunchGuest(NSString *appPath, NSString *dataPath, NSString *bundleId, NSString *_Nullable geodePath);
NS_ASSUME_NONNULL_END
