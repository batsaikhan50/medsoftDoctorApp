import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:medsoft_doctor/api/map_dao.dart';
import 'package:medsoft_doctor/login.dart';
import 'package:medsoft_doctor/webview_screen.dart';
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
      if (mounted) {
        refreshPatients();
      } else {
        timer.cancel();
      }
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

  void _filterPatients() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredPatients = patients;
      } else {
        filteredPatients = patients.where((patient) {
          final String patientPhone = patient['patientPhone']?.toString().toLowerCase() ?? '';

          final Map<String, dynamic>? patientData = patient['data'] is Map
              ? patient['data'] as Map<String, dynamic>
              : null;

          final String patientName = patientData?['patientName']?.toString().toLowerCase() ?? '';
          final String patientRegNo = patientData?['patientRegNo']?.toString().toLowerCase() ?? '';

          return patientPhone.contains(query) ||
              patientName.contains(query) ||
              patientRegNo.contains(query);
        }).toList();
      }
    });
  }

  Future<void> fetchPatients({bool initialLoad = false}) async {
    if (!mounted) return;
    if (initialLoad && mounted) {
      setState(() => isLoading = true);
    } // Exit if the widget is disposed
    try {
      final response = await _mapDAO.getPatientsListAmbulance();

      // Check mounted again after the asynchronous network call
      if (!mounted) return;

      if (response.success) {
        final json = response.data!;
        setState(() {
          patients = json;
          isLoading = false;
        });
      } else {
        if (initialLoad) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      // Handle the SocketException to prevent the app from crashing
      debugPrint("Network error: $e");
      if (initialLoad && mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _logOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return; // Exit if the widget is disposed

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

    if (!mounted) return; // Check added here

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

                                try {
                                  final response = await _mapDAO.requestDoneByApp(roomId);

                                  if (!mounted) return; // ✅ Added mounted check

                                  if (response.statusCode == 401 || // ✅ Added 401/403 check
                                      response.statusCode == 403) {
                                    _logOut();
                                    return;
                                  }

                                  if (response.success == true) {
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
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(content: Text('Амжилтгүй: ${response.statusCode}')),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('API error: $e');
                                  if (!mounted) return; // ✅ Added mounted check
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

                                try {
                                  final response = await _mapDAO.requestDoneByOTP(roomId);

                                  if (!mounted) return;

                                  if (response.statusCode == 401 || // ✅ Added 401/403 check
                                      response.statusCode == 403) {
                                    _logOut();
                                    return;
                                  }

                                  if (response.success == true) {
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
                                                    final doneResponse = await _mapDAO.doneByOTP({
                                                      'roomId': roomId,
                                                      'otp': otp,
                                                    });

                                                    if (!mounted) return; // ✅ Added mounted check

                                                    if (doneResponse.statusCode ==
                                                            401 || // ✅ Added 401/403 check
                                                        doneResponse.statusCode == 403) {
                                                      _logOut();
                                                      return;
                                                    }

                                                    if (doneResponse.success) {
                                                      if (!mounted) return;
                                                      Navigator.of(context).pop();
                                                      ScaffoldMessenger.of(
                                                        rootContext,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(' Амжилттай баталгаажлаа'),
                                                        ),
                                                      );
                                                    } else {
                                                      if (!mounted) return;
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
                                                    if (!mounted) return; // ✅ Added mounted check
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
                                    if (!mounted) return; // ✅ Added mounted check
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
                                  if (!mounted) return; // ✅ Added mounted check
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

  Widget _buildEmButton(
    BuildContext context,
    String? roomId,
    String xMedsoftToken,
    double buttonFontSize,
  ) {
    final String tenantDomain = sharedPreferencesData['tenantDomain'] ?? '';

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.medication, size: 18),
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
                        url:
                            '$tenantDomain/requestMedicine/AmbulanceRequest/$roomId/$xMedsoftToken',
                        title: 'Эм хүсэлт',
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    const Color customTeal = Color(0xFF00CCCC);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 600 : 700),
          child: Material(
            elevation: 2.0,
            borderRadius: BorderRadius.circular(12),
            shadowColor: customTeal.withOpacity(0.5),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,

                labelText: 'Утас, Нэр, Регистрийн дугаараар хайх',
                hintText: 'Хайлт...',
                prefixIcon: const Icon(Icons.search, color: customTeal),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: customTeal),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: customTeal),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: customTeal, width: 2.0),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: customTeal, width: 1.0),
                ),

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

        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

        return Scaffold(
          body: Column(
            children: [
              _buildSearchBar(isTablet),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredPatients.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          'Хайсан үгээр өвчтөн олдсонгүй',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : filteredPatients.isEmpty
                    ? const Center(
                        child: Text(
                          'Өвчтөний жагсаалт хоосон байна.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),

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

                          final isNarrowScreen = screenWidth < 500;

                          final isWideScreen = screenWidth >= 600;

                          final mainAxisAlignment = isNarrowScreen
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center;

                          final buttonFontSize = isWideScreen ? 16.0 : 11.5;

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
                                            padding: const EdgeInsets.all(0),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisAlignment: mainAxisAlignment,
                                                children: [
                                                  SizedBox(
                                                    width: isTablet ? 130 : 110,
                                                    child: _buildUzlegButton(
                                                      context,
                                                      roomId,
                                                      xMedsoftToken,
                                                      buttonFontSize,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 0),

                                                  SizedBox(
                                                    width: isTablet ? 220 : 190,
                                                    child: _buildBatalgaajuulahButton(
                                                      context,
                                                      patient,
                                                      arrived,
                                                      buttonFontSize,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 0),

                                                  SizedBox(
                                                    width: isTablet ? 110 : 100,
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
