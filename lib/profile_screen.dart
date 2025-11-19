import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Assuming the original file name was doctor_profile_screen.dart,
// I'm renaming this to ProfileScreen to avoid confusion
// with the patient's ProfileScreen in the other file.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onGuideTap;
  final VoidCallback onLogoutTap;

  const ProfileScreen({super.key, required this.onGuideTap, required this.onLogoutTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _initialDataFuture;

  // Static colors from the patient screen for consistency
  static const Color _wateryGreen = Color.fromARGB(255, 67, 180, 100);
  static const Color _dangerRed = Color.fromARGB(255, 217, 83, 96);

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadEmployeeData();
  }

  Future<Map<String, dynamic>> _loadEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeJson = prefs.getString('employee');

    if (employeeJson == null || employeeJson.isEmpty) {
      return {}; // Return empty data on failure
    }

    try {
      final Map<String, dynamic> employeeData = jsonDecode(employeeJson);

      // Map gender to Mongolian
      String gender = employeeData['gender'] as String? ?? 'Хүйс байхгүй';
      gender = gender == 'MALE' ? 'Эрэгтэй' : (gender == 'FEMALE' ? 'Эмэгтэй' : gender);

      // Extract work-related info
      final String branchName = employeeData['branch']?['name'] ?? 'Байхгүй';
      final String branchNickname = employeeData['branch']?['nickname'] ?? '';
      final String workplace = employeeData['workplace'] ?? 'Байхгүй';

      // Get the primary phone number
      final List<dynamic>? phones = employeeData['phones'];
      final String phoneNumber = (phones != null && phones.isNotEmpty)
          ? phones.first
          : 'Утасны дугааргүй';

      return {
        'firstName': employeeData['firstname'] ?? '',
        'lastName': employeeData['lastname'] ?? '',
        'regNo': employeeData['regNo'] ?? 'РД байхгүй',
        'civilId': employeeData['civilId'] ?? 'ИБД байхгүй',
        'phoneNumber': phoneNumber,
        'email': employeeData['email'] ?? 'Имэйл байхгүй',
        'birthday': employeeData['birthday'] ?? 'Төрсөн огноо байхгүй',
        'gender': gender,
        'branchName': branchName,
        'branchNickname': branchNickname,
        'workplace': workplace,
      };
    } catch (e) {
      print('Exception during employee data loading/decoding: $e');
      return {};
    }
  }

  // Helper function to generate initials (copied from patient screen)
  String _getInitials(String firstName, String lastName) {
    String firstInitial = firstName.isNotEmpty ? firstName[0] : '';
    String lastInitial = lastName.isNotEmpty ? lastName[0] : '';
    return (lastInitial + firstInitial).toUpperCase();
  }

  // Helper for 'РД' and 'ИБД' custom icons (copied from patient screen)
  Widget _buildCustomIcon(String text, Color color) {
    return Container(
      width: 35,
      height: 30,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  // Helper function for building info rows (copied from patient screen)
  Widget _buildInfoRow(
    BuildContext context,
    Widget icon,
    String text, {
    String? subtitle,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: <Widget>[
          Padding(padding: const EdgeInsets.only(right: 15.0), child: icon),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: isMultiline ? 14 : 16,
                    fontWeight: isMultiline ? FontWeight.normal : FontWeight.w500,
                    color: isMultiline ? Colors.black87 : Colors.black,
                  ),
                  maxLines: isMultiline ? 3 : 1,
                  overflow: isMultiline ? TextOverflow.ellipsis : TextOverflow.clip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build profile image widget (Simplified: using only initials avatar as image data is missing in employee JSON)
  Widget _buildProfileImage(String initials, bool isWideScreen) {
    final double size = isWideScreen ? 160.0 : 100.0;
    final double fontSize = isWideScreen ? 48.0 : 32.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.8), shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double maxWidth = 600.0;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      // appBar: AppBar(title: const Text('Миний профайл')),
      body: SingleChildScrollView(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final String firstName = data['firstName'] ?? '';
            final String lastName = data['lastName'] ?? '';
            final String regNo = data['regNo'] ?? 'Алдаа';
            final String civilId = data['civilId'] ?? 'Алдаа';
            final String phoneNumber = data['phoneNumber'] ?? 'Алдаа';
            final String email = data['email'] ?? 'Алдаа';
            final String birthday = data['birthday'] ?? 'Алдаа';
            final String gender = data['gender'] ?? 'Алдаа';
            final String branchName = data['branchName'] ?? 'Алдаа';
            final String branchNickname = data['branchNickname'] ?? 'Алдаа';
            final String workplace = data['workplace'] ?? 'Алдаа';

            final String initials = _getInitials(firstName, lastName);
            final String fullName = '${lastName.isNotEmpty ? lastName[0] : ''}.$firstName';

            // --- INFO ROWS LIST ---
            List<Widget> infoRows = [
              // 1st Row: Branch/Nickname
              _buildInfoRow(
                context,
                const Icon(Icons.apartment, color: Colors.indigo),
                '$branchName ($branchNickname)',
                subtitle: 'Ажиллаж буй байгууллага',
                isMultiline: true,
              ),
              const Divider(height: 20, thickness: 1),

              // 2nd Row: Workplace/Tasag
              _buildInfoRow(
                context,
                const Icon(Icons.work, color: Colors.purple),
                workplace,
                subtitle: 'Ажлын байр',
                isMultiline: true,
              ),
              const Divider(height: 20, thickness: 1),

              // 3rd Row: Registration Number (RegNo)
              _buildInfoRow(
                context,
                _buildCustomIcon('РД', Colors.blueGrey),
                regNo,
                subtitle: 'Регистрийн дугаар',
              ),
              const Divider(height: 20, thickness: 1),

              // 4th Row: Civil ID
              _buildInfoRow(
                context,
                _buildCustomIcon('ИБД', Colors.orange),
                civilId,
                subtitle: 'Иргэний бүртгэлийн дугаар',
              ),
              const Divider(height: 20, thickness: 1),

              // 5th Row: Phone Number
              _buildInfoRow(
                context,
                const Icon(Icons.phone, color: Colors.green),
                phoneNumber,
                subtitle: 'Утасны дугаар',
              ),
              const Divider(height: 20, thickness: 1),

              // 6th Row: Email
              _buildInfoRow(
                context,
                const Icon(Icons.email, color: Colors.blue),
                email,
                subtitle: 'Имэйл хаяг',
              ),
              const Divider(height: 20, thickness: 1),

              // 7th Row: Birthday
              _buildInfoRow(
                context,
                const Icon(Icons.cake, color: Colors.pink),
                birthday,
                subtitle: 'Төрсөн огноо',
              ),
              const Divider(height: 20, thickness: 1),

              // 8th Row: Gender
              _buildInfoRow(
                context,
                Icon(
                  gender == 'Эрэгтэй'
                      ? Icons.male
                      : (gender == 'Эмэгтэй' ? Icons.female : Icons.person),
                  color: gender == 'Эрэгтэй'
                      ? Colors.blue
                      : (gender == 'Эмэгтэй' ? Colors.pink : Colors.grey),
                ),
                gender,
                subtitle: 'Хүйс',
              ),
              // const Divider(height: 20, thickness: 1),

              // // Last Row: Status/Welcome Note (Replacing the DAN note)
              // _buildInfoRow(
              //   context,
              //   const Icon(Icons.verified_user, color: _wateryGreen),
              //   'Та системийн бүртгэлтэй эмч/ажилтан байна.',
              //   isMultiline: true,
              // ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final double horizontalMargin = isLandscape ? 80.0 : 15.0;
                final bool isWideScreen = constraints.maxWidth > maxWidth + (horizontalMargin * 2);

                final double effectiveWidth = isWideScreen ? maxWidth : constraints.maxWidth;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: effectiveWidth),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: 20),
                          // PROFILE PICTURE & Name
                          Center(
                            child: Column(
                              children: [
                                _buildProfileImage(initials, isWideScreen),
                                const SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // --- USER INFO CONTAINER ---
                          Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 15.0,
                              horizontal: isWideScreen ? 0.0 : horizontalMargin,
                            ),
                            padding: const EdgeInsets.all(15.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(children: infoRows),
                          ),

                          // Removed DAN Button

                          // "Гарах" (Logout) Button
                          Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 15.0,
                              horizontal: isWideScreen ? 0.0 : horizontalMargin,
                            ),
                            child: Material(
                              elevation: 1.0,
                              color: _dangerRed,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: widget.onLogoutTap,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: const Text(
                                    'Гарах',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
