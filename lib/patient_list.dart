import 'dart:async';
import 'dart:convert';

import 'package:medsoft_doctor/api/map_dao.dart';
import 'package:medsoft_doctor/login.dart';
import 'package:medsoft_doctor/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => PatientListScreenState();
}

class PatientListScreenState extends State<PatientListScreen> {
  List<dynamic> patients = [];
  List<dynamic> filteredPatients = [];

  bool isLoading = true;
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};
  Timer? _refreshTimer;
  final Set<int> _expandedTiles = {};
  final _mapDAO = MapDAO();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPatients(initialLoad: true);
    _loadSharedPreferencesData();

    _searchController.addListener(_filterPatients);

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
    _searchController.removeListener(_filterPatients);
    _searchController.dispose();
    super.dispose();
  }

  // --- CORRECTED Filtering logic ---
  void _filterPatients() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        // If the query is empty, show the full list
        filteredPatients = patients;
      } else {
        // Filter based on patientPhone, patientName, or patientRegNo
        filteredPatients = patients.where((patient) {
          // Access patientPhone and safely convert to string
          final String patientPhone = patient['patientPhone']?.toString().toLowerCase() ?? '';

          // Safely cast 'data' to Map if possible, otherwise null
          final Map<String, dynamic>? patientData = patient['data'] is Map
              ? patient['data'] as Map<String, dynamic>
              : null;

          // Access nested fields, safely convert to string
          final String patientName = patientData?['patientName']?.toString().toLowerCase() ?? '';
          final String patientRegNo = patientData?['patientRegNo']?.toString().toLowerCase() ?? '';

          // Check if the query is contained in any of the fields
          return patientPhone.contains(query) ||
              patientName.contains(query) ||
              patientRegNo.contains(query);
        }).toList();
      }
    });
  }

  Future<void> fetchPatients({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => isLoading = true);
    }

    // final prefs = await SharedPreferences.getInstance();
    // final token = prefs.getString('X-Medsoft-Token') ?? '';
    // final server = prefs.getString('X-Tenant') ?? '';

    // final uri = Uri.parse('${Constants.appUrl}/room/get/driver');

    // final headers = {
    //   'Authorization': 'Bearer $token',
    //   'X-Medsoft-Token': token,
    //   'X-Tenant': server,
    //   'X-Token': Constants.xToken,
    // };

    // final response = await http.get(uri, headers: headers);
    final response = await _mapDAO.getPatientsListAmbulance();

    if (response.statusCode == 200) {
      final json = response.data;
      // const JsonEncoder encoder = JsonEncoder.withIndent('  ');

      // final String prettyJson = response.data != null ? encoder.convert(response.data) : 'null';

      //       final String fullLogMessage =
      //           '''
      // ############################################
      // ### FULL API RESPONSE (waitQR) ###

      // Status Code: ${response.statusCode}
      // Success: ${response.success}
      // Message: ${response.message}
      // --- Data (Pretty JSON) ---
      // $prettyJson
      // ############################################
      // ''';
      // debugPrint(fullLogMessage, wrapWidth: 1024);
      if (response.success == true) {
        setState(() {
          patients = json as List;
          _filterPatients();
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
    prefs.clear();

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
        padding: const EdgeInsets.all(5),
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
                        url: '$tenantDomain/request/AmbulanceRequest/$roomId/$xMedsoftToken',
                        title: 'Түргэн тусламж',
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
      child: Padding(
        padding: const EdgeInsets.all(5),
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

                                // final prefs = await SharedPreferences.getInstance();
                                // final token = prefs.getString('X-Medsoft-Token') ?? '';
                                // final tenant = prefs.getString('X-Tenant') ?? '';

                                // final uri = Uri.parse(
                                //   '${Constants.appUrl}/room/done_request_app?roomId=$roomId',
                                // );

                                try {
                                  // final response = await http.get(
                                  //   uri,
                                  //   headers: {
                                  //     'X-Medsoft-Token': token,
                                  //     'X-Tenant': tenant,
                                  //     'X-Token': Constants.xToken,
                                  //   },
                                  // );
                                  final response = await _mapDAO.requestDoneByApp(roomId);
                                  if (response.success == true) {
                                    // debugPrint('done_request success: ${response.message}');
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
                                    // debugPrint(
                                    //   'done_request failed: ${response.statusCode} ${response.message} ',
                                    // );
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

                                // final prefs = await SharedPreferences.getInstance();
                                // final token = prefs.getString('X-Medsoft-Token') ?? '';
                                // This was hardcoded to 'staging' in the previous inlined code
                                // const tenant = 'staging';

                                // final uri = Uri.parse(
                                //   '${Constants.appUrl}/room/done_request_otp?roomId=$roomId',
                                // );

                                try {
                                  // final response = await http.get(
                                  //   uri,
                                  //   headers: {
                                  //     'X-Medsoft-Token': token,
                                  //     'X-Tenant': tenant,
                                  //     'X-Token': Constants.xToken,
                                  //   },
                                  // );
                                  final response = await _mapDAO.requestDoneByOTP(roomId);

                                  if (response.success == true) {
                                    // debugPrint(' done_request_otp success: ${response.success}');
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
                                                    // final doneUri = Uri.parse(
                                                    //   '${Constants.appUrl}/room/done',
                                                    // );

                                                    // final doneResponse = await http.post(
                                                    //   doneUri,
                                                    //   headers: {
                                                    //     'Content-Type': 'application/json',
                                                    //     'X-Medsoft-Token': token,
                                                    //     'X-Tenant': tenant,
                                                    //     'X-Token': Constants.xToken,
                                                    //   },
                                                    //   body: jsonEncode({
                                                    //     'roomId': roomId,
                                                    //     'otp': otp,
                                                    //   }),
                                                    // );
                                                    final doneResponse = await _mapDAO.doneByOTP({
                                                      'roomId': roomId,
                                                      'otp': otp,
                                                    });

                                                    if (doneResponse.success) {
                                                      Navigator.of(context).pop();
                                                      ScaffoldMessenger.of(
                                                        rootContext,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(' Амжилттай баталгаажлаа'),
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                        rootContext,
                                                      ).showSnackBar(
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
                                      'done_request_otp failed: ${response.statusCode} ${response.message}',
                                    );
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'OTP илгээх амжилтгүй: ${response.statusCode}',
                                        ),
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

                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text("Буцах", style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      );
                    },
                  );
                }
              : null,
        ),
      ),
    );
  }

  // --- NEW HELPER METHOD 3: Em Button ---
  Widget _buildEmButton(
    BuildContext context,
    String? roomId,
    String xMedsoftToken,
    double buttonFontSize,
  ) {
    // Ensure sharedPreferencesData is accessible or passed if it's not a stateful widget's member
    // Assuming 'tenantDomain' is accessible here, as in _buildUzlegButton
    final String tenantDomain = sharedPreferencesData['tenantDomain'] ?? '';

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.medication, size: 18), // Used a relevant icon
          label: Text(
            "Эм",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: buttonFontSize),
          ),
          onPressed: roomId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        // NEW URL: for requesting medicine
                        url:
                            '$tenantDomain/requestMedicine/AmbulanceRequest/$roomId/$xMedsoftToken',
                        title: 'Эм хүсэлт', // New title for the webview screen
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

  // --- NEW WIDGET: Search Bar ---
  Widget _buildSearchBar(bool isTablet) {
    const Color customTeal = Color(0xFF00CCCC);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 600 : 700),
          child: Material(
            elevation: 2.0, // Set the desired elevation
            borderRadius: BorderRadius.circular(12), // Match the TextField's border radius
            shadowColor: customTeal.withOpacity(0.5),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                // Using the detailed label from your request
                labelText: 'Утас, Нэр, Регистрийн дугаараар хайх',
                hintText: 'Хайлт...',
                prefixIcon: const Icon(Icons.search, color: customTeal), // Optional: set icon color
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: customTeal,
                        ), // Optional: set clear icon color
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                // --- UPDATED BORDER CONFIGURATION ---
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: customTeal), // Default state color
                ),
                // Ensure border color is set when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: customTeal,
                    width: 2.0,
                  ), // Focus state color and thickness
                ),
                // Optional: Set a subtle color for the unfocused border
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: customTeal,
                    width: 1.0,
                  ), // Enabled state color
                ),
                // ------------------------------------
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
              ),
              onChanged: (value) {
                _filterPatients();
              },
            ),
          ),
        ),
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
        // final tenantDomain = prefs.getString('tenantDomain') ?? '';

        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

        return Scaffold(
          body: Column(
            children: [
              _buildSearchBar(isTablet),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    // Check if search has results
                    : filteredPatients.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          'Хайсан үгээр өвчтөн олдсонгүй',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    // Check if the original list is empty (no data at all)
                    : filteredPatients.isEmpty
                    ? const Center(
                        child: Text(
                          'Өвчтөний жагсаалт хоосон байна.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        // key: PageStorageKey('PatientListScrollKey'),
                        padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                        // Use filteredPatients list
                        itemCount: filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          final roomId = patient['roomId'];
                          final arrived = patient['arrived'] ?? false;
                          final distance = patient['totalDistance'] ?? 'N/A';
                          final duration = patient['totalDuration'] ?? 'N/A';
                          final patientPhone = patient['patientPhone'] ?? '';
                          final patientData = patient['data'] ?? {};
                          final values = patientData != {} ? patientData['values'] : null;

                          String getValue(String key) {
                            if (values != null &&
                                values[key] != null &&
                                values[key]['value'] != null) {
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

                          final isExpandedCurrent = _expandedTiles.contains(index);

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
                          // final patientId = patient['_id']; // Not used

                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: isTablet ? 600 : 700),
                              child: Card(
                                color: Colors.white,
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
                                      // key: PageStorageKey<String>(patients.elementAt(index)['_id']),
                                      // key: PageStorageKey(patientId),
                                      initiallyExpanded: isExpandedCurrent,
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
                                          if (!isExpandedCurrent && address.isNotEmpty)
                                            Text(
                                              address,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          if (!isExpandedCurrent && receivedShort.isNotEmpty)
                                            Text(
                                              receivedShort,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            // REMOVE THE RIGHT PADDING or adjust it if necessary
                                            // padding: EdgeInsets.only(right: isNarrowScreen ? 0 : 100.0),
                                            padding: const EdgeInsets.all(
                                              0,
                                            ), // Removed right padding
                                            child: SingleChildScrollView(
                                              // WRAP with SingleChildScrollView
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisAlignment: mainAxisAlignment,
                                                children: [
                                                  // Button 1: Үзлэг
                                                  // REMOVED Expanded, ADDED SizedBox with fixed width
                                                  SizedBox(
                                                    width: isTablet
                                                        ? 130
                                                        : 110, // Increased fixed width for bigger buttons
                                                    child: _buildUzlegButton(
                                                      context,
                                                      roomId,
                                                      xMedsoftToken,
                                                      buttonFontSize,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 0),

                                                  // Button 2: Баталгаажуулах
                                                  // REMOVED Expanded, ADDED SizedBox with fixed width
                                                  SizedBox(
                                                    width: isTablet
                                                        ? 220
                                                        : 190, // Increased fixed width for bigger buttons
                                                    child: _buildBatalgaajuulahButton(
                                                      context,
                                                      patient,
                                                      arrived,
                                                      buttonFontSize,
                                                    ),
                                                  ),

                                                  // Space for your NEW Button
                                                  const SizedBox(width: 0),

                                                  // Button 3: Эм
                                                  // REMOVED Expanded, ADDED SizedBox with fixed width
                                                  SizedBox(
                                                    width: isTablet
                                                        ? 110
                                                        : 100, // Increased fixed width for bigger buttons
                                                    child: _buildEmButton(
                                                      context,
                                                      roomId,
                                                      xMedsoftToken,
                                                      buttonFontSize,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      childrenPadding: const EdgeInsets.all(16.0),
                                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Иргэн:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Html(
                                          data:
                                              'Нэр: $patientName<br>РД: $patientRegNo<br>Утас: $patientPhone<br>Хүйс: ' +
                                              (patientGender == 'MALE' || patientGender == 'FEMALE'
                                                  ? patientGender
                                                  : 'Тодорхойгүй'),
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
                                          Text("Distance: ${(distance as String)}"),
                                          Text("Duration: ${(duration as String)}"),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
