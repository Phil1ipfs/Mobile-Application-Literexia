// lib/features/assessments/ui/pre_assessment_intro_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as Math;
import 'package:flutter/services.dart';

// Custom speech bubble painter
class SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final double radius = 10.0;
    
    // Create a path for the speech bubble with the tail
    final path = Path()
      // Start at top left with rounded corner
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      // Top right corner
      ..arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      // Right side to almost bottom
      ..lineTo(size.width, size.height - radius - 15)
      // Bottom right corner
      ..arcToPoint(
        Offset(size.width - radius, size.height - 15),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      // Bottom side to the point where the tail starts
      ..lineTo(size.width - 40, size.height - 15)
      // Draw the tail
      ..lineTo(size.width - 25, size.height)
      ..lineTo(size.width - 55, size.height - 15)
      // Continue bottom side
      ..lineTo(radius, size.height - 15)
      // Bottom left corner
      ..arcToPoint(
        Offset(0, size.height - radius - 15),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      // Left side
      ..lineTo(0, radius)
      // Top left corner
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..close();

    // Draw the filled shape and border
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class PreAssessmentIntroScreen extends StatefulWidget {
  final int assessmentId;
  
  const PreAssessmentIntroScreen({
    Key? key, 
    required this.assessmentId,
  }) : super(key: key);

  @override
  State<PreAssessmentIntroScreen> createState() => _PreAssessmentIntroScreenState();
}

class _PreAssessmentIntroScreenState extends State<PreAssessmentIntroScreen> with SingleTickerProviderStateMixin {
  String _displayText = "";
  int _currentIndex = 0;
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;
  bool _showAnimation = false;
  bool _lottieError = false;
  bool _ttsCompleted = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _fadeController;

  // TTS related variables
  bool _isTTSEnabled = true;
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;

  // Full text for typewriter and TTS
  final String _fullText = "Bago tayo magsimula, kailangan muna nating tukuyin ang inyong antas.";

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true); // Make the animation repeat for the fallback penguin

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

  void _startTypewriterEffect() {
    // Cancel any existing timer
    _typewriterTimer?.cancel();

    // Reset the text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
      _ttsCompleted = false;
    });

    // Start a timer to add one character at a time
    _typewriterTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _displayText = _fullText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing is complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });
        
        // Start TTS after typing completes
        _startTTS();
      }
    });
  }

   void _startTTS() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    if (themeProvider.textToSpeechEnabled) {
      setState(() {
        _isTTSLoading = true;
      });

      final success = await themeProvider.speakText(
        _fullText,
        cache: true,
        onStart: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = true;
              _isTTSLoading = false;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _ttsCompleted = true;
            });
          }
        },
        onError: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _isTTSLoading = false;
            });
          }
        },
      );

      if (!success && mounted) {
        setState(() {
          _isTTSLoading = false;
        });
      }
    }
  }

  void _toggleTTS() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    if (_isTTSPlaying) {
      // Stop TTS
      await themeProvider.stopSpeaking();
      setState(() {
        _isTTSPlaying = false;
      });
    } else if (_isTypingComplete && !_isTTSLoading) {
      // Restart TTS
      _startTTS();
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

  void _proceedToAssessment() {
    // Stop any playing TTS
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.stopSpeaking();
    
    // Play button audio
    _playButtonAudio();

    // Create assessment provider
    final assessmentProvider = AssessmentProvider();
    
    // Navigate to the pre-assessment question screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: assessmentProvider,
          child: PreAssessmentQuestionScreen(
            assessmentId: widget.assessmentId,
            provider: assessmentProvider,
            onAssessmentComplete: (readingLevel, score, total, readingPercentage) {
              // Handle completion
              print('Assessment completed: Level=$readingLevel, Score=$score/$total, Reading Percentage=$readingPercentage%');
            },
          ),
        ),
      ),
    );
  }

  // Load Lottie animation with error handling
  Widget _loadLottieAnimation() {
    try {
      return Lottie.asset(
        'assets/animations/penguin.json',
        width: 250,
        height: 250,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading Lottie animation: $error');
          setState(() {
            _lottieError = true;
          });
          return _buildAnimatedPenguin();
        },
      );
    } catch (e) {
      print('Exception loading Lottie animation: $e');
      return _buildAnimatedPenguin();
    }
  }

  // Improved animated penguin as fallback
  Widget _buildAnimatedPenguin() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, 6 * Math.sin(_fadeController.value * 2 * Math.pi)),
              child: Container(
                width: 130,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF00394D),
                  borderRadius: BorderRadius.circular(65),
                ),
                child: Stack(
                  children: [
                    // White belly
                    Positioned(
                      bottom: 0,
                      left: 12,
                      child: Container(
                        width: 106,
                        height: 106,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(53),
                            bottomRight: Radius.circular(53),
                          ),
                        ),
                      ),
                    ),
                    // Eyes
                    Positioned(
                      top: 32,
                      left: 28,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 32,
                      right: 28,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Beak
                    Positioned(
                      top: 65,
                      left: 45,
                      child: Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Wings
                    Positioned(
                      top: 57,
                      left: 0,
                      child: Transform.rotate(
                        angle: -0.2 - (0.1 * _fadeController.value),
                        child: Container(
                          width: 32,
                          height: 65,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00394D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 57,
                      right: 0,
                      child: Transform.rotate(
                        angle: 0.2 + (0.1 * _fadeController.value),
                        child: Container(
                          width: 32,
                          height: 65,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00394D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Feet
                    Positioned(
                      bottom: 0,
                      left: 32,
                      child: Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 32,
                      child: Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Speech bubble with pointed tail and TTS controls
  Widget _buildSpeechBubble(String text) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              // Main speech bubble
              CustomPaint(
                painter: SpeechBubblePainter(
                  backgroundColor: const Color(0xFF4D4D4D),
                  borderColor: Colors.amber,
                  borderWidth: 2.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(
                    children: [
                      // Text content
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: themeProvider.getRealFontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // TTS Controls
                      if (themeProvider.textToSpeechEnabled && _isTypingComplete) ...[
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Play/Stop button
                            if (_isTTSLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: _toggleTTS,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isTTSPlaying ? Colors.red.shade400 : Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isTTSPlaying ? Icons.stop : Icons.volume_up,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            
                            // Status indicator
                            if (_ttsCompleted && !_isTTSPlaying)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // TTS Status text
              if (themeProvider.textToSpeechEnabled && _isTypingComplete)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isTTSLoading
                        ? 'Preparing audio...'
                        : _isTTSPlaying
                            ? 'Playing...'
                            : _ttsCompleted
                                ? 'Audio complete'
                                : 'Tap speaker to hear',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: themeProvider.getRealFontSize(12),
                      fontFamily: themeProvider.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen width to constrain animation size
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth - 48; // Account for padding
    
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1), // Add flexible space at top
              
              // Speech bubble with typewriter text and TTS controls
              _buildSpeechBubble(_displayText),
              
              // Lottie animation or fallback penguin animation - centered
              Expanded(
                flex: 3, // Increased flex to push button up
                child: AnimatedOpacity(
                  opacity: _showAnimation ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: 200,
                      child: _lottieError ? _buildAnimatedPenguin() : _loadLottieAnimation(),
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 1), // Reduced space before button
              
              // Continue button with simple animation - lifted closer to penguin
              Padding(
                padding: const EdgeInsets.only(bottom: 120), // Reduced bottom padding
                child: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.95, end: 1.0),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _proceedToAssessment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFCC00),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                'MAG PATULOY',
                                style: TextStyle(
                                  fontSize: themeProvider.getRealFontSize(16),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: themeProvider.fontFamily,
                                  letterSpacing: themeProvider.getRealLetterSpacing(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
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
    _typewriterTimer?.cancel();
    _fadeController.dispose();
    _audioPlayer.dispose();
    
    // Stop TTS when leaving the screen
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.stopSpeaking();
    
    super.dispose();
  }
}