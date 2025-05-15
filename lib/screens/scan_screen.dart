import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:posture_tracker_app/utils/bluetooth_manager.dart';
import 'package:posture_tracker_app/widgets/loading_widget.dart';
import 'package:posture_tracker_app/widgets/scan_result_tile.dart';

import '../utils/snackbar.dart';
import '../widgets/system_device_tile.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        _scanResults = results;
        if (mounted) {
          setState(() {});
        }
      },
      onError: (e) {
        Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
      },
    );

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
    onScanPressed();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      // `withServices` is required on iOS for privacy purposes, ignored on android.
      var withServices = [
        Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"),
      ]; // Battery Level Service
      _systemDevices = await FlutterBluePlus.systemDevices(withServices);
      // _systemDevices = _systemDevices.where((dev)=>dev.servicesList.firstWhereOrNull((service)=> service.uuid == Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e")) != null).toList();
    } catch (e) {
      Snackbar.show(
        ABC.b,
        prettyException("System Devices Error:", e),
        success: false,
      );
      print(e);
    }
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(minutes: 1),
        withServices: [BluetoothManager.serviceUuid],
      );
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.b,
        prettyException("Start Scan Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {});
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    final manager = BluetoothManager();
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    manager.addDevice(device).then((status) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (status == BluetoothErrorStatus.success) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed("/");
        }
      } else {
        Snackbar.show(
          ABC.b,
          prettyException("Connect Error:", status),
          success: false,
        );
      }
    });
  }

  List<Widget> _buildSystemDeviceTiles(BuildContext context) {
    return _systemDevices
        .map(
          (d) =>
              SystemDeviceTile(device: d, onConnect: () => onConnectPressed(d)),
        )
        .toList();
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: LoadingWidget(
        isLoading: _isLoading,
        child: Scaffold(
          appBar: AppBar(title: const Text('Choose Devices')),
          body: ListView(
            children: <Widget>[
              ..._buildSystemDeviceTiles(context),
              ..._buildScanResultTiles(context),
            ],
          ),
        ),
      ),
    );
  }
}
