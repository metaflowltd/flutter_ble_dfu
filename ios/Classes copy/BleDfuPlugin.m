#import "BleDfuPlugin.h"
#import <ble_dfu/ble_dfu-Swift.h>

@implementation BleDfuPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftBleDfuPlugin registerWithRegistrar:registrar];
}
@end
