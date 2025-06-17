// add_new_device_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'globals.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_manager.dart';
import 'qr_scanner_screen.dart';

class AddNewDeviceScreen extends StatefulWidget {
  const AddNewDeviceScreen({super.key});

  @override
  State<AddNewDeviceScreen> createState() => _AddNewDeviceScreenState();
}

class _AddNewDeviceScreenState extends State<AddNewDeviceScreen> {
  bool isWifiLoading = false;
  bool _wasQrScanned = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late final BleManager bleManager = BleManager();

  @override
  void initState() {
    super.initState();
    _nameController.text = "Шкаф 1";
  }

  List<String> wifiNetworks = [];
  String? selectedNetwork;
  bool isConnected = false;
  bool isScanningQr = false;
  bool isConnecting = false;

  bool get _allFieldsFilled {
    final nameFilled = _nameController.text.isNotEmpty;
    final serialFilled = _serialController.text.isNotEmpty;

    if (!_wasQrScanned) {
      return nameFilled && serialFilled;
    } else {
      return isConnected &&
          selectedNetwork != null &&
          passwordController.text.length >= 8;
    }
  }

  @override
  void dispose() {
    bleManager.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              bleManager: bleManager,
              onDeviceScanned: _onDeviceScanned,
            ),
      ),
    );

    if (result != null) {
      setState(() {
        _serialController.text = result;
      });
    }
  }

  void _onDeviceScanned(String deviceName) {
    setState(() {
      _serialController.text = deviceName;
      _wasQrScanned = true;
    });
    _initPermissionsAndScan(deviceName);
  }

  Future<void> _initPermissionsAndScan(String deviceName) async {
    await [Permission.bluetooth, Permission.location].request();
    _startScan(deviceName);
  }

  void _startScan(String deviceName) {
    setState(() => isConnecting = true);

    bleManager.scanAndConnect(
      deviceName,
      onConnected: () async {
        try {
          await bleManager.sendCommand("con~1;");
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Ошибка отправки команды: $e")),
            );
          }
        }

        setState(() {
          isConnected = true;
          isConnecting = false;
          _wasQrScanned = true;
        });
        _listenToWifiList();
      },
      onDisconnected: () {
        setState(() {
          isConnected = false;
          isConnecting = false;
        });
      },
      onError: (error) {
        setState(() {
          isConnected = false;
          isConnecting = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка подключения: $error")));
      },
      onLog: (msg) {
        // Выводим лог в SnackBar — как и просил
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }

  void _listenToWifiList() {
    setState(() => isWifiLoading = true);

    bleManager.listenToWifiList((networks) {
      setState(() {
        isWifiLoading = false;

        for (int i = 0; i < networks.length; i++) {
          if (i >= wifiNetworks.length) {
            wifiNetworks.add(networks[i]);
          } else if (networks[i].isNotEmpty) {
            wifiNetworks[i] = networks[i];
          }
        }
      });
    });
  }

  Future<void> _sendPassword() async {
    if (selectedNetwork == null) {
      throw Exception("Сеть не выбрана");
    }

    try {
      await bleManager.sendWifiCredentials(
        selectedNetwork!,
        passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Сохранение')));
      }

      await bleManager.disconnect();
      setState(() => isConnected = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка отправки пароля: $e")));
      }
      rethrow;
    }
  }

  Future<void> _submit() async {
    try {
      if (isConnected) {
        await _sendPassword();
      }

      final name = _nameController.text.trim();
      final serial = _serialController.text.trim();

      if (name.isNotEmpty && serial.isNotEmpty && mounted) {
        Navigator.pop(context, {'name': name, 'serial': serial});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
      }
      if (_nameController.text.trim().isNotEmpty &&
          _serialController.text.trim().isNotEmpty &&
          mounted) {
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'serial': _serialController.text.trim(),
        });
      }
    }
  }

  InputDecoration _inputDecoration(String labelText, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color.fromARGB(255, 255, 255, 255)),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildConnectionIndicator() {
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
      );
    } else if (isConnected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    } else {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Новое устройство",
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Название устройства"),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _serialController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                "Серийный номер",
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildConnectionIndicator(),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code, color: Colors.green),
                      onPressed: _scanQrCode,
                    ),
                  ],
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            if (isConnected && isWifiLoading) ...[
              const SizedBox(height: 20),
              const Row(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    "Поиск Wi-Fi сетей...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ] else if (isConnected && wifiNetworks.isNotEmpty) ...[
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: selectedNetwork,
                hint: const Text(
                  'Выберите Wi-Fi сеть',
                  style: TextStyle(color: Colors.white),
                ),
                dropdownColor: Colors.black87,
                iconEnabledColor: Colors.white,
                isExpanded: true,
                items:
                    wifiNetworks
                        .where((e) => e.isNotEmpty)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => selectedNetwork = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Пароль от Wi-Fi'),
                obscureText: false,
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 30),
            if (_allFieldsFilled)
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  isConnected ? "Добавить и отправить" : "Добавить",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
