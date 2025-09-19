// lib/features/auth/ui/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import '../../../config/router.dart';
import 'package:rive/rive.dart' as rive;
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Controllers and basic state
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasValidationError = false;
  bool _obscureText = false;

  // Network state
  bool _hasNetworkConnection = true;
  bool _isCheckingNetwork = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Animation and visual state
  bool _showAnimation = false;
  late AnimationController _fadeController;

  // Typewriter effect state
  String _displayText = "";
  int _currentIndex = 0;
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;
  bool _hasSpokenText = false;
  final String _promptText = "Maari mo bang ilagay ang iyong ID NUMBER?";

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Rive animation state
  rive.Artboard? _riveArtboard;
  rive.StateMachineController? _controller;
  rive.SMIBool? _isHandsUp;
  rive.SMIBool? _isPrivateField;
  rive.SMITrigger? _successTrigger;
  rive.SMITrigger? _failTrigger;

  // Providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  // Responsive design utilities
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;
  bool get _isTablet => _screenWidth >= 768;
  bool get _isLargeTablet => _screenWidth >= 1024;
  bool get _isMobile => _screenWidth < 768;

  // Platform-specific checks
  bool get _isIOS => Platform.isIOS;
  bool get _isAndroid => Platform.isAndroid;

  // Responsive font sizes
  double _getResponsiveFontSize(double baseFontSize) {
    double scaleFactor = 1.0;

    if (_isLargeTablet) {
      scaleFactor = 1.5; // Larger tablets
    } else if (_isTablet) {
      scaleFactor = 1.3; // Regular tablets
    } else if (_isMobile && _screenWidth < 400) {
      scaleFactor = 0.9; // Small phones
    }

    return baseFontSize * scaleFactor;
  }

  // Responsive padding and spacing
  EdgeInsets get _responsivePadding {
    if (_isLargeTablet) return const EdgeInsets.symmetric(horizontal: 60.0);
    if (_isTablet) return const EdgeInsets.symmetric(horizontal: 40.0);
    return const EdgeInsets.symmetric(horizontal: 24.0);
  }

  double get _responsiveSpacing {
    if (_isLargeTablet) return 35.0;
    if (_isTablet) return 30.0;
    return 25.0;
  }

  double get _responsiveButtonHeight {
    if (_isLargeTablet) return 70.0;
    if (_isTablet) return 65.0;
    return 56.0;
  }

  double get _responsiveAnimationHeight {
    if (_isLargeTablet) return 240.0;
    if (_isTablet) return 210.0;
    return 180.0;
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Load Rive animation
    _loadRiveAnimation();

    // Set up focus listener for animation
    _idFocusNode.addListener(_onFocusChange);

    // Initialize network monitoring
    _initializeNetworkMonitoring();

    // Start initial animations after frame is built
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
    // Get provider references
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
  }

  // ANIMATION METHODS

  void _loadRiveAnimation() async {
    try {
      final data = await rootBundle.load('assets/rive/penguin_login.riv');
      final file = rive.RiveFile.import(data);

      if (mounted) {
        setState(() {
          _riveArtboard = file.mainArtboard;
        });

        var controller = rive.StateMachineController.fromArtboard(
          _riveArtboard!,
          'Login Machine',
        );

        if (controller != null) {
          _riveArtboard!.addController(controller);
          _controller = controller;

          // Get animation triggers and states
          _isHandsUp = controller.findSMI('isFocus') as rive.SMIBool?;
          _isPrivateField =
              controller.findSMI('isPrivateField') as rive.SMIBool?;
          _successTrigger =
              controller.findSMI('successTrigger') as rive.SMITrigger?;
          _failTrigger = controller.findSMI('failTrigger') as rive.SMITrigger?;

          // Set initial states
          _isHandsUp?.value = false;
          _isPrivateField?.value = false;
        }
      }
    } catch (e) {
      debugPrint('Error loading Rive animation: $e');
    }
  }

  void _onFocusChange() {
    // Update animation when focus changes
    if (_isHandsUp != null) {
      _isHandsUp!.value = _idFocusNode.hasFocus;
    }

    // Update private field state based on text and obscure setting
    _updatePrivateFieldState();
  }

  void _updatePrivateFieldState() {
    if (_isPrivateField != null && _idController.text.isNotEmpty) {
      _isPrivateField!.value = _obscureText;
    }
  }

  void _startTypewriterEffect() {
    // Cancel existing timer if any
    _typewriterTimer?.cancel();

    // Reset text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
      _hasSpokenText = false;
    });

    // Start timer to add characters one by one
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex < _promptText.length) {
        setState(() {
          _displayText = _promptText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });

        // Speak text after small delay
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _speakPromptText();
          }
        });
      }
    });
  }

  // NETWORK MONITORING METHODS

  void _initializeNetworkMonitoring() async {
    // Check initial connection status
    await _checkNetworkConnection();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _handleConnectivityChange(result);
      },
    );
  }

  Future<void> _checkNetworkConnection() async {
    setState(() {
      _isCheckingNetwork = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = await _testNetworkQuality();

      if (mounted) {
        setState(() {
          _hasNetworkConnection =
              connectivityResult != ConnectivityResult.none && hasConnection;
          _isCheckingNetwork = false;
        });
      }
    } catch (e) {
      print('Error checking network connection: $e');
      if (mounted) {
        setState(() {
          _hasNetworkConnection = false;
          _isCheckingNetwork = false;
        });
      }
    }
  }

  Future<bool> _testNetworkQuality() async {
    try {
      // Test network quality by making a quick HTTP request with timeout
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('https://www.google.com'));
      final response = await request.close().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Network test timeout'),
          );

      client.close();

      // Consider connection good if we get any response
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      print('Network quality test failed: $e');
      return false;
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (mounted) {
      if (result == ConnectivityResult.none) {
        setState(() {
          _hasNetworkConnection = false;
        });
        _showNetworkError('No internet connection detected');
      } else {
        // When connectivity is restored, test the quality
        _checkNetworkConnection().then((_) {
          // If connection is restored and there was a previous error, clear it
          if (_hasNetworkConnection && _hasValidationError) {
            setState(() {
              _hasValidationError = false;
              _errorMessage = null;
              _startTypewriterEffect(); // Reset to prompt text
            });

            // Speak positive feedback
            if (_ttsProvider != null && _ttsProvider!.isAvailable) {
              _ttsProvider!.speakText(
                'Internet connection restored. You can try logging in now.',
                speed: 0.4,
              );
            }
          }
        });
      }
    }
  }

  void _showNetworkError(String message) {
    setState(() {
      _errorMessage = message;
      _hasValidationError = true;
    });
    _triggerFailAnimation();

    // Speak the error message if TTS is available
    if (_ttsProvider != null && _ttsProvider!.isAvailable) {
      _ttsProvider!.speakText(
        'Network connection problem. Please check your internet connection.',
        speed: 0.4,
      );
    }
  }

  // AUDIO AND TTS METHODS

  void _speakPromptText() {
    if (_hasSpokenText || !mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        _promptText,
        speed: 0.4, // Slower speed for better understanding
        onStart: () {
          if (mounted) {
            setState(() {
              _hasSpokenText = true;
            });
          }
        },
        onComplete: () {
          // Focus on input field after speech completes
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _idFocusNode.requestFocus();
            });
          }
        },
        onError: () {
          debugPrint('TTS Error occurred');
        },
      );
    } else {
      debugPrint('TTS not available or enabled');
    }
  }

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  // INPUT VALIDATION

  bool _validateInput(String text) {
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your ID number';
        _hasValidationError = true;
      });
      _triggerFailAnimation();
      return false;
    }

    if (int.tryParse(text) == null) {
      setState(() {
        _errorMessage = 'ID must be a valid number';
        _hasValidationError = true;
      });
      _triggerFailAnimation();
      return false;
    }

    if (text.length < 4) {
      setState(() {
        _errorMessage = 'ID must be at least 4 digits';
        _hasValidationError = true;
      });
      _triggerFailAnimation();
      return false;
    }

    return true;
  }

  void _updateAnimationState(String text) {
    if (_isHandsUp != null) {
      _isHandsUp!.value = text.isNotEmpty || _idFocusNode.hasFocus;
    }

    if (_isPrivateField != null) {
      _isPrivateField!.value = _obscureText && text.isNotEmpty;
    }

    // Clear error when user types
    if (_hasValidationError && text.isNotEmpty) {
      setState(() {
        _hasValidationError = false;
        _errorMessage = null;
        _startTypewriterEffect(); // Reset to prompt text
      });
    }
  }

  // ANIMATION TRIGGERS

  void _triggerFailAnimation() {
    _failTrigger?.fire();

    // Add haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _triggerSuccessAnimation() {
    _successTrigger?.fire();

    // Add haptic feedback
    HapticFeedback.lightImpact();
  }

  // LOGIN LOGIC

  Future<void> _login() async {
    String idNumber = _idController.text.trim();

    // Validate input
    if (!_validateInput(idNumber)) {
      return;
    }

    // Check network connection first
    if (!_hasNetworkConnection) {
      await _checkNetworkConnection(); // Double-check network status
    }

    if (!_hasNetworkConnection) {
      _showNetworkError('Please check your internet connection and try again.');
      return;
    }

    // Play button audio
    _playButtonAudio();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasValidationError = false;
    });

    // Check database connection
    final dbService = DatabaseService();
    final isConnected = dbService.isConnected;

    if (!isConnected) {
      setState(() {
        _errorMessage =
            'Database connection error. Please check your internet connection.';
        _hasValidationError = true;
        _isLoading = false;
      });
      _triggerFailAnimation();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Add timeout to the login attempt
      final success = await authProvider.login(idNumber).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Login request timed out. Please check your connection and try again.',
              const Duration(seconds: 15));
        },
      );

      if (success && mounted) {
        // Trigger success animation
        _triggerSuccessAnimation();

        // Delay to show animation
        await Future.delayed(const Duration(milliseconds: 1000));

        // Stop TTS before navigation
        _ttsProvider?.stopSpeaking();

        // Navigate based on assessment status
        final user = authProvider.currentUser;
        if (user != null) {
          final hasCompletedAssessment = user.preAssessmentCompleted == true ||
              (user.readingLevel != null && user.readingLevel!.isNotEmpty);

          if (hasCompletedAssessment) {
            Navigator.of(context).pushReplacementNamed(AppRouter.home);
          } else {
            Navigator.of(context).pushReplacementNamed(
              AppRouter.preAssessmentIntro,
              arguments: {'assessmentId': 1},
            );
          }
        } else {
          // Fallback navigation
          Navigator.of(context).pushReplacementNamed(
            AppRouter.preAssessmentIntro,
            arguments: {'assessmentId': 1},
          );
        }
      } else if (mounted) {
        // Handle login failure
        _triggerFailAnimation();

        setState(() {
          _errorMessage = authProvider.errorMessage ??
              'Login failed. ID not found in database.';
          _hasValidationError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        _triggerFailAnimation();

        String errorMessage;
        if (e is TimeoutException) {
          errorMessage =
              'Connection timeout. Please check your internet connection and try again.';
          // Update network status
          await _checkNetworkConnection();
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection') ||
            e.toString().contains('timeout')) {
          errorMessage =
              'Network connection error. Please check your internet and try again.';
          await _checkNetworkConnection();
        } else {
          errorMessage = 'Login error. Please try again.';
        }

        setState(() {
          _errorMessage = errorMessage;
          _hasValidationError = true;
        });

        // Speak error message if TTS is available
        if (_ttsProvider != null && _ttsProvider!.isAvailable) {
          _ttsProvider!.speakText(
            'Connection problem. Please check your internet connection.',
            speed: 0.4,
          );
        }
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
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF1C2B4E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: _responsivePadding,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Speech bubble
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          painter: SpeechBubblePainter(
                            color: _hasValidationError
                                ? const Color(0xFFAA3333)
                                : const Color(0xFF4D4D4D),
                            borderColor: Colors.white,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                vertical: _isTablet ? 24 : 18,
                                horizontal: _isTablet ? 28 : 20),
                            margin: EdgeInsets.symmetric(
                                horizontal: _isTablet ? 30 : 20),
                            child: Text(
                              _hasValidationError
                                  ? (_errorMessage ??
                                      'Something is wrong with your input')
                                  : _displayText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _getResponsiveFontSize(18),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: _responsiveSpacing * 0.2),

                    // Penguin animation
                    SizedBox(
                      height: _responsiveAnimationHeight,
                      child: AnimatedOpacity(
                        opacity: _showAnimation ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: _riveArtboard != null
                            ? rive.Rive(
                                artboard: _riveArtboard!,
                                fit: BoxFit.contain,
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),

                    SizedBox(height: _responsiveSpacing),

                    // ID input field with enhanced styling
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                        focusNode: _idFocusNode,
                        obscureText: _obscureText,
                        keyboardType: TextInputType.number,
                        onChanged: (text) => _updateAnimationState(text),
                        decoration: InputDecoration(
                          hintText: 'LRN NUMBER',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            letterSpacing: _isTablet ? 6 : 4,
                            fontWeight: FontWeight.w500,
                            fontSize: _getResponsiveFontSize(16),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: _isTablet ? 32 : 24,
                              vertical: _isTablet ? 24 : 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                                _updatePrivateFieldState();
                              });
                            },
                          ),
                        ),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: _getResponsiveFontSize(18),
                          letterSpacing: _isTablet ? 6 : 4,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: _responsiveSpacing * 2),

                    // Login button with enhanced styling
                    Stack(
                      children: [
                        // Drop shadow effect
                        Container(
                          width: double.infinity,
                          height: _responsiveButtonHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(199, 255, 204, 0),
                                offset: Offset(0, 4.5),
                                blurRadius: 0,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),

                        // Button with animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: _responsiveButtonHeight,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 255, 204, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                  vertical: _isTablet ? 16 : 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    'MAG LOGIN',
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(18),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      letterSpacing: 2,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: _responsiveSpacing * 0.8),

                    // Help text with slight animation
                    AnimatedOpacity(
                      opacity: _showAnimation ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        'No account yet? Please contact your administrator.',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: _getResponsiveFontSize(14)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up resources
    _idController.dispose();
    _idFocusNode.dispose();
    _fadeController.dispose();
    _typewriterTimer?.cancel();
    _audioPlayer.dispose();

    // Stop TTS
    _ttsProvider?.stopSpeaking();

    // Clean up network subscription
    _connectivitySubscription?.cancel();

    // Clean up Rive animation
    if (_controller != null && _riveArtboard != null) {
      _riveArtboard?.removeController(_controller!);
    }

    super.dispose();
  }
}

