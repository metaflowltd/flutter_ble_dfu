import 'dart:async';

import 'package:flutter/services.dart';

class BleDfu {
  static const MethodChannel _channel = const MethodChannel('ble_dfu');

  static const EventChannel _eventChannel = const EventChannel('ble_dfu_event');

  static Future<String> get scanForDfuDevice async {
    final String version = await _channel.invokeMethod('scanForDfuDevice');
    return version;
  }

  static Stream<dynamic> get startDfu {
    var stream = _eventChannel.receiveBroadcastStream();
    _channel.invokeMethod('startDfu');
    return stream;
  }
}
