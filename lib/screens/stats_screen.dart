import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:posture_tracker_app/utils/bluetooth_manager.dart';
import 'package:posture_tracker_app/widgets/loading_widget.dart';

class PostureProgressIndicator extends StatelessWidget {
  final List<Telemetry> telemetryHistory;

  const PostureProgressIndicator({required this.telemetryHistory, super.key});

  @override
  Widget build(BuildContext context) {
    log("Rebuilding graph ${telemetryHistory.length}");
    late final List<FlSpot> spots;
    if (telemetryHistory.isNotEmpty) {
      spots =
          telemetryHistory.mapIndexed((index, telem) {
            double val = 0;
            if (telem.seconds_in_bad_posture != 0 ||
                telem.seconds_in_good_posture != 0) {
              val =
                  telem.seconds_in_good_posture /
                  (telem.seconds_in_good_posture +
                      telem.seconds_in_bad_posture);
            }
            return FlSpot(index.toDouble(), val);
          }).toList();
    } else {
      spots = [FlSpot(1, 1), FlSpot(2, 1)];
    }
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value >= 0 && value < days.length) {
                  final int_val =
                      (value.toInt() + DateTime.now().weekday) %
                      DateTime.daysPerWeek;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[int_val],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            axisNameWidget: const Text(
          'Progress',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(spots: spots, color: Theme.of(context).primaryColor),
        ],
      ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final BluetoothManager _bluetoothManager = BluetoothManager();

  StreamSubscription<BluetoothErrorStatus>? _adapterStateSubscription;
  StreamSubscription<PostureState>? _postureSubscription;
  StreamSubscription<List<Telemetry>>? _telemetrySubscription;

  PostureState _postureState = PostureState.correct;
  List<Telemetry> _telemetry = [];
  List<List<Telemetry>> _telemetryByDays = [];

  void _setTelemetry(List<Telemetry> telem) {
    _telemetry = telem;
    int hour = TimeOfDay.now().hour;
    _telemetryByDays = [];
    _telemetryByDays.insert(0, telem.sublist(telem.length - hour));
    telem = telem.sublist(0, telem.length - hour);
    for (int i = 0; i < 6; i++) {
      _telemetryByDays.insert(0, telem.sublist(telem.length - 24));
      telem = telem.sublist(0, telem.length - 24);
    }
  }

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Listen to Bluetooth state changes
    _adapterStateSubscription = _bluetoothManager.stream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state == BluetoothErrorStatus.bluetoothDisabled) {
        // Push the BluetoothOffScreen if Bluetooth is off
        log('Pushing BluetoothOffScreen');
        Navigator.of(context).pushReplacementNamed("/BluetoothOffScreen");
      } else if (state == BluetoothErrorStatus.noDeviceIdSaved ||
          state == BluetoothErrorStatus.noDeviceAvailable) {
        // Push the ScanScreen if no device ID is saved
        log('Pushing ScanScreen');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil("/ScanScreen", (_) => false);
      } else if (state == BluetoothErrorStatus.success) {
        _bluetoothManager.requestState();
        _bluetoothManager.requestTelemetry();
      } else {
        setState(() {});
      }
    });

    _postureSubscription = _bluetoothManager.postureState.listen((state) {
      _postureState = state;
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    });

    _telemetrySubscription = _bluetoothManager.telemetry.listen((telem) {
      _setTelemetry(telem);
      _isLoading = false;
      log("Telemetry received ${telem.length}");
      if (mounted) {
        setState(() {});
      }
    });
    if (_bluetoothManager.status == BluetoothErrorStatus.success) {
      _bluetoothManager.requestState();
      _bluetoothManager.requestTelemetry();
    }
  }

  Telemetry combine(Telemetry left, Telemetry right) {
    return Telemetry(
      left.posture_notifications + right.posture_notifications,
      left.activeness_notifications + right.activeness_notifications,
      left.seconds_not_moving + right.seconds_not_moving,
      left.seconds_in_bad_posture + right.seconds_in_bad_posture,
      left.seconds_in_good_posture + right.seconds_in_good_posture,
    );
  }

  @override
  void dispose() {
    // Cancel the subscription to avoid memory leaks
    _adapterStateSubscription?.cancel();
    _postureSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingWidget(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Statistics"),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).pushNamed('/Settings');
              },
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            spacing: 30,
            children: [
              Text(
                "Posture state is: ${_postureState.label}",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Column(
                children: [
                  Text(
                    "Your progress for the last 7 days",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(
                    width: 400,
                    height: 200,
                    child: PostureProgressIndicator(
                      telemetryHistory:
                          _telemetryByDays
                              .map((x) => x.reduce(combine))
                              .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
