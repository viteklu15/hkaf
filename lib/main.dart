import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ble_manager.dart';
import 'WIFI_service.dart';
import 'door_open_dialog.dart';
import 'mode_settings_dialog.dart';
import 'dart:async';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.green,
          onPrimary: Colors.white,
        ),
      ),
      home: DryerScreen(),
    ),
  );
}

class DryerScreen extends StatefulWidget {
  const DryerScreen({super.key});

  @override
  State<DryerScreen> createState() => _DryerScreenState();
}

class _DryerScreenState extends State<DryerScreen> with WidgetsBindingObserver {
  bool _statusConfirmed = false; // добавляем переменную-флаг
  DateTime? _localActionUntil;
  Timer? _statusTimer;
  Timer? _modeWatchTimer;
  int modeProgram = 0;
  int _prevSens = 0;
  bool _isDoorDialogShown = false;

  List<String> dropdownItems = [];
  String? selectedItem;
  String? deviceIp;
  bool isWaterActive = true;

  final BleManager bleManager = BleManager();
  Color connectionStateColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setIpForDevice("fff", "192.168.0.114");
    _loadDevices();

    _modeWatchTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      // print("⏱ modeProgram1: ${modeProgram1.value}, modeProgram: $modeProgram");

      final now = DateTime.now();
      if ((_localActionUntil == null || now.isAfter(_localActionUntil!)) &&
          modeProgram != modeProgram1.value) {
        setState(() {
          modeProgram = modeProgram1.value;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Приложение переходит в фоновый режим или закрывается
      _statusTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Приложение возвращается на передний план
      if (deviceIp != null && deviceIp!.isNotEmpty) {
        _startStatusPolling();
      }
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    if (deviceIp != null && deviceIp!.isNotEmpty) {
      _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final gotStatus = await NetworkService.statusGET(deviceIp: deviceIp);
          if (mounted) {
            setState(() {
              _statusConfirmed = gotStatus;
              connectionStateColor = gotStatus ? Colors.green : Colors.red;

              // ✅ Проверка на изменение sens
              if (_prevSens == 0 && sens == 1 && !_isDoorDialogShown) {
                _isDoorDialogShown = true;
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder:
                      (context) => DoorOpenDialog(
                        onDismiss: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _isDoorDialogShown = false;
                          });
                        },
                      ),
                );
              }
              // ✅ Закрываем окно, если sens стал 0
              if (_isDoorDialogShown && sens == 0) {
                Navigator.of(context, rootNavigator: true).pop();
                _isDoorDialogShown = false;
              }

              _prevSens = sens;
            });
          }
        } catch (e) {
          debugPrint("Ошибка запроса статуса: $e");
        }
      });
    }
  }

  Future<void> _setIpForDevice(String name, String ip) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('devices');
    if (jsonString == null) return;

    final List devices = jsonDecode(jsonString);
    final updated =
        devices.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['name'] == name) {
            map['ip'] = ip;
          }
          return map;
        }).toList();

    await prefs.setString('devices', jsonEncode(updated));
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('devices');
    final savedSelection = prefs.getString('selectedDevice');

    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);
      final devices = List<Map<String, dynamic>>.from(
        decoded.map((item) => Map<String, dynamic>.from(item)),
      );

      final items =
          devices.map((e) => (e['name'] ?? 'Без имени').toString()).toList();

      setState(() {
        dropdownItems = items;
        selectedItem =
            items.contains(savedSelection)
                ? savedSelection
                : (items.isNotEmpty ? items.first : null);
      });

      if (selectedItem != null && selectedItem!.isNotEmpty) {
        final device = devices.firstWhere(
          (e) => e['name'] == selectedItem,
          orElse: () => {},
        );
        final serial = device['serial'];
        final ip = device['ip'];
        deviceIp = ip;

        bool statusOk = false;
        if (ip != null && ip.isNotEmpty) {
          bool gotStatus;
          try {
            gotStatus = await NetworkService.statusGET(deviceIp: ip);

            if (gotStatus) {
              _statusConfirmed = true;
              setState(() {
                connectionStateColor = Colors.green;
              });
              statusOk = true;
              _startStatusPolling();
            } else {
              print("⌛ Статус не получен — запускаем BLE IP запрос");
              setState(() => connectionStateColor = Colors.red);
              // _showSnackBar("IP не отвечает, пробуем через BLE...");
              _waitForIpFromBle();
            }
          } catch (e) {
            print("BLE требуется, ошибка запроса: $e");
          }

          // ⏱ Если в течение 3 секунд статус не получен, запускаем BLE
          Future.delayed(const Duration(seconds: 3), () {
            if (!_statusConfirmed && mounted) {
              print("⌛ Статус не получен — запускаем BLE IP запрос");
              setState(() => connectionStateColor = Colors.red);
              // _showSnackBar("IP не отвечает, пробуем через BLE...");
              _waitForIpFromBle();
            }
          });
        }

        if (!statusOk && serial != null) {
          setState(() => connectionStateColor = Colors.white);
          await bleManager.disconnect();
          bleManager.scanAndConnect(
            serial,
            onConnected: () async {
              final ip = deviceIp;
              if (ip != null) {
                final gotStatus = await NetworkService.statusGET(deviceIp: ip);
                if (gotStatus) {
                  _statusConfirmed = true;
                  setState(() => connectionStateColor = Colors.green);
                  _startStatusPolling();
                }
              }
              _waitForIpFromBle();
            },

            onDisconnected: () {
              setState(() => connectionStateColor = Colors.red);
            },
            onError: (err) {
              setState(() => connectionStateColor = Colors.red);
              // _showSnackBar('Ошибка BLE: $err');
            },
            onLog: _showSnackBar,
          );
        }
      }
    }
  }

  Future<void> _saveIpToDevice(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('devices');
    if (jsonString == null) return;

    final List devices = jsonDecode(jsonString);
    final updated =
        devices.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['name'] == selectedItem) map['ip'] = ip;
          return map;
        }).toList();

    await prefs.setString('devices', jsonEncode(updated));
  }

  void _waitForIpFromBle() async {
    bleManager.notifySub?.cancel();
    try {
      await bleManager.flutterReactiveBle.writeCharacteristicWithoutResponse(
        bleManager.characteristic!,
        value: utf8.encode('IP~1;'),
      );
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Ошибка отправки IP команды: $e')),
        // );
      }
      return;
    }

    bleManager.notifySub = bleManager.flutterReactiveBle
        .subscribeToCharacteristic(bleManager.characteristic!)
        .listen((data) async {
          final response = utf8.decode(data).trim();
          final parts = response.split(';~');
          if (parts.length == 2) {
            final index = int.tryParse(parts[0]);
            final value = parts[1];

            final ipRegExp = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
            if (index == 0 && ipRegExp.hasMatch(value)) {
              await _saveIpToDevice(value);
              setState(() => deviceIp = value);
              bleManager.notifySub?.cancel();

              // 🟢 ПОВТОРНО вызываем statusGET
              final gotStatus = await NetworkService.statusGET(deviceIp: value);
              if (gotStatus) {
                _statusConfirmed = true;
                setState(() => connectionStateColor = Colors.green);
                _startStatusPolling();
              }
            }
          }
        });

    Future.delayed(const Duration(seconds: 5), () {
      bleManager.notifySub?.cancel();
    });
  }

  Future<void> _saveSelectedItem(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDevice', value);
  }

  void _showSnackBar(String message) {
    final context = this.context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _modeWatchTimer?.cancel();
    bleManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProgramSelected = (modeProgram != 0 && modeProgram1.value != 0);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 10, left: 4),
                  decoration: BoxDecoration(
                    color: connectionStateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (dropdownItems.isNotEmpty)
                  DropdownButton<String>(
                    value: selectedItem,
                    dropdownColor: Colors.grey[900],
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    iconSize: 28,
                    style: const TextStyle(fontSize: 16),
                    underline: const SizedBox(),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    items:
                        dropdownItems.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() {
                          selectedItem = value;
                          connectionStateColor = Colors.white;
                          deviceIp = null;
                        });

                        await _saveSelectedItem(value);

                        final prefs = await SharedPreferences.getInstance();
                        final devices = jsonDecode(
                          prefs.getString('devices') ?? '[]',
                        );
                        final matched = (devices as List)
                            .map((e) => Map<String, dynamic>.from(e))
                            .firstWhere(
                              (d) => d['name'] == value,
                              orElse: () => {},
                            );

                        final serial = matched['serial'];
                        final ip = matched['ip'];
                        deviceIp = ip;

                        bool statusOk = false;
                        if (ip != null && ip.isNotEmpty) {
                          bool gotStatus;
                          try {
                            gotStatus = await NetworkService.statusGET(
                              deviceIp: ip,
                            );

                            if (gotStatus) {
                              setState(() {
                                connectionStateColor = Colors.green;
                              });
                              statusOk = true;
                              _startStatusPolling();
                            } else {
                              print(
                                "⌛ Статус не получен — запускаем BLE IP запрос",
                              );
                              setState(() => connectionStateColor = Colors.red);
                              // _showSnackBar(
                              //   "IP не отвечает, пробуем через BLE...",
                              // );
                              _waitForIpFromBle();
                            }
                          } catch (e) {
                            print("BLE требуется, ошибка запроса: $e");
                          }

                          Future.delayed(const Duration(seconds: 3), () {
                            if (!_statusConfirmed && mounted) {
                              print(
                                "⌛ Статус не получен — запускаем BLE IP запрос",
                              );
                              setState(() => connectionStateColor = Colors.red);
                              // _showSnackBar(
                              //   "IP не отвечает, пробуем через BLE...",
                              // );
                              _waitForIpFromBle();
                            }
                          });
                        }

                        if (!statusOk && serial != null) {
                          await bleManager.disconnect();
                          bleManager.scanAndConnect(
                            serial,
                            onConnected: () {
                              // setState(() => connectionStateColor = Colors.green,);
                              _startStatusPolling();
                              _waitForIpFromBle();
                            },
                            onDisconnected: () {
                              setState(() => connectionStateColor = Colors.red);
                            },
                            onError: (err) {
                              setState(() => connectionStateColor = Colors.red);
                              // _showSnackBar('Ошибка BLE: $err');
                            },
                            onLog: _showSnackBar,
                          );
                        }
                      }
                    },
                  ),
                Expanded(
                  child: Center(
                    child: Text(
                      deviceIp != null ? 'IP: $deviceIp' : '',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SettingsScreen(deviceIp: deviceIp),
                      ),
                    );
                    _loadDevices();
                  },
                ),
              ],
            ),

            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isProgramSelected)
                      Flexible(
                        child: Center(
                          child: Text(
                            "Выберите программу",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (flagDelayStart == 1) _infoText("Запуск отложен"),
                          Row(
                            children: [
                              const Icon(
                                Icons.thermostat,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$targetTemperature ºC",
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (isProgramSelected)
                      Text(
                        (hour == 0 && min == 0 && sec > 0)
                            ? "$sec сек"
                            : "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}",
                        style: GoogleFonts.orbitron(
                          fontSize: 48,
                          color:
                              (hour == 0 && min == 0 && sec > 0)
                                  ? Colors.red
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final buttons = [
                      [
                        "СТАНДАРТНЫЙ",
                        Icons.emoji_people,
                        Colors.deepPurple,
                        Colors.pink,
                      ],
                      [
                        "УМНЫЙ РЕЖИМ",
                        Icons.psychology,
                        Colors.teal,
                        Colors.blueAccent,
                      ],
                      [
                        "БЫСТРАЯ СУШКА",
                        Icons.timer,
                        Colors.yellow,
                        Colors.pink,
                      ],
                      [
                        "БЕЗ НАГРЕВА",
                        Icons.thermostat,
                        Colors.deepPurple,
                        Colors.yellow,
                      ],
                      [
                        "ПЕРСОНАЛЬНЫЙ",
                        Icons.badge,
                        Colors.deepPurple,
                        Colors.indigo,
                      ],
                      ["ЛЁГКАЯ ГЛАЖКА", Icons.iron, Colors.cyan, Colors.blue],
                    ];

                    final b = buttons[index];
                    final isStopped =
                        modeProgram != 0 && modeProgram == index + 1;

                    final title = isStopped ? "СТОП" : b[0] as String;
                    final icon = isStopped ? Icons.stop : b[1] as IconData;
                    final start = isStopped ? Colors.red : b[2] as Color;
                    final end = isStopped ? Colors.red : b[3] as Color;

                    return _modeButton(title, icon, start, end, index + 1);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _modeButton(
    String title,
    IconData icon,
    Color start,
    Color end,
    int index,
  ) {
    final isStopped = modeProgram != 0 && modeProgram == index;
    final displayTitle = isStopped ? "СТОП" : title;
    final displayIcon = isStopped ? Icons.stop : icon;
    final displayStart = isStopped ? Colors.red : start;
    final displayEnd = isStopped ? Colors.red : end;

    return GestureDetector(
      onTap: () async {
        if (modeProgram == index) {
          setState(() {
            modeProgram = 0;
            modeProgram1.value = 0;
            _localActionUntil = DateTime.now().add(const Duration(seconds: 2));
          });

          if (deviceIp != null) {
            await NetworkService.set_prog(
              comand: "set_prog?prog=0,0,0,42,1,15",
              deviceIp: deviceIp!,
            );
          }

          await Future.delayed(const Duration(seconds: 2));
          return;
        }

        final modeMap = {
          "СТАНДАРТНЫЙ": DryerMode.standart,
          "УМНЫЙ РЕЖИМ": DryerMode.smart,
          "БЫСТРАЯ СУШКА": DryerMode.fast,
          "БЕЗ НАГРЕВА": DryerMode.noHeat,
          "ПЕРСОНАЛЬНЫЙ": DryerMode.personal,
          "ЛЁГКАЯ ГЛАЖКА": DryerMode.iron,
        };

        final mode = modeMap[title];
        if (mode != null && deviceIp != null) {
          ModeSettingsDialog.show(
            context,
            deviceIp: deviceIp!,
            mode,
            onConfirmed: () {
              setState(() {
                _localActionUntil = DateTime.now().add(
                  const Duration(seconds: 3),
                );
                modeProgram = index;
                modeProgram1.value = index;
              });
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [displayStart, displayEnd]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(displayIcon, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
