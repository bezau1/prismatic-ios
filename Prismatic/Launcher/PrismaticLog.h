#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Append a line to Documents/prismatic.log (synchronous, survives crashes).
void PrismaticLogString(NSString *line);
/// Log uncaught exceptions and fatal signals (with a backtrace) to the same file.
void PrismaticInstallCrashHandlers(void);
NSString *PrismaticLogPath(void);
NS_ASSUME_NONNULL_END
