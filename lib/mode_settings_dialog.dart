import 'package:flutter/material.dart';
import 'WIFI_service.dart';

enum DryerMode { standart, smart, fast, noHeat, personal, iron }

String getModeTitle(DryerMode mode) {
  switch (mode) {
    case DryerMode.standart:
      return "СТАНДАРТНЫЙ";
    case DryerMode.smart:
      return "УМНЫЙ РЕЖИМ";
    case DryerMode.fast:
      return "БЫСТРАЯ СУШКА";
    case DryerMode.noHeat:
      return "БЕЗ НАГРЕВА";
    case DryerMode.personal:
      return "ПЕРСОНАЛЬНЫЙ";
    case DryerMode.iron:
      return "ЛЁГКАЯ ГЛАЖКА";
    default:
      return "РЕЖИМ";
  }
}

class ModeSettingsDialog {
  static void show(
    BuildContext context,
    DryerMode mode, {
    required String deviceIp,
    required VoidCallback onConfirmed,
  }) {
    final allowTemp =
        mode == DryerMode.smart ||
        mode == DryerMode.personal ||
        mode == DryerMode.iron;
    final allowTime = mode == DryerMode.personal;
    final allowDelay = true;

    int temperature;
    int workHour;
    int workMin;

    switch (mode) {
      case DryerMode.standart:
        temperature = tempSetting[0];
        workHour = hourSetting[0];
        workMin = minSetting[0];
        break;
      case DryerMode.smart:
        temperature = tempSetting[1];
        workHour = hourSetting[1];
        workMin = minSetting[1];
        break;
      case DryerMode.fast:
        temperature = tempSetting[2];
        workHour = hourSetting[2];
        workMin = minSetting[2];
        break;
      case DryerMode.noHeat:
        temperature = tempSetting[3];
        workHour = hourSetting[3];
        workMin = minSetting[3];
        break;
      case DryerMode.personal:
        temperature = mT;
        workHour = mH;
        workMin = mMin;
        break;
      case DryerMode.iron:
        temperature = tempSetting[4];
        workHour = hourSetting[4];
        workMin = minSetting[4];
        break;
    }

    int delayHour = 0;
    int delayMin = 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        getModeTitle(mode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Температура
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.remove_circle,
                              color:
                                  allowTemp &&
                                          ((mode == DryerMode.iron &&
                                                  temperature == 60) ||
                                              (mode != DryerMode.iron &&
                                                  temperature > 20))
                                      ? Colors.green
                                      : Colors.green.withOpacity(0.3),
                            ),

                            onPressed:
                                allowTemp && mode == DryerMode.iron
                                    ? temperature == 60
                                        ? () => setModalState(
                                          () => temperature = 40,
                                        )
                                        : null
                                    : allowTemp && temperature > 20
                                    ? () =>
                                        setModalState(() => temperature -= 1)
                                    : null,
                          ),
                          Text(
                            "$temperature ºC",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.add_circle,
                              color:
                                  (allowTemp && temperature < 60)
                                      ? Colors.green
                                      : Colors.green.withOpacity(0.3),
                            ),
                            onPressed:
                                allowTemp && mode == DryerMode.iron
                                    ? temperature == 40
                                        ? () => setModalState(
                                          () => temperature = 60,
                                        )
                                        : null
                                    : allowTemp && temperature < 60
                                    ? () =>
                                        setModalState(() => temperature += 1)
                                    : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Время работы
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.remove_circle,
                              color:
                                  (allowTime && (workHour > 0 || workMin > 15))
                                      ? Colors.green
                                      : Colors.green.withOpacity(0.3),
                            ),
                            onPressed:
                                allowTime && (workMin >= 15 || workHour > 0)
                                    ? () => setModalState(() {
                                      if (workMin >= 15) {
                                        workMin -= 15;
                                      } else if (workHour > 0) {
                                        workHour -= 1;
                                        workMin = 45;
                                      }
                                    })
                                    : null,
                          ),
                          Text(
                            "${workHour.toString().padLeft(2, '0')}:${workMin.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.add_circle,
                              color:
                                  (allowTime &&
                                          !(workHour == 24 && workMin == 0))
                                      ? Colors.green
                                      : Colors.green.withOpacity(0.3),
                            ),
                            onPressed:
                                allowTime && !(workHour == 24 && workMin == 0)
                                    ? () => setModalState(() {
                                      if (workMin < 45) {
                                        workMin += 15;
                                      } else if (workHour < 24) {
                                        workHour += 1;
                                        workMin = 0;
                                      }
                                    })
                                    : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        "ОТЛОЖЕННЫЙ СТАРТ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              IconButton(
                                iconSize: 44,
                                icon: Icon(
                                  Icons.add_circle,
                                  color:
                                      (allowDelay && delayHour < 23)
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                                onPressed:
                                    allowDelay && delayHour < 23
                                        ? () =>
                                            setModalState(() => delayHour += 1)
                                        : null,
                              ),
                              Text(
                                delayHour.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                              IconButton(
                                iconSize: 44,
                                icon: Icon(
                                  Icons.remove_circle,
                                  color:
                                      (allowDelay && delayHour > 0)
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                                onPressed:
                                    allowDelay && delayHour > 0
                                        ? () =>
                                            setModalState(() => delayHour -= 1)
                                        : null,
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                          Column(
                            children: [
                              IconButton(
                                iconSize: 44,
                                icon: Icon(
                                  Icons.add_circle,
                                  color:
                                      (allowDelay && delayMin < 55)
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                                onPressed:
                                    allowDelay && delayMin < 55
                                        ? () =>
                                            setModalState(() => delayMin += 5)
                                        : null,
                              ),
                              Text(
                                delayMin.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                              IconButton(
                                iconSize: 44,
                                icon: Icon(
                                  Icons.remove_circle,
                                  color:
                                      (allowDelay && delayMin > 0)
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                                onPressed:
                                    allowDelay && delayMin > 0
                                        ? () =>
                                            setModalState(() => delayMin -= 5)
                                        : null,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ), // стало меньше
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();

                          final String comand =
                              "set_prog?prog=${delayHour},${delayMin},${mode.index+1},$temperature,$workHour,$workMin";

                          try {
                            await NetworkService.set_prog(
                              comand: comand,
                              deviceIp: deviceIp,
                            );
                          } catch (e) {
                            print("Ошибка при отправке команды: $e");
                          }

                          onConfirmed(); // после запроса
                        },

                        child: const Text(
                          "СТАРТ",
                          style: TextStyle(
                            fontSize: 22, // было 26
                            fontWeight:
                                FontWeight
                                    .w600, // можно оставить bold, но чуть легче
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
