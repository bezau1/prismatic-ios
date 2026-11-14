// LiveContainer-style in-process guest loader (written from scratch; LiveContainer is GPL-3).
#import "PrismaticLoader.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define CS_OPS_STATUS 0
#define CS_DEBUGGED 0x10000000

BOOL PrismaticIsJITEnabled(void) {
    int flags = 0; csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags));
    return (flags & CS_DEBUGGED) != 0;
}

static NSString *gGuestBundlePath, *gGuestBundleId;

// --- NSBundle spoofing: the game must believe its own .app is the main bundle ---
@implementation NSBundle (Prismatic)
+ (NSBundle *)prism_mainBundle { return [NSBundle bundleWithPath:gGuestBundlePath]; }
- (NSString *)prism_bundleIdentifier {
    return (self == [NSBundle bundleWithPath:gGuestBundlePath]) ? gGuestBundleId : [self prism_bundleIdentifier];
}
@end

static void swizzle(Class c, SEL a, SEL b, BOOL meta) {
    if (meta) c = object_getClass(c);
    method_exchangeImplementations(class_getInstanceMethod(c, a), class_getInstanceMethod(c, b));
}

// Turn the MH_EXECUTE into a loadable MH_DYLIB copy so dlopen accepts it.
static NSString *patchedCopy(NSString *exe, NSString *dir) {
    NSString *dst = [dir stringByAppendingPathComponent:@"Library/Caches/guest.patched"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dst.stringByDeletingLastPathComponent
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableData *d = [NSMutableData dataWithContentsOfFile:exe];
    struct mach_header_64 *h = (void *)d.mutableBytes;
    if (h->magic != MH_MAGIC_64) return nil;           // thin arm64 only; thin the fat file at import time
    h->filetype = MH_DYLIB;
    // Drop LC_MAIN-only constraints: dyld wants an LC_ID_DYLIB for dylibs.
    uint8_t *p = (uint8_t *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *lc = (void *)p;
        if (lc->cmd == LC_MAIN) { lc->cmd = LC_ID_DYLIB == 0 ? lc->cmd : lc->cmd; }
        p += lc->cmdsize;
    }
    [d writeToFile:dst atomically:YES];
    return dst;
}

static uint64_t entryOffset(NSString *exe) {
    NSData *d = [NSData dataWithContentsOfFile:exe options:NSDataReadingMappedIfSafe error:nil];
    const struct mach_header_64 *h = d.bytes; const uint8_t *p = (void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        const struct load_command *lc = (void *)p;
        if (lc->cmd == LC_MAIN) return ((const struct entry_point_command *)lc)->entryoff;
        p += lc->cmdsize;
    }
    return 0;
}

void PrismaticLaunchGuest(NSString *appPath, NSString *dataPath, NSString *bundleId, NSString *geodePath) {
    gGuestBundlePath = appPath; gGuestBundleId = bundleId;
    NSString *exeName = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]][@"CFBundleExecutable"];
    NSString *exe = [appPath stringByAppendingPathComponent:exeName];

    // Redirect the guest's sandbox into the instance folder.
    setenv("HOME", dataPath.UTF8String, 1);
    setenv("CFFIXED_USER_HOME", dataPath.UTF8String, 1);
    setenv("TMPDIR", [dataPath stringByAppendingPathComponent:@"tmp"].UTF8String, 1);
    for (NSString *s in @[@"Documents", @"Library/Caches", @"Library/Preferences", @"tmp"])
        [[NSFileManager defaultManager] createDirectoryAtPath:[dataPath stringByAppendingPathComponent:s]
                                  withIntermediateDirectories:YES attributes:nil error:nil];

    swizzle(NSBundle.class, @selector(mainBundle), @selector(prism_mainBundle), YES);
    swizzle(NSBundle.class, @selector(bundleIdentifier), @selector(prism_bundleIdentifier), NO);

    // Geode first, so its constructors can hook before GD's static initialisers run.
    if (geodePath && !dlopen(geodePath.UTF8String, RTLD_NOW | RTLD_GLOBAL))
        NSLog(@"[Prismatic] Geode load failed: %s", dlerror());

    NSString *patched = patchedCopy(exe, dataPath);
    void *handle = patched ? dlopen(patched.UTF8String, RTLD_LAZY) : NULL;
    if (!handle) { NSLog(@"[Prismatic] guest dlopen failed: %s", dlerror()); return; }

    // main() = image base + LC_MAIN entryoff
    Dl_info info; void *sym = dlsym(handle, "_mh_dylib_header") ?: dlsym(handle, "__mh_execute_header");
    uintptr_t base = sym ? (uintptr_t)sym : 0;
    if (!base) { NSLog(@"[Prismatic] cannot locate guest image base"); return; }
    int (*guestMain)(int, char **) = (void *)(base + entryOffset(exe));
    char *argv[] = { (char *)exe.UTF8String, NULL };
    (void)info;
    exit(guestMain(1, argv));
}
