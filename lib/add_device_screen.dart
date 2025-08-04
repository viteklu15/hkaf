import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_new_device_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  List<Map<String, String>> devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('devices');
    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);
      setState(() {
        devices = List<Map<String, String>>.from(
          decoded.map((item) => Map<String, String>.from(item)),
        );
      });
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('devices', jsonEncode(devices));
  }

  void _addDevice(Map<String, String> device) {
    setState(() {
      devices.add(device);
    });
    _saveDevices().then((_) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Устройство ${device['name']} добавлено')),
      // );
    });
  }

  void _removeDevice(int index) {
    final deviceName = devices[index]['name'];
    setState(() {
      devices.removeAt(index);
    });
    _saveDevices().then((_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Устройство $deviceName удалено')));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Добавление устройств',
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

            devices.isEmpty
                ? const Expanded(
                  child: Center(
                    child: Text(
                      'Нет добавленных устройств',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                )
                : Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        color: Colors.white10,
                        child: ListTile(
                          title: Text(
                            device['name'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            device['serial'] ?? '',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _removeDevice(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 16,
                ), // отступ снизу
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 12,
                      bottom: 16,
                    ), // отступ снизу
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newDevice =
                            await Navigator.push<Map<String, String>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddNewDeviceScreen(),
                              ),
                            );
                        if (newDevice != null) {
                          _addDevice(newDevice);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить устройство'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
