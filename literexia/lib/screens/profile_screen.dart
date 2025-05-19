// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mongo_dart/mongo_dart.dart' show where, modify;
import '../config/router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/logic/auth_provider.dart';
import '../services/database_service.dart';

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
  String? _originalName;
  String? _originalGradeLevel;

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
          // Store original values for comparison when saving
          _originalName = user.firstName ?? user.name ?? '';
          _nameController.text = _originalName!;
          
          // Map reading level to grade level in Filipino
          String gradeLevel = '';
          switch(user.readingLevel?.toLowerCase() ?? '') {
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
              gradeLevel = user.readingLevel ?? 'Hindi tinukoy';
          }
          
          _originalGradeLevel = gradeLevel;
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

  Future<void> _saveUserData() async {
    // Only proceed if data actually changed
    if (_nameController.text == _originalName &&
        _gradeController.text == _originalGradeLevel) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null) {
        // Process name update if changed
        if (_nameController.text != _originalName) {
          // For name updates, we'll use the database service directly
          final dbService = DatabaseService();
          
          if (dbService.isConnected) {
            // Update in MongoDB
            final collection = dbService.getCollection('users');
            
            // Create a query for the user by ID
            final userQuery = where.eq('idNumber', user.idNumber);
            
            // Update the name fields
            await collection.updateOne(
              userQuery,
              modify.set('name', _nameController.text).set('firstName', _nameController.text),
            );
          }
          
          // Always update in local database
          await dbService.saveUserDataLocally(
            idNumber: user.idNumber.toString(),
            name: _nameController.text,
            readingLevel: user.readingLevel,
          );
        }
        
        // Process reading level update if changed
        if (_gradeController.text != _originalGradeLevel) {
          // Map grade level back to reading level
          String readingLevel = user.readingLevel ?? '';
          switch(_gradeController.text.toLowerCase()) {
            case 'baitang isa':
              readingLevel = 'Emergent';
              break;
            case 'baitang dalawa':
              readingLevel = 'Early';
              break;
            case 'baitang tatlo':
              readingLevel = 'Fluent';
              break;
          }
          
          // Only update if it actually changed
          if (readingLevel != user.readingLevel && readingLevel.isNotEmpty) {
            // Remove await since updateUserReadingLevel is void, not a Future
            authProvider.updateUserReadingLevel(readingLevel);
          }
        }
        
        // Refresh the user data
        if (user.idNumber != null) {
          // Call login as a statement, not as an expression
          authProvider.login(user.idNumber.toString());
          
          // Add a small delay to allow the provider to update
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _loadUserData();
          }
        }
        
        setState(() {
          _isEditing = false;
          _originalName = _nameController.text;
          _originalGradeLevel = _gradeController.text;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving user data: $e';
      });
      print('Error saving user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Call the logout method
    authProvider.logout();
    
    // Navigate to login screen
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDarkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.amber),
              onPressed: _saveUserData,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.amber),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.amber,
                            width: 2.0,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/penguin.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Name field
                    const Text(
                      'Pangalan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
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
                    const Text(
                      'Antas ng Baitang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
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
                    const Text(
                      'Numero ng ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _idNumberController,
                        enabled: false, // ID Number is not editable
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
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
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 60),
                    
                    // Logout button
                    Center(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.logout, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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