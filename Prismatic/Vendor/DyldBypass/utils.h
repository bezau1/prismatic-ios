// Minimal stand-in for LiveContainer's utils.h: only what dyld_bypass_validation.m needs.
#import <Foundation/Foundation.h>
#include <mach-o/dyld_images.h>
struct dyld_all_image_infos *_alt_dyld_get_all_image_infos(void);
