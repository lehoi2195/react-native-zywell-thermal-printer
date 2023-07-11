
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNZywellThermalPrinterSpec.h"

@interface ZywellThermalPrinter : NSObject <NativeZywellThermalPrinterSpec>
#else
#import <React/RCTBridgeModule.h>

@interface ZywellThermalPrinter : NSObject <RCTBridgeModule>
#endif

@end
