import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BluetoothErrorStatus {
  success,
  connecting,
  connectionFailure,
  noDeviceIdSaved,
  noDeviceAvailable,
  bluetoothDisabled,
}

enum PostureDeviceEvent { wrongPosture, activeness }

enum PostureState { correct, invalid, movement, incorrect 
}

extension PostureStateExtension on PostureState {
  String get label {
    switch (this) {
      case PostureState.correct:
        return 'correct';
      case PostureState.invalid:
        return 'not detecting';
      case PostureState.movement:
        return 'movements';
      case PostureState.incorrect:
        return 'incorrect';
    }
  }
}

class DeviceSettings {
  late final bool? requestCalibration;
  late final bool? notificationEnabled;
  late final int? timeout;
  late final int? detectionRange;

  DeviceSettings({
    this.requestCalibration,
    this.notificationEnabled,
    this.timeout,
    this.detectionRange,
  });

  DeviceSettings.fromRequest(List<int> inData) {
    assert(inData.length == 4);
    ByteData data = ByteData.sublistView(Uint8List.fromList(inData));
    notificationEnabled = data.getUint8(2) != 0;
    timeout = data.getUint8(0);
    detectionRange = data.getUint8(1);
  }

  List<int> toRequest() {
    List<int> buffer = ['S'.codeUnitAt(0)];
    if (requestCalibration != null) {
      buffer.add('C'.codeUnitAt(0));
    }
    if (notificationEnabled != null) {
      buffer.add('W'.codeUnitAt(0));
      buffer.add(notificationEnabled! ? 1 : 0);
    }
    if (timeout != null) {
      buffer.add('T'.codeUnitAt(0));
      buffer.add(timeout!);
    }
    if (timeout != null) {
      buffer.add('R'.codeUnitAt(0));
      buffer.add(detectionRange!);
    }
    return buffer;
  }
}

class Telemetry {
  late final int posture_notifications;
  late final int activeness_notifications;
  late final int seconds_not_moving;
  late final int seconds_in_bad_posture;
  late final int seconds_in_good_posture;

  Telemetry(
    this.posture_notifications,
    this.activeness_notifications,
    this.seconds_not_moving,
    this.seconds_in_bad_posture,
    this.seconds_in_good_posture,
  );
  Telemetry.fromData(ByteData data) {
    assert(data.lengthInBytes == 12);

    posture_notifications = data.getUint8(4);
    activeness_notifications = data.getUint8(5);
    seconds_not_moving = data.getInt16(6, Endian.little);
    seconds_in_bad_posture = data.getInt16(8, Endian.little);
    seconds_in_good_posture = data.getInt16(10, Endian.little);
  }
}

