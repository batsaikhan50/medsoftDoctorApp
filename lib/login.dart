import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:doctor_app/claim_qr.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:http/http.dart' as http;
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:doctor_app/constants.dart';
import 'package:doctor_app/main.dart';
import 'package:doctor_app/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameLoginController =
      TextEditingController();
  final TextEditingController _passwordLoginController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FocusNode _codeFocus = FocusNode();
  final FocusNode _usernameLoginFocus = FocusNode();
  final FocusNode _passwordLoginFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _passwordCheckFocus = FocusNode();
  final FocusNode _regNoFocus = FocusNode();
  final FocusNode _firstnameFocus = FocusNode();
  final FocusNode _lastnameFocus = FocusNode();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameLoginController.dispose();
    _passwordLoginController.dispose();
    _usernameController.dispose();
    _passwordController.removeListener(_updatePasswordRules);
    _passwordCheckController.removeListener(_updatePasswordRules);
    _passwordController.dispose();
    _passwordCheckController.dispose();
    _regNoController.dispose();
    _firstnameFocus.dispose();
    _lastnameFocus.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _usernameFocus.dispose();
    _passwordLoginFocus.dispose();
    _passwordFocus.dispose();
    _passwordCheckFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, String>? _selectedRole;

  bool _isPasswordLoginVisible = false;
  bool _isPasswordVisible = false;
  bool _isPasswordCheckVisible = false;
  int _selectedToggleIndex = 0; //0-Иргэн, 1-103
  double _dragPosition = 0.0;

  bool _isKeyboardVisible = false;

  List<Map<String, String>> _serverNames = [];
  Map<String, dynamic> sharedPreferencesData = {};

  Map<String, bool> _passwordRulesStatus = {};
  String? _passwordCheckValidationError;
  String? _regNoValidationError;
  String? _firstnameValidationError;
  String? _lastnameValidationError;

  final RegExp _regNoRegex = RegExp(
    r'^[А-ЯӨҮ]{2}[0-9]{2}(0[1-9]|1[0-2]|2[0-9]|3[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{2}$',
  );
  final RegExp mongolianCyrillicRegex = RegExp(r'^[А-Яа-яӨөҮүЁё]+$');

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;

    if (_isKeyboardVisible != newValue) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  bool isMongolianCyrillic(String text) {
    return mongolianCyrillicRegex.hasMatch(text);
  }

  Future<void> _getInitialScreenString() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? xServer = prefs.getString('X-Tenant');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Token');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      debugPrint(
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername',
      );
    } else {
      return debugPrint("empty shared");
    }
  }

  Future<void> _fetchServerData() async {
    const url = '${Constants.runnerUrl}/gateway/servers';
    final headers = {'X-Token': Constants.xToken};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<Map<String, String>> serverNames =
              List<Map<String, String>>.from(
                data['data'].map<Map<String, String>>((server) {
                  return {
                    'name': server['fullName'].toString(),
                    'domain': server['domain'].toString(),
                  };
                }),
              );

          setState(() {
            _serverNames = serverNames;
          });
        } else {
          setState(() {
            _errorMessage = 'Эмнэлгүүдийг дуудах үйлдэл амжилтгүй боллоо.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Серверийн мэдээлэл авахад алдаа гарлаа.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Алдаа гарлаа: $e';
      });
    }
  }

  void _updatePasswordRules() {
    final password = _passwordController.text;
    final rules = _validatePasswordRules(password);

    setState(() {
      _passwordRulesStatus = rules;
      _passwordCheckValidationError = _validatePasswordMatch(
        password,
        _passwordCheckController.text,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _usernameLoginController.addListener(() {
      setState(() {});
    });

    _usernameController.addListener(() {
      setState(() {});
    });

    _passwordLoginController.addListener(() {
      setState(() {});
      _updatePasswordRules();
    });

    _passwordController.addListener(() {
      setState(() {});
      _updatePasswordRules();
    });

    _passwordCheckController.addListener(() {
      setState(() {});
      _updatePasswordRules();
    });
    _regNoController.addListener(_validateRegNo);

    _dragPosition =
        _selectedToggleIndex *
        ((MediaQueryData.fromView(WidgetsBinding.instance.window).size.width -
                32 -
                8) /
            2);
    _fetchServerData();
    _getInitialScreenString();
  }

  void _validateRegNo() {
    final regNo = _regNoController.text.trim().toUpperCase();

    setState(() {
      if (regNo.isEmpty) {
        _regNoValidationError = null;
      } else if (!_regNoRegex.hasMatch(regNo)) {
        _regNoValidationError = 'Регистрын дугаар буруу байна';
      } else {
        _regNoValidationError = null;
      }
    });
  }

  void _validateName() {
    final firstname = _firstnameController.text.trim().toUpperCase();
    final lastname = _lastnameController.text.trim().toUpperCase();

    setState(() {
      if (firstname.isEmpty) {
        _firstnameValidationError = null;
      } else if (!mongolianCyrillicRegex.hasMatch(firstname)) {
        _firstnameValidationError = 'Кирилл үсгээр бичнэ үү.';
      } else {
        _firstnameValidationError = null;
      }

      if (lastname.isEmpty) {
        _lastnameValidationError = null;
      } else if (!mongolianCyrillicRegex.hasMatch(lastname)) {
        _lastnameValidationError = 'Кирилл буруу байна';
      } else {
        _lastnameValidationError = null;
      }
    });
  }

  bool _validateRegisterInputs() {
    final password = _passwordController.text;
    final passwordMatchError = _validatePasswordMatch(
      password,
      _passwordCheckController.text,
    );
    final rules = _validatePasswordRules(password);

    final regNo = _regNoController.text.trim().toUpperCase();
    if (regNo.isEmpty || !_regNoRegex.hasMatch(regNo)) {
      _regNoValidationError = 'Регистрын дугаар буруу байна';
    } else {
      _regNoValidationError = null;
    }

    setState(() {
      _passwordRulesStatus = rules;
      _passwordCheckValidationError = passwordMatchError;
    });

    final allPassed = rules.values.every((passed) => passed == true);
    return allPassed &&
        passwordMatchError == null &&
        _regNoValidationError == null;
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    final body = {
      'username': _usernameController.text,
      'password': _passwordController.text,
      'passwordConfirm': _passwordCheckController.text,
      'regNo': _regNoController.text,
      'firstname': _firstnameController.text,
      'lastname': _lastnameController.text,
      'type': 'driver',
    };

    final headers = {'Content-Type': 'application/json'};

    debugPrint('Request Headers: $headers');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse('${Constants.appUrl}/auth/signup'),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Register response Status: ${response.statusCode}');
      debugPrint('Register response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();

          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('X-Tenant');
          await prefs.remove('X-Medsoft-Token');
          await prefs.remove('Username');
          await prefs.remove('scannedToken');

          setState(() {
            _selectedToggleIndex = 0;
            _dragPosition = 0.0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Бүртгэл амжилтгүй боллоо: ${data['message']}';
            _isLoading = false;
          });
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _errorMessage = 'Бүртгэх үед алдаа гарлаа. Дахин оролдоно уу.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Алдаа гарлаа: $e';
        _isLoading = false;
      });
    }
  }

  /// Retrieve the saved scanned token from SharedPreferences
  Future<String?> getSavedToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('scannedToken');
  }

  /// Call the /wait and /attend endpoints with the scanned token
  Future<void> callWaitApi(BuildContext context, String token) async {
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

      debugPrint('Login Wait API Response: ${waitResponse.body}');

      if (waitResponse.statusCode == 200) {
        // ✅ Success → go to ClaimQRScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ClaimQRScreen(token: token)),
        );
      } else {
        debugPrint("Login Wait failed: ${waitResponse.statusCode}");
      }
    } catch (e) {
      debugPrint('Error calling wait API: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    if (_selectedRole == null) {
      setState(() {
        _errorMessage = 'Эмнэлэг сонгоно уу.';
        _isLoading = false;
      });
      return;
    }

    final body = _selectedRole?['name'] == 'Citizen'
        ? {
            'username': _usernameLoginController.text,
            'password': _passwordLoginController.text,
            'type': 'driver',
          }
        : {
            'username': _usernameLoginController.text,
            'password': _passwordLoginController.text,
          };

    final headers = _selectedRole?['name'] == 'Citizen'
        ? {'Content-Type': 'application/json'}
        : {
            'X-Token': Constants.xToken,
            'X-Tenant': _selectedRole?['name'] ?? '',
            'Content-Type': 'application/json',
          };

    debugPrint('Request Headers: $headers');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse(
          _selectedRole?['name'] == 'Citizen'
              ? '${Constants.appUrl}/auth/login'
              : '${Constants.runnerUrl}/gateway/auth',
        ),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        if (!(Platform.environment['SIMULATOR_DEVICE_NAME'] ==
            'iPhone SE (3rd generation)')) {
          FlutterAppBadger.removeBadge();
        } else {}

        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          final String token = data['data']['token'];

          await prefs.setString('X-Tenant', _selectedRole?['name'] ?? '');
          await prefs.setString('X-Medsoft-Token', token);

          debugPrint('Username controller: ${_usernameLoginController.text}');
          await prefs.setString('Username', _usernameLoginController.text);

          _loadSharedPreferencesData();

          final savedToken = await getSavedToken();
          if (savedToken != null) {
            debugPrint("INMY LOGIN'S if savedToken: ${savedToken}");
            await callWaitApi(context, savedToken);
            return;
          }

          _isLoading = false;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyHomePage(title: 'Дуудлагын жагсаалт'),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Нэвтрэхэд амжилтгүй боллоо: ${data['message']}';
            _isLoading = false;
          });
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _errorMessage = 'Нэвтрэх үед алдаа гарлаа. Дахин оролдоно уу.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Алдаа гарлаа: $e';
        _isLoading = false;
      });
    }
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
      sharedPreferencesData = data;
    });
  }

  Map<String, bool> _validatePasswordRules(String password) {
    return {
      'Нууц үгэнд дор хаяж нэг тоо байх ёстой': password.contains(
        RegExp(r'\d'),
      ),
      'Нууц үгэнд дор хаяж нэг жижиг үсэг байх ёстой': password.contains(
        RegExp(r'[a-z]'),
      ),
      'Нууц үгэнд дор хаяж нэг том үсэг байх ёстой': password.contains(
        RegExp(r'[A-Z]'),
      ),
      'Нууц үгэнд дор хаяж нэг тусгай тэмдэгт байх ёстой': password.contains(
        RegExp(r"[!@#&()\[\]{}:;',?/*~$^+=<>]"),
      ),
      'Нууц үгийн урт 10-35 тэмдэгт байх ёстой':
          password.length >= 10 && password.length <= 35,
    };
  }

  String? _validatePasswordMatch(String password, String confirmPassword) {
    if (password != confirmPassword) {
      return 'Нууц үг таарахгүй байна';
    }
    return null;
  }

  Widget buildAnimatedToggle() {
    List<Map<String, String>> toggleOptions = [
      {'label': 'Нэвтрэх'},
      {'label': 'Бүртгүүлэх'},
    ];

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double totalWidth = isTablet ? screenWidth * 0.5 : screenWidth - 32;
    final double knobWidth = (totalWidth - 8) / 2;

    return Center(
      child: Container(
        width: totalWidth,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(30),
        ),
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragPosition += details.delta.dx;
              _dragPosition = _dragPosition.clamp(0, knobWidth);
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              if (_dragPosition < (knobWidth / 2)) {
                _selectedToggleIndex = 0;
                _dragPosition = 0;
              } else {
                _selectedToggleIndex = 1;
                _dragPosition = knobWidth;
              }
            });
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx;
            setState(() {
              if (dx < totalWidth / 2) {
                _selectedToggleIndex = 0;
                _dragPosition = 0;
              } else {
                _selectedToggleIndex = 1;
                _dragPosition = knobWidth;
              }
            });
          },
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: _dragPosition,
                top: 0,
                bottom: 0,
                width: knobWidth,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: _selectedToggleIndex == 0
                        ? const Color(0xFF009688)
                        : const Color(0xFF0077b3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              Row(
                children: List.generate(toggleOptions.length, (index) {
                  final option = toggleOptions[index];
                  final isSelected = index == _selectedToggleIndex;

                  return Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == 0 ? Icons.login : Icons.person_add,
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyboardActionsConfig _buildKeyboardActionsConfig(BuildContext context) {
    const Color iosToolbarColor = Color(0x00D8D7DE);

    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
      nextFocus: true,
      keyboardBarColor: iosToolbarColor,
      actions: [
        if (_selectedToggleIndex == 0)
          KeyboardActionsItem(
            focusNode: _usernameLoginFocus,
            displayArrows: true,
            displayDoneButton: false,
          ),

        if (_selectedToggleIndex == 0)
          KeyboardActionsItem(
            focusNode: _passwordLoginFocus,
            displayArrows: true,
            displayDoneButton: false,
          ),
      ],
    );
  }

  // Remove the old _scrollIntoView function, as it's not used
  // in this new KeyboardActionsConfig configuration.
  // void _scrollIntoView(FocusNode focusNode) { ... }
  void _scrollIntoView(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: KeyboardActions(
            config: _buildKeyboardActionsConfig(context),
            child: _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final maxWidth = isTablet
        ? MediaQuery.of(context).size.width * 0.5
        : double.infinity;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icon/doctor_logo_login.png', height: 150),
                const Text(
                  'Тавтай морил',
                  style: TextStyle(
                    fontSize: 22.4,
                    color: Color(0xFF009688),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // buildAnimatedToggle(),
                // const SizedBox(height: 20),
                if (_serverNames.isNotEmpty && _selectedToggleIndex == 0)
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF808080),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.black),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<Map<String, String>>(
                            value: _selectedRole,
                            hint: const Text('Эмнэлэг сонгох'),
                            isExpanded: true,
                            onChanged: (Map<String, String>? newValue) async {
                              if (newValue != null) {
                                setState(() {
                                  _selectedRole = newValue;
                                  _errorMessage = '';
                                });

                                debugPrint(
                                  'MY FORGET URL: ${newValue.toString()}',
                                );

                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'forgetUrl',
                                  newValue['domain'] ?? '',
                                );
                              }
                            },
                            items: _serverNames
                                .map<DropdownMenuItem<Map<String, String>>>((
                                  Map<String, String> value,
                                ) {
                                  return DropdownMenuItem<Map<String, String>>(
                                    value: value,
                                    child: Text(value['name']!),
                                  );
                                })
                                .toList(),
                            underline: const SizedBox.shrink(),
                          ),
                        ),
                        if (_selectedRole != null)
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.black54,
                            ),
                            onPressed: () async {
                              setState(() {
                                _selectedRole = null;
                              });
                              SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove('forgetUrl');
                            },
                          ),
                      ],
                    ),
                  ),

                if (_serverNames.isNotEmpty && _selectedToggleIndex == 0)
                  const SizedBox(height: 20),

                if (_selectedToggleIndex == 0)
                  TextFormField(
                    controller: _usernameLoginController,
                    focusNode: _usernameLoginFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_usernameLoginFocus);
                    },
                    decoration: InputDecoration(
                      labelText: 'Нэвтрэх нэр',
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _usernameLoginController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _usernameLoginController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_usernameFocus);
                    },
                    decoration: InputDecoration(
                      labelText: 'Нэвтрэх нэр',
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _usernameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _usernameController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                if (_selectedToggleIndex == 0)
                  TextFormField(
                    controller: _passwordLoginController,
                    focusNode: _passwordLoginFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    obscureText: !_isPasswordLoginVisible,
                    decoration: InputDecoration(
                      labelText: 'Нууц үг',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_passwordLoginController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _passwordLoginController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isPasswordLoginVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordLoginVisible =
                                    !_isPasswordLoginVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                if (_selectedToggleIndex == 0) const SizedBox(height: 20),

                // if (_selectedToggleIndex == 1)
                //   TextFormField(
                //     controller: _passwordController,
                //     focusNode: _passwordFocus,
                //     textInputAction: TextInputAction.done,
                //     onFieldSubmitted: (_) {
                //       FocusScope.of(context).unfocus();
                //     },
                //     obscureText: !_isPasswordVisible,
                //     decoration: InputDecoration(
                //       labelText: 'Нууц үг',
                //       prefixIcon: const Icon(Icons.lock),
                //       suffixIcon: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           if (_passwordController.text.isNotEmpty)
                //             IconButton(
                //               icon: const Icon(Icons.clear),
                //               onPressed: () {
                //                 _passwordController.clear();
                //                 setState(() {});
                //               },
                //             ),
                //           IconButton(
                //             icon: Icon(
                //               _isPasswordVisible
                //                   ? Icons.visibility
                //                   : Icons.visibility_off,
                //             ),
                //             onPressed: () {
                //               setState(() {
                //                 _isPasswordVisible = !_isPasswordVisible;
                //               });
                //             },
                //           ),
                //         ],
                //       ),
                //       border: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(12),
                //       ),
                //     ),
                //   ),
                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Нууц үг',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_passwordController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _passwordController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _passwordCheckController,
                    focusNode: _passwordCheckFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    obscureText: !_isPasswordCheckVisible,
                    decoration: InputDecoration(
                      labelText: 'Нууц үг давтах',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordCheckVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordCheckVisible = !_isPasswordCheckVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _passwordCheckValidationError,
                    ),
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _regNoController,
                    focusNode: _regNoFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocus);
                    },
                    decoration: InputDecoration(
                      labelText: 'Регистрын дугаар',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _regNoValidationError,
                    ),
                    onChanged: (value) {
                      _regNoController.value = _regNoController.value.copyWith(
                        text: value.toUpperCase(),
                        selection: TextSelection.collapsed(
                          offset: value.length,
                        ),
                      );
                    },
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _lastnameController,
                    focusNode: _lastnameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocus);
                    },
                    decoration: InputDecoration(
                      labelText: 'Овог',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _lastnameValidationError,
                    ),
                    onChanged: (value) {
                      _lastnameController.value = _lastnameController.value
                          .copyWith(
                            text: value,
                            selection: TextSelection.collapsed(
                              offset: value.length,
                            ),
                          );
                    },
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                if (_selectedToggleIndex == 1)
                  TextFormField(
                    controller: _firstnameController,
                    focusNode: _firstnameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocus);
                    },
                    decoration: InputDecoration(
                      labelText: 'Нэр',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _firstnameValidationError,
                    ),
                    onChanged: (value) {
                      _firstnameController.value = _firstnameController.value
                          .copyWith(
                            text: value,
                            selection: TextSelection.collapsed(
                              offset: value.length,
                            ),
                          );
                    },
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                if (_selectedToggleIndex == 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () async {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        String? baseUrl = prefs.getString('forgetUrl');

                        debugPrint('MY PREFS FORGETURL: ${baseUrl}');
                        String? hospital = _selectedRole?['name'];

                        if (baseUrl != null &&
                            baseUrl.isNotEmpty &&
                            hospital != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(
                                url:
                                    '$baseUrl/forget?callback=medsoftdoctor://callback',
                                title: 'Нэвтрэх | ${hospital}',
                              ),
                            ),
                          );
                        } else {
                          setState(() {
                            _errorMessage =
                                'Нууц үг солихын тулд эмнэлэг сонгоно уу.';
                          });
                        }
                      },
                      child: const Text(
                        'Нууц үг мартсан?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF009688),
                        ),
                      ),
                    ),
                  ),

                if (_selectedToggleIndex == 1) const SizedBox(height: 10),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedToggleIndex == 0
                        ? const Color(0xFF009688)
                        : const Color(0xFF0077b3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_selectedToggleIndex == 1) {
                            if (_validateRegisterInputs()) {
                              _register();
                            }
                          } else {
                            _login();
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedToggleIndex == 0 ? 'НЭВТРЭХ' : 'БҮРТГҮҮЛЭХ',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
