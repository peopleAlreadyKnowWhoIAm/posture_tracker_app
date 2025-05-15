import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utils/snackbar.dart';

class BluetoothOffScreen extends StatefulWidget {
  const BluetoothOffScreen({super.key, this.adapterState});

  final BluetoothAdapterState? adapterState;

  @override
  State<BluetoothOffScreen> createState() => _BluetoothOffScreenState();
}

class _BluetoothOffScreenState extends State<BluetoothOffScreen> {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  BluetoothAdapterState lastAdapterState = BluetoothAdapterState.unknown;
  @override
  void initState() {
    super.initState();
    log('BluetoothOffScreen initState');
    // Listen to Bluetooth state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && lastAdapterState != state) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed("/ScanScreen");
          }
        log("Popping BluetoothOffScreen");
      }

      lastAdapterState = state;
    });
  }

  @override
  void dispose() {
    // Cancel the subscription to avoid memory leaks
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  Widget buildBluetoothOffIcon(BuildContext context) {
    return const Icon(
      Icons.bluetooth_disabled,
      size: 200.0,
      color: Colors.white54,
    );
  }

  Widget buildTitle(BuildContext context) {
    String? state = widget.adapterState?.toString().split(".").last;
    return Text(
      'Bluetooth Adapter is ${state ?? 'not available'}',
      style: Theme.of(
        context,
      ).primaryTextTheme.titleSmall?.copyWith(color: Colors.white),
    );
  }

  Widget buildTurnOnButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ElevatedButton(
        child: const Text('TURN ON'),
        onPressed: () async {
          try {
            if (Platform.isAndroid) {
              await FlutterBluePlus.turnOn();
            }
          } catch (e) {
            Snackbar.show(
              ABC.a,
              prettyException("Error Turning On:", e),
              success: false,
            );
            print(e);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      // key: Snackbar.snackBarKeyA,
      child: Scaffold(
        backgroundColor: Colors.lightBlue,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              buildBluetoothOffIcon(context),
              buildTitle(context),
              if (Platform.isAndroid) buildTurnOnButton(context),
            ],
          ),
        ),
      ),
    );
  }
}
