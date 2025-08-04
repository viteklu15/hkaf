import 'dart:async';
import 'dart:convert';
import 'globals.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // обязательно вверху
import 'dart:io';

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



Future<bool> _checkPermissions(void Function(String onLog) onLog) async {
  if (Platform.isIOS) {
    // ✅ Проверка гео через Geolocator
    final geoPermission = await Geolocator.checkPermission();
    if (geoPermission == LocationPermission.denied ||
        geoPermission == LocationPermission.deniedForever) {
      // final result = await Geolocator.requestPermission();
      // onLog('📍 Георазрешение (iOS): $result');
    }

    final geoStatus = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // onLog('📡 Геослужба включена: $serviceEnabled');
    // onLog('📍 Гео статус: $geoStatus');

    // ⚠️ BLE разрешения не проверяем через permission_handler — считаем, что iOS сам покажет при необходимости

    return (geoStatus == LocationPermission.always ||
            geoStatus == LocationPermission.whileInUse) &&
        serviceEnabled;
  } else {
    // ✅ Android: проверяем всё
    final permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    final statuses = await permissions.request();
    final allGranted = statuses.values.every((status) => status.isGranted);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    return allGranted && serviceEnabled;
  }
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
      //  onLog('📡 Найдено устройство: ${device.name} (${device.id})');
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

  final List<String> wifiList = [];

  notifySub = flutterReactiveBle
      .subscribeToCharacteristic(characteristic!)
      .listen((data) {
    final parts = utf8.decode(data).split(';~');
    if (parts.length == 2) {
      final index = int.tryParse(parts[0]);
      final name = parts[1];

      if (index != null && name.isNotEmpty) {
        while (wifiList.length <= index) {
          wifiList.add('');
        }
        wifiList[index] = name;

        // Передаём весь список каждый раз
        onData(List.from(wifiList));
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
