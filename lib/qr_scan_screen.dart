import 'dart:developer';

import 'package:doctor_app/claim_qr.dart';
import 'package:doctor_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shortestSide = MediaQuery.of(context).size.shortestSide;
      debugPrint('shortestSide : $shortestSide');

      const double tabletBreakpoint = 600;

      if (shortestSide < tabletBreakpoint) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
        Uri.parse("${Constants.runnerUrl}/gateway/general/get/api/auth/qr/wait?id=$token"),
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
    // Determine the size of the square cutout area
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate scan area based on a percentage of the smaller dimension,
    // capped at a maximum (to avoid being too large on tablets).
    const maxScanArea = 350.0;
    final proportionalSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.9;
    final scanArea = proportionalSize < maxScanArea ? proportionalSize : maxScanArea;

    return Scaffold(
      appBar: AppBar(title: const Text("QR код унших")),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: const Color(0xFF00CCCC), // corner color
                  borderRadius: 15, // rounded corners
                  borderLength: 50, // long corners
                  borderWidth: 15, // thick corners
                  cutOutSize: scanArea, // center square size
                  overlayColor: const Color(0xFFFDF7FE), // background outside cutout
                ),
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(child: Text("QR кодоо камерын хүрээнд байрлуулна уу.")),
          ),
        ],
      ),
    );
  }
}
