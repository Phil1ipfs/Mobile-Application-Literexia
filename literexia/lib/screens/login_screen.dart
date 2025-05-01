// lib/features/auth/ui/login_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../../config/router.dart';
import '../../../widgets/connection_status_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDetailedStatus = false;

  @override
  void initState() {
    super.initState();
    // For debugging - pre-fill with test user
    // _idController.text = '123456'; // Uncomment for testing
  }

  Future<void> _login() async {
    String idNumber = _idController.text.trim();

    if (idNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your ID number';
      });
      return;
    }

    // Validate ID is numeric
    if (int.tryParse(idNumber) == null) {
      setState(() {
        _errorMessage = 'ID must be a valid number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Add debug print statements
      print('[LoginScreen] Attempting login with ID: $idNumber');

      final success = await authProvider.login(idNumber);

      print('[LoginScreen] Login result: $success');
      print('[LoginScreen] Component mounted: $mounted');
      print('[LoginScreen] Home route: ${AppRouter.home}');

      if (success && mounted) {
        print('[LoginScreen] Navigating to home screen');

        // Add a small delay to ensure state is updated
        await Future.delayed(Duration(milliseconds: 100));

        // Navigate to home screen on successful login
        Navigator.of(context).pushReplacementNamed(AppRouter.home);

        print('[LoginScreen] Navigation completed');
      } else if (mounted) {
        print('[LoginScreen] Login failed, showing error');
        print('[LoginScreen] Error message: ${authProvider.errorMessage}');

        // Show detailed error message
        setState(() {
          _errorMessage =
              authProvider.errorMessage ??
              'Login failed. ID not found in database.';
          // Toggle detailed status to show connection info
          _showDetailedStatus = true;
        });
      }
    } catch (e) {
      print('[LoginScreen] Login error: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          // Toggle detailed status to help with debugging
          _showDetailedStatus = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF334970), // Dark blue background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Literexia Login'),
        actions: [
          // Database connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showDetailedStatus = !_showDetailedStatus;
                });
              },
              child: const ConnectionStatusWidget(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Show detailed status widget when toggled
          if (_showDetailedStatus)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: ConnectionStatusWidget(showDetailedStatus: true),
            ),

          // Main login content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Penguin image
                      Image.asset(
                        'assets/images/penguin.png',
                        height: 150,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            width: 150,
                            color: Colors.grey.withOpacity(0.3),
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      // Speech bubble with text
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D4D4D), // Gray speech bubble
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: const Text(
                          'Maari mo bang ilagay ang iyong ID NUMBER?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ID Number text field
                      TextField(
                        controller: _idController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          hintText: 'Enter ID Number',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                          // Show error message if any
                          errorText: _errorMessage,
                          errorStyle: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _login(),
                      ),

                      const SizedBox(height: 30),

                      // Continue button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size(double.infinity, 60),
                        ),
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                                : const Text(
                                  'MAGPATULOY',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                      ),

                      // Help text for students without accounts
                      const SizedBox(height: 20),
                      const Text(
                        'No account yet? Please see your administrator.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),

                      // Debug info in development mode
                      if (const bool.fromEnvironment('dart.vm.product') ==
                          false)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            'Note: Login now expects integer IDs (123456)',
                            style: TextStyle(
                              color: Colors.amber.withOpacity(0.6),
                              fontSize: 12,
                            ),
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
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }
}
