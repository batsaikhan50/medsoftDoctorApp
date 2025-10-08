import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doctor_app/login.dart';
import 'package:doctor_app/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:marquee/marquee.dart'; // Add in pubspec.yaml: marquee: ^2.3.0
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

  /// Helper to render HTML values properly (or just plain if no HTML)
  Widget _buildMultilineHTMLText(String value) {
    if (value.isEmpty) {
      // Ensure spacing is preserved so layout doesn't collapse
      return Html(data: '');
    }

    return Html(data: value);
  }

  /// Extract a single line containing a keyword from an HTML-ish string
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

  /// Cut off receiver name part after Хүлээж авсан: line (rough heuristic)
  String _extractReceivedShort(String htmlValue) {
    if (htmlValue.isEmpty) return '';
    final lines = htmlValue.split('<br>');
    for (final line in lines) {
      if (line.contains('Хүлээж авсан')) {
        final clean = line.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        // Example: "Хүлээж авсан: 2025.09.0109:45Э.Уранцэцэг" → cut name part
        final idx = clean.indexOf(
          RegExp(r'[А-ЯA-Z]\.'),
        ); // name likely starts with capital + dot
        return idx > 0 ? clean.substring(0, idx).trim() : clean;
      }
    }
    return '';
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

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Container(
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isExpanded && address.isNotEmpty)
                                  Text(
                                    address,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                if (!isExpanded && receivedShort.isNotEmpty)
                                  Text(
                                    receivedShort,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: arrived
                                            ? () {
                                                /* Arrived logic */
                                              }
                                            : null,
                                        child: const Text(
                                          "Үзлэг баталгаажуулах",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => WebViewScreen(
                                                url:
                                                    '${tenantDomain}/ambulanceApp/${roomId}/${xMedsoftToken}',
                                                // 'https://100.100.10.100:5173/ambulanceApp/${roomId}/${xMedsoftToken}',
                                                title: 'Форм тест',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text("Ambulance"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.all(16.0),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Only show expanded content here
                              const Text(
                                'Иргэн:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Html(
                                data:
                                    '$patientName | $patientRegNo<br>$patientPhone<br>Хүйс: $patientGender',
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Дуудлага:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildMultilineHTMLText(reportedCitizen),
                              const SizedBox(height: 5),
                              const Text(
                                'Хүлээж авсан:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildMultilineHTMLText(received),
                              const SizedBox(height: 5),
                              const Text(
                                'Ангилал:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildMultilineHTMLText(type),
                              const SizedBox(height: 5),
                              const Text(
                                'Дуудлагын цаг:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildMultilineHTMLText(time),
                              const SizedBox(height: 5),
                              const Text(
                                'ТТ-ийн баг:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
                    );
                  },
                ),
        );
      },
    );
  }
}