// Custom painters for visual effects

class SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  SpeechBubblePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = 10.0;
    final double tailBaseWidth = 30.0;
    final double tailHeight = 20.0;

    // Position tail on bottom
    final double tailStartX = size.width * 0.35;
    final double tailEndX = tailStartX + tailBaseWidth;
    final double tailTipX = size.width * 0.52;
    final double tailTipY = size.height + tailHeight;

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Create bubble path with curved tail
    final Path bubblePath = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(Offset(size.width - radius, size.height),
          radius: Radius.circular(radius))
      ..lineTo(tailEndX, size.height)
      ..quadraticBezierTo(
        tailEndX + 5,
        size.height + 5,
        tailTipX,
        tailTipY,
      )
      ..quadraticBezierTo(
        tailStartX + 10,
        size.height + 8,
        tailStartX,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(Offset(0, size.height - radius),
          radius: Radius.circular(radius))
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..close();

    canvas.drawPath(bubblePath, fillPaint);
    canvas.drawPath(bubblePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is SpeechBubblePainter &&
      (oldDelegate.color != color || oldDelegate.borderColor != borderColor);
}

class InnerShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blur;
  final double borderRadius;

  InnerShadowPainter({
    required this.color,
    required this.offset,
    required this.blur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Create the shadow paint
    final Paint shadowPaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    // Save the canvas state
    canvas.saveLayer(rect, Paint());

    // Clip to the button shape
    canvas.clipRRect(rrect);

    // Create an expanded rectangle for the shadow source
    final expandedRect = rect.inflate(blur * 2);
    final expandedRRect = RRect.fromRectAndRadius(
        expandedRect, Radius.circular(borderRadius + blur * 2));

    // Translate canvas for shadow offset
    canvas.translate(offset.dx, offset.dy);

    // Draw the shadow
    canvas.drawRRect(expandedRRect, shadowPaint);

    // Reset translation
    canvas.translate(-offset.dx, -offset.dy);

    // Cut out the button area to create inner shadow effect
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);

    // Restore canvas
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
