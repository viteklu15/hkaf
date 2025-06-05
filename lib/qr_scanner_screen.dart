import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ble_manager.dart'; // обязательно подключи если нужен bleManager

class QRScannerScreen extends StatefulWidget {
  final BleManager bleManager;               // ← добавлено
  final Function(String) onDeviceScanned;    // ← добавлено

  const QRScannerScreen({
    super.key,
    required this.bleManager,
    required this.onDeviceScanned,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (!_scanned && value != null) {
                  _scanned = true;
                  widget.onDeviceScanned(value); // ← используется
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          // Кнопка назад
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Подсказка
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Наведите камеру на QR-код",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          // Рамка
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
