#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "PBlocker-White-Square" asset catalog image resource.
static NSString * const ACImageNamePBlockerWhiteSquare AC_SWIFT_PRIVATE = @"PBlocker-White-Square";

#undef AC_SWIFT_PRIVATE
