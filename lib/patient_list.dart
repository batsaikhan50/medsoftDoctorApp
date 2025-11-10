import 'dart:async';
import 'dart:convert';

import 'package:doctor_app/login.dart';
import 'package:doctor_app/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
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
  final Set<int> _expandedTiles = {};

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

    final headers = {
      'Authorization': 'Bearer $token',
      'X-Medsoft-Token': token,
      'X-Tenant': server,
      'X-Token': Constants.xToken,
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
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

      if (response.statusCode == 401 || response.statusCode == 403) {
        _logOut();
      }
    }
  }

  void _logOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Tenant');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');
    await prefs.remove('scannedToken');
    await prefs.remove('tenantDomain');
    await prefs.remove('forgetUrl');

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
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

  Widget _buildMultilineHTMLText(String value) {
    if (value.isEmpty) {
      return Html(data: '');
    }

    return Html(data: value);
  }

  String _extractLine(String htmlValue, String keyword) {
    if (htmlValue.isEmpty) return '';
    final lines = htmlValue.split('<br>');
    for (final line in lines) {
      if (line.contains(keyword)) {
        return line.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }
    }
    return '';
  }

  String _extractReceivedShort(String htmlValue) {
    if (htmlValue.isEmpty) return '';
    final lines = htmlValue.split('<br>');
    for (final line in lines) {
      if (line.contains('Хүлээж авсан')) {
        final clean = line.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        final idx = clean.indexOf(RegExp(r'[А-ЯA-Z]\.'));
        return idx > 0 ? clean.substring(0, idx).trim() : clean;
      }
    }
    return '';
  }

  // --- NEW HELPER METHOD 1: Vuzleg Button ---
  Widget _buildUzlegButton(
    BuildContext context,
    String? roomId,
    String xMedsoftToken,
    double buttonFontSize,
  ) {
    final tenantDomain = sharedPreferencesData['tenantDomain'] ?? '';

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.remove_red_eye, size: 18),
          label: Text(
            "Үзлэг",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: buttonFontSize),
          ),
          onPressed: roomId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        url: '$tenantDomain/ambulanceApp/$roomId/$xMedsoftToken',
                        title: 'Форм тест',
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

  // --- NEW HELPER METHOD 2: Batalgaajuulah Button (Contains complex showDialog) ---
  Widget _buildBatalgaajuulahButton(
    BuildContext context,
    dynamic patient,
    bool arrived,
    double buttonFontSize,
  ) {
    final roomId = patient['roomId'];
    final phone = patient['patientPhone'];

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle, size: 18),
        label: Text(
          "Баталгаажуулах",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: buttonFontSize),
        ),
        onPressed: arrived
            ? () async {
                if (roomId == null || phone == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Room ID эсвэл утасны дугаар олдсонгүй'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }

                final rootContext = context;

                showDialog(
                  context: rootContext,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Үзлэг баталгаажуулах",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          SizedBox(height: 8),
                          Divider(thickness: 1),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Icon(Icons.phone_iphone, color: Colors.cyan),
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
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: Colors.cyan.withOpacity(0.4),
                              elevation: 8,
                            ),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();

                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('X-Medsoft-Token') ?? '';
                              final tenant = prefs.getString('X-Tenant') ?? '';

                              final uri = Uri.parse(
                                '${Constants.appUrl}/room/done_request_app?roomId=$roomId',
                              );

                              try {
                                final response = await http.get(
                                  uri,
                                  headers: {
                                    'X-Medsoft-Token': token,
                                    'X-Tenant': tenant,
                                    'X-Token': Constants.xToken,
                                  },
                                );

                                if (response.statusCode == 200) {
                                  debugPrint('done_request success: ${response.body}');
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text(
                                        'Иргэний апп руу хүсэлт илгээгдлээ',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  );
                                } else {
                                  debugPrint(
                                    'done_request failed: ${response.statusCode} ${response.body} ',
                                  );
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(content: Text('Амжилтгүй: ${response.statusCode}')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('API error: $e');
                                ScaffoldMessenger.of(
                                  rootContext,
                                ).showSnackBar(const SnackBar(content: Text('Алдаа гарлаа')));
                              }
                            },
                            child: const Text(
                              "Иргэний аппликейшн руу баталгаажуулах хүсэлт илгээх",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: const [
                              Icon(Icons.message, color: Colors.orange),
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
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: Colors.orange.withOpacity(0.4),
                              elevation: 8,
                            ),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();

                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('X-Medsoft-Token') ?? '';
                              // This was hardcoded to 'staging' in the previous inlined code
                              const tenant = 'staging';

                              final uri = Uri.parse(
                                '${Constants.appUrl}/room/done_request_otp?roomId=$roomId',
                              );

                              try {
                                final response = await http.get(
                                  uri,
                                  headers: {
                                    'X-Medsoft-Token': token,
                                    'X-Tenant': tenant,
                                    'X-Token': Constants.xToken,
                                  },
                                );

                                if (response.statusCode == 200 || response.statusCode == 429) {
                                  debugPrint(' done_request_otp success: ${response.body}');
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    const SnackBar(
                                      content: Text('Иргэний утас руу OTP илгээгдлээ'),
                                    ),
                                  );

                                  final TextEditingController otpController =
                                      TextEditingController();

                                  showDialog(
                                    context: rootContext,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('OTP оруулах'),
                                        content: TextField(
                                          controller: otpController,
                                          keyboardType: TextInputType.number,
                                          maxLength: 6,
                                          decoration: const InputDecoration(
                                            hintText: '6 оронтой OTP',
                                            counterText: '',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Буцах'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final otp = otpController.text.trim();

                                              if (otp.length == 6) {
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
                                                    body: jsonEncode({
                                                      'roomId': roomId,
                                                      'otp': otp,
                                                    }),
                                                  );

                                                  if (doneResponse.statusCode == 200) {
                                                    Navigator.of(context).pop();
                                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(' Амжилттай баталгаажлаа'),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'OTP амжилтгүй: ${doneResponse.statusCode}',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  debugPrint('Finalization error: $e');
                                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Баталгаажуулах үед алдаа гарлаа',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('OTP 6 оронтой байх ёстой.'),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Баталгаажуулах'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  debugPrint(
                                    'done_request_otp failed: ${response.statusCode} ${response.body}',
                                  );
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(
                                      content: Text('OTP илгээх амжилтгүй: ${response.statusCode}'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('API error: $e');
                                ScaffoldMessenger.of(
                                  rootContext,
                                ).showSnackBar(const SnackBar(content: Text('Алдаа гарлаа')));
                              }
                            },
                            child: const Text(
                              "Иргэний утас руу OTP илгээх",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prefs = snapshot.data!;
        final xMedsoftToken = prefs.getString('X-Medsoft-Token') ?? '';
        final tenantDomain = prefs.getString('tenantDomain') ?? '';

        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

        return Scaffold(
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final roomId = patient['roomId'];
                    final arrived = patient['arrived'] ?? false;
                    final distance = patient['totalDistance'] ?? '';
                    final duration = patient['distotalDistancetance'] ?? '';
                    final patientPhone = patient['patientPhone'] ?? '';
                    final patientData = patient['data'] ?? {};
                    final values = patientData['values'] ?? {};

                    String getValue(String key) {
                      if (values[key] != null && values[key]['value'] != null) {
                        return values[key]['value'] as String;
                      }
                      return '';
                    }

                    final patientName = patientData['patientName'] ?? '';
                    final patientRegNo = patientData['patientRegNo'] ?? '';
                    final patientGender = patientData['patientGender'] ?? '';

                    final reportedCitizen = getValue('reportedCitizen');
                    final received = getValue('received');
                    final type = getValue('type');
                    final time = getValue('time');
                    final ambulanceTeam = getValue('ambulanceTeam');

                    final address = _extractLine(reportedCitizen, 'Хаяг');
                    final receivedShort = _extractReceivedShort(received);

                    final isExpanded = _expandedTiles.contains(index);

                    final screenWidth = MediaQuery.of(context).size.width;
                    // Define the threshold for "narrow screen" (iPhone portrait)
                    final isNarrowScreen = screenWidth < 500;
                    // Define the threshold for "wide screen" (iPad/Landscape) for font size
                    final isWideScreen = screenWidth >= 600;

                    // Set alignment: start for narrow, end for wide
                    final mainAxisAlignment = isNarrowScreen
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center;

                    // Set font size: smaller for the tight narrow screen layout
                    final buttonFontSize = isWideScreen ? 16.0 : 11.5;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isTablet ? 600 : 700),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Container(
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                key: PageStorageKey(index),
                                initiallyExpanded: false,
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 1,
                                ),
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedTiles.add(index);
                                    } else {
                                      _expandedTiles.remove(index);
                                    }
                                  });
                                },
                                title: Text(
                                  patientPhone,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isExpanded && address.isNotEmpty)
                                      Text(address, overflow: TextOverflow.ellipsis, maxLines: 1),
                                    if (!isExpanded && receivedShort.isNotEmpty)
                                      Text(
                                        receivedShort,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: EdgeInsets.only(right: isNarrowScreen ? 0 : 100.0),
                                      child: Row(
                                        mainAxisAlignment: mainAxisAlignment,
                                        children: [
                                          // Button 1: Үзлэг (40% on narrow, content-sized on wide)
                                          isNarrowScreen
                                              ? Expanded(
                                                  flex: 4,
                                                  child: _buildUzlegButton(
                                                    context,
                                                    roomId,
                                                    xMedsoftToken,
                                                    buttonFontSize,
                                                  ),
                                                )
                                              : Expanded(
                                                  flex: 5,
                                                  child: _buildUzlegButton(
                                                    context,
                                                    roomId,
                                                    xMedsoftToken,
                                                    buttonFontSize,
                                                  ),
                                                ),

                                          const SizedBox(width: 8),

                                          // Button 2: Баталгаажуулах (60% on narrow, content-sized on wide)
                                          isNarrowScreen
                                              ? Expanded(
                                                  flex: 6,
                                                  child: _buildBatalgaajuulahButton(
                                                    context,
                                                    patient,
                                                    arrived,
                                                    buttonFontSize,
                                                  ),
                                                )
                                              : Expanded(
                                                  flex: 5,
                                                  child: _buildBatalgaajuulahButton(
                                                    context,
                                                    patient,
                                                    arrived,
                                                    buttonFontSize,
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                childrenPadding: const EdgeInsets.all(16.0),
                                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Иргэн:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Html(
                                    data:
                                        '$patientName | $patientRegNo<br>$patientPhone<br>Хүйс: $patientGender',
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Дуудлага:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  _buildMultilineHTMLText(reportedCitizen),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Хүлээж авсан:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  _buildMultilineHTMLText(received),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Ангилал:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  _buildMultilineHTMLText(type),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Дуудлагын цаг:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  _buildMultilineHTMLText(time),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'ТТ-ийн баг:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  _buildMultilineHTMLText(ambulanceTeam),
                                  const SizedBox(height: 5),
                                  if (arrived) ...[
                                    Text("Distance: ${distance ?? 'N/A'} km"),
                                    Text("Duration: ${duration ?? 'N/A'}"),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
