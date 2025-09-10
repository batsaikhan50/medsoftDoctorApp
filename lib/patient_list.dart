import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:doctor_app/login.dart';
import 'package:doctor_app/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => PatientListScreenState();
}

class PatientListScreenState extends State<PatientListScreen> {
  List<dynamic> patients = [];
  bool isLoading = true;
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};
  Timer? _refreshTimer;

  static const platform = MethodChannel('com.example.doctor_app/location');

  @override
  void initState() {
    super.initState();
    fetchPatients();
    _loadSharedPreferencesData();

    platform.invokeMethod('startIdleLocation');

    _refreshTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      refreshPatients();
    });
  }

  void refreshPatients() {
    setState(() {
      isLoading = true;
    });
    fetchPatients();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('X-Medsoft-Token') ?? '';
    final server = prefs.getString('X-Tenant') ?? '';

    final uri = Uri.parse('${Constants.appUrl}/room/get/driver');

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
        setState(() {
          patients = json['data'];
          isLoading = false;
        });
      }
    } else {
      setState(() => isLoading = false);
      debugPrint('Failed to fetch patients: ${response.statusCode}');
      if (response.statusCode == 401 || response.statusCode == 403) {
        _logOut();
      }
    }
  }

  void _logOut() async {
    debugPrint("Entered _logOut");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Tenant');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');

    // try {
    //   await platform.invokeMethod('stopLocationUpdates');
    // } on PlatformException catch (e) {
    //   debugPrint("Failed to stop location updates: '${e.message}'.");
    // }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn' || key == 'arrivedInFifty') {
        data[key] = prefs.getBool(key);
      } else {
        data[key] = prefs.getString(key) ?? 'null';
      }
    }

    setState(() {
      username = prefs.getString('Username');
      sharedPreferencesData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final patientPhone = patient['patientPhone'] ?? 'Unknown';
                final sentToPatient = patient['sentToPatient'] ?? false;
                final patientSent = patient['patientSent'] ?? false;
                final arrived = patient['arrived'] ?? false;
                final distance = patient['totalDistance'];
                final duration = patient['totalDuration'];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientPhone,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: arrived
                                    ? () async {
                                        final roomId = patient['roomId'];
                                        final roomIdNum = patient['_id'];
                                        final phone = patient['patientPhone'];

                                        if (roomId == null || phone == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Room ID эсвэл утасны дугаар олдсонгүй',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                          return;
                                        }
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              titlePadding:
                                                  const EdgeInsets.fromLTRB(
                                                    24,
                                                    24,
                                                    24,
                                                    0,
                                                  ),
                                              title: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: const [
                                                  Text(
                                                    "Үзлэг баталгаажуулах",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Divider(thickness: 1),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: const [
                                                      Icon(
                                                        Icons.phone_iphone,
                                                        color: Colors.cyan,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "Хэрвээ дуудлага өгсөн иргэн Medsoft аппликейшн ашигладаг бол:",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      shadowColor: Colors.cyan
                                                          .withOpacity(0.4),
                                                      elevation: 8,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      debugPrint(
                                                        "Иргэний аппликейшн руу баталгаажуулах хүсэлт илгээгдлээ.",
                                                      );
                                                    },
                                                    child: const Text(
                                                      "Иргэний аппликейшн руу баталгаажуулах хүсэлт илгээх",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    children: const [
                                                      Icon(
                                                        Icons.message,
                                                        color: Colors.orange,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "Хэрвээ дуудлага өгсөн иргэн Medsoft аппликейшн ашигладаггүй бол:",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      shadowColor: Colors.orange
                                                          .withOpacity(0.4),
                                                      elevation: 8,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      debugPrint(
                                                        "Иргэний утасны дугаар руу OTP илгээгдлээ.",
                                                      );
                                                    },
                                                    child: const Text(
                                                      "Иргэний утасны дугаар руу OTP илгээх",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                                  child: const Text("Буцах"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Flexible(
                                      child: Text("Үзлэг баталгаажуулах"),
                                    ),
                                    if (arrived) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (arrived) ...[
                          const SizedBox(height: 8),
                          Text("Distance: ${distance ?? 'N/A'} km"),
                          Text("Duration: ${duration ?? 'N/A'}"),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
