import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../config/router.dart';
import '../../features/auth/logic/auth_provider.dart';

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
  bool _showLoader = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
        // Show loader after text animation completes
        setState(() {
          _showLoader = true;
        });
        _playBounceAudio();
      });
    });

    // Navigate after delay
    _navigateToNextScreen();
  }

  void _playBounceAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/json bounce.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    // Delay for the splash screen - 10 seconds as per original
    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Navigator.pushReplacementNamed(
        context,
        authProvider.isAuthenticated ? AppRouter.home : AppRouter.login,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E3C5A), // Dark blue background
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
                            fontFamily: 'BubblegumSans',
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF9D56E), // Yellow/gold color
                            letterSpacing: 8.0,
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
            const SizedBox(height: 15),

            // Lottie Animation - only show after text animation
            if (_showLoader)
              SizedBox(
                height: 296,
                width: 296,
                child: Lottie.asset(
                  'assets/animations/penguin.json',
                  repeat: true,
                  animate: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}