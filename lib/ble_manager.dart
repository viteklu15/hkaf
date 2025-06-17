import 'dart:async';
import 'dart:convert';
import 'globals.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // обязательно вверху

class BleManager {
  static final Uuid defaultServiceUuid = Uuid.parse(
    "12345678-1234-1234-1234-123456789abc",
  );
  static final Uuid defaultCharacteristicUuid = Uuid.parse(
    "87654321-4321-4321-4321-abcdefabcdef",
  );

  final FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();
  final Uuid serviceUuid;
  final Uuid characteristicUuid;

  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<List<int>>? notifySub;
  QualifiedCharacteristic? characteristic;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  BleManager({Uuid? serviceUuid, Uuid? characteristicUuid})
    : serviceUuid = serviceUuid ?? defaultServiceUuid,
      characteristicUuid = characteristicUuid ?? defaultCharacteristicUuid;

  Future<bool> _checkPermissions(void Function(String) onLog) async {
    final permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    final statuses = await permissions.request();

    // for (var entry in statuses.entries) {
    //   // onLog(
    //   //   '[BLE PERM] ${entry.key.toString().split('.').last}: ${entry.value}',
    //   // );
    // }

    final allGranted = statuses.values.every((status) => status.isGranted);
    // onLog('[BLE PERM] allGranted = $allGranted');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    // onLog('[BLE PERM] location enabled = $serviceEnabled');

    return allGranted && serviceEnabled;
  }

  Future<void> scanAndConnect(
    String serial, {
    required void Function() onConnected,
    required void Function() onDisconnected,
    required void Function(String error) onError,
    required void Function(String message) onLog,
  }) async {
    // 🔒 Проверка разрешений
    if (!await _checkPermissions(onLog)) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        onLog('❌ Геолокация отключена');
        onError('Пожалуйста, включите геолокацию на устройстве');
      } else {
        onLog('❌ Требуются разрешения на BLE и геолокацию');
        onError('Разрешения не получены');
      }

      return;
    }
    print("Scan");
    // onLog('🔍 Начато сканирование BLE устройств...');
    scanSub = flutterReactiveBle.scanForDevices(withServices: []).listen((
      device,
    ) {
      // onLog('📡 Найдено устройство: ${device.name} (${device.id})');
      print('📡 Найдено устройство: ${device.name} (${device.id})');
      if (device.name == serial) {
        // onLog('✅ Устройство совпадает с serial: $serial');
        print('✅ Устройство совпадает с serial: $serial');

        scanSub?.cancel();
        _connectToDevice(
          device,
          onConnected: onConnected,
          onDisconnected: onDisconnected,
          onError: onError,
          onLog: onLog,
        );
      }
    }, onError: (e) => onLog('❌ Ошибка сканирования: $e'));
  }

  Future<void> sendCommand(String command) async {
    if (characteristic == null) {
      throw Exception("BLE characteristic is not available");
    }

    await flutterReactiveBle.writeCharacteristicWithoutResponse(
      characteristic!,
      value: utf8.encode(command),
    );
  }

  void _connectToDevice(
    DiscoveredDevice device, {
    required void Function() onConnected,
    required void Function() onDisconnected,
    required void Function(String error) onError,
    required void Function(String message) onLog,
  }) {
    void connect() {
      _connectionSub = flutterReactiveBle
          .connectToDevice(id: device.id)
          .listen(
            (connectionState) {
              if (connectionState.connectionState ==
                  DeviceConnectionState.connected) {
                characteristic = QualifiedCharacteristic(
                  deviceId: device.id,
                  serviceId: serviceUuid,
                  characteristicId: characteristicUuid,
                );
                onConnected();
              } else if (connectionState.connectionState ==
                  DeviceConnectionState.disconnected) {
                onLog('⚠️ Устройство отключено');
                Future.delayed(const Duration(seconds: 2), () {
                  scanAndConnect(
                    device.name,
                    onConnected: onConnected,
                    onDisconnected: onDisconnected,
                    onError: onError,
                    onLog: onLog,
                  );
                });
              }
            },
            onError: (error) {
              onLog('❌ Ошибка подключения: $error');
              onError(error.toString());
            },
          );
    }
      connect(); // без задержки    
  }

  void listenToWifiList(void Function(List<String> networks) onData) {
    if (characteristic == null) return;

    notifySub = flutterReactiveBle
        .subscribeToCharacteristic(characteristic!)
        .listen((data) {
          final parts = utf8.decode(data).split(';~');
          if (parts.length == 2) {
            final index = int.tryParse(parts[0]);
            final name = parts[1];
            if (index != null && name.isNotEmpty) {
              onData(List.generate(index + 1, (i) => i == index ? name : ''));
            }
          }
        });
  }

  Future<void> sendWifiCredentials(String ssid, String password) async {
    if (characteristic == null)
      throw Exception("BLE characteristic is not available");

    await flutterReactiveBle.writeCharacteristicWithoutResponse(
      characteristic!,
      value: utf8.encode('ssid~$ssid;'),
    );

    await flutterReactiveBle.writeCharacteristicWithoutResponse(
      characteristic!,
      value: utf8.encode('pas~$password;'),
    );
  }

  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    await scanSub?.cancel();
    await notifySub?.cancel();
    characteristic = null;
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
