// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import '../config/router.dart';
import '../features/auth/logic/auth_provider.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  final List<Animation<double>> _letterAnimations = [];
  final String title = 'LITEREXIA';
  bool _titleSpoken = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Store references to providers
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
      scaleFactor = 1.6; // Larger tablets
    } else if (_isTablet) {
      scaleFactor = 1.3; // Regular tablets
    } else if (_isMobile && _screenWidth < 400) {
      scaleFactor = 0.9; // Small phones
    }
    
    return baseFontSize * scaleFactor;
  }

  @override
  void initState() {
    super.initState();

    // Controller for letter bounce animations
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Controller for fade-in of the entire title
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create individual animations for each letter with proper intervals
    // The key fix: ensure all intervals remain within 0.0-1.0 range
    final int letterCount = title.length;
    final double maxInterval =
        0.85; // Leave room for the last letter to complete
    final double intervalStep = maxInterval / letterCount;

    for (int i = 0; i < letterCount; i++) {
      final double begin = i * intervalStep;
      // Ensure the end value never exceeds 1.0
      final double end = begin + (intervalStep * 2.0);
      final double safeEnd = end.clamp(0.0, 0.95); // Clamp to valid range

      final Animation<double> letterAnimation = CurvedAnimation(
        parent: _bounceController,
        curve: Interval(begin, safeEnd, curve: Curves.easeOutQuad),
      );

      _letterAnimations.add(letterAnimation);
    }

    // Setup animation sequence
    _fadeController.forward().then((_) {
      _bounceController.forward().then((_) {
        _playBounceAudio();

        // Speak the title after animation completes
        _speakTitle();
      });
    });

    // Navigate after delay
    _navigateToNextScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references safely during widget lifecycle
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
  }

  void _speakTitle() {
    if (_titleSpoken || !mounted) return;

    // Small delay to ensure audio doesn't overlap with bounce sound
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // Check if TTS is available and enabled
      if (_ttsProvider != null &&
          _ttsProvider!.isAvailable &&
          _themeProvider != null &&
          _themeProvider!.textToSpeechEnabled) {
        // Use phonetic spelling for correct pronunciation with ElevenLabs
        const String phoneticTitle =
            "lihterexia"; // Phonetic spelling for proper pronunciation

        _ttsProvider!.speakText(
          phoneticTitle,
          speed: 0.4, // Use slower speed for better clarity
          onStart: () {
            if (mounted) {
              setState(() {
                _titleSpoken = true;
              });
            }
          },
          onComplete: () {
            // Optional: Handle completion
          },
          onError: () {
            print('ElevenLabs TTS Error occurred while speaking title');
          },
        );
      } else {
        print(
            'ElevenLabs TTS not available or enabled for title. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
      }
    });
  }

  void _playBounceAudio() async {
    // Audio removed - no longer playing soundwalkcartoon mp3
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    super.dispose();
  }

  void _navigateToNextScreen() async {
    // Delay for the splash screen - 10 seconds as per original
    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      // Stop any ongoing TTS before navigating
      if (_ttsProvider != null) {
        _ttsProvider!.stopSpeaking();
      }

      // Check authentication status and navigate accordingly
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        final hasCompletedAssessment = user.preAssessmentCompleted == true ||
            (user.readingLevel != null && user.readingLevel!.isNotEmpty);

        if (hasCompletedAssessment) {
          // User is authenticated and completed assessment, go to home
          Navigator.pushReplacementNamed(context, AppRouter.home);
        } else {
          // User is authenticated but hasn't completed assessment
          Navigator.pushReplacementNamed(
            context,
            AppRouter.preAssessmentIntro,
            arguments: {'assessmentId': 1},
          );
        }
      } else {
        // User is not authenticated, go to login
        Navigator.pushReplacementNamed(context, AppRouter.preLogin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
          0xFF1C2B4E), // Fixed dark blue background - no theme changes
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated LITEREXIA text
            FadeTransition(
              opacity: _fadeController,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  title.length,
                  (index) => AnimatedBuilder(
                    animation: _letterAnimations[index],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          15 * (1 - _letterAnimations[index].value),
                        ),
                        child: Text(
                          title[index],
                          style: TextStyle(
                            fontFamily: 'Snow Blue',
                            fontSize: _getResponsiveFontSize(40),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: _isTablet ? 12.0 : 8.0,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 2),
                                blurRadius: 3.0,
                                color: Colors.black.withOpacity(0.9),
                              ),
                              Shadow(
                                offset: const Offset(0, 4),
                                blurRadius: 6.0,
                                color: Colors.black.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
