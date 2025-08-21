// lib/features/auth/ui/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../config/router.dart';
import 'package:rive/rive.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_intro_screen.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
  bool _hasSpokenText = false;
  final String _promptText = "Maari mo bang ilagay ang iyong ID NUMBER?";

  late AnimationController _fadeController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Store references to providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  Artboard? _riveArtboard;
  StateMachineController? _controller;
  SMIBool? _isHandsUp;
  SMIBool? _isPrivateField;
  SMITrigger? _successTrigger;
  SMITrigger? _failTrigger;

  bool _obscureText = true;
  bool _showTutorial = true;

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
    }
  }

  void _speakPromptText() {
    if (_hasSpokenText || !mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        _promptText,
        speed: 0.4, // Explicitly set slower speed
        onStart: () {
          if (mounted) {
            setState(() {
              _hasSpokenText = true;
            });
          }
        },
        onComplete: () {
          // Optional: Handle completion
        },
        onError: () {
          // Handle error silently
          print('TTS Error occurred');
        },
      );
    } else {
      print(
          'TTS not available or enabled. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
    }
  }

  void _startTypewriterEffect() {
    // Cancel any existing timer
    _typewriterTimer?.cancel();

    // Reset the text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
      _hasSpokenText = false;
    });

    // Start a timer to add one character at a time
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex < _promptText.length) {
        setState(() {
          _displayText = _promptText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing is complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });

        // Small delay before speaking to ensure visual effect is complete
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _speakPromptText();
          }
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

    // Start typewriter effect after providers are initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startTypewriterEffect();
        setState(() {
          _showAnimation = true;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references safely during widget lifecycle
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
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
        _isPrivateField!.value = _obscureText && text.isNotEmpty;
      }
    }
  }

  // Keep the working validation logic from the second file
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

  // Keep the working login logic from the second file
  Future<void> _login() async {
    String idNumber = _idController.text.trim();

    // Validate input before proceeding
    if (!_validateInput(idNumber)) {
      return;
    }

    // Play button audio
    _playButtonAudio();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check database connection status
    final dbService = DatabaseService();
    final isConnected = dbService.isConnected;
    final connectionError = dbService.connectionError;

    print('DB Connected: $isConnected');
    print('DB Error: $connectionError');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.login(idNumber);

      if (success && mounted) {
        // Trigger success animation
        _triggerSuccessAnimation();

        // Add a small delay to let the animation play
        await Future.delayed(const Duration(milliseconds: 1000));

        // Stop any ongoing TTS before navigating
        if (_ttsProvider != null) {
          _ttsProvider!.stopSpeaking();
        }

        // Navigate based on whether the user has a reading level
        final user = authProvider.currentUser;
        if (user != null) {
          // Check if reading level is set - handle it safely in case the field doesn't exist yet
          final hasCompletedAssessment = user.preAssessmentCompleted == true ||
              (user.readingLevel != null && user.readingLevel!.isNotEmpty);

          if (hasCompletedAssessment) {
            // If they have a reading level, go to home
            Navigator.of(context).pushReplacementNamed(AppRouter.home);
          } else {
            // Navigate to PreAssessmentIntroScreen using named route
            Navigator.of(context).pushReplacementNamed(
              AppRouter.preAssessmentIntro,
              arguments: {'assessmentId': 1},
            );
          }
        } else {
          // Fallback - navigate to intro screen as well
          Navigator.of(context).pushReplacementNamed(
            AppRouter.preAssessmentIntro,
            arguments: {'assessmentId': 1},
          );
        }
      } else if (mounted) {
        // Trigger fail animation
        _triggerFailAnimation('login failed');

        // Show detailed error message
        setState(() {
          _errorMessage = authProvider.errorMessage ??
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
      backgroundColor: const Color(0xFF334970), // Fixed dark blue background - no theme changes
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Stop any ongoing TTS before navigating
            if (_ttsProvider != null) {
              _ttsProvider!.stopSpeaking();
            }

            Navigator.of(context).pushReplacementNamed(AppRouter.splash);
          },
        ),
        title: null,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center content vertically
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          painter: _SpeechBubblePainter(
                            color: _hasValidationError
                                ? const Color(0xFFAA3333)
                                : const Color(0xFF4D4D4D),
                            borderColor: Colors.white,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _hasValidationError
                                  ? (_errorMessage ?? 'Something is wrong with your input')
                                  : _displayText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5), // Minimal spacing
                    // Penguin animation - reduced size
                    SizedBox(
                      height: 180, // Fixed height instead of Expanded to reduce size
                      child: AnimatedOpacity(
                        opacity: _showAnimation ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: _riveArtboard != null
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
                      key: const ValueKey('tutorial_input'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15), // adjust as needed
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _idController,
                        obscureText: _obscureText,
                        keyboardType: TextInputType.number,
                        onChanged: (text) => _updateAnimationState(text),
                        decoration: InputDecoration(
                          hintText: 'LRN NUMBER',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            letterSpacing: 4,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                                if (_isPrivateField != null &&
                                    _idController.text.isNotEmpty) {
                                  _isPrivateField!.value = _obscureText;
                                }
                              });
                            },
                          ),
                        ),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 50), // Minimal spacing
                    // Continue button
                    Stack(
                      children: [
                        // Drop shadow (outside)
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 22,
                                offset: Offset(0, 7), // y: 7 for drop shadow
                              ),
                            ],
                          ),
                        ),
                        // Inner shadow (inside)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _InnerShadowPainter(
                                color: Colors.black.withOpacity(0.18),
                                offset: Offset(0, 7), // y: -7 for inner shadow
                                blur: 22,
                                borderRadius: 30,
                              ),
                            ),
                          ),
                        ),
                        // The button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFCC00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
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
                      ],
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
            // Tutorial overlay
            if (_showTutorial)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Stack(
                    children: [
                      // Animated arrow
                      Positioned(
                        left: 40,
                        top: MediaQuery.of(context).size.height * 0.38,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 10),
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, value),
                              child: child,
                            );
                          },
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 48,
                            color: Colors.yellowAccent,
                          ),
                        ),
                      ),
                      // Hint text
                      Positioned(
                        left: 30,
                        top: MediaQuery.of(context).size.height * 0.38 - 60,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Ilagay ang iyong LRN Number dito',
                            style: TextStyle(
                              fontFamily: 'Century Gothic',
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Dismiss button
                      Positioned(
                        right: 30,
                        bottom: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow[700],
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _showTutorial = false;
                            });
                          },
                          child: const Text(
                            'Got it!',
                            style: TextStyle(
                              fontFamily: 'Century Gothic',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _fadeController.dispose();
    _typewriterTimer?.cancel();
    _audioPlayer.dispose();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    if (_controller != null && _riveArtboard != null) {
      _riveArtboard?.removeController(_controller!);
    }
    super.dispose();
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _SpeechBubblePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = 10.0;
    final double tailBaseWidth = 30.0;
    final double tailHeight = 20.0;
    
    // Position the tail on the bottom right area
    final double tailStartX = size.width * 0.35; // Move start further left
    final double tailEndX = tailStartX + tailBaseWidth;
    final double tailTipX = size.width * 0.52; // Move tip further left
    final double tailTipY = size.height + tailHeight;

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Create the main bubble path with curved tail
    final Path bubblePath = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(Offset(size.width - radius, size.height), radius: Radius.circular(radius))
      
      // Right side to start of tail
      ..lineTo(tailEndX, size.height)
      
      // Create curved tail using quadratic bezier
      ..quadraticBezierTo(
        tailEndX + 5, size.height + 5, // Control point for smooth curve
        tailTipX, tailTipY, // End point (tip of tail)
      )
      
      // Curve back to the left side of tail base
      ..quadraticBezierTo(
        tailStartX + 10, size.height + 8, // Control point for return curve
        tailStartX, size.height, // Back to bubble bottom
      )
      
      // Continue with left side of bubble
      ..lineTo(radius, size.height)
      ..arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius))
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..close();

    canvas.drawPath(bubblePath, fillPaint);
    canvas.drawPath(bubblePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnerShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blur;
  final double borderRadius;

  _InnerShadowPainter({
    required this.color,
    required this.offset,
    required this.blur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final Paint shadowPaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    final Path outer = Path()..addRRect(rrect);
    final Path inner = Path()
      ..addRRect(rrect.deflate(1))
      ..close();

    canvas.saveLayer(rect, Paint());
    canvas.translate(offset.dx, offset.dy);
    canvas.drawPath(outer, shadowPaint);
    canvas.translate(-offset.dx, -offset.dy);
    canvas.drawPath(inner, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}