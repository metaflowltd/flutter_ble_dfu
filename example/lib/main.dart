import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ble_dfu/ble_dfu.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _foundDeviceName = 'Unknown';
  bool _foundDevice = false;

  String _lastDfuState = "idle";
  @override
  initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  initPlatformState() async {
    String foundDeviceName;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      foundDeviceName = await BleDfu.scanForDfuDevice;
    } on PlatformException {
      foundDeviceName = 'Failed to find device.';
    }

    if (!mounted) return;

    setState(() {
      if (foundDeviceName != "unknown") {
        _foundDevice = true;
      }
      _foundDeviceName = foundDeviceName;
    });
  }

  startDfuPressed() {
    BleDfu.startDfu.listen((onData) {
      setState(() {
        _lastDfuState = onData.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
        ),
        body: new Center(
          child: new Column(
            children: <Widget>[
              new Text('Found device: $_foundDeviceName\n'),
              getStartButton(),
              new Text("last state: $_lastDfuState")
            ],
          ),
        ),
      ),
    );
  }

  getStartButton() {
    if (_foundDevice) {
      return new RaisedButton(
        child: new Text("start dfu"),
        onPressed: startDfuPressed,
      );
    } else {
      return new Container();
    }
  }
}
