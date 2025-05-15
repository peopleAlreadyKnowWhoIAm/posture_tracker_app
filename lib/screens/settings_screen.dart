import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_tracker_app/utils/bluetooth_manager.dart';
import 'package:posture_tracker_app/widgets/loading_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  bool _isWorking = true;
  double _detectionRange = 20;
  double _detectionTime = 15;
    final BluetoothManager _manager = BluetoothManager();

  StreamSubscription<DeviceSettings>? _settingsFromDevice;

  @override
  void initState() {
    super.initState();

    _settingsFromDevice = _manager.settings.listen((settings) {
      _isLoading = false;
      _isWorking = settings.notificationEnabled!;
      _detectionRange = settings.detectionRange!.toDouble();
      _detectionTime = settings.timeout!.toDouble();
      if (mounted) {
        setState(() {
          
        });
      }
    });
    _manager.requestSettings();
  }

  @override
  void dispose() {
    _settingsFromDevice?.cancel();
    super.dispose();
  }

  void _commitSettings(DeviceSettings settings) {
    _isLoading = true;
    _manager.sendSettings(settings).then((s) {
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingWidget(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 20,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Enable all notification",
                    style: Theme.of(context).textTheme.titleMedium!,
                  ),
                  Switch(
                    value: _isWorking,
                    onChanged: (state) => _isWorking = state,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose detection range:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    label: "${_detectionRange.round()} degrees",
                    divisions: 20,
                    min: 15,
                    max: 35,
                    value: _detectionRange,
                    onChanged: (value) {
                      _detectionRange = value;
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose detection time:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    label: "${_detectionTime.round()} seconds",
                    divisions: 20,
                    min: 10,
                    max: 30,
                    value: _detectionTime,
                    onChanged: (value) {
                      _detectionTime = value;
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              MaterialButton(
                onPressed:
                    () => _commitSettings(
                      DeviceSettings(
                        notificationEnabled: _isWorking,
                        timeout: _detectionTime.round(),
                        detectionRange: _detectionRange.round(),
                      ),
                    ),
                child: Text("Save settings"),
                color: Theme.of(context).primaryColor,
                minWidth: 300,
              ),
              Divider(height: 10, thickness: 1),
              Text("Actions", style: Theme.of(context).textTheme.titleLarge),
              MaterialButton(
                onPressed: ()=> _commitSettings(DeviceSettings(requestCalibration: true)),
                child: const Text("Calibrate right posture"),
                color: Theme.of(context).primaryColor,
                minWidth: 300,
              ),
              MaterialButton(
                onPressed: () => _manager.removeDevice(),
                child: const Text("Delete device"),
                color: Theme.of(context).colorScheme.error,
                minWidth: 300,
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
