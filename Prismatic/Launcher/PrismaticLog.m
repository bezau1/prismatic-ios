#import "PrismaticLog.h"
#import <execinfo.h>
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
#import <time.h>

static int gLogFD = -1;
static NSString *gLogPath;

NSString *PrismaticLogPath(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Resolved once, before the guest redirects $HOME into an instance folder.
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        gLogPath = [docs stringByAppendingPathComponent:@"prismatic.log"];
    });
    return gLogPath;
}

static void openLog(void) {
    if (gLogFD >= 0) return;
    NSString *p = PrismaticLogPath();
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
    if ([a fileSize] > 512 * 1024) [[NSFileManager defaultManager] removeItemAtPath:p error:nil]; // keep it small
    gLogFD = open(p.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0644);
}

void PrismaticLogString(NSString *line) {
    openLog();
    NSLog(@"[Prismatic] %@", line);
    if (gLogFD < 0) return;
    time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
    char ts[32]; strftime(ts, sizeof ts, "%H:%M:%S", &tmv);
    dprintf(gLogFD, "[%s] %s\n", ts, line.UTF8String);
    fsync(gLogFD);
}

static void crashHandler(int sig) {
    if (gLogFD >= 0) {
        dprintf(gLogFD, "!!! CRASH: signal %d\n", sig);
        void *bt[64]; int n = backtrace(bt, 64);
        backtrace_symbols_fd(bt, n, gLogFD);
        fsync(gLogFD);
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

static void exceptionHandler(NSException *e) {
    PrismaticLogString([NSString stringWithFormat:@"!!! UNCAUGHT EXCEPTION %@: %@\n%@", e.name, e.reason, e.callStackSymbols]);
}

void PrismaticInstallCrashHandlers(void) {
    openLog();
    NSSetUncaughtExceptionHandler(exceptionHandler);
    int sigs[] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGTRAP, SIGFPE };
    for (size_t i = 0; i < sizeof sigs / sizeof *sigs; i++) signal(sigs[i], crashHandler);
}
