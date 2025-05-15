// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:posture_tracker_app/screens/settings_screen.dart';
import 'package:posture_tracker_app/screens/stats_screen.dart';
import 'package:posture_tracker_app/utils/bluetooth_manager.dart';

import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

//
// This widget shows BluetoothOffScreen or
// ScanScreen depending on the adapter state
//
class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      initialRoute: '/',
      routes: {
        '/': (context) => StatsScreen(),
        '/BluetoothOffScreen': (context) => const BluetoothOffScreen(),
        '/ScanScreen': (context) => const ScanScreen(),
        '/Settings': (context) => const SettingsScreen(),
      },
    );
  }
}
