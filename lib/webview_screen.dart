import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:doctor_app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? roomId;
  final String? roomIdNum;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title = "Login",
    this.roomId,
    this.roomIdNum,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool arrivedInFifty = false;

  static const platform = MethodChannel(
    'com.example.doctor_app/location',
  );
  List<String> activeLocationLogs = [];

  @override
  void initState() {
    super.initState();

    platform.invokeMethod('startLocationManagerAfterLogin');

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('medsofttrack://callback')) {
            Navigator.of(context).pop();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );

    platform.setMethodCallHandler((call) async {
      if (call.method == 'arrivedInFiftyReached') {
        final bool arrived = call.arguments?['arrivedInFifty'] ?? false;
        debugPrint(
          "arrivedInFiftyReached received in Dart: ${call.arguments?['arrivedInFifty']}",
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('arrivedInFifty', arrived);

        setState(() {
          arrivedInFifty = arrived;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Та 50 метр дотор ирлээ."),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      if (call.method == 'activeLocationSaved') {
        debugPrint("activeLocationSaved_1: ${call.arguments?['saveCounter']}");
        debugPrint("activeLocationSaved_2: ${call.arguments?['savedTime']}");
        debugPrint(
          "activeLocationSaved_3: ${call.arguments?['distanceUpdate']}",
        );

        final saveCounter = call.arguments?['saveCounter'];
        final savedTime = call.arguments?['savedTime'];
        final distanceUpdate = call.arguments?['distanceUpdate'];

        final logEntry = "($saveCounter, $savedTime, $distanceUpdate)";

        setState(() {
          activeLocationLogs.add(logEntry);

          if (activeLocationLogs.length > 5) {
            activeLocationLogs.removeAt(0);
          }
        });

        for (final log in activeLocationLogs) {
          debugPrint(log);
        }
      }
    });
  }

  Future<void> _sendLocation() async {
    try {
      await platform.invokeMethod('sendLocationToAPIByButton');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to send location: '${e.message}'");

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send location: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _markArrived(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('X-Medsoft-Token') ?? '';
      final server = prefs.getString('X-Tenant') ?? '';

      final uri = Uri.parse('${Constants.appUrl}/room/arrived?id=$id');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'X-Medsoft-Token': token,
          'X-Tenant': server,
          'X-Token': Constants.xToken,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Амжилттай бүртгэгдлээ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          await platform.invokeMethod('startIdleLocation');
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(json['message'] ?? 'Амжилтгүй'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTTP алдаа: ${data.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to mark arrived: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сүлжээний алдаа: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      height: 40,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.black),
        label: Text(label, style: const TextStyle(color: Colors.black)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF009688),
        title: GestureDetector(
          onTap:
              () => {
                platform.invokeMethod("startIdleLocation"),
                Navigator.pop(context),
              },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 16,
                  top: 1,
                  bottom: 2,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          widget.title == 'Дуудлагын жагсаалт'
              ? Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 1,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              activeLocationLogs
                                  .map(
                                    (log) => Text(
                                      log,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 16,
                    right: 16,
                    child: _buildActionButton(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      onPressed: () {
                        _controller.reload();
                      },
                    ),
                  ),

                  if (widget.roomIdNum != null && arrivedInFifty)
                    Positioned(
                      top: 72,
                      right: 16,
                      child: _buildActionButton(
                        icon: Icons.check_circle,
                        label: 'Ирсэн',
                        onPressed: () {
                          _markArrived(widget.roomIdNum!);
                        },
                      ),
                    ),

                  Positioned(
                    bottom: 24,
                    right: 90,
                    child: _buildActionButton(
                      icon: Icons.send,
                      label: 'Байршил илгээх',
                      onPressed: _sendLocation,
                    ),
                  ),
                ],
              )
              : WebViewWidget(controller: _controller),
    );
  }
}
