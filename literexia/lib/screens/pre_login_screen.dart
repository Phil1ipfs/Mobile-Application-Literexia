// lib/screens/pre_login_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../config/router.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';
import '../Tutorial/Login_tutorial.dart';

class PreLoginScreen extends StatefulWidget {
  const PreLoginScreen({super.key});

  @override
  State<PreLoginScreen> createState() => _PreLoginScreenState();
}

class _PreLoginScreenState extends State<PreLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _snowflakeController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasSpokenIntro = false;
  bool _showTutorialButton =
      true; // Show tutorial button by default for new users
  bool _showLoginButton = false; // Hide login button by default for new users
  bool _showButtons = false; // Hide buttons until typewriter completes

  // Store references to providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  final String _introText =
      "Maligayang pagdating sa LITEREXIA! Ang app na ito ay idinisenyo para sa mga estudyanteng upang mahasa at matuto sa pag ta-tagalog.";

  // Typewriter effect for description
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedDescription = '';
  final String _fullDescriptionText =
      'Maligayang pagdating sa LITEREXIA! Ang app na ito ay idinisenyo para sa mga estudyante upang mahasa at matuto sa pag ta-tagalog.';

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
      scaleFactor = 1.4; // Larger tablets
    } else if (_isTablet) {
      scaleFactor = 1.2; // Regular tablets
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
    if (_isLargeTablet) return 40.0;
    if (_isTablet) return 32.0;
    return 24.0;
  }

  double get _responsiveButtonHeight {
    if (_isLargeTablet) return 60.0;
    if (_isTablet) return 55.0;
    return 50.0;
  }

  double get _responsiveAnimationHeight {
    if (_isLargeTablet) return 200.0;
    if (_isTablet) return 170.0;
    return 140.0;
  }

  double get _responsiveButtonWidth {
    if (_isLargeTablet) return 350.0;
    if (_isTablet) return 320.0;
    return 280.0;
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _snowflakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Initialize typewriter animation controller
    _typewriterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // Slow typewriter effect
    );

    // Initialize typewriter animation
    _typewriterAnimation = IntTween(
      begin: 0,
      end: _fullDescriptionText.length,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.linear,
    ));

    // Listen to animation changes
    _typewriterAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _displayedDescription =
              _fullDescriptionText.substring(0, _typewriterAnimation.value);
        });
      }
    });

    // Listen for animation completion
    _typewriterAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showButtons = true;
        });
      }
    });

    // Start fade animation when screen loads
    _fadeController.forward();

    // Check if user has completed tutorial before
    _checkTutorialStatus();

    // Start typewriter effect after fade animation completes
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _typewriterController.forward();
      }
    });

    // Speak intro text after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _speakIntroText();
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

  // Check if user has completed the tutorial before
  Future<void> _checkTutorialStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedTutorial =
          prefs.getBool('has_completed_login_tutorial') ?? false;

      if (mounted) {
        setState(() {
          _showTutorialButton =
              !hasCompletedTutorial; // Show tutorial for new users only
          _showLoginButton =
              hasCompletedTutorial; // Show login for users who completed tutorial
        });
      }

      print(
          '[PreLoginScreen] Tutorial status checked: hasCompleted=$hasCompletedTutorial, showTutorial=$_showTutorialButton, showLogin=$_showLoginButton');
    } catch (e) {
      print('[PreLoginScreen] Error checking tutorial status: $e');
      // Default to showing tutorial button if there's an error
      if (mounted) {
        setState(() {
          _showTutorialButton = true;
          _showLoginButton = false;
        });
      }
    }
  }

  // Mark tutorial as completed
  Future<void> _markTutorialAsCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_login_tutorial', true);
      print('[PreLoginScreen] Tutorial marked as completed');
    } catch (e) {
      print('[PreLoginScreen] Error saving tutorial status: $e');
    }
  }

  void _speakIntroText() {
    if (_hasSpokenIntro || !mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        _introText,
        speed: 0.4,
        onStart: () {
          if (mounted) {
            setState(() {
              _hasSpokenIntro = true;
            });
          }
        },
        onComplete: () {
          // Optional: Handle completion
        },
        onError: () {
          print('ElevenLabs TTS Error occurred while speaking intro');
        },
      );
    }
  }

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
    }
  }

  void _navigateToLogin() {
    _playButtonAudio();

    // Stop any ongoing TTS before navigating
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    // Navigate directly to Login Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToTutorial() {
    _playButtonAudio();

    // Stop any ongoing TTS before navigating
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    // Mark tutorial as completed when user clicks the tutorial button
    _markTutorialAsCompleted();

    // Navigate to Login Tutorial
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginTutorial()),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _snowflakeController.dispose();
    _typewriterController.dispose();
    _audioPlayer.dispose();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snowflake = Icon(Icons.ac_unit, color: Colors.white, size: 48);
    return Scaffold(
      backgroundColor: const Color(0xFF1C2B4E), // Dark blue background
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Stack(
            children: [
              // Snowflakes and Penguin
              Column(
                children: [
                  SizedBox(height: _responsiveSpacing * 1.3),
                  SizedBox(
                    height: _isTablet ? 100 : 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedBuilder(
                          animation: _snowflakeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset:
                                  Offset(0, 20 * _snowflakeController.value),
                              child: child,
                            );
                          },
                          child: snowflake,
                        ),
                        AnimatedBuilder(
                          animation: _snowflakeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset:
                                  Offset(0, -20 * _snowflakeController.value),
                              child: child,
                            );
                          },
                          child: snowflake,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: _responsiveSpacing),
                  // Penguin Lottie Animation
                  Center(
                    child: SizedBox(
                      height: _responsiveAnimationHeight,
                      child: Lottie.asset('assets/animations/penguin.json',
                          repeat: true),
                    ),
                  ),
                  SizedBox(height: _responsiveSpacing),
                  // App Name
                  Text(
                    'LITEREXIA',
                    style: TextStyle(
                      fontFamily: 'Snow Blue',
                      fontSize: _getResponsiveFontSize(42),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: _isTablet ? 6.0 : 4.0,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 3.0,
                          color: Colors.black.withOpacity(0.9),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: _responsiveSpacing),
                  // Description with typewriter effect
                  Padding(
                    padding: _responsivePadding,
                    child: AnimatedBuilder(
                      animation: _typewriterAnimation,
                      builder: (context, child) {
                        return Text(
                          _displayedDescription,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(16),
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  // Show tutorial button only for new users
                  if (_showTutorialButton)
                    Padding(
                      padding:
                          EdgeInsets.only(bottom: _responsiveSpacing * 1.5),
                      child: SizedBox(
                        width: _responsiveButtonWidth,
                        height: _responsiveButtonHeight,
                        child: ElevatedButton(
                          onPressed: _navigateToTutorial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            'Login Tutorial',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(20),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: _isTablet ? 3 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Login Button - only show for users who completed tutorial
                  if (_showLoginButton)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: _responsiveSpacing * 1.25,
                          top: _showTutorialButton
                              ? 0.0
                              : _responsiveSpacing * 0.7),
                      child: SizedBox(
                        width: _responsiveButtonWidth,
                        height: _responsiveButtonHeight,
                        child: ElevatedButton(
                          onPressed: _navigateToLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            'Mag Login',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(20),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: _isTablet ? 3 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: _responsiveSpacing * 1.25),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFF9D56E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    final clipPath = Path()..addRRect(rrect);
    canvas.saveLayer(rect, Paint());
    canvas.clipPath(clipPath);
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
