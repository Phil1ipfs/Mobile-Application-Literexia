// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mongo_dart/mongo_dart.dart' show where, modify;
import '../config/router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/logic/auth_provider.dart';
import '../services/database_service.dart';

import 'package:literexia/features/settings/provider/theme_provider.dart';

import 'package:literexia/features/settings/theme_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null) {
        setState(() {
          _nameController.text = user.firstName ?? user.name ?? '';

          // Map reading level to grade level in Filipino
          String gradeLevel = '';
          switch (user.readingLevel?.toLowerCase() ?? '') {
            case 'emergent':
              gradeLevel = 'Baitang isa';
              break;
            case 'early':
              gradeLevel = 'Baitang dalawa';
              break;
            case 'fluent':
              gradeLevel = 'Baitang tatlo';
              break;
            default:
              gradeLevel = user.readingLevel ?? 'Transitioning';
          }

          _gradeController.text = gradeLevel;
          _idNumberController.text = user.idNumber?.toString() ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: $e';
      });
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.primaryColor,
          appBar: AppBar(
            backgroundColor: theme.headerColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.textColor),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              'Profile',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(24),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
                letterSpacing: themeProvider.getRealLetterSpacing(),
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.edit, color: theme.accentColor),
                onPressed: () {
                  // Enable editing functionality here
                },
              ),
            ],
          ),
          body:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: theme.accentColor),
                  )
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile picture
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: theme.accentColor,
                                  width: 2.0,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Name field
                          Text(
                            'Pangalan',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _nameController,
                              enabled: _isEditing,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: themeProvider.getRealFontSize(16),
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Grade level field
                          Text(
                            'Antas ng Baitang',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _gradeController,
                              enabled: _isEditing,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: themeProvider.getRealFontSize(16),
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ID Number field (non-editable)
                          Text(
                            'Numero ng ID',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _idNumberController,
                              enabled: false, // ID Number is not editable
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: themeProvider.getRealFontSize(16),
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                fillColor: Colors.grey.shade200,
                                filled: true,
                              ),
                            ),
                          ),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: themeProvider.getRealFontSize(14),
                                  fontFamily: themeProvider.fontFamily,
                                  letterSpacing:
                                      themeProvider.getRealLetterSpacing(),
                                ),
                              ),
                            ),

                          const SizedBox(height: 50),

                          // Logout button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: theme.buttonTextColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: themeProvider.getRealFontSize(
                                        16,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeProvider.fontFamily,
                                      letterSpacing:
                                          themeProvider.getRealLetterSpacing(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }
}
