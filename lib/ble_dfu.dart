import 'dart:async';

import 'package:flutter/services.dart';

class BleDfu {
  static const MethodChannel _channel =
      const MethodChannel('ble_dfu');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
