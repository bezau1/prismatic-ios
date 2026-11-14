#import "PrismaticDecrypt.h"
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <spawn.h>
#import <signal.h>
#import <dlfcn.h>
#import <sys/wait.h>

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
extern char **environ;
typedef kern_return_t (*tfp_t)(mach_port_t, int, mach_port_t *);

#define FAIL(m) do { if (err) *err = (m); return NO; } while (0)

NSString *PrismaticInstalledAppPath(NSString *bid) {
#if PRISMATIC_PRIVILEGED
    Class P = NSClassFromString(@"LSApplicationProxy");
    id proxy = [P performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") withObject:bid];
    NSURL *u = [proxy performSelector:NSSelectorFromString(@"bundleURL")];
    return u.path;
#else
    return nil;
#endif
}

#if PRISMATIC_PRIVILEGED
BOOL PrismaticDecryptBundle(NSString *src, NSString *dst, NSString **err) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *exeName = [NSDictionary dictionaryWithContentsOfFile:[src stringByAppendingPathComponent:@"Info.plist"]][@"CFBundleExecutable"];
    if (!exeName) FAIL(@"Couldn't read the installed app's Info.plist.");
    [fm removeItemAtPath:dst error:nil];
    [fm createDirectoryAtPath:dst.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *e; if (![fm copyItemAtPath:src toPath:dst error:&e]) FAIL(e.localizedDescription);

    NSString *srcExe = [src stringByAppendingPathComponent:exeName], *dstExe = [dst stringByAppendingPathComponent:exeName];
    NSMutableData *bin = [NSMutableData dataWithContentsOfFile:dstExe];
    if (bin.length < 64) FAIL(@"Binary unreadable.");

    // locate the arm64 slice
    size_t slice = 0; uint32_t magic = *(uint32_t *)bin.bytes;
    if (magic == FAT_CIGAM) {
        struct fat_header *fh = bin.mutableBytes; struct fat_arch *fa = (void *)(fh + 1);
        uint32_t n = OSSwapBigToHostInt32(fh->nfat_arch); BOOL found = NO;
        for (uint32_t i = 0; i < n; i++)
            if (OSSwapBigToHostInt32(fa[i].cputype) == CPU_TYPE_ARM64) { slice = OSSwapBigToHostInt32(fa[i].offset); found = YES; }
        if (!found) FAIL(@"No arm64 slice.");
    }
    struct mach_header_64 *mh = (void *)((uint8_t *)bin.mutableBytes + slice);
    if (mh->magic != MH_MAGIC_64) FAIL(@"Not a 64-bit Mach-O.");
    struct encryption_info_command_64 *enc = NULL; uint8_t *p = (uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        struct load_command *lc = (void *)p;
        if (lc->cmd == LC_ENCRYPTION_INFO_64) { enc = (void *)lc; break; }
        p += lc->cmdsize;
    }
    if (!enc || enc->cryptid == 0) return YES; // nothing to do

    // spawn the genuine installed binary, suspended, so the kernel maps it with FairPlay active
    pid_t pid; posix_spawnattr_t attr; posix_spawnattr_init(&attr);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_START_SUSPENDED);
    char *argv[] = { (char *)srcExe.UTF8String, NULL };
    if (posix_spawn(&pid, srcExe.UTF8String, NULL, &attr, argv, environ) != 0) FAIL(@"posix_spawn failed (missing entitlements?).");

    tfp_t tfp = (tfp_t)dlsym(RTLD_DEFAULT, "task_for_pid");
    mach_port_t task = MACH_PORT_NULL;
    if (!tfp || tfp(mach_task_self(), pid, &task) != KERN_SUCCESS) { kill(pid, SIGKILL); FAIL(@"task_for_pid denied. Is the app signed with the TrollStore/jailbreak entitlements?"); }

    // find the main executable's load address (first MH_EXECUTE mapping)
    vm_address_t addr = 0, base = 0;
    for (int i = 0; i < 4096 && !base; i++) {
        vm_size_t size = 0; vm_region_basic_info_data_64_t info; mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64; mach_port_t obj;
        if (vm_region_64(task, &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj) != KERN_SUCCESS) break;
        if (info.protection & VM_PROT_READ) {
            struct mach_header_64 h; vm_size_t out = 0;
            if (vm_read_overwrite(task, addr, sizeof h, (vm_address_t)&h, &out) == KERN_SUCCESS && h.magic == MH_MAGIC_64 && h.filetype == MH_EXECUTE) base = addr;
        }
        addr += size;
    }
    if (!base) { kill(pid, SIGKILL); FAIL(@"Couldn't find the game's image in the child process."); }

    // read the encrypted range; reading pages makes the kernel decrypt them
    uint32_t off = enc->cryptoff, len = enc->cryptsize;
    NSMutableData *plain = [NSMutableData dataWithLength:len];
    for (uint32_t done = 0; done < len;) {
        vm_size_t want = MIN((uint32_t)0x100000, len - done), out = 0;
        if (vm_read_overwrite(task, base + off + done, want, (vm_address_t)((uint8_t *)plain.mutableBytes + done), &out) != KERN_SUCCESS || !out) {
            kill(pid, SIGKILL); FAIL(@"Memory read failed while dumping.");
        }
        done += out;
    }
    kill(pid, SIGKILL); int st; waitpid(pid, &st, 0);

    memcpy((uint8_t *)bin.mutableBytes + slice + off, plain.bytes, len);
    enc->cryptid = 0;
    if (![bin writeToFile:dstExe atomically:YES]) FAIL(@"Couldn't write decrypted binary.");
    return YES;
}
#else
BOOL PrismaticDecryptBundle(NSString *s, NSString *d, NSString **err) { FAIL(@"Decrypt isn't available in the standard build."); }
#endif

#if PRISMATIC_JAILBREAK
BOOL PrismaticInstallIPA(NSString *ipa, NSString **err) {
    id ws = [NSClassFromString(@"LSApplicationWorkspace") performSelector:NSSelectorFromString(@"defaultWorkspace")];
    SEL sel = NSSelectorFromString(@"installApplication:withOptions:error:");
    if (![ws respondsToSelector:sel]) FAIL(@"installApplication API missing on this iOS version.");
    NSError *e = nil; NSDictionary *opts = @{ @"PackageType": @"Customer" }; NSURL *url = [NSURL fileURLWithPath:ipa];
    NSMethodSignature *sig = [ws methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = ws; inv.selector = sel; NSError *__autoreleasing *ep = &e;
    [inv setArgument:&url atIndex:2]; [inv setArgument:&opts atIndex:3]; [inv setArgument:&ep atIndex:4];
    [inv invoke]; BOOL ok = NO; [inv getReturnValue:&ok];
    if (!ok) FAIL(e.localizedDescription ?: @"installd refused the IPA (is AppSync installed?).");
    return YES;
}
#else
BOOL PrismaticInstallIPA(NSString *i, NSString **err) { FAIL(@"Install is jailbreak-only."); }
#endif
