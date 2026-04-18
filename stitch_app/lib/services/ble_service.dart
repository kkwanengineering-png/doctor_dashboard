import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'fall_detection_service.dart';

// ---------------------------------------------------------------------------
// Configure these three constants to match your ESP32 sketch.
// ---------------------------------------------------------------------------
const String kBleDeviceName = 'Rehab_Sensor_Shank'; // advertised device name
const String kBleServiceUuid =
    '4fafc201-1fb5-459e-8fcc-c5c9c331914b'; // e.g. '4fafc201-...'
const String kBleCharUuid =
    'beb5483e-36e1-4688-b7f5-ea07361b26a8'; // notify characteristic

enum BleConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

/// Singleton BLE service that manages the ESP32 connection and exposes a
/// [Stream<double>] of pitch angle values parsed from UTF-8 notifications.
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  // Internal controllers
  final _angleController = StreamController<double>.broadcast();
  final _stateController = StreamController<BleConnectionState>.broadcast();

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  BleConnectionState _state = BleConnectionState.idle;

  // ── Source-level throttle ────────────────────────────────────────────────
  // The BNO055 / ESP32 can burst at >100 Hz during rapid movement.
  // We cap emissions to every 10 ms (100 Hz max) here at the source so all
  // downstream subscribers — UI, rep-logic — are never flooded.
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  double _latestAngle = 0;

  // Sliding windows for ML/Data Processing (6 seconds @ 20Hz = 120 samples)
  final List<double> recentAccel = [];
  final List<double> recentGyro = [];
  final List<double> recentLinearAccel = [];

  // Fall Detection Stream
  final _fallResultController = StreamController<FallDetectionResult>.broadcast();
  Stream<FallDetectionResult> get fallStream => _fallResultController.stream;

  bool isProcessingFall = false;
  int _inferenceCounter = 0;

  /// Live stream of parsed angle values (degrees).
  Stream<double> get angleStream => _angleController.stream;

  /// Live stream of connection state changes.
  Stream<BleConnectionState> get connectionStateStream =>
      _stateController.stream;

  BleConnectionState get currentState => _state;

  void _emit(BleConnectionState s) {
    _state = s;
    _stateController.add(s);
    debugPrint('[BLE] state → $s');
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Request permissions (Android) then start scanning.
  Future<void> startScan() async {
    if (_state == BleConnectionState.scanning ||
        _state == BleConnectionState.connecting ||
        _state == BleConnectionState.connected) {
      return; // already active
    }

    // Request runtime permissions on Android 12+
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Check adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('[BLE] Bluetooth is off — cannot scan');
      _emit(BleConnectionState.error);
      return;
    }

    _emit(BleConnectionState.scanning);

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        // Match on Service UUID — always in the primary advertisement packet,
        // unlike the device name which may be deferred to the scan response.
        if (r.advertisementData.serviceUuids.contains(Guid(kBleServiceUuid))) {
          _onDeviceFound(r.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 30),
    );
  }

  Future<void> disconnect() async {
    await _cleanup();
    _emit(BleConnectionState.idle);
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  Future<void> _onDeviceFound(BluetoothDevice device) async {
    if (_state != BleConnectionState.scanning) return;
    _emit(BleConnectionState.connecting);

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    _device = device;

    try {
      await device.connect(autoConnect: false);

      // Subscribe to disconnection AFTER connect() returns — subscribing before
      // would cause the stream's initial 'disconnected' emission to fire _cleanup()
      // while the connection handshake is still in progress.
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _emit(BleConnectionState.disconnected);
          _cleanup();
        }
      });

      // Give Android's stack a moment to stabilize before MTU negotiation
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        await device.requestMtu(256);
      } catch (e) {
        debugPrint('[BLE] MTU request failed, continuing: $e');
      }

      final services = await device.discoverServices();
      BluetoothCharacteristic? target;

      for (final svc in services) {
        if (svc.uuid.str128.toLowerCase() == kBleServiceUuid.toLowerCase()) {
          for (final c in svc.characteristics) {
            if (c.uuid.str128.toLowerCase() == kBleCharUuid.toLowerCase()) {
              target = c;
              break;
            }
          }
        }
      }

      if (target == null) {
        debugPrint('[BLE] Characteristic not found');
        _emit(BleConnectionState.error);
        await device.disconnect();
        return;
      }

      await target.setNotifyValue(true);
      _notifySub = target.lastValueStream.listen(_onRawData);

      _emit(BleConnectionState.connected);
    } catch (e) {
      debugPrint('[BLE] Connection error: $e');
      _emit(BleConnectionState.error);
      await device.disconnect();
    }
  }

  /// Parse incoming bytes as a UTF-8 string and push the double downstream.
  /// Throttled to at most one emission per 10 ms to prevent flooding all
  /// subscribers during rapid sensor movement.
  void _onRawData(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final raw = utf8.decode(bytes).trim();
      final parts = raw.split(',');

      if (parts.length >= 3) {
        // 1. Parse Pitch (for UI Stream)
        _latestAngle = double.parse(parts[0]);

        // 2. Parse Accel, Gyro, and Linear Accel (for ML sliding windows)
        final accel = double.parse(parts[1]);
        final gyro = double.parse(parts[2]);
        final linearAccel = parts.length >= 4 ? double.parse(parts[3]) : (accel - 9.81);

        recentAccel.add(accel);
        recentGyro.add(gyro);
        recentLinearAccel.add(linearAccel);
        
        // Maintain sliding window of 120 (6 seconds at 20Hz) for Fall detection
        if (recentAccel.length > 120) recentAccel.removeAt(0);
        if (recentGyro.length > 120) recentGyro.removeAt(0);
        if (recentLinearAccel.length > 120) recentLinearAccel.removeAt(0);

        // 3. Background Monitoring (Updates Debug Panel continuously)
        _inferenceCounter++;
        if (_inferenceCounter >= 10) {
          _inferenceCounter = 0;
          if (recentAccel.length == 120) {
            FallDetectionService.getFallProbability(
              List<double>.from(recentAccel),
              List<double>.from(recentGyro),
              List<double>.from(recentLinearAccel),
              isImpactTriggered: false,
            ).then((result) {
              if (result != null) _fallResultController.add(result);
            });
          }
        }

        // 4. The Delayed Impact Trigger (Crucial for False Positives)
        if (accel > 15.0 && !isProcessingFall) {
          isProcessingFall = true;
          debugPrint('[BLE] High impact detected ($accel). Starting 2s collection window...');
          
          Future.delayed(const Duration(seconds: 2), () {
            FallDetectionService.getFallProbability(
              List<double>.from(recentAccel),
              List<double>.from(recentGyro),
              List<double>.from(recentLinearAccel),
              isImpactTriggered: true,
            ).then((result) {
              if (result != null) _fallResultController.add(result);
            });
          });

          Future.delayed(const Duration(seconds: 5), () {
            isProcessingFall = false;
          });
        }

        // 4. Emit angle if throttled (max 100Hz max, though firmware is 20Hz)
        final now = DateTime.now();
        if (now.difference(_lastEmit).inMilliseconds >= 10) {
          _lastEmit = now;
          _angleController.add(_latestAngle);
        }
      }
    } catch (e) {
      debugPrint('[BLE] Error parsing data "$bytes": $e');
    }
  }

  Future<void> _cleanup() async {
    // Save references before nulling so we don't cancel _connSub
    // from within its own callback (self-cancel deadlock).
    final notifySub = _notifySub;
    final scanSub = _scanSub;
    final connSub = _connSub;
    final device = _device;

    _notifySub = null;
    _scanSub = null;
    _connSub = null;
    _device = null;

    await notifySub?.cancel();
    await scanSub?.cancel();
    await connSub?.cancel();

    try {
      await device?.disconnect();
    } catch (_) {
      // Best-effort disconnection
    }
  }
}
