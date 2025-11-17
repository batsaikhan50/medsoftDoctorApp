import 'dart:async';
import 'dart:convert';

import 'package:doctor_app/api/auth_dao.dart';
import 'package:doctor_app/api/map_dao.dart';
import 'package:doctor_app/login.dart';
import 'package:doctor_app/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'package:intl/intl.dart';

class EmergencyListScreen extends StatefulWidget {
  const EmergencyListScreen({super.key});

  @override
  State<EmergencyListScreen> createState() => EmergencyListScreenState();
}

class EmergencyListScreenState extends State<EmergencyListScreen> {
  List<dynamic> patients = [];
  bool isLoading = true;
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};
  Timer? _refreshTimer;
  final Set<int> _expandedTiles = {};
  final _mapDAO = MapDAO();

  DateTime subtractMonths(DateTime date, int monthsToSubtract) {
    int newMonth = date.month - monthsToSubtract;
    int newYear = date.year;

    // Handle month wrap-around (e.g., if current month is Jan and you subtract 2 months)
    while (newMonth <= 0) {
      newMonth += 12; // Add 12 months
      newYear -= 1; // Subtract 1 year
    }

    // Use the new year, new month, and original day/time components
    // Note: Dart's DateTime constructor automatically handles month/day overflow
    // (e.g., trying to set day 30 in February) by moving to the next month,
    // but for a simple "subtract 2 months" this logic is simpler and safer.
    return DateTime(
      newYear,
      newMonth,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  // Example usage:
  DateTime _dateTo = DateTime.now(); // e.g., Nov 17
  late DateTime _dateFrom = subtractMonths(_dateTo, 2); // -> Sep 17

  // DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 60));
  // DateTime _dateTo = DateTime.now();

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

  Future<void> _pickDate({required bool isFrom}) async {
    DateTime initial = isFrom ? _dateFrom : _dateTo;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
        // refresh data
        fetchPatients();
      });
    }
  }

  Future<void> fetchPatients({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => isLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('X-Medsoft-Token') ?? '';
    final server = prefs.getString('X-Tenant') ?? '';

    // final uri = Uri.parse('${Constants.appUrl}/room/get/driver');

    // final headers = {
    //   'Authorization': 'Bearer $token',
    //   'X-Medsoft-Token': token,
    //   'X-Tenant': server,
    //   'X-Token': Constants.xToken,
    // };

    // final response = await http.get(uri, headers: headers);
    final body = ["Opened", "Closed"];

    String dateFrom =
        "${_dateFrom.year}.${_dateFrom.month.toString().padLeft(2, '0')}.${_dateFrom.day.toString().padLeft(2, '0')}";
    String dateTo =
        "${_dateTo.year}.${_dateTo.month.toString().padLeft(2, '0')}.${_dateTo.day.toString().padLeft(2, '0')}";

    final response = await _mapDAO.getPatientsListEmergency(body, dateFrom, dateTo);

    if (response.statusCode == 200) {
      final json = response.data;
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');

      final String prettyJson = response.data != null ? encoder.convert(response.data) : 'null';

      final String fullLogMessage =
          '''
############################################
### FULL API RESPONSE (waitQR) ###

Status Code: ${response.statusCode}
Success: ${response.success} 
Message: ${response.message}
--- Data (Pretty JSON) ---
$prettyJson
############################################
''';
      // debugPrint(fullLogMessage, wrapWidth: 1024);
      if (response.success == true) {
        setState(() {
          patients = json as List;
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
    String? emergencyRequestId,
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
          onPressed: emergencyRequestId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        url:
                            '$tenantDomain/request/EmergencyRequest/$emergencyRequestId/$xMedsoftToken',
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
  // Widget _buildBatalgaajuulahButton(
  //   BuildContext context,
  //   dynamic patient,
  //   bool arrived,
  //   double buttonFontSize,
  // ) {
  //   final roomId = patient['roomId'];
  //   final phone = patient['patientPhone'];

  //   return SizedBox(
  //     height: 48,
  //     child: ElevatedButton.icon(
  //       icon: const Icon(Icons.check_circle, size: 18),
  //       label: Text(
  //         "Баталгаажуулах",
  //         textAlign: TextAlign.center,
  //         style: TextStyle(fontSize: buttonFontSize),
  //       ),
  //       onPressed: arrived
  //           ? () async {
  //               if (roomId == null || phone == null) {
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   const SnackBar(
  //                     content: Text('Room ID эсвэл утасны дугаар олдсонгүй'),
  //                     duration: Duration(seconds: 1),
  //                   ),
  //                 );
  //                 return;
  //               }

  //               final rootContext = context;

  //               showDialog(
  //                 context: rootContext,
  //                 builder: (BuildContext dialogContext) {
  //                   return AlertDialog(
  //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //                     titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
  //                     title: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: const [
  //                         Text(
  //                           "Үзлэг баталгаажуулах",
  //                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
  //                         ),
  //                         SizedBox(height: 8),
  //                         Divider(thickness: 1),
  //                       ],
  //                     ),
  //                     content: Column(
  //                       mainAxisSize: MainAxisSize.min,
  //                       crossAxisAlignment: CrossAxisAlignment.stretch,
  //                       children: [
  //                         const SizedBox(height: 8),
  //                         Row(
  //                           children: const [
  //                             Icon(Icons.phone_iphone, color: Colors.cyan),
  //                             SizedBox(width: 8),
  //                             Expanded(
  //                               child: Text(
  //                                 "Хэрвээ дуудлага өгсөн иргэн Medsoft аппликейшн ашигладаг бол:",
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 8),
  //                         ElevatedButton(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: Colors.white,
  //                             padding: const EdgeInsets.symmetric(vertical: 14),
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(12),
  //                             ),
  //                             shadowColor: Colors.cyan.withOpacity(0.4),
  //                             elevation: 8,
  //                           ),
  //                           onPressed: () async {
  //                             Navigator.of(dialogContext).pop();

  //                             // final prefs = await SharedPreferences.getInstance();
  //                             // final token = prefs.getString('X-Medsoft-Token') ?? '';
  //                             // final tenant = prefs.getString('X-Tenant') ?? '';

  //                             // final uri = Uri.parse(
  //                             //   '${Constants.appUrl}/room/done_request_app?roomId=$roomId',
  //                             // );

  //                             try {
  //                               // final response = await http.get(
  //                               //   uri,
  //                               //   headers: {
  //                               //     'X-Medsoft-Token': token,
  //                               //     'X-Tenant': tenant,
  //                               //     'X-Token': Constants.xToken,
  //                               //   },
  //                               // );
  //                               final response = await _mapDAO.requestDoneByApp(roomId);
  //                               if (response.success == true) {
  //                                 debugPrint('done_request success: ${response.message}');
  //                                 ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                   const SnackBar(
  //                                     backgroundColor: Colors.green,
  //                                     content: Text(
  //                                       'Иргэний апп руу хүсэлт илгээгдлээ',
  //                                       style: TextStyle(color: Colors.white),
  //                                     ),
  //                                   ),
  //                                 );
  //                               } else {
  //                                 debugPrint(
  //                                   'done_request failed: ${response.statusCode} ${response.message} ',
  //                                 );
  //                                 ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                   SnackBar(content: Text('Амжилтгүй: ${response.statusCode}')),
  //                                 );
  //                               }
  //                             } catch (e) {
  //                               debugPrint('API error: $e');
  //                               ScaffoldMessenger.of(
  //                                 rootContext,
  //                               ).showSnackBar(const SnackBar(content: Text('Алдаа гарлаа')));
  //                             }
  //                           },
  //                           child: const Text(
  //                             "Иргэний аппликейшн руу баталгаажуулах хүсэлт илгээх",
  //                             textAlign: TextAlign.center,
  //                             style: TextStyle(color: Colors.black),
  //                           ),
  //                         ),
  //                         const SizedBox(height: 20),
  //                         Row(
  //                           children: const [
  //                             Icon(Icons.message, color: Colors.orange),
  //                             SizedBox(width: 8),
  //                             Expanded(
  //                               child: Text(
  //                                 "Хэрвээ дуудлага өгсөн иргэн Medsoft аппликейшн ашигладаггүй бол:",
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 8),
  //                         ElevatedButton(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: Colors.white,
  //                             padding: const EdgeInsets.symmetric(vertical: 14),
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(12),
  //                             ),
  //                             shadowColor: Colors.orange.withOpacity(0.4),
  //                             elevation: 8,
  //                           ),
  //                           onPressed: () async {
  //                             Navigator.of(dialogContext).pop();

  //                             // final prefs = await SharedPreferences.getInstance();
  //                             // final token = prefs.getString('X-Medsoft-Token') ?? '';
  //                             // This was hardcoded to 'staging' in the previous inlined code
  //                             // const tenant = 'staging';

  //                             // final uri = Uri.parse(
  //                             //   '${Constants.appUrl}/room/done_request_otp?roomId=$roomId',
  //                             // );

  //                             try {
  //                               // final response = await http.get(
  //                               //   uri,
  //                               //   headers: {
  //                               //     'X-Medsoft-Token': token,
  //                               //     'X-Tenant': tenant,
  //                               //     'X-Token': Constants.xToken,
  //                               //   },
  //                               // );
  //                               final response = await _mapDAO.requestDoneByOTP(roomId);

  //                               if (response.success == true) {
  //                                 debugPrint(' done_request_otp success: ${response.success}');
  //                                 ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                   const SnackBar(
  //                                     content: Text('Иргэний утас руу OTP илгээгдлээ'),
  //                                   ),
  //                                 );

  //                                 final TextEditingController otpController =
  //                                     TextEditingController();

  //                                 showDialog(
  //                                   context: rootContext,
  //                                   barrierDismissible: false,
  //                                   builder: (BuildContext context) {
  //                                     return AlertDialog(
  //                                       title: const Text('OTP оруулах'),
  //                                       content: TextField(
  //                                         controller: otpController,
  //                                         keyboardType: TextInputType.number,
  //                                         maxLength: 6,
  //                                         decoration: const InputDecoration(
  //                                           hintText: '6 оронтой OTP',
  //                                           counterText: '',
  //                                         ),
  //                                       ),
  //                                       actions: [
  //                                         TextButton(
  //                                           onPressed: () {
  //                                             Navigator.of(context).pop();
  //                                           },
  //                                           child: const Text('Буцах'),
  //                                         ),
  //                                         ElevatedButton(
  //                                           onPressed: () async {
  //                                             final otp = otpController.text.trim();

  //                                             if (otp.length == 6) {
  //                                               try {
  //                                                 // final doneUri = Uri.parse(
  //                                                 //   '${Constants.appUrl}/room/done',
  //                                                 // );

  //                                                 // final doneResponse = await http.post(
  //                                                 //   doneUri,
  //                                                 //   headers: {
  //                                                 //     'Content-Type': 'application/json',
  //                                                 //     'X-Medsoft-Token': token,
  //                                                 //     'X-Tenant': tenant,
  //                                                 //     'X-Token': Constants.xToken,
  //                                                 //   },
  //                                                 //   body: jsonEncode({
  //                                                 //     'roomId': roomId,
  //                                                 //     'otp': otp,
  //                                                 //   }),
  //                                                 // );
  //                                                 final doneResponse = await _mapDAO.doneByOTP({
  //                                                   'roomId': roomId,
  //                                                   'otp': otp,
  //                                                 });

  //                                                 if (doneResponse.success) {
  //                                                   Navigator.of(context).pop();
  //                                                   ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                                     const SnackBar(
  //                                                       content: Text(' Амжилттай баталгаажлаа'),
  //                                                     ),
  //                                                   );
  //                                                 } else {
  //                                                   ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                                     SnackBar(
  //                                                       content: Text(
  //                                                         'OTP амжилтгүй: ${doneResponse.statusCode}',
  //                                                       ),
  //                                                     ),
  //                                                   );
  //                                                 }
  //                                               } catch (e) {
  //                                                 debugPrint('Finalization error: $e');
  //                                                 ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                                   const SnackBar(
  //                                                     content: Text(
  //                                                       'Баталгаажуулах үед алдаа гарлаа',
  //                                                     ),
  //                                                   ),
  //                                                 );
  //                                               }
  //                                             } else {
  //                                               ScaffoldMessenger.of(context).showSnackBar(
  //                                                 const SnackBar(
  //                                                   content: Text('OTP 6 оронтой байх ёстой.'),
  //                                                 ),
  //                                               );
  //                                             }
  //                                           },
  //                                           child: const Text('Баталгаажуулах'),
  //                                         ),
  //                                       ],
  //                                     );
  //                                   },
  //                                 );
  //                               } else {
  //                                 debugPrint(
  //                                   'done_request_otp failed: ${response.statusCode} ${response.message}',
  //                                 );
  //                                 ScaffoldMessenger.of(rootContext).showSnackBar(
  //                                   SnackBar(
  //                                     content: Text('OTP илгээх амжилтгүй: ${response.statusCode}'),
  //                                   ),
  //                                 );
  //                               }
  //                             } catch (e) {
  //                               debugPrint('API error: $e');
  //                               ScaffoldMessenger.of(
  //                                 rootContext,
  //                               ).showSnackBar(const SnackBar(content: Text('Алдаа гарлаа')));
  //                             }
  //                           },
  //                           child: const Text(
  //                             "Иргэний утас руу OTP илгээх",
  //                             textAlign: TextAlign.center,
  //                             style: TextStyle(color: Colors.black),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   );
  //                 },
  //               );
  //             }
  //           : null,
  //     ),
  //   );
  // }

  // --- NEW HELPER METHOD 3: Em Button ---
  Widget _buildEmButton(
    BuildContext context,
    String? emergencyRequestId,
    String xMedsoftToken,
    double buttonFontSize,
  ) {
    // Ensure sharedPreferencesData is accessible or passed if it's not a stateful widget's member
    // Assuming 'tenantDomain' is accessible here, as in _buildUzlegButton
    final tenantDomain = sharedPreferencesData['tenantDomain'] ?? '';

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
          onPressed: emergencyRequestId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        // NEW URL: for requesting medicine
                        url:
                            '$tenantDomain/requestMedicine/EmergencyRequest/$emergencyRequestId/$xMedsoftToken',
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
          body: Column(
            children: [
              const SizedBox(height: 12),
              // --- DATE PICKER BAR ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // date from
                  InkWell(
                    onTap: () => _pickDate(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        // Added subtle shadow for a button look
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                        // Removed the border/outline
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Added calendar icon
                          const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            "Эхлэх: ${_dateFrom.year}.${_dateFrom.month.toString().padLeft(2, '0')}.${_dateFrom.day.toString().padLeft(2, '0')}",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // date to
                  InkWell(
                    onTap: () => _pickDate(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        // Added subtle shadow for a button look
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                        // Removed the border/outline
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Added calendar icon
                          const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            "Дуусах: ${_dateTo.year}.${_dateTo.month.toString().padLeft(2, '0')}.${_dateTo.day.toString().padLeft(2, '0')}",
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 0),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        key: PageStorageKey('EmergencyListScrollKey'),
                        padding: const EdgeInsets.all(12.0),
                        itemCount: patients.length,

                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          debugPrint('Patient data: $patient');
                          // final roomId = patient['roomId'];
                          final emergencyRequestId = patient['id'];
                          final arrived = patient['arrived'] ?? false;
                          final distance = patient['totalDistance'] ?? '';
                          final duration = patient['distotalDistancetance'] ?? '';
                          final patientPhone = patient['patientPhone'] ?? '';
                          final values = patient['values'];

                          String getValue(String key) {
                            if (values != null &&
                                values[key] != null &&
                                values[key]['value'] != null) {
                              return values[key]['value'] as String;
                            }
                            return '';
                          }

                          String getCaption(String key) {
                            if (values != null &&
                                values[key] != null &&
                                values[key]['caption'] != null) {
                              return '${values[key]['caption'] as String}:';
                            }
                            return '';
                          }

                          final patientName = patient['patientName'] ?? '';
                          debugPrint('Patient Name: $patientName');
                          final patientRegNo = patient['patientRegNo'] ?? '';
                          final patientGender = patient['patientGender'] ?? '';
                          final patientCitizenStatus = patient['patientCitizenStatus'] ?? '';
                          // NEW: Extract age and ageDetail
                          final patientAge = patient['patientAge']?.toString() ?? '';
                          final patientAgeDetail = patient['patientAgeDetail'] ?? '';

                          // final reportedCitizen = patient('patientCitizenStatus');
                          // final receivedUserName = patient['receivedUserName'] ?? '';
                          // final receivedUserDate = patient['receivedUserDate'] ?? '';

                          // String formattedReceivedUserDate = '';
                          // if (receivedUserDate != null) {
                          //   // Convert from UTC to local time (optional, but often preferred for display)
                          //   final localDateTime = DateTime.parse(receivedUserDate).toLocal();

                          //   // Define the desired format: Year-Month-Day Hour:Minute (e.g., 2025-09-29 09:39)
                          //   final formatter = DateFormat('yyyy.MM.dd HH:mm');
                          //   formattedReceivedUserDate = formatter.format(localDateTime);
                          // }

                          // final type = getValue('type');
                          // final time = getValue('time');
                          // final ambulanceTeam = getValue('ambulanceTeam');

                          // final address = _extractLine(reportedCitizen, 'Хаяг');
                          // final receivedShort = _extractReceivedShort(received);

                          final receivedUser = getValue('receivedUser');
                          final receivedUserCaption = getCaption('receivedUser');
                          final nurse = getValue('nurse');
                          final nurseCaption = getCaption('nurse');
                          final nurseInspection = getValue('nurseInspection');
                          final nurseInspectionCaption = getCaption('nurseInspection');
                          final doctor = getValue('doctor');
                          final doctorCaption = getCaption('doctor');
                          final diagnosis = getValue('diagnosis');
                          final diagnosisCaption = getCaption('diagnosis');
                          final decision = getValue('decision');
                          final decisionCaption = getCaption('decision');
                          final blood = getValue('blood');
                          final bloodCaption = getCaption('blood');

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
                          final ageDisplay = patientCitizenStatus != 'Нярай'
                              ? '$patientAge нас' // Show just age for adults
                              : patientAgeDetail; // Show detail for non-adults

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
                                        patientName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!isExpanded && receivedUser.isNotEmpty)
                                            Text(
                                              receivedUser
                                                  .replaceAll('Нэр', 'Эмч') // rename Нэр → Эмч
                                                  .replaceAll("<br>", "\n") // break line
                                                  .replaceAllMapped(
                                                    // reorder lines: date first
                                                    RegExp(r'Эмч: (.*)\nОгноо: (.*)'),
                                                    (m) =>
                                                        'Хүлээн авсан огноо: ${m[2]}\nХүлээн авсан эмч: ${m[1]}',
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          // if (!isExpanded && receivedUserName.isNotEmpty)
                                          //   Text(
                                          //     'Эмч: $receivedUserName',
                                          //     overflow: TextOverflow.ellipsis,
                                          //     maxLines: 1,
                                          //   ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: EdgeInsets.only(
                                              right: isNarrowScreen ? 0 : 100.0,
                                            ),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisAlignment: mainAxisAlignment,
                                                children: [
                                                  // Button 1: Үзлэг (40% on narrow, content-sized on wide)
                                                  SizedBox(
                                                    width:
                                                        120, // Increased fixed width for bigger buttons
                                                    child: _buildUzlegButton(
                                                      context,
                                                      emergencyRequestId,
                                                      xMedsoftToken,
                                                      buttonFontSize,
                                                    ),
                                                  ),

                                                  //   const SizedBox(width: 8),

                                                  //   // Button 2: Баталгаажуулах (60% on narrow, content-sized on wide)
                                                  //   isNarrowScreen
                                                  //       ? Expanded(
                                                  //           flex: 6,
                                                  //           child: _buildBatalgaajuulahButton(
                                                  //             context,
                                                  //             patient,
                                                  //             arrived,
                                                  //             buttonFontSize,
                                                  //           ),
                                                  //         )
                                                  //       : Expanded(
                                                  //           flex: 5,
                                                  //           child: _buildBatalgaajuulahButton(
                                                  //             context,
                                                  //             patient,
                                                  //             arrived,
                                                  //             buttonFontSize,
                                                  //           ),
                                                  //         ),

                                                  // Button 3: Эм
                                                  // REMOVED Expanded, ADDED SizedBox with fixed width
                                                  SizedBox(
                                                    width:
                                                        100, // Increased fixed width for bigger buttons
                                                    child: _buildEmButton(
                                                      context,
                                                      emergencyRequestId,
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
                                              'Нэр: $patientName<br>РД: $patientRegNo<br>Нас: $ageDisplay<br>Хүйс: $patientGender',
                                        ),
                                        // const SizedBox(height: 5),
                                        // const Text(
                                        //   'Дуудлага:',
                                        //   style: TextStyle(
                                        //     fontSize: 16,
                                        //     fontWeight: FontWeight.bold,
                                        //   ),
                                        // ),
                                        // _buildMultilineHTMLText(reportedCitizen),
                                        const SizedBox(height: 5),
                                        Text(
                                          receivedUserCaption,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(receivedUser),
                                        const SizedBox(height: 5),
                                        Text(
                                          nurseCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(nurse),
                                        const SizedBox(height: 5),
                                        Text(
                                          nurseInspectionCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(nurseInspection),
                                        const SizedBox(height: 5),
                                        Text(
                                          doctorCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(doctor),
                                        const SizedBox(height: 5),
                                        Text(
                                          diagnosisCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(diagnosis),
                                        const SizedBox(height: 5),
                                        Text(
                                          decisionCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(decision),
                                        const SizedBox(height: 5),
                                        Text(
                                          bloodCaption,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        _buildMultilineHTMLText(blood),

                                        // const Text(
                                        //   'Ангилал:',
                                        //   style: TextStyle(
                                        //     fontSize: 16,
                                        //     fontWeight: FontWeight.bold,
                                        //   ),
                                        // ),
                                        // _buildMultilineHTMLText(type),
                                        // const SizedBox(height: 5),
                                        // const Text(
                                        //   'Дуудлагын цаг:',
                                        //   style: TextStyle(
                                        //     fontSize: 16,
                                        //     fontWeight: FontWeight.bold,
                                        //   ),
                                        // ),
                                        // _buildMultilineHTMLText(time),
                                        // const SizedBox(height: 5),
                                        // const Text(
                                        //   'ТТ-ийн баг:',
                                        //   style: TextStyle(
                                        //     fontSize: 16,
                                        //     fontWeight: FontWeight.bold,
                                        //   ),
                                        // ),
                                        // _buildMultilineHTMLText(ambulanceTeam),
                                        // const SizedBox(height: 5),
                                        // if (arrived) ...[
                                        //   Text("Distance: ${distance ?? 'N/A'} km"),
                                        //   Text("Duration: ${duration ?? 'N/A'}"),
                                        // ],
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
