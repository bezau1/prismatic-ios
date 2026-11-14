#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// YES when CS_DEBUGGED is set on this process, i.e. JIT / relaxed code signing is available.
BOOL PrismaticIsJITEnabled(void);
/// LiveContainer's dyld library-validation bypass (needs JIT). Safe to call repeatedly.
void init_bypassDyldLibValidation(void);
/// Convert the game executable into a loadable dylib in place (LiveContainer's LCPatchExecSlice).
/// Returns an error string, or nil on success. Must run BEFORE signing.
NSString *_Nullable PrismaticPatchExecutable(NSString *path);
/// Load the guest game into this process and jump to its main(). Call only from main(), before UIKit starts,
/// in a process that was just (re)launched. Returns only on failure (details go to the log).
void PrismaticLaunchGuest(NSString *appPath, NSString *dataPath, NSString *bundleId, NSString *_Nullable geodePath);
NS_ASSUME_NONNULL_END
