import 'package:Savor_Go/screens/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController retypeNewPasswordController = TextEditingController();

  String originalPassword = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    final response = await http.get(
      Uri.parse("$myurl/customer/details/${widget.userId}"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        nameController.text = data['name'];
        emailController.text = data['email'];
        phoneController.text = data['phone_number'];
        originalPassword = data['password'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch user data.")),
      );
    }
  }

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (currentPasswordController.text != originalPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Current password is incorrect.")),
      );
      return;
    }

    if (newPasswordController.text != retypeNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("New passwords do not match.")),
      );
      return;
    }

    final updatedData = {
      "name": nameController.text,
      "email": emailController.text,
      "phone_number": phoneController.text,
      "password": newPasswordController.text.isNotEmpty
          ? newPasswordController.text
          : originalPassword,
    };

    final response = await http.put(
      Uri.parse("$myurl/customer/update/${widget.userId}"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updatedData),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile updated successfully.")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update profile.")),
      );
    }
  }

  Widget buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(
        text,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    backgroundColor: theme.colorScheme.background,
    appBar: AppBar(
      backgroundColor: Colors.deepOrange,
      title: const Text("Edit Profile"),
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 0,
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Personal Information",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      context,
                      nameController,
                      "Name",
                      Icons.person,
                      validatorMsg: "Enter your name",
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      context,
                      emailController,
                      "Email",
                      Icons.email,
                      validatorMsg: "Enter your email",
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      context,
                      phoneController,
                      "Phone Number",
                      Icons.phone,
                      validatorMsg: "Enter phone number",
                    ),

                    const SizedBox(height: 30),
                    Text(
                      "Change Password",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      context,
                      currentPasswordController,
                      "Current Password",
                      Icons.lock,
                      validatorMsg: "Enter current password",
                      obscure: true,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      context,
                      newPasswordController,
                      "New Password",
                      Icons.lock_outline,
                      obscure: true,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      context,
                      retypeNewPasswordController,
                      "Retype New Password",
                      Icons.lock_reset,
                      obscure: true,
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: updateProfile,
                      icon: const Icon(Icons.save),
                      label: const Text("Update", style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
  );
}

Widget _inputField(
  BuildContext context,
  TextEditingController controller,
  String label,
  IconData icon, {
  String? validatorMsg,
  bool obscure = false,
}) {
  final theme = Theme.of(context);

  return TextFormField(
    controller: controller,
    obscureText: obscure,
    style: TextStyle(color: theme.colorScheme.onBackground),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Colors.deepOrange),
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
    ),
    validator: (value) => (validatorMsg != null && value!.isEmpty) ? validatorMsg : null,
  );
}
}
