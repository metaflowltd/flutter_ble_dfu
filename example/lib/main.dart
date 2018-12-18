import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ble_dfu/ble_dfu.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String _deviceName;
  String _deviceAddress = "F6:61:0A:D6:98:5A";
  String _lastDfuState;

  @override
  initState() {
    super.initState();

    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  initPlatformState() async {
    if (!Platform.isIOS) {
      _deviceName = "LUMEN_DFU";
      return;
    }

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      _deviceName = await BleDfu.scanForDfuDevice;
    } on PlatformException {
      _deviceName = null;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    final children = <Widget>[
      Text('Found device: ${_deviceName ?? "Not found"}'),
    ];

    if (Platform.isAndroid) {
      children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Device address: $_deviceAddress'),
          )
      );
    }

    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text("Last state: ${_lastDfuState ?? ""}"),
      )
    );

    children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: FlatButton(
            child: Text("START DFU"),
            onPressed: _deviceName != null ? _onStartDfuPressed : null),
        )
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('DFU Plugin example'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  _onStartDfuPressed() {
    BleDfu.startDfu("https://src.metaflow.co/firmware/lumen_v2_20181216.zip", _deviceAddress, _deviceName).listen((onData) {
      setState(() {
        _lastDfuState = onData.toString();
      });
    });
  }
}
