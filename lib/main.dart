import 'dart:async';
import 'package:doctor_app/claim_qr.dart';
import 'package:doctor_app/qr_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:doctor_app/constants.dart';
import 'package:doctor_app/guide.dart';
import 'package:doctor_app/patient_list.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'package:uni_links/uni_links.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Error checking login status")),
            );
          } else if (snapshot.hasData) {
            return snapshot.data!;
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final initialLink = await getInitialLink();
    debugPrint("INMY MAIN'S _getInitialScreen initialLink: ${initialLink}");

    if (initialLink != null) {
      Uri uri = Uri.parse(initialLink);

      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'qr') {
        String token = uri.pathSegments[1];
        await prefs.setString('scannedToken', token);
      }
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      return const MyHomePage(title: 'Дуудлагын жагсаалт');
    } else {
      return const LoginScreen();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? username;
  Map<String, dynamic> sharedPreferencesData = {};

  final GlobalKey<PatientListScreenState> _patientListKey =
      GlobalKey<PatientListScreenState>();

  static const String xToken = Constants.xToken;

  @override
  void initState() {
    super.initState();

    _loadSharedPreferencesData();

    Future<void> saveScannedToken(String token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scannedToken', token);
    }

    Future<String?> getSavedToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('scannedToken');
    }

    Future<bool> callWaitApi(String token) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final tokenSaved = prefs.getString('X-Medsoft-Token') ?? '';
        final server = prefs.getString('X-Tenant') ?? '';

        final waitResponse = await http.get(
          Uri.parse(
            '${Constants.runnerUrl}/gateway/general/get/api/auth/qr/wait?id=$token',
          ),
          headers: {
            'X-Medsoft-Token': tokenSaved,
            'X-Tenant': server,
            'X-Token': Constants.xToken,
          },
        );

        debugPrint('Main Wait API Response: ${waitResponse.body}');

        if (waitResponse.statusCode == 200) {
          return true;
        } else {
          return false;
        }
      } catch (e) {
        debugPrint('Error calling MAIN wait API: $e');
        return false;
      }
    }

    linkStream.listen((link) async {
      if (link != null) {
        Uri uri = Uri.parse(link);
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'qr') {
          String token = uri.pathSegments[1];

          await saveScannedToken(token);

          bool waitSuccess = false;

          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool('isLoggedIn') == true) {
            waitSuccess = await callWaitApi(token);
          }

          if (waitSuccess && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ClaimQRScreen(token: token)),
            );
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('isLoggedIn') == true) {
        _initializeNotifications();
      }
    });
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn') {
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

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'Your channel description',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(badgeNumber: 1);

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Системээс гарсан байна.',
      'Ахин нэвтэрнэ үү.',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  void _logOut() async {
    debugPrint("Entered _logOut");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Tenant');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');
    await prefs.remove('scannedToken');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00CCCC),
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _patientListKey.currentState?.refreshPatients();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          // The main container must be a Column
          children: <Widget>[
            // 1. DrawerHeader (Fixed Height)
            DrawerHeader(
              // ... (your existing decoration and child)
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 236, 169, 175),
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/doctor_logo_login.png',
                  width: 150,
                  height: 150,
                ),
              ),
            ),

            // 2. Scrollable Content Area (Uses Expanded to take up remaining space)
            Expanded(
              child: ListView(
                // <--- Make the *middle* section scrollable
                padding: EdgeInsets.zero,
                children: <Widget>[
                  // User Info
                  ListTile(
                    title: Center(
                      child: Text(
                        username ?? 'Guest',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const Divider(),
                  // Хэрэглэх заавар
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.blueAccent,
                    ),
                    title: const Text(
                      'Хэрэглэх заавар',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GuideScreen(),
                        ),
                      );
                    },
                  ),
                  // QR код унших
                  ListTile(
                    leading: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.green,
                    ),
                    title: const Text(
                      'QR код унших',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QrScanScreen(),
                        ),
                      );
                    },
                  ),

                  // Add extra scrollable padding here if needed, NOT outside the Column.
                  // const SizedBox(height: 10),
                ],
              ),
            ),

            // 3. Sticky Footer (Fixed Height)
            // This part will be pushed to the very bottom.
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 217, 83, 96),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                title: const Center(
                  child: Text(
                    'Гарах',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  _logOut();
                },
              ),
            ),

            // Remove the large SizedBox(height: 50) and use a smaller margin if needed.
            const SizedBox(height: 10),
          ],
        ),
      ),
      body: PatientListScreen(key: _patientListKey),
    );
  }
}
