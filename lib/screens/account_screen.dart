import 'package:Savor_Go/screens/url.dart';
import 'package:flutter/material.dart';
import 'package:Savor_Go/screens/firstpage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Savor_Go/screens/EditProfileScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountScreen extends StatefulWidget {
  final String userId;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;

  const AccountScreen({
    Key? key,
    required this.userId,
    required this.themeMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String userName = "Loading...";
  String userEmail = "Loading...";
  String userPhone = "Loading...";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final response = await http.get(Uri.parse('$myurl/user/${widget.userId}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data['name'] ?? "Unknown";
          userEmail = data['email'] ?? "Unknown";
          userPhone = data['phone'] ?? "Unknown";
          isLoading = false;
        });
      } else {
        setState(() {
          userName = "Error fetching data";
          userEmail = "Error fetching data";
          userPhone = "Error fetching data";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        userName = "Network Error";
        userEmail = "Network Error";
        userPhone = "Network Error";
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("My Account"),
        foregroundColor: Colors.white,
        backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage("assets/images/real/male.png"),
                    ),
                  ),
                  SizedBox(height: 20),

                  Text("Name:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(userName, style: TextStyle(fontSize: 16)),

                  SizedBox(height: 10),

                  Text("Email:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(userEmail, style: TextStyle(fontSize: 16)),

                  SizedBox(height: 10),

                  Text("Phone:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(userPhone, style: TextStyle(fontSize: 16)),

                  SizedBox(height: 20),

                  Divider(),

                  ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue),
                    title: Text("Edit Profile"),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userId: widget.userId),
                        ),
                      );
                      // 🔁 Refresh user details after EditProfileScreen returns
                      _fetchUserDetails();
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.brightness_6, color: Colors.orange),
                    title: Text("Theme Mode"),
                    trailing: DropdownButton<ThemeMode>(
                      value: widget.themeMode,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (ThemeMode? mode) {
                        if (mode != null) widget.onThemeChanged(mode);
                      },
                    ),
                  ),

                  Spacer(),

                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove("isLoggedIn");
  await prefs.remove("userId");

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => FirstPage(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ),
    (route) => false,
  );
},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: Text("Logout"),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
