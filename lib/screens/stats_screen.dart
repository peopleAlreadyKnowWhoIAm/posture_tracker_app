import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:posture_tracker_app/utils/bluetooth_manager.dart';
import 'package:posture_tracker_app/widgets/loading_widget.dart';

class PostureNotificationByDays extends StatelessWidget {
  final List<Telemetry> telemetryHistory;

  const PostureNotificationByDays({super.key, required this.telemetryHistory});

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<BarChartGroupData> barGroups;
    if (telemetryHistory.isNotEmpty) {
      barGroups =
          telemetryHistory.mapIndexed((index, telem) {
            return BarChartGroupData(
              x: index,
              barRods: [
                // Posture notifications bar
                BarChartRodData(
                  toY: telem.posture_notifications.toDouble(),
                  color: Theme.of(context).primaryColor,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: telem.posture_notifications.toDouble(),
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                ),
                // Movement notifications bar
                BarChartRodData(
                  toY: telem.activeness_notifications.toDouble(),
                  color: Theme.of(context).colorScheme.secondary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: telem.activeness_notifications.toDouble(),
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList();
    } else {
      barGroups = [
        for (var i = 0; i < 7; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: 0, width: 16),
              BarChartRodData(toY: 0, width: 16),
            ],
          ),
      ];
    }

    return Column(
      children: [
        Text(
          "Amount of notification for the last 7 days",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 20,),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY:
                  telemetryHistory.isEmpty
                      ? 10
                      : telemetryHistory
                              .map(
                                (t) =>
                                    (t.posture_notifications >
                                            t.activeness_notifications)
                                        ? t.posture_notifications
                                        : t.activeness_notifications,
                              )
                              .reduce((a, b) => a > b ? a : b)
                              .toDouble() +
                          2,
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
                    getTitlesWidget: (value, meta) {
                      const days = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      if (value >= 0 && value < days.length) {
                        final dayIndex =
                            (value.toInt() + DateTime.now().weekday) % 7;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[dayIndex],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5, // Show label every 5 units
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  axisNameWidget: const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 5,
                    color: Colors.grey.withAlpha(80),
                    dashArray: [5, 5],
                  ),
                ],
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Add legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(
              context,
              'Posture',
              Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 24),
            _buildLegendItem(
              context,
              'Movement',
              Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

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
      spots = [for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), 0)];
    }
    return SizedBox(
      height: 200,
      child: LineChart(
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
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  if (value >= 0 && value < days.length) {
                    final int_val =
                        (value.toInt() + DateTime.now().weekday) %
                        DateTime.daysPerWeek;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        days[int_val],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
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
            LineChartBarData(
              spots: spots,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
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
                  PostureProgressIndicator(
                    telemetryHistory:
                        _telemetryByDays.map((x) => x.reduce(combine)).toList(),
                  ),
                ],
              ),
              PostureNotificationByDays(
                telemetryHistory:
                    _telemetryByDays.map((x) => x.reduce(combine)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
