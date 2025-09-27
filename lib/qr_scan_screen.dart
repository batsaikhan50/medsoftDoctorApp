import 'dart:developer';
import 'package:doctor_app/main.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanned = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    ctrl.scannedDataStream.listen((scanData) async {
      if (!isScanned) {
        setState(() => isScanned = true);

        String token = scanData.code ?? "";
        log("Scanned token: $token");

        // Save token to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("X-Medsoft-Token", token);
        await prefs.setBool("isLoggedIn", true);

        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MyHomePage(
                title: 'Дуудлагын жагсаалт',
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR код унших")),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text("QR кодоо камерын хүрээнд байрлуулна уу."),
            ),
          ),
        ],
      ),
    );
  }
}
