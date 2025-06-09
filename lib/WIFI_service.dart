import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

int flagDelayStart = 0;
ValueNotifier<int> modeProgram1 = ValueNotifier<int>(0);
int targetTemperature = 0;
ValueNotifier<int> uf = ValueNotifier<int>(0);
ValueNotifier<int> muz = ValueNotifier<int>(0);
int utc = 0;
int sens = 0;
int mT = 0;
int mH = 0;
int mMin = 0;
int hour = 0;
int min = 0;
int sec = 0;
List<int> tempSetting = List.filled(5, 0);
List<int> hourSetting = List.filled(5, 0);
List<int> minSetting = List.filled(5, 0);

int Flag_delayStart = 0;

class NetworkService {
  /// Базовая отправка GET-запроса
  static Future<String> sendGet(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);

      if (response.statusCode == 200) { 
        return response.body;
      } else {
        throw Exception('Ошибка запроса: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка запроса: $e');
    }
  }

  /// Отправка команды на устройство по IP
  static Future<String> sendCommandToDevice(String ip, String command) async {
    //  print(command);
    final url = 'http://$ip/$command';
    print(url);
    return await sendGet(url);
  }

  // set_prog  запуск программы
  static Future<void> set_prog({
    required String comand,
    required String deviceIp,
  }) async {
    // print(comand);
    try {
      final result = await sendCommandToDevice(deviceIp, comand);
      // print(result);
    } catch (e) {
      print("Ошибка при GET-запросе: $e");
    }
  }

  static Future<bool> statusGET({required String? deviceIp}) async {
    if (deviceIp == null || deviceIp.isEmpty) return false;

    try {
      final url = 'http://$deviceIp/status';
      // print("🌐 Отправка запроса: $url");

      // Таймаут в 3 секунды на случай зависания
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        print("⚠️ Сервер вернул код: ${response.statusCode}");
        return false;
      }

      // print("📨 Ответ получен: ${response.body}");
      final Map<String, dynamic> data = jsonDecode(response.body);

      final isValid =
          data.containsKey("mode_program") && data.containsKey("UTC");
      if (!isValid) {
        print("⚠️ Получен некорректный JSON: отсутствуют ключи");
        return false;
      }

      flagDelayStart = data["Flag_delayStart"] ?? 0;
      modeProgram1.value = data["mode_program"] ?? 0;
      targetTemperature = data["targetTemperature"] ?? 0;
      uf.value = data["UF"] ?? 0;
      muz.value = data["muz"] ?? 0;
      sens = data["sens"] ?? 0;
      utc = data["UTC"] ?? 0;
      mT = data["mT"] ?? 0;
      mH = data["mH"] ?? 0;
      mMin = data["mMin"] ?? 0;
      hour = data["hour"] ?? 0;
      min = data["min"] ?? 0;
      sec = data["sec"] ?? 0;

      tempSetting = List<int>.from(data["temp_seting"] ?? []);
      hourSetting = List<int>.from(data["hour_seting"] ?? []);
      minSetting = List<int>.from(data["min_seting"] ?? []);

      return true;
    } on TimeoutException {
      print("❌ Ошибка: превышено время ожидания ответа от $deviceIp");
      return false;
    } catch (e) {
      print("❌ Ошибка при запросе или парсинге статуса: $e");
      return false;
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
