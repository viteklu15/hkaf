import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<bool> _checkPermissions() async {
    // запрос разрешения
    final statuses =
        await [
          Permission.location,
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> scanAndConnect(
    String serial, {
    required void Function() onConnected,
    required void Function() onDisconnected,
    required void Function(String error) onError,
    required void Function(String message) onLog,
  }) async {
    // 🔒 Проверка разрешений
    if (!await _checkPermissions()) {
      onLog('❌ Требуются разрешения на BLE и геолокацию');
      onError('Разрешения не получены');
      return;
    }

    // onLog('🔍 Начато сканирование BLE устройств...');
    scanSub = flutterReactiveBle.scanForDevices(withServices: []).listen((
      device,
    ) {
      // onLog('📡 Найдено устройство: ${device.name} (${device.id})');
      if (device.name == serial) {
        // onLog('✅ Устройство совпадает с serial: $serial');
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

  void _connectToDevice(
    DiscoveredDevice device, {
    required void Function() onConnected,
    required void Function() onDisconnected,
    required void Function(String error) onError,
    required void Function(String message) onLog,
  }) {
    // onLog('🔗 Подключение к ${device.name} (${device.id})...');
    _connectionSub = flutterReactiveBle
        .connectToDevice(id: device.id)
        .listen(
          (connectionState) {
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
              // onLog('✅ Устройство подключено: ${device.name}');
              characteristic = QualifiedCharacteristic(
                deviceId: device.id,
                serviceId: serviceUuid,
                characteristicId: characteristicUuid,
              );
              onConnected();
            } else if (connectionState.connectionState ==
                DeviceConnectionState.disconnected) {
              onLog('⚠️ Устройство отключено');
              onDisconnected();
            }
          },
          onError: (error) {
            onLog('❌ Ошибка подключения: $error');
            onError(error.toString());
          },
        );
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

  void dispose() {
    disconnect();
  }
}
