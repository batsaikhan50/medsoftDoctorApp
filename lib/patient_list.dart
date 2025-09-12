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

  @override
  void initState() {
    super.initState();
    fetchPatients(initialLoad: true);
    _loadSharedPreferencesData();

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      refreshPatients();
    });
  }

  void refreshPatients() {
    fetchPatients();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchPatients({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => isLoading = true);
    }

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
      debugPrint('Successfully updated patients: ${response.statusCode}');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        setState(() {
          patients = json['data'];
          isLoading = false;
        });
      }
    } else {
      if (initialLoad) {
        setState(() => isLoading = false);
      }
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
                                        final phone = patient['patientPhone'];

                                        if (roomId == null || phone == null) {
                                          // show snackbar with root context
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

                                        // Save a safe parent context before showing dialog
                                        final rootContext = context;

                                        showDialog(
                                          context: rootContext,
                                          builder: (BuildContext dialogContext) {
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
                                                    onPressed: () async {
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();

                                                      final prefs =
                                                          await SharedPreferences.getInstance();
                                                      final token =
                                                          prefs.getString(
                                                            'X-Medsoft-Token',
                                                          ) ??
                                                          '';
                                                      final tenant =
                                                          prefs.getString(
                                                            'X-Tenant',
                                                          ) ??
                                                          '';

                                                      final uri = Uri.parse(
                                                        '${Constants.appUrl}/room/done_request_app?roomId=$roomId',
                                                      );

                                                      try {
                                                        final response =
                                                            await http.get(
                                                              uri,
                                                              headers: {
                                                                'X-Medsoft-Token':
                                                                    token,
                                                                'X-Tenant':
                                                                    tenant,
                                                                'X-Token':
                                                                    Constants
                                                                        .xToken,
                                                              },
                                                            );

                                                        if (response
                                                                .statusCode ==
                                                            200) {
                                                          debugPrint(
                                                            'done_request success: ${response.body}',
                                                          );
                                                          ScaffoldMessenger.of(
                                                            rootContext,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              backgroundColor:
                                                                  Colors.green,
                                                              content: Text(
                                                                'Иргэний апп руу хүсэлт илгээгдлээ',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        } else {
                                                          debugPrint(
                                                            'done_request failed: ${response.statusCode} ${response.body} ',
                                                          );
                                                          ScaffoldMessenger.of(
                                                            rootContext,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Амжилтгүй: ${response.statusCode}',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        debugPrint(
                                                          'API error: $e',
                                                        );
                                                        ScaffoldMessenger.of(
                                                          rootContext,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Алдаа гарлаа',
                                                            ),
                                                          ),
                                                        );
                                                      }
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
                                                    onPressed: () async {
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();

                                                      final prefs =
                                                          await SharedPreferences.getInstance();
                                                      final token =
                                                          prefs.getString(
                                                            'X-Medsoft-Token',
                                                          ) ??
                                                          '';
                                                      const tenant = 'staging';

                                                      final uri = Uri.parse(
                                                        '${Constants.appUrl}/room/done_request_otp?roomId=$roomId',
                                                      );

                                                      try {
                                                        final response =
                                                            await http.get(
                                                              uri,
                                                              headers: {
                                                                'X-Medsoft-Token':
                                                                    token,
                                                                'X-Tenant':
                                                                    tenant,
                                                                'X-Token':
                                                                    Constants
                                                                        .xToken,
                                                              },
                                                            );

                                                        if (response.statusCode ==
                                                                200 ||
                                                            response.statusCode ==
                                                                429) {
                                                          debugPrint(
                                                            ' done_request_otp success: ${response.body}',
                                                          );
                                                          ScaffoldMessenger.of(
                                                            rootContext,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Иргэний утас руу OTP илгээгдлээ',
                                                              ),
                                                            ),
                                                          );

                                                          final TextEditingController
                                                          otpController =
                                                              TextEditingController();

                                                          showDialog(
                                                            context:
                                                                rootContext,
                                                            barrierDismissible:
                                                                false,
                                                            builder:
                                                                (
                                                                  BuildContext
                                                                  context,
                                                                ) {
                                                                  return AlertDialog(
                                                                    title: const Text(
                                                                      'OTP оруулах',
                                                                    ),
                                                                    content: TextField(
                                                                      controller:
                                                                          otpController,
                                                                      keyboardType:
                                                                          TextInputType
                                                                              .number,
                                                                      maxLength:
                                                                          6,
                                                                      decoration: const InputDecoration(
                                                                        hintText:
                                                                            '6 оронтой OTP',
                                                                        counterText:
                                                                            '',
                                                                      ),
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () {
                                                                          Navigator.of(
                                                                            context,
                                                                          ).pop(); // close dialog
                                                                        },
                                                                        child: const Text(
                                                                          'Буцах',
                                                                        ),
                                                                      ),
                                                                      ElevatedButton(
                                                                        onPressed: () async {
                                                                          final otp = otpController
                                                                              .text
                                                                              .trim();

                                                                          if (otp.length ==
                                                                              6) {
                                                                            try {
                                                                              final doneUri = Uri.parse(
                                                                                '${Constants.appUrl}/room/done',
                                                                              );

                                                                              final doneResponse = await http.post(
                                                                                doneUri,
                                                                                headers: {
                                                                                  'Content-Type': 'application/json',
                                                                                  'X-Medsoft-Token': token,
                                                                                  'X-Tenant': tenant,
                                                                                  'X-Token': Constants.xToken,
                                                                                },
                                                                                body: jsonEncode(
                                                                                  {
                                                                                    'roomId': roomId,
                                                                                    'otp': otp,
                                                                                  },
                                                                                ),
                                                                              );

                                                                              if (doneResponse.statusCode ==
                                                                                  200) {
                                                                                Navigator.of(
                                                                                  context,
                                                                                ).pop(); // close dialog
                                                                                ScaffoldMessenger.of(
                                                                                  rootContext,
                                                                                ).showSnackBar(
                                                                                  const SnackBar(
                                                                                    content: Text(
                                                                                      ' Амжилттай баталгаажлаа',
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                              } else {
                                                                                ScaffoldMessenger.of(
                                                                                  rootContext,
                                                                                ).showSnackBar(
                                                                                  SnackBar(
                                                                                    content: Text(
                                                                                      'Алдаа: ${doneResponse.statusCode}',
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                              }
                                                                            } catch (
                                                                              e
                                                                            ) {
                                                                              debugPrint(
                                                                                'done error: $e',
                                                                              );
                                                                              ScaffoldMessenger.of(
                                                                                rootContext,
                                                                              ).showSnackBar(
                                                                                const SnackBar(
                                                                                  content: Text(
                                                                                    'Сүлжээний алдаа',
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }
                                                                          } else {
                                                                            ScaffoldMessenger.of(
                                                                              rootContext,
                                                                            ).showSnackBar(
                                                                              const SnackBar(
                                                                                content: Text(
                                                                                  'OTP 6 оронтой байх ёстой',
                                                                                ),
                                                                              ),
                                                                            );
                                                                          }
                                                                        },
                                                                        child: const Text(
                                                                          'Шалгах',
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                          );
                                                        } else {
                                                          debugPrint(
                                                            'done_request_otp failed: ${response.statusCode} ${response.body}',
                                                          );
                                                          ScaffoldMessenger.of(
                                                            rootContext,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Амжилтгүй: ${response.statusCode}',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        debugPrint(
                                                          'API error: $e',
                                                        );
                                                        ScaffoldMessenger.of(
                                                          rootContext,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Алдаа гарлаа',
                                                            ),
                                                          ),
                                                        );
                                                      }
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
                                                    dialogContext,
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
