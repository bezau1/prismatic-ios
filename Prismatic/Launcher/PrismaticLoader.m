// In-process guest loader modelled on LiveContainer's LCBootstrap (AGPL-3.0). Written for Prismatic.
#import "PrismaticLoader.h"
#import "PrismaticLog.h"
#import "LCMachOUtils.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <limits.h>

extern const char **_CFGetProcessPath(void);
extern char **environ;
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define CS_OPS_STATUS 0
#define CS_DEBUGGED 0x10000000

#define PLOG(...) PrismaticLogString([NSString stringWithFormat:__VA_ARGS__])

BOOL PrismaticIsJITEnabled(void) {
    int flags = 0; csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags));
    return (flags & CS_DEBUGGED) != 0;
}

NSString *PrismaticPatchExecutable(NSString *path) {
    return LCParseMachO(path.fileSystemRepresentation, false, ^(const char *p, struct mach_header_64 *h, int fd, void *filePtr) {
        int r = LCPatchExecSlice(p, h, false);
        PLOG(@"patched executable %s (result flags %d)", p, r);
    });
}

// ---- NSBundle spoofing: the game must see its own .app as the main bundle.
// The guest bundle is created BEFORE swizzling and cached: calling +bundleWithPath: from inside the swizzled
// +mainBundle would recurse forever.
static NSBundle *gGuestBundle;
static NSString *gGuestBundleId;

@implementation NSBundle (Prismatic)
+ (NSBundle *)prism_mainBundle { return gGuestBundle; }
- (NSString *)prism_bundleIdentifier {
    return (self == gGuestBundle) ? gGuestBundleId : [self prism_bundleIdentifier];
}
@end

static void swizzle(Class c, SEL a, SEL b, BOOL meta) {
    if (meta) c = object_getClass(c);
    Method ma = class_getInstanceMethod(c, a), mb = class_getInstanceMethod(c, b);
    if (ma && mb) method_exchangeImplementations(ma, mb);
}

static const struct mach_header_64 *guestHeader(NSString *exe) {
    const char *want = exe.fileSystemRepresentation;
    char real[PATH_MAX]; BOOL haveReal = realpath(want, real) != NULL;
    NSString *tail = [NSString stringWithFormat:@"%@/%@", exe.stringByDeletingLastPathComponent.lastPathComponent, exe.lastPathComponent];
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (!strcmp(n, want) || (haveReal && !strcmp(n, real)) || [@(n) hasSuffix:tail]) {
            return (const struct mach_header_64 *)_dyld_get_image_header(i);
        }
    }
    return NULL;
}

static void *entryPoint(const struct mach_header_64 *h) {
    const uint8_t *p = (const uint8_t *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        const struct load_command *lc = (const void *)p;
        if (lc->cmd == LC_MAIN) return (void *)((uint8_t *)h + ((const struct entry_point_command *)lc)->entryoff);
        p += lc->cmdsize;
    }
    return NULL;
}

void PrismaticLaunchGuest(NSString *appPath, NSString *dataPath, NSString *bundleId, NSString *geodePath) {
    PLOG(@"launch guest: app=%@ data=%@ id=%@ geode=%@ jit=%d", appPath, dataPath, bundleId, geodePath ?: @"-", PrismaticIsJITEnabled());
    NSBundle *bundle = [NSBundle bundleWithPath:appPath];
    NSString *exe = bundle.executablePath;
    if (!bundle || !exe) { PLOG(@"FAIL: no bundle/executable at %@", appPath); return; }
    gGuestBundle = bundle; gGuestBundleId = bundleId;

    // Redirect the guest's sandbox into the instance folder.
    setenv("HOME", dataPath.UTF8String, 1);
    setenv("CFFIXED_USER_HOME", dataPath.UTF8String, 1);
    setenv("TMPDIR", [dataPath stringByAppendingPathComponent:@"tmp"].UTF8String, 1);
    for (NSString *s in @[@"Documents", @"Library/Caches", @"Library/Preferences", @"Library/Application Support", @"tmp"])
        [[NSFileManager defaultManager] createDirectoryAtPath:[dataPath stringByAppendingPathComponent:s]
                                  withIntermediateDirectories:YES attributes:nil error:nil];

    swizzle(NSBundle.class, @selector(mainBundle), @selector(prism_mainBundle), YES);
    swizzle(NSBundle.class, @selector(bundleIdentifier), @selector(prism_bundleIdentifier), NO);

    if (PrismaticIsJITEnabled()) { init_bypassDyldLibValidation(); PLOG(@"dyld validation bypass installed"); }
    else PLOG(@"no JIT: skipping dyld bypass");

    *_CFGetProcessPath() = strdup(exe.fileSystemRepresentation);

    void *handle = dlopen(exe.fileSystemRepresentation, RTLD_LAZY | RTLD_GLOBAL | RTLD_FIRST);
    if (!handle) { PLOG(@"FAIL: dlopen(game) -> %s", dlerror()); return; }
    PLOG(@"game image loaded");

    // Geode loads after the game image exists (like a TweakLoader dependency) and before main().
    if (geodePath) {
        void *g = dlopen(geodePath.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
        if (g) PLOG(@"Geode loaded"); else PLOG(@"Geode dlopen failed: %s", dlerror());
    }

    NSError *err = nil;
    if (![bundle loadAndReturnError:&err]) PLOG(@"bundle load reported: %@ (continuing)", err);

    const struct mach_header_64 *h = guestHeader(exe);
    void *entry = h ? entryPoint(h) : NULL;
    if (!entry) { PLOG(@"FAIL: could not find the game's main() (header=%p)", h); return; }

    PLOG(@"jumping to game main at %p", entry);
    char *argv[] = { (char *)exe.fileSystemRepresentation, NULL };
    int ret = ((int (*)(int, char **, char **))entry)(1, argv, environ);
    PLOG(@"game main returned %d", ret);
}
