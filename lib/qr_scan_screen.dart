import 'dart:developer';
import 'package:doctor_app/claim_qr.dart';
import 'package:doctor_app/constants.dart';
import 'package:doctor_app/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  Future<void> _handleScannedToken(String url) async {
    try {
      
      Uri uri = Uri.parse(url);
      String? token;
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == "qr") {
        token = uri.pathSegments[1];
      }

      if (token == null) {
        log("Invalid QR format");
        return;
      }

      log("Extracted token: $token");

      final prefs = await SharedPreferences.getInstance();
      final tokenSaved = prefs.getString('X-Medsoft-Token') ?? '';
      final server = prefs.getString('X-Tenant') ?? '';

      final headers = {
        'X-Medsoft-Token': tokenSaved,
        'X-Tenant': server,
        'X-Token': Constants.xToken,
      };

      final response = await http.get(
        Uri.parse(
          "https:
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ClaimQRScreen(token: token!)),
        );
      } else {
        log("Wait API failed: ${response.statusCode}");
      }
    } catch (e) {
      log("Error handling QR: $e");
    }
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    ctrl.scannedDataStream.listen((scanData) async {
      if (!isScanned) {
        setState(() => isScanned = true);

        
        await controller?.pauseCamera();
        

        
        
        Future.microtask(() {
          _handleScannedToken(scanData.code ?? "");
        });
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
            child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
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
