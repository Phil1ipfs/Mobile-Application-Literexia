// lib/features/auth/ui/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../config/router.dart';
import '../../../widgets/connection_status_widget.dart';
import 'package:rive/rive.dart';

import 'package:literexia/features/assessments/ui/assessment_question_screen.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDetailedStatus = false;
  bool _obscureId = true;
  bool _showAnimation = false;
  bool _hasValidationError = false;

  String _currentText = "";
  String _displayText = "";
  int _currentIndex = 0;
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;

  late AnimationController _fadeController;

  Artboard? _riveArtboard;
  StateMachineController? _controller;
  SMIBool? _isHandsUp;
  SMIBool? _isPrivateField;
  SMITrigger? _successTrigger;
  SMITrigger? _failTrigger;

  void _startTypewriterEffect() {
    // Cancel any existing timer
    _typewriterTimer?.cancel();

    // Reset the text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
    });

    // Get the full text
    final String fullText = "Maari mo bang ilagay ang iyong ID NUMBER?";

    // Start a timer to add one character at a time
    _typewriterTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_currentIndex < fullText.length) {
        setState(() {
          _displayText = fullText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing is complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });
      }
    });
  }

  void _loadRiveFile() async {
    try {
      final data = await rootBundle.load('assets/rive/penguin_login.riv');
      final file = RiveFile.import(data);

      setState(() {
        _riveArtboard = file.mainArtboard;
      });

      var controller = StateMachineController.fromArtboard(
        _riveArtboard!,
        'Login Machine',
      );

      if (controller != null) {
        _riveArtboard!.addController(controller);
        _controller = controller;

        _isHandsUp = controller.findSMI('isFocus') as SMIBool?;
        _isPrivateField = controller.findSMI('isPrivateField') as SMIBool?;
        _successTrigger = controller.findSMI('successTrigger') as SMITrigger?;
        _failTrigger = controller.findSMI('failTrigger') as SMITrigger?;

        // Set initial states
        if (_isHandsUp != null) {
          _isHandsUp!.value = false;
        }
        if (_isPrivateField != null) {
          _isPrivateField!.value = false;
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadRiveFile();

    // Start typewriter effect after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startTypewriterEffect();
        setState(() {
          _showAnimation = true;
        });
        _fadeController.forward();
      }
    });
  }

  void _updateAnimationState(String text) {
    if (_currentText != text) {
      _currentText = text;

      if (_hasValidationError) {
        setState(() {
          _hasValidationError = false;
          _errorMessage = null;
        });
      }

      if (_isHandsUp != null) {
        _isHandsUp!.value = text.isNotEmpty;
      }

      if (_isPrivateField != null) {
        _isPrivateField!.value = _obscureId && text.isNotEmpty;
      }
    }
  }

  // Update the _validateInput method to use the improved _triggerFailAnimation
  bool _validateInput(String text) {
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your ID number';
        _hasValidationError = true;
      });
      _triggerFailAnimation('empty input');
      return false;
    }

    if (int.tryParse(text) == null) {
      setState(() {
        _errorMessage = 'ID must be a valid number';
        _hasValidationError = true;
      });
      _triggerFailAnimation('non-numeric input');
      return false;
    }

    if (text.length < 4) {
      setState(() {
        _errorMessage = 'ID must be at least 4 digits';
        _hasValidationError = true;
      });
      _triggerFailAnimation('too short input');
      return false;
    }

    return true;
  }

  // Add these two methods for improved animation triggering
  void _triggerFailAnimation(String reason) {
    if (_failTrigger != null) {
      _failTrigger!.fire();
    }
  }

  void _triggerSuccessAnimation() {
    if (_successTrigger != null) {
      _successTrigger!.fire();
    }
  }

  // Update the _login method to use the new trigger methods
  Future<void> _login() async {
    String idNumber = _idController.text.trim();

    // Validate input before proceeding
    if (!_validateInput(idNumber)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.login(idNumber);

      if (success && mounted) {
        // Trigger success animation
        _triggerSuccessAnimation();

        // Add a small delay to let the animation play
        await Future.delayed(const Duration(milliseconds: 1000));

        // Create assessment provider
        final assessmentProvider = AssessmentProvider();

        // Navigate to PreAssessmentQuestionScreen with a default assessmentId of 1
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => ChangeNotifierProvider.value(
                  value: assessmentProvider,
                  child: PreAssessmentQuestionScreen(
                    assessmentId: 1, // Replace with appropriate assessment ID
                    provider: assessmentProvider,
                    onAssessmentComplete: (readingLevel, score, total) {
                      // Handle assessment completion, e.g., save to user profile
                      print(
                        'Pre-Assessment completed: Level=$readingLevel, Score=$score/$total',
                      );
                      // You can navigate to home or another screen here if needed
                    },
                  ),
                ),
          ),
        );
      } else if (mounted) {
        // Trigger fail animation
        _triggerFailAnimation('login failed');

        // Show detailed error message
        setState(() {
          _errorMessage =
              authProvider.errorMessage ??
              'Login failed. ID not found in database.';
          _hasValidationError = true;
          _showDetailedStatus = true;
        });
      }
    } catch (e) {
      if (mounted) {
        // Trigger fail animation
        _triggerFailAnimation('login exception');

        setState(() {
          _errorMessage = 'Error: $e';
          _hasValidationError = true;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(AppRouter.splash);
          },
        ),
        title: null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center content vertically
              children: [
                // Speech bubble with typewriter text
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color:
                        _hasValidationError
                            ? const Color(0xFFAA3333)
                            : const Color(0xFF4D4D4D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Text(
                    _hasValidationError
                        ? (_errorMessage ??
                            'Something is wrong with your input')
                        : _displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 5), // Minimal spacing
                // Penguin animation - reduced size
                Container(
                  height:
                      180, // Fixed height instead of Expanded to reduce size
                  child: AnimatedOpacity(
                    opacity: _showAnimation ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child:
                        _riveArtboard != null
                            ? Rive(
                              artboard: _riveArtboard!,
                              fit: BoxFit.contain,
                            )
                            : const Center(child: CircularProgressIndicator()),
                  ),
                ),

                const SizedBox(height: 25), // Minimal spacing
                // ID Number text field
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: TextField(
                    controller: _idController,
                    obscureText: _obscureId,
                    keyboardType: TextInputType.number,
                    onChanged: (text) {
                      _updateAnimationState(text);
                    },
                    decoration: InputDecoration(
                      hintText: 'ID Number',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ), // Reduced padding
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureId ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureId = !_obscureId;
                            if (_isPrivateField != null &&
                                _idController.text.isNotEmpty) {
                              _isPrivateField!.value = _obscureId;
                            }
                          });
                        },
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 50), // Minimal spacing
                // Continue button
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCC00),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reduced padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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
                ),

                // Help text for students without accounts
                const SizedBox(height: 20), // Minimal spacing
                const Text(
                  'No account yet? Please see your administrator.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _fadeController.dispose();
    _typewriterTimer?.cancel();
    if (_controller != null && _riveArtboard != null) {
      _riveArtboard?.removeController(_controller!);
    }
    super.dispose();
  }
}