class BluetoothManager {
  // Private constructor
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;
  BluetoothManager._privateConstructor() {
    // Subscribe to Bluetooth state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((
      state,
    ) async {
      if (state == BluetoothAdapterState.on) {
        log("Trying to connect from settings");
        await _connectionManager();
      }
    });
  }
  final _streamController = StreamController<BluetoothErrorStatus>.broadcast();
  Stream<BluetoothErrorStatus> get stream => _streamController.stream;

  final _eventStreamController =
      StreamController<PostureDeviceEvent>.broadcast();
  Stream<PostureDeviceEvent> get postureEvent => _eventStreamController.stream;

  final _stateStreamController = StreamController<PostureState>.broadcast();
  Stream<PostureState> get postureState => _stateStreamController.stream;

  final _telemetryStreamController =
      StreamController<List<Telemetry>>.broadcast();
  Stream<List<Telemetry>> get telemetry => _telemetryStreamController.stream;

  final _settingsStreamController =
      StreamController<DeviceSettings>.broadcast();
  Stream<DeviceSettings> get settings => _settingsStreamController.stream;

  static final String remoteIdSettingsKey = 'remoteId';
  static final Guid serviceUuid = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final Guid receiveCharacteristicUuid = Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  );
  static final Guid transmitCharacteristicUuid = Guid(
    '6E400002-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  // Singleton instance
  static final BluetoothManager _instance =
      BluetoothManager._privateConstructor();

  BluetoothErrorStatus _error = BluetoothErrorStatus.connecting;
  BluetoothErrorStatus get status => _error;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _receiveCharacteristic;
  BluetoothCharacteristic? _transmitCharacteristic;
  // Factory constructor to return the same instance
  factory BluetoothManager() {
    return _instance;
  }

  Future<void> _connectionManager() async {
    if (_device == null || !_device!.isConnected) {
      log("Trying to connect from settings");
      final error = await _connectFromSaved();
      _setError(error);
    }
  }

  void _setError(BluetoothErrorStatus error) {
    _error = error;
    log("BluetoothManager error: $_error");
    _streamController.add(error);
  }

  Future<void> dispose() async {
    await _adapterStateSubscription.cancel();
    await _streamController.close();
  }

  Future<BluetoothErrorStatus> addDevice(BluetoothDevice device) async {
    if (_receiveCharacteristic != null || _device != null) {
      log("Trying to add device when already connected");
      _receiveCharacteristic = null;
      _device = null;
    }
    BluetoothErrorStatus state = await _connectToDevice(device);
    _setError(state);
    return state;
  }

  Future<BluetoothErrorStatus> _connectToDevice(BluetoothDevice device) async {
    log(
      "Trying to esasdadsdsdsaaaVVonnect to device with ID: ${device.remoteId.toString()}",
    );
    (BluetoothCharacteristic, BluetoothCharacteristic)? characteristic;
    try {
      for (int i = 0; i < 5; i++) {
        try {
          await device.connect(timeout: Duration(seconds: 5), mtu: null);
          break;
        } on FlutterBluePlusException catch (_) {
        } on PlatformException catch (_) {}
        log("Connection attempt $i failed");
      }
      await device.requestMtu(512);
      characteristic = await _discoverCharacteristic(device);
      if (characteristic == null) {
        await device.disconnect();
        return BluetoothErrorStatus.noDeviceAvailable;
      }
      if (await device.bondState.first != BluetoothBondState.bonded) {
        await device.createBond();
      }
    } catch (e) {
      log('Error connecting to device: $e');
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        return BluetoothErrorStatus.bluetoothDisabled;
      }
      return BluetoothErrorStatus.connectionFailure;
    }
    _device = device;
    _receiveCharacteristic = characteristic.$1;
    _transmitCharacteristic = characteristic.$2;
    _saveDeviceIdToSettings(device);
    readData();
    return BluetoothErrorStatus.success;
  }

  Future<BluetoothErrorStatus> _connectFromSaved() async {
    if (_receiveCharacteristic != null && _device!.isConnected) {
      return BluetoothErrorStatus.success;
    }
    late BluetoothDevice device;
    if (_device == null) {
      log("Trying to connect from settings");
      final preferenceHandler = await SharedPreferences.getInstance();
      final remoteId = preferenceHandler.getString(remoteIdSettingsKey);
      if (remoteId == null) {
        log('No device ID saved in settings');
        return BluetoothErrorStatus.noDeviceIdSaved;
      }
      var found_device = await FlutterBluePlus.bondedDevices.then(
        (l) => l.firstWhereOrNull(
          (bonded_device) =>
              bonded_device.remoteId == DeviceIdentifier(remoteId),
        ),
      );
      if (found_device == null) {
        log('No bonded device found with ID: $remoteId');
        preferenceHandler.remove(remoteIdSettingsKey);
        return BluetoothErrorStatus.noDeviceAvailable;
      } else {
        device = found_device;
      }
    } else {
      device = _device!;
    }
    return await _connectToDevice(device);
  }

  Future<void> _saveDeviceIdToSettings(BluetoothDevice d) async {
    final preferenceHandler = await SharedPreferences.getInstance();
    await preferenceHandler.setString(
      remoteIdSettingsKey,
      d.remoteId.toString(),
    );
  }

  Future<(BluetoothCharacteristic, BluetoothCharacteristic)?>
  _discoverCharacteristic(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices(timeout: 5);
      final service = services.firstWhereOrNull(
        (service) => service.uuid == serviceUuid,
      );
      if (service == null) {
        return null;
      }
      var transCharacteristic = service.characteristics.firstWhereOrNull(
        (characteristic) => characteristic.uuid == transmitCharacteristicUuid,
      );
      if (transCharacteristic == null) {
        log("Error descovering trasmit characteristic");
        return null;
      }

      var recvCharacheristic = service.characteristics.firstWhereOrNull(
        (characteristic) => characteristic.uuid == receiveCharacteristicUuid,
      );
      if (recvCharacheristic != null) {
        await recvCharacheristic.setNotifyValue(true);
      } else {
        log("Error descovering receive characteristic");
        return null;
      }
      return (recvCharacheristic, transCharacteristic);
    } catch (e) {
      log('Error discovering services: $e');
      return null;
    }
  }

  Future<String?> readData() async {
    List<Telemetry> collected_telem = [];
    int next_piece = 0;
    try {
      if (!_receiveCharacteristic!.isNotifying) {
        log("Error charachteristic not notifying");
        return null;
      }
      var data = _receiveCharacteristic!.onValueReceived;
      await data.forEach((data) {
        log("Data received $data");
        if (data.length == 2) {
          String chars = String.fromCharCodes(data);
          if (chars[0] == "N") {
            _eventStreamController.add(
              chars[1] == "P"
                  ? PostureDeviceEvent.wrongPosture
                  : PostureDeviceEvent.activeness,
            );
          } else if (chars[0] == "S") {
            _stateStreamController.add(PostureState.values[data[1]]);
          } else if (chars == "TD") {
            log("Streaming telemetry len ${collected_telem.length}");
            if (collected_telem.length > 168) {
              int diff = collected_telem.length - 168;
              collected_telem = collected_telem.sublist(diff);
            }
            _telemetryStreamController.add(collected_telem);
            collected_telem = [];
            next_piece = 0;
          }
        } else if (data.length == 5 && String.fromCharCode(data[0]) == "U") {
          _settingsStreamController.add(
            DeviceSettings.fromRequest(data.sublist(1)),
          );
        } else if ((data.length - 1) % 12 == 0) {
          // Telemetry
          int piece_indx = data[0];
          if (next_piece != piece_indx) {
            log("Unknown sequence of telemtry, error");
            next_piece = 0;
            return;
          }
          next_piece++;
          var telem = data
              .sublist(1)
              .slices(12)
              .map(
                (slice) => Telemetry.fromData(
                  ByteData.sublistView(Uint8List.fromList(slice)),
                ),
              );
          collected_telem.addAll(telem);
        } else {
          log("Unexpected bluetooth payload");
        }
      });
    } catch (e) {
      log('Error reading data: $e');
      return null;
    }
    return "";
  }

  bool isConnected() {
    final isConnected =
        _receiveCharacteristic != null &&
        _receiveCharacteristic!.device.isConnected;
    log("Is connected: $isConnected");
    return isConnected;
  }

  Future<void> _sendSometing(List<int> data) async {
    if (_transmitCharacteristic == null) {
      log("Error requesting state: not connected");
      return;
    }
    try {
      await _transmitCharacteristic!.write(data);
    } catch (e) {
      log("Error during state request $e");
    }
  }

  Future<void> requestState() async {
    List<int> req = "RS".codeUnits;
    await _sendSometing(req);
  }

  Future<void> requestTelemetry() async {
    List<int> req = "TELEM".codeUnits;
    await _sendSometing(req);
  }

  Future<void> sendSettings(DeviceSettings settings) async {
    await _sendSometing(settings.toRequest());
  }

  Future<void> requestSettings() async {
    List<int> req = "RU".codeUnits;
    await _sendSometing(req);
  }

  Future<void> removeDevice() async {
    final preferenceHandler = await SharedPreferences.getInstance();
    preferenceHandler.remove(remoteIdSettingsKey);
    if (_device == null) {
      return;
    }
    try {
      if (_device!.isConnected) {
        await _device!.disconnect();
      }
    } catch (e) {
      log("Error disconecting device $e");
    }
    _device = null;
    _receiveCharacteristic = null;
    _transmitCharacteristic = null;
    _setError(BluetoothErrorStatus.noDeviceIdSaved);
  }
}
