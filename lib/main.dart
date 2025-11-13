import 'dart:async';

import 'package:doctor_app/api/auth_dao.dart';
import 'package:doctor_app/claim_qr.dart';
import 'package:doctor_app/constants.dart';
import 'package:doctor_app/emergency_list.dart';
import 'package:doctor_app/guide.dart';
import 'package:doctor_app/patient_list.dart';
import 'package:doctor_app/profile_screen.dart';
import 'package:doctor_app/qr_scan_screen.dart';
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
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return const Scaffold(body: Center(child: Text("Error checking login status")));
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
  int _selectedIndex = 0;
  // 0 for PatientList (myHomePage), 1 for EmptyScreen
  int _homeContentIndex = 0;
  // -----------------------------

  @override
  void initState() {
    super.initState();

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
        AndroidInitializationSettings('app_icon');

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

  // Method to handle BottomNavigationBar item taps (used by the Profile tab only)
  void _onItemTapped(int index) {
    if (index == 1) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Returns the content for the Home/Inbox tab
  Widget _getHomeContent() {
    // 0 is the original 'myHomePage' (PatientListScreen)
    if (_homeContentIndex == 0) {
      return PatientListScreen(key: _patientListKey);
    }
    // 1 is the second option in the dropdown (EmptyScreen)
    return const EmergencyListScreen();
  }

  // Your original _getBody() function
  Widget _getBody() {
    Widget currentContent;
    if (_selectedIndex == 0) {
      currentContent = _getHomeContent();
    } else {
      currentContent = const ProfileScreen();
    }

    // WRAPPING content to explicitly remove top and bottom safe area padding
    return SafeArea(top: false, bottom: false, child: currentContent);
  }

  // Helper to get the descriptive title and icon for the current Home sub-screen
  Map<String, dynamic> _getHomeSelectionDetails() {
    if (_homeContentIndex == 0) {
      return {'title': 'Түргэн тусламж', 'icon': Icons.list_alt}; // Changed icon to list_alt
    } else {
      return {'title': 'Яаралтай', 'icon': Icons.inbox}; // Changed icon to inbox
    }
  }

  // Helper to get the descriptive title for the current Home sub-screen (used by AppBar)
  String _getCurrentHomeTitle() {
    return _getHomeSelectionDetails()['title'];
  }

  // --- Custom Bottom Navigation Bar with Nested Menu ---
  Widget _buildCustomBottomNavBar() {
    const selectedColor = Color(0xFF00CCCC);
    const unselectedColor = Colors.grey;

    final homeDetails = _getHomeSelectionDetails();
    final homeIcon = homeDetails['icon'] as IconData;
    final homeCaption = homeDetails['title'] as String;

    // Function to show the popup menu anchored to the Inbox key's position
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
            itemCenter - (menuWidth / 2), // Horizontal position centered on the item
            // Adjusted Top: A value like 115px is appropriate for two menu items (~110px total height),
            // ensuring the menu is not pushed too far up.
            position.dy - 120,
            itemCenter + (menuWidth / 2),
            position
                .dy, // Bottom: Aligned exactly with the top edge of the navigation item (no padding).
          ),
          items: [
            const PopupMenuItem<int>(value: 0, child: Text('Түргэн тусламж')),
            const PopupMenuItem<int>(value: 1, child: Text('Яаралтай')),
          ],
          elevation: 8.0,
        ).then((int? result) {
          if (result != null) {
            setState(() {
              _homeContentIndex = result;
              // Ensure we are on the Home tab when content changes
              if (_selectedIndex != 0) {
                _selectedIndex = 0;
              }
            });
          }
        });
      });
    }

    // Define the items including the divider
    final items = [
      // Inbox/Home item (with dropdown logic)
      Expanded(
        child: Material(
          // Use Material and InkWell for tap feedback
          color: Colors.white,
          child: InkWell(
            key: _inboxKey, // Anchor for the popup
            onTap: () {
              // Switch to Home tab if on Profile
              if (_selectedIndex == 1) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
              // Now show the nested menu
              showNestedMenu(context);
            },
            child: Container(
              height: 60,

              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- START: Combined Icons Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        homeIcon, // Dynamic Icon
                        color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                        size: 24.0, // Standard size
                      ),
                      const SizedBox(width: 2), // Small space between icon and indicator
                      Icon(
                        Icons.unfold_more, // UnfoldMore indicator
                        color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                        size: 16.0, // Slightly smaller to suggest it's a decorator
                      ),
                    ],
                  ),
                  // --- END: Combined Icons Row ---
                  Text(
                    homeCaption, // <-- Dynamic Caption
                    style: TextStyle(
                      color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Divider between the options
      // const SizedBox(
      //   height: kBottomNavigationBarHeight,
      //   child: VerticalDivider(
      //     width: 1, // Actual width of the space the divider takes
      //     thickness: 1, // Thickness of the drawn line
      //     color: Colors.grey,
      //   ),
      // ),

      // Profile item (regular navigation)
      Expanded(
        child: Material(
          // Use Material and InkWell for tap feedback
          color: Colors.white,
          child: InkWell(
            onTap: () {
              _onItemTapped(1); // regular navigation to index 1
            },
            child: Container(
              height: 60,

              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: _selectedIndex == 1 ? selectedColor : unselectedColor),
                  Text(
                    'Profile',
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
    ];
    return SafeArea(
      top: false,
      // ✅ The SafeArea now contains a white background that fills its full height,
      // including the bottom inset.
      child: Container(
        color: Colors.white, // <- Paints the SafeArea’s background white
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Your fixed-height navigation bar
            Container(
              color: Colors.white,
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        key: _inboxKey,
                        onTap: () {
                          if (_selectedIndex == 1) {
                            setState(() => _selectedIndex = 0);
                          }
                          showNestedMenu(context);
                        },
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    homeIcon,
                                    color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.unfold_more,
                                    color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                homeCaption,
                                style: TextStyle(
                                  color: _selectedIndex == 0 ? selectedColor : unselectedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _onItemTapped(1),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                color: _selectedIndex == 1 ? selectedColor : unselectedColor,
                              ),
                              Text(
                                'Profile',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- End Custom Bottom Navigation Bar ---

  @override
  Widget build(BuildContext context) {
    Widget? actualAppBarTitle;
    List<Widget> appBarActions = [];
    final isHomeTab = _selectedIndex == 0;
    final isPatientListScreen = isHomeTab && _homeContentIndex == 0;

    // --- Simplified AppBar Logic ---
    if (isHomeTab) {
      // Show the current sub-screen title
      actualAppBarTitle = Text(_getCurrentHomeTitle());

      // Only show refresh if we are on the original PatientListScreen
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
    } else {
      // Profile Tab
      actualAppBarTitle = const Text('Profile');
    }
    // --- End Simplified AppBar Logic ---

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
      body: _getBody(),

      // --- Custom Bottom Navigation Bar ---
      bottomNavigationBar: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(height: 60, child: Container(child: _buildCustomBottomNavBar())),
        ),
      ),
      // -----------------------------
    );
  }
}
