import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:google_fonts/google_fonts.dart';
import 'add_device_screen.dart';
import 'WIFI_service.dart'; // Здесь находится ufNotifier

class SettingsScreen extends StatefulWidget {
  final String? deviceIp;

  const SettingsScreen({super.key, required this.deviceIp});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _uvEnabled = false;
  bool _muzEnabled = false;
  // late VoidCallback _ufListener;
  // late VoidCallback _muzListener;

  int _selectedTimezone = 3;

  void _showTimezoneDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: List.generate(12, (index) {
                if (index < 11) {
                  final value = index + 2;
                  return _buildZoneButton(value);
                } else {
                  return SizedBox.expand(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoneButton(int value) {
    final isSelected = _selectedTimezone == value;
    return SizedBox.expand(
      child: ElevatedButton(
        onPressed: () async {
          setState(() => _selectedTimezone = value);
          Navigator.pop(context);

          // Отправка команды на устройство
          if (widget.deviceIp != null && widget.deviceIp!.isNotEmpty) {
            final command = "set_prog?UTC=$value";
            await NetworkService.sendCommandToDevice(widget.deviceIp!, command);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.green : Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        child: Text(
          '+$value',
          style: TextStyle(color: isSelected ? Colors.black : Colors.white),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTimezone = utc;
    _uvEnabled = uf.value == 1;
    _muzEnabled = muz.value == 1;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "НАСТРОЙКИ",
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _settingBlock(
              title: "Часовой пояс",
              description:
                  "Выберите актуальный часовой пояс,\nдля корректного отображения времени.",
              trailing: GestureDetector(
                onTap: _showTimezoneDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '+$_selectedTimezone',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),

              titleColor: Colors.green,
            ),
            _settingBlock(
              title: "UV обработка",
              description:
                  "При активации во всех режимах\nвключается обработка ультрафиолетом.",
              trailing: CupertinoSwitch(
                value: _uvEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    _uvEnabled = value;
                    uf.value = value ? 1 : 0;
                  });

                  if (widget.deviceIp != null && widget.deviceIp!.isNotEmpty) {
                    final command = "set_prog?UF=${uf.value}";
                    await NetworkService.sendCommandToDevice(
                      widget.deviceIp!,
                      command,
                    );
                  }
                },
              ),
              titleColor: Colors.green,
            ),

            _settingBlock(
              title: "Звуки",
              description:
                  "Эта настройка выключает/включает\nзвуковые уведомления.",
              trailing: CupertinoSwitch(
                value: _muzEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    _muzEnabled = value;
                    muz.value = value ? 1 : 0;
                  });

                  if (widget.deviceIp != null && widget.deviceIp!.isNotEmpty) {
                    final command = "set_prog?muz=${muz.value}";
                    await NetworkService.sendCommandToDevice(
                      widget.deviceIp!,
                      command,
                    );
                  }
                },
              ),
              titleColor: Colors.green,
            ),

            _settingBlock(
              title: "Добавить устройство",
              description:
                  "Для подключения к Яндекс Алиса,\nподключитесь к домашней сети.",
              trailing: IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                  size: 36,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddDeviceScreen(),
                    ),
                  );
                },
              ),
              titleColor: Colors.green,
            ),
            const Spacer(),
            const Center(
              child: Text(
                "Schönes Feuer",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingBlock({
    required String title,
    required String description,
    required Widget trailing,
    required Color titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
