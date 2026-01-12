import 'dart:async';

import 'package:medsoft_doctor/api/auth_dao.dart';
import 'package:medsoft_doctor/claim_qr.dart';
import 'package:medsoft_doctor/constants.dart';
import 'package:medsoft_doctor/doctor_call_screen.dart';
import 'package:medsoft_doctor/emergency_list.dart';
import 'package:medsoft_doctor/guide.dart';
import 'package:medsoft_doctor/home_screen.dart';
import 'package:medsoft_doctor/patient_list.dart';
import 'package:medsoft_doctor/profile_screen.dart';
import 'package:medsoft_doctor/qr_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

import 'login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medsoft Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return const Scaffold(body: Center(child: Text("Нэвтрэх төлөвийг шалгахад алдаа гарлаа")));
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
    debugPrint("INMY MAIN'S _getInitialScreen initialLink: $initialLink");

    if (initialLink != null) {
      Uri uri = Uri.parse(initialLink);

      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'qr') {
        String token = uri.pathSegments[1];
        await prefs.setString('scannedToken', token);
      }
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      // The initial screen will still be MyHomePage, but now it handles the navigation.
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

  final _authDao = AuthDAO();
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};

  // Key for PatientListScreen, used for the refresh action
  final GlobalKey<PatientListScreenState> _patientListKey = GlobalKey<PatientListScreenState>();

  // GlobalKey for the Inbox/Home item anchor (used for positioning the menu)
  final GlobalKey _inboxKey = GlobalKey();

  static const String xToken = Constants.xToken;

  // --- Navigation Bar State ---
  // 0 for Home/Inbox (PatientList/EmptyScreen), 1 for Profile
  int _selectedIndex = 1;
  // 0 for PatientList (myHomePage), 1 for EmergencyList
  int _homeContentIndex = 0;
  // -----------------------------
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();

    _widgetOptions = <Widget>[
      // Index 0: Not used (as per existing doctor app's _selectedIndex starting at 1)
      const Center(child: Text("Tab 0 ашиглагдаагүй")),
      // Index 1: Nested Content (PatientList/EmergencyList)
      _getSecondTabContent(),
      // Index 2: QR Scanner
      // const QrScanScreen(),
      const SizedBox(),
      // Index 3: Profile
      ProfileScreen(onGuideTap: _navigateToGuideScreen, onLogoutTap: _logOut),
    ];
    _loadSharedPreferencesData();

    Future<void> saveScannedToken(String token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scannedToken', token);
    }

    Future<bool> callWaitApi(String token) async {
      try {
        final waitResponse = await _authDao.waitQR(token);

        debugPrint('Main Wait API Response: ${waitResponse.toString()}');

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
            Navigator.push(context, MaterialPageRoute(builder: (_) => ClaimQRScreen(token: token)));
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
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _logOut() async {
    debugPrint("Entered _logOut");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScanScreen())).then((
        _,
      ) {
        debugPrint("Returned from QR Screen");
      });
      return;
    }

    if (index != _selectedIndex && index >= 0 && index <= 3) {
      setState(() {
        _selectedIndex = index;
        _widgetOptions[1] = _getSecondTabContent();
      });
    }
  }

  // Returns the content for the Home/Inbox tab
  Widget _getSecondTabContent() {
    debugPrint("_getSecondTabContent called with _homeContentIndex: $_homeContentIndex");
    // 0 is the original 'Түргэн тусламж' (PatientListScreen)
    if (_homeContentIndex == 0) {
      return PatientListScreen(key: _patientListKey);
    }
    // 1 is the 'Яаралтай' (EmergencyListScreen)
    return const EmergencyListScreen();
  }

  void _navigateToGuideScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const GuideScreen()));
  }

  // Your original _getBody() function
  Widget _getBody() {
    // Use SafeArea to handle top and bottom padding as before
    return SafeArea(
      top: false,
      bottom: false,
      child: IndexedStack(
        index: _selectedIndex, // Use the current selected index
        children: _widgetOptions, // Use the pre-defined list of widgets
      ),
    );
  }

  // Helper to get the descriptive title and icon for the current Home sub-screen
  Map<String, dynamic> _getNestedTabDetails() {
    if (_homeContentIndex == 0) {
      return {'title': 'Түргэн тусламж', 'icon': Icons.crisis_alert};
    } else {
      return {'title': 'Яаралтай', 'icon': Icons.local_hospital};
    }
  }

  // Helper to get the descriptive title for the current screen (used by AppBar)
  String _getCurrentTitle() {
    switch (_selectedIndex) {
      // case 0:
      //   return 'Нүүр хуудас';
      case 1:
        return _getNestedTabDetails()['title'];
      case 2:
        return 'QR код унших';
      case 3:
        return 'Профайл';
      default:
        return widget.title;
    }
  }

  // --- Custom Bottom Navigation Bar with Nested Menu ---
  Widget _buildCustomBottomNavBar() {
    const selectedColor = Color(0xFF00CCCC);
    const unselectedColor = Colors.grey;

    final nestedTabDetails = _getNestedTabDetails();
    final nestedTabIcon = nestedTabDetails['icon'] as IconData;
    final nestedTabCaption = nestedTabDetails['title'] as String;
    void showNestedMenu(BuildContext context) {
      // Need to wait until the current frame finishes rendering before getting RenderBox
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final RenderBox? renderBox = _inboxKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final size = renderBox.size;
        final position = renderBox.localToGlobal(Offset.zero);

        // Calculate the horizontal center of the item and estimate the menu width
        const menuWidth = 150.0;
        final itemCenter = position.dx + size.width / 2;

        showMenu<int>(
          context: context,
          // Position the menu.
          position: RelativeRect.fromLTRB(
            itemCenter - (menuWidth / 2),
            position.dy - 120,
            itemCenter + (menuWidth / 2),
            position.dy,
          ),
          items: [
            const PopupMenuItem<int>(
              value: 0,
              child: Row(
                children: [
                  Icon(Icons.crisis_alert, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Түргэн тусламж'),
                ],
              ),
            ),
            const PopupMenuItem<int>(
              value: 1,
              child: Row(
                children: [
                  Icon(Icons.local_hospital, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Яаралтай'),
                ],
              ),
            ),
          ],
          elevation: 8.0,
        ).then((int? result) {
          if (result != null) {
            setState(() {
              _homeContentIndex = result;
              // **This is the critical line added for the IndexedStack**
              _widgetOptions[1] = _getSecondTabContent();
              // --------------------------------------------------------
              // Ensure we are on the Nested tab (index 1) when content changes
              if (_selectedIndex != 1) {
                _selectedIndex = 1;
              }
            });
          }
        });
      });
    }

    // Define the screen width for 3 equal-sized navigation items
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- 1. HOME SCREEN (INDEX 0) ---
                  // SizedBox(
                  //   width: screenWidth / 3,
                  //   child: Material(
                  //     color: Colors.white,
                  //     child: InkWell(
                  //       onTap: () => _onItemTapped(0),
                  //       child: Center(
                  //         child: Column(
                  //           mainAxisSize: MainAxisSize.min,
                  //           children: [
                  //             Icon(
                  //               Icons.home_outlined, // Icon for the new screen
                  //               color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                  //             ),
                  //             Text(
                  //               'Нүүр хуудас',
                  //               style: TextStyle(
                  //                 color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                  //                 fontSize: 12,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // --- 1. NESTED MENU (INDEX 0) ---
                  SizedBox(
                    width: screenWidth / 3,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        key: _inboxKey, // Anchor for the popup
                        onTap: () {
                          if (_selectedIndex == 1) {
                            showNestedMenu(context);
                          }
                          // Switch to this tab (index 1) first
                          if (_selectedIndex != 1) {
                            setState(() => _selectedIndex = 1);
                          }
                        },
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    nestedTabIcon,
                                    color: _selectedIndex == 1 ? selectedColor : unselectedColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.unfold_more,
                                    color: _selectedIndex == 1 ? selectedColor : unselectedColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                nestedTabCaption,
                                style: TextStyle(
                                  color: _selectedIndex == 1 ? selectedColor : unselectedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- 2. QR Screen (INDEX 1) ---
                  SizedBox(
                    width: screenWidth / 3,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _onItemTapped(2),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                // Color should never be selected color since the index is never 2
                                // It should be unselectedColor, as it's a floating action.
                                color: unselectedColor, // *** MODIFIED ***
                              ),
                              Text(
                                'QR',
                                style: TextStyle(
                                  // Color should never be selected color since the index is never 2
                                  color: unselectedColor, // *** MODIFIED ***
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- 3. PROFILE (INDEX 2) ---
                  SizedBox(
                    width: screenWidth / 3,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _onItemTapped(3),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                color: _selectedIndex == 3 ? selectedColor : unselectedColor,
                              ),
                              Text(
                                'Профайл',
                                style: TextStyle(
                                  color: _selectedIndex == 3 ? selectedColor : unselectedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? actualAppBarTitle;
    List<Widget> appBarActions = [];
    final isSecondTab = _selectedIndex == 1;
    final isPatientListScreen = isSecondTab && _homeContentIndex == 0;

    appBarActions.add(
      IconButton(
        icon: const Icon(Icons.videocam),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DoctorCallScreen()),
          );
        },
      ),
    );

    // --- Simplified AppBar Logic ---
    // if (isHomeTab) {
    //   // --- Simplified AppBar Logic ---
    //   actualAppBarTitle = Text(_getCurrentTitle());

    actualAppBarTitle = Text(_getCurrentTitle());

    if (isSecondTab) {
      // Only show refresh if we are on the original PatientListScreen ('Түргэн тусламж')
      if (isPatientListScreen) {
        appBarActions.add(
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              debugPrint("Refreshing patient list");
              _patientListKey.currentState?.refreshPatients();
            },
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00CCCC),
        title: actualAppBarTitle,
        actions: appBarActions,
        toolbarHeight: 45.0,
      ),
      // The existing drawer logic remains here
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Color.fromARGB(255, 236, 169, 175)),
              child: Center(
                child: Image.asset('assets/icon/doctor_logo_login.png', width: 150, height: 150),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ListTile(
                    title: Center(
                      child: Text(username ?? 'Guest', style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
                    title: const Text('Хэрэглэх заавар', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GuideScreen()),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
                    title: const Text('QR код унших', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QrScanScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

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

            const SizedBox(height: 10),
          ],
        ),
      ),
      // Use the new _getBody() for conditional content

      // Use the new _getBody() for conditional content
      body: _getBody(),

      // --- Custom Bottom Navigation Bar ---
      bottomNavigationBar: Material(
        color: Colors.white,
        child: SafeArea(top: false, child: SizedBox(height: 60, child: _buildCustomBottomNavBar())),
      ),
      // -----------------------------
    );
  }
}
