import 'dart:async';

import 'package:flutter/services.dart';

class BleDfu {
  static const MethodChannel _channel = const MethodChannel('ble_dfu');

  static const EventChannel _eventChannel = const EventChannel('ble_dfu_event');

  static Future<String> get scanForDfuDevice async {
    return await _channel.invokeMethod('scanForDfuDevice');
  }

  static Stream<dynamic> startDfu(String url, String deviceAddress, String deviceName) {
    final stream = _eventChannel.receiveBroadcastStream();
    _channel.invokeMethod('startDfu', {
      "deviceAddress": deviceAddress,
      "deviceName": deviceName,
      "url": url
    });
    return stream;
  }
}
