// lib/features/assessments/ui/alphabet_knowledge_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/repositories/assessment_repository.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/utils/tts_pronunciation.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

// Import necessary model and provider classes
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/screens/home_screen.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/services/database_service.dart';
import 'package:literexia/utils/category_results_helper.dart';
import '../../../core/theme/app_theme.dart';
import 'PhonologicalMatching.dart';
import 'package:mongo_dart/mongo_dart.dart' show where;
import 'package:literexia/services/background_music_service.dart';

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

// Loading screen for transition to PhonologicalMatching
class LoadingScreen extends StatefulWidget {
  final String assessmentId;
  final AssessmentProvider provider;
  final bool isPreAssessment;
  final String assessmentType; // New parameter for assessment type

  const LoadingScreen({
    Key? key,
    required this.assessmentId,
    required this.provider,
    required this.isPreAssessment,
    this.assessmentType = 'main_assessment', // Default to main assessment type
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  String _displayText = "";
  int _currentIndex = 0;
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;
  bool _showAnimation = false;
  bool _lottieError = false;
  bool _ttsCompleted = false;

  late AnimationController _fadeController;

  // TTS related variables
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;

  // Full text for typewriter and TTS
  final String _fullText = "Magpatuloy tayo sa susunod na yugto...";

  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20),
    )..repeat(reverse: true);

    // Start typewriter effect after a short delay
    Future.delayed(const Duration(milliseconds: 20), () {
      if (mounted) {
        _startTypewriterEffect();
        setState(() {
          _showAnimation = true;
        });
        _fadeController.forward();
      }
    });

    // Initialize providers after a short delay to ensure context is available
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      }
    });

    // Auto-navigate after loading is complete (3 seconds)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToPhonologicalMatching();
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
    _typewriterTimer = Timer.periodic(Duration(milliseconds: 30), (timer) {
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
      }
    });
  }

  void _navigateToPhonologicalMatching() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: widget.provider,
          child: PhonologicalMatchingScreen(
            assessmentId: widget.assessmentId,
            isPreAssessment: widget.isPreAssessment,
            assessmentType: widget.assessmentType, // Pass assessment type
            onOptionSelected: (optionId) {
              print('[PhonologicalMatching] Selected option: $optionId');
            },
            onContinue: () {
              print('[PhonologicalMatching] Continue to next assessment');
              Navigator.of(context).pop();
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
        'assets/animations/mascotte-design.json',
        width: 300,
        height: 300,
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
              offset:
                  Offset(0, 6 * Math.sin(_fadeController.value * 2 * Math.pi)),
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

  // Speech bubble with typewriter text
  Widget _buildSpeechBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CustomPaint(
        painter: SpeechBubblePainter(
          backgroundColor: const Color(0xFF4D4D4D),
          borderColor: Colors.amber,
          borderWidth: 2.0,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Century Gothic',
              letterSpacing: 0.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth - 48;

    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // Speech bubble with typewriter text
              _buildSpeechBubble(_displayText),

              // Lottie animation or fallback penguin animation
              Expanded(
                flex: 3,
                child: AnimatedOpacity(
                  opacity: _showAnimation ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: 200,
                      child: _lottieError
                          ? _buildAnimatedPenguin()
                          : _loadLottieAnimation(),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
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

    // Stop TTS when leaving the screen
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.stopSpeaking();

    _ttsProvider?.stopSpeaking();
    super.dispose();
  }
}

class AlphabetKnowledgeScreen extends StatefulWidget {
  final String assessmentId;
  final AssessmentProvider provider;
  final Function(
          String readingLevel, int score, int total, double readingPercentage)?
      onAssessmentComplete;
  final bool isPreAssessment;
  final String assessmentType; // New parameter for assessment type

  const AlphabetKnowledgeScreen({
    super.key,
    required this.assessmentId,
    required this.provider,
    this.onAssessmentComplete,
    this.isPreAssessment = false, // Default to main assessment
    this.assessmentType = 'main_assessment', // Default to main assessment type
  });

  @override
  State<AlphabetKnowledgeScreen> createState() =>
      _AlphabetKnowledgeScreenState();
}

class _AlphabetKnowledgeScreenState extends State<AlphabetKnowledgeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedOptionId;
  DateTime? _loadingStartTime;
  static const int MIN_LOADING_DURATION_MS = 8000; // 8 seconds minimum

  // Audio players
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _correctAnswerPlayer = AudioPlayer();
  // Background music is now handled by BackgroundMusicService
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer();
  final AudioPlayer _congratsSoundPlayer = AudioPlayer();

  // TTS state
  bool _isTTSPlaying = false;
  String? _currentPlayingOptionId;
  TTSProvider? _ttsProvider;
  AuthProvider? _authProvider; // cached so completion flow doesn't touch a dead context
  
  // Congratulations sound state
  bool _isCongratsPlaying = false;
  ThemeProvider? _themeProvider;

  // Feedback state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackDescription = '';

  // Confetti controllers for fireworks animation
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // Loading animation state
  bool _lottieLoadingError = false;
  late AnimationController _fallbackAnimationController;

  // Typewriter effect state
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedText = '';
  String _fullQuestionText = '';

  // Flow control state
  bool _typewriterCompleted = false;
  bool _showTTSButton = false;
  bool _showImage = false;
  bool _showChoices = false;
  bool _userListened = false;

  // Heartbeat animation for TTS button
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

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
  double _getResponsiveFontSize(
      double baseFontSize, ThemeProvider themeProvider) {
    double scaleFactor = 1.0;

    if (_isLargeTablet) {
      scaleFactor = 1.4; // Larger tablets
    } else if (_isTablet) {
      scaleFactor = 1.2; // Regular tablets
    } else if (_isMobile && _screenWidth < 400) {
      scaleFactor = 0.9; // Small phones
    }

    return themeProvider.getRealFontSize(baseFontSize * scaleFactor);
  }

  // Responsive padding and spacing
  EdgeInsets get _responsivePadding {
    if (_isLargeTablet)
      return const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0);
    if (_isTablet)
      return const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0);
    return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0);
  }

  double get _responsiveSpacing {
    if (_isLargeTablet) return 30.0;
    if (_isTablet) return 25.0;
    return 20.0;
  }

  double get _responsiveButtonHeight {
    if (_isLargeTablet) return 80.0;
    if (_isTablet) return 70.0;
    return 60.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize confetti controllers
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Initialize fallback animation controller
    _fallbackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Initialize typewriter animation controller
    _typewriterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Initialize heartbeat animation controller
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _heartbeatAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _heartbeatController,
      curve: Curves.easeInOut,
    ));

    // Start heartbeat animation loop
    _heartbeatController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _heartbeatController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _heartbeatController.forward();
      }
    });

    // Debug the assessment ID before loading
    Future.microtask(() async {
      final repository = AssessmentRepository();
      await repository.debugAssessmentQueries(widget.assessmentId.toString());
    });

    _loadAssessment();

    // Initialize providers after a short delay to ensure context is available
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        _authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Set current user ID in assessment provider for response tracking
        _setCurrentUserIdInProvider();

        // Start background music after providers are initialized
        _startBackgroundMusic();
      }
    });
  }

  // Start background music using centralized service
  void _startBackgroundMusic() async {
    try {
      await BackgroundMusicService.startBackgroundMusic(
        track: 'assets/audio/homeBg.mp3',
        volume: 0.2,
      );
      print('[AlphabetKnowledgeScreen] Background music started successfully');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Background music error: $e');
    }
  }

  // Pause background music using centralized service
  void _pauseBackgroundMusic() async {
    try {
      await BackgroundMusicService.pauseBackgroundMusic();
      print('[AlphabetKnowledgeScreen] Background music paused');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error pausing music: $e');
    }
  }

  // Resume background music using centralized service
  void _resumeBackgroundMusic() async {
    try {
      await BackgroundMusicService.resumeBackgroundMusic();
      print('[AlphabetKnowledgeScreen] Background music resumed');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error resuming music: $e');
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

  // Set current user ID in assessment provider for response tracking
  void _setCurrentUserIdInProvider() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final assessmentProvider = widget.provider;

      if (authProvider.currentUser != null) {
        final userId = authProvider.currentUser!.idNumber.toString();
        assessmentProvider.setCurrentUserId(userId);
        print(
            '[AlphabetKnowledgeScreen] Set user ID in assessment provider: $userId');
      } else {
        print(
            '[AlphabetKnowledgeScreen] WARNING: No current user found for setting user ID');
      }
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error setting user ID in provider: $e');
    }
  }

  // Play correct answer sound
  void _playCorrectAnswerSound() async {
    try {
      await _correctAnswerPlayer.stop();
      await _correctAnswerPlayer.setAsset('assets/audio/assessmentsound.mp3');

      // Temporarily reduce volume for correct answer sound
      await BackgroundMusicService.setVolume(0.8); // 0.5 * 0.3 = 0.15

      await _correctAnswerPlayer.play();

      _correctAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          BackgroundMusicService.setVolume(0.5); // Restore original volume
        }
      });
    } catch (e) {
      print('Correct answer sound error: $e');
    }
  }

  // Play incorrect answer sound
  void _playIncorrectAnswerSound() async {
    try {
      await _incorrectAnswerPlayer.stop();
      await _incorrectAnswerPlayer.setAsset('assets/audio/incorrectanswer.mp3');

      // Temporarily reduce volume for incorrect answer sound
      await BackgroundMusicService.setVolume(0.15); // 0.5 * 0.3 = 0.15

      await _incorrectAnswerPlayer.play();

      _incorrectAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          BackgroundMusicService.setVolume(0.5); // Restore original volume
        }
      });
    } catch (e) {
      print('Incorrect answer sound error: $e');
    }
  }

  // Play congratulations sound
  Future<void> _playCongratsSound() async {
    try {
      await _congratsSoundPlayer.setAsset('assets/audio/congrats fx.mp3');
      await _congratsSoundPlayer.seek(Duration.zero);
      await _congratsSoundPlayer.play();
      print('[AlphabetKnowledgeScreen] Playing congratulations sound');
      
      // Set a flag to prevent disposal while sound is playing
      _isCongratsPlaying = true;
      
      // Listen for completion to reset the flag
      _congratsSoundPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isCongratsPlaying = false;
        }
      });
    } catch (e) {
      print(
          '[AlphabetKnowledgeScreen] Error playing congratulations sound: $e');
      _isCongratsPlaying = false;
    }
  }

  // Enhanced Lottie loading animation with fallback
  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: _lottieLoadingError
                ? _buildFallbackLoadingAnimation()
                : _buildLottieLoadingAnimation(),
          ),
          const SizedBox(height: 30),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Text(
                'Maghintay lamang...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(18, themeProvider),
                  fontWeight: FontWeight.w600,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _fallbackAnimationController,
                builder: (context, child) {
                  double animationValue =
                      (_fallbackAnimationController.value * 3) % 3;
                  double opacity = 0.3;

                  if (animationValue >= index && animationValue < index + 1) {
                    opacity = 1.0;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieLoadingAnimation() {
    try {
      return Lottie.asset(
        'assets/animations/mascotte-design.json',
        width: 300,
        height: 300,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading Lottie animation: $error');
          setState(() {
            _lottieLoadingError = true;
          });
          return _buildFallbackLoadingAnimation();
        },
      );
    } catch (e) {
      print('Exception loading Lottie animation: $e');
      return _buildFallbackLoadingAnimation();
    }
  }

  // Fallback animation for loading
  Widget _buildFallbackLoadingAnimation() {
    return AnimatedBuilder(
      animation: _fallbackAnimationController,
      builder: (context, child) {
        return Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Transform.rotate(
              angle: _fallbackAnimationController.value * 2 * Math.pi,
              child: Transform.translate(
                offset: Offset(
                    0,
                    10 *
                        Math.sin(
                            _fallbackAnimationController.value * 4 * Math.pi)),
                child: Container(
                  width: 160,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00394D),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  child: Stack(
                    children: [
                      // White belly
                      Positioned(
                        bottom: 0,
                        left: 15,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(65),
                              bottomRight: Radius.circular(65),
                            ),
                          ),
                        ),
                      ),
                      // Eyes
                      Positioned(
                        top: 40,
                        left: 35,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 35,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
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
                        top: 80,
                        left: 55,
                        child: Container(
                          width: 50,
                          height: 15,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      // Wings with animation
                      Positioned(
                        top: 70,
                        left: -5,
                        child: Transform.rotate(
                          angle: -0.3 -
                              (0.2 *
                                  Math.sin(_fallbackAnimationController.value *
                                      6 *
                                      Math.pi)),
                          child: Container(
                            width: 40,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00394D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 70,
                        right: -5,
                        child: Transform.rotate(
                          angle: 0.3 +
                              (0.2 *
                                  Math.sin(_fallbackAnimationController.value *
                                      6 *
                                      Math.pi)),
                          child: Container(
                            width: 40,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00394D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      // Feet
                      Positioned(
                        bottom: 0,
                        left: 40,
                        child: Container(
                          width: 30,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 40,
                        child: Container(
                          width: 30,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Dynamically load assessment data from MongoDB database
  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingStartTime = DateTime.now();
    });

    try {
      print(
          '[AlphabetKnowledgeScreen] ===== LOADING DYNAMIC ALPHABET KNOWLEDGE ASSESSMENT =====');
      print('[AlphabetKnowledgeScreen] Assessment ID: ${widget.assessmentId}');
      print(
          '[AlphabetKnowledgeScreen] Is Pre-Assessment: ${widget.isPreAssessment}');

      // Load alphabet knowledge assessment based on context
      // Load based on assessment type
      if (widget.assessmentType == 'intervention_assessment') {
        // Load intervention assessment data
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.currentUser?.idNumber.toString() ?? '';
        final readingLevel = authProvider.currentUser?.readingLevel ?? '';
        await widget.provider.loadInterventionAssessmentDirect(
          'Alphabet Knowledge',
          readingLevel,
          userId: userId,
        );
        print(
            '[AlphabetKnowledgeScreen] Loaded INTERVENTION assessment for Alphabet Knowledge');
      } else if (widget.isPreAssessment ||
          widget.assessmentType == 'pre_assessment') {
        // Load from pre-assessment database
        await widget.provider.loadAlphabetKnowledgeAssessment();
        print(
            '[AlphabetKnowledgeScreen] Loaded PRE assessment for Alphabet Knowledge');
      } else {
        // Load from main assessment database WITH reading level filtering
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userReadingLevel = authProvider.currentUser?.readingLevel;
        await widget.provider.loadCategoryAssessment(
          category: 'Alphabet Knowledge',
          readingLevel: userReadingLevel ?? '',
        );
        print(
            '[AlphabetKnowledgeScreen] Loaded MAIN assessment for Alphabet Knowledge with reading level: $userReadingLevel');
      }

      // Calculate how long loading has taken
      if (_loadingStartTime != null && mounted) {
        final elapsedTime =
            DateTime.now().difference(_loadingStartTime!).inMilliseconds;
        final remainingTime = MIN_LOADING_DURATION_MS - elapsedTime;

        if (remainingTime > 0) {
          print(
              '[AlphabetKnowledgeScreen] Adding ${remainingTime}ms delay for minimum loading time');
          await Future.delayed(Duration(milliseconds: remainingTime));
        }
      }

      // Validate and analyze dynamically loaded assessment from MongoDB
      if (widget.provider.assessment != null) {
        final loadedAssessment = widget.provider.assessment!;
        print(
            '[AlphabetKnowledgeScreen] ===== DYNAMIC MONGODB VALIDATION =====');
        print(
            '[AlphabetKnowledgeScreen] Loaded Assessment ID: ${loadedAssessment.assessmentId}');
        print(
            '[AlphabetKnowledgeScreen] Questions Count: ${loadedAssessment.questions.length}');

        // Dynamically analyze question types from MongoDB
        final akQuestions = loadedAssessment.questions
            .where((q) =>
                q.category?.toLowerCase() == 'alphabet knowledge' ||
                q.questionId.startsWith('AK_'))
            .toList();
        print(
            '[AlphabetKnowledgeScreen] Alphabet Knowledge questions found: ${akQuestions.length}');

        // Debug dynamic question structure
        for (final question in akQuestions) {
          print(
              '[AlphabetKnowledgeScreen] Dynamic Question: ${question.questionId}');
          print(
              '[AlphabetKnowledgeScreen] Question Type: ${question.questionType}');
          print('[AlphabetKnowledgeScreen] Category: ${question.category}');
          print(
              '[AlphabetKnowledgeScreen] Options: ${question.options.length}');
        }
        print(
            '[AlphabetKnowledgeScreen] ===== END DYNAMIC MONGODB VALIDATION =====');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Start the typewriter effect flow when dynamic assessment is loaded
        _startTypewriterFlow();
      }
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error loading dynamic assessment: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Hindi ma-load ang tanong. Subukan muli.';
        });
      }
    }
  }

  // Start the typewriter effect flow
  void _startTypewriterFlow() {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion != null) {
      _fullQuestionText = currentQuestion.questionText;
      _resetFlowState();
      _startTypewriterEffect();
    }
  }

  // Reset flow state for new question
  void _resetFlowState() {
    setState(() {
      _displayedText = '';
      _typewriterCompleted = false;
      _showTTSButton = false;
      _showImage = false;
      _showChoices = false;
      _userListened = false;
    });
    _typewriterController.reset();
    _heartbeatController.stop();
  }

  // Start typewriter effect
  void _startTypewriterEffect() {
    _typewriterAnimation = IntTween(
      begin: 0,
      end: _fullQuestionText.length,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.easeOut,
    ));

    _typewriterAnimation.addListener(() {
      setState(() {
        _displayedText = _fullQuestionText.substring(
            0, _typewriterAnimation.value.clamp(0, _fullQuestionText.length));
      });
    });

    _typewriterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onTypewriterCompleted();
      }
    });

    _typewriterController.forward();
  }

  // Handle typewriter completion
  void _onTypewriterCompleted() {
    setState(() {
      _typewriterCompleted = true;
      _showTTSButton = true;
      _showImage = true;
      // Don't show choices until user clicks Pakinggan
      _showChoices = false;
      _userListened = false;
    });
    // Start heartbeat animation
    _heartbeatController.forward();
  }

  // Handle TTS button press - user listened to question
  void _onTTSButtonPressed() {
    if (!_userListened) {
      _speakText(_fullQuestionText);
      setState(() {
        _userListened = true;
        _showChoices = true;
      });
      // Stop heartbeat animation
      _heartbeatController.stop();
    }
  }

  // Select option method
  void _selectOption(String optionId) {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;

    setState(() {
      _selectedOptionId = optionId;
    });
  }

  // Go to next step
  void _goToNextStep() {
    // Stop any ongoing TTS when user clicks "Tignan ang Sagot" button
    // This prevents widget lifecycle errors and provides smooth user experience
    if (!_showFeedback) {
      // This is the "Tignan ang Sagot" button - stop TTS
      _stopTTS();
    }
    
    if (_showFeedback) {
      setState(() {
        _showFeedback = false;
      });
      _processAnswerAndMoveNext();
      return;
    }

    _playButtonAudio();

    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;

    if (_selectedOptionId != null) {
      _showFeedbackAndPlaySound(currentQuestion);
    }
  }

  // Show feedback and play appropriate sound
  void _showFeedbackAndPlaySound(Question currentQuestion) {
    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == _selectedOptionId!,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    String description = selectedOption.explanation ?? '';

    if (description.isEmpty) {
      if (selectedOption.isCorrect) {
        description = 'Ito ang tamang sagot.';
      } else {
        final correctOption = currentQuestion.options.firstWhere(
          (option) => option.isCorrect,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );
        description =
            'Ayos lang! Ang tamang sagot ay ${correctOption.optionText}.';
      }
    }

    setState(() {
      _showFeedback = true;
      _isCorrectAnswer = selectedOption.isCorrect;
      _feedbackDescription = description;
    });

    if (selectedOption.isCorrect) {
      _confettiControllerLeft.play();
      _confettiControllerRight.play();
    }

    if (selectedOption.isCorrect) {
      _playCorrectAnswerSound();
    } else {
      _playIncorrectAnswerSound();
    }
  }

  // Process answer and move to next question
  void _processAnswerAndMoveNext() async {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null || _selectedOptionId == null) return;

    // Find the correct answer and determine if the selected answer is correct
    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == _selectedOptionId,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    final correctOption = currentQuestion.options.firstWhere(
      (option) => option.isCorrect,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    final isCorrect = selectedOption.isCorrect;

    // Get the assessment's ObjectId for categoryId and user's reading level
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final userReadingLevel = currentUser?.readingLevel ?? '';

    // Get the assessment's ObjectId from the loaded assessment data
    final categoryId = widget.provider.getAssessmentObjectId();

    // Save individual response in new MongoDB format with categoryId and readingLevel
    await widget.provider.saveIndividualResponse(
      questionId: currentQuestion.questionId,
      category: 'Alphabet Knowledge',
      questionType: currentQuestion.questionType ?? 'patinig',
      response: [_selectedOptionId!], // ✅ FIXED: Save optionId instead of optionText
      isCorrect: isCorrect,
      responseTime: 0, // Could be tracked if needed
      categoryId: categoryId, // Add the missing categoryId
      readingLevel: userReadingLevel, // Add the missing readingLevel
    );

    // Record the response using the existing method for compatibility
    if (_selectedOptionId != null) {
      widget.provider.answerCurrentQuestion(_selectedOptionId!);
    }

    if (widget.provider.isAssessmentComplete) {
      _handleAssessmentComplete();
    } else {
      setState(() {
        _selectedOptionId = null;
      });
      // Start typewriter flow for next question
      _startTypewriterFlow();
    }
  }

  void _handleAssessmentComplete() {
    final score = widget.provider.score;
    final total = widget.provider.totalQuestions;
    final readingPercentage = widget.provider.getEffectiveReadingPercentage();
    final readingLevel = widget.provider.readingLevel ?? "Undefined";

    print('[AlphabetKnowledgeScreen] ALPHABET KNOWLEDGE COMPLETED');
    print(
        '[AlphabetKnowledgeScreen] Score: $score/$total, Percentage: $readingPercentage%');
    print(
        '[AlphabetKnowledgeScreen] Is Pre-Assessment: ${widget.isPreAssessment}');

    // Don't save to database yet - this is just one part of the complete assessment
    // Only store the results temporarily in the provider

    if (widget.onAssessmentComplete != null) {
      widget.onAssessmentComplete!(
          readingLevel, score, total, readingPercentage);
    }

    _pauseBackgroundMusic();

    if (widget.isPreAssessment) {
      // Pre-assessment flow: navigate to PhonologicalMatching for next assessment
      print(
          '[AlphabetKnowledgeScreen] Pre-assessment flow - navigating to PhonologicalMatching');
      _navigateToPhonologicalMatching();
    } else if (widget.assessmentType == 'intervention_assessment') {
      // Intervention assessment flow: handle intervention completion
      print(
          '[AlphabetKnowledgeScreen] Intervention assessment flow - handling intervention completion');
      _handleInterventionAssessmentComplete(score, total, readingPercentage);
    } else {
      // Main assessment flow: show score display before navigating back to home
      print(
          '[AlphabetKnowledgeScreen] Main assessment flow - showing score display');
      _showMainAssessmentScoreDisplay(score, total, readingPercentage);
    }
  }

  // New method specifically for Alphabet Knowledge intervention assessment completion
  void _handleInterventionAssessmentComplete(
      int score, int total, double readingPercentage) async {
    try {
      if (!mounted) return;
      
      print('[AlphabetKnowledgeScreen] ===== INTERVENTION ASSESSMENT COMPLETION =====');
      print('[AlphabetKnowledgeScreen] Score: $score/$total, Percentage: ${readingPercentage.toStringAsFixed(1)}%');
      print('[AlphabetKnowledgeScreen] Assessment Type: ${widget.assessmentType}');
      
      // Get user ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      
      if (userId.isEmpty) {
        print('[AlphabetKnowledgeScreen] ERROR: No user ID for intervention completion');
        return;
      }
      
      // Handle intervention completion based on pass/fail status
      final isPassed = readingPercentage >= 75.0;
      print('[AlphabetKnowledgeScreen] Intervention passed: $isPassed');
      
      if (isPassed) {
        // SUCCESS: Intervention passed - only save to intervention_responses
        print('[AlphabetKnowledgeScreen] Intervention PASSED - response saved to intervention_responses collection');
        await CategoryResultsHelper.handleInterventionSuccess(userId, 'Alphabet Knowledge', readingPercentage);
      } else {
        // FAILURE: Intervention failed - only save to intervention_responses
        print('[AlphabetKnowledgeScreen] Intervention FAILED - response saved to intervention_responses collection');
        await CategoryResultsHelper.handleInterventionFailure(userId, 'Alphabet Knowledge');
      }
      
      // Play congratulations sound
      _playCongratsSound();
      
      // Show intervention completion dialog
      _showInterventionCompletionDialog(score, total, readingPercentage);
      
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error in intervention assessment completion: $e');
    }
  }

  // Show intervention completion dialog
  void _showInterventionCompletionDialog(int score, int total, double readingPercentage) {
    try {
      if (!mounted) return;
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      // Play congratulations sound when showing the intervention completed dialog
      _playCongratsSound();

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: _isLargeTablet
                  ? 500
                  : _isTablet
                      ? 400
                      : 350,
              padding: EdgeInsets.all(_isTablet ? 32 : 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2B4E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFDE37C),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with trophy icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE37C),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: const Color(0xFF1C2B4E),
                      size: _isTablet ? 60 : 50,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Mga Letra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(24, themeProvider),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Tapos na ang Pagsasanay!',
                    style: TextStyle(
                      color: const Color(0xFFFDE37C),
                      fontSize: _getResponsiveFontSize(16, themeProvider),
                      fontWeight: FontWeight.w600,
                      fontFamily: themeProvider.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Score display
                  Container(
                    padding: EdgeInsets.all(_isTablet ? 24 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFDE37C).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Score
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$score',
                              style: TextStyle(
                                color: const Color(0xFFFDE37C),
                                fontSize:
                                    _getResponsiveFontSize(48, themeProvider),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                            Text(
                              ' / $total',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    _getResponsiveFontSize(32, themeProvider),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Tamang Sagot',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: _getResponsiveFontSize(14, themeProvider),
                            fontFamily: themeProvider.fontFamily,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Percentage
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: readingPercentage >= 75
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: readingPercentage >= 75
                                  ? Colors.green
                                  : Colors.red,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${readingPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: readingPercentage >= 75
                                  ? Colors.green
                                  : Colors.red,
                              fontSize:
                                  _getResponsiveFontSize(20, themeProvider),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Performance message
                  Text(
                    readingPercentage >= 75 
                      ? 'Magaling! Naipasa mo ang pagsasanay.'
                      : 'Magsanay pa tayo! May bagong gawain ang guro para sa iyo.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(16, themeProvider),
                      fontFamily: themeProvider.fontFamily,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: _responsiveButtonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(); // Close dialog
                        Navigator.of(dialogContext).popUntil((route) => route.isFirst); // Return to home
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDE37C),
                        foregroundColor: const Color(0xFF1C2B4E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: Text(
                        'Magpatuloy',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(18, themeProvider),
                          fontWeight: FontWeight.bold,
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error showing intervention completion dialog: $e');
    }
  }

  // New method specifically for Alphabet Knowledge main assessment scoring
  void _showMainAssessmentScoreDisplay(
      int score, int total, double readingPercentage) {
    try {
      if (!mounted) return;
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // CRITICAL FIX: Capture providers EARLY to avoid context issues
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      // Play congratulations sound when showing the assessment completed dialog
      _playCongratsSound();

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: _isLargeTablet
                  ? 500
                  : _isTablet
                      ? 400
                      : 350,
              padding: EdgeInsets.all(_isTablet ? 32 : 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2B4E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFDE37C),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with trophy icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE37C),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: const Color(0xFF1C2B4E),
                      size: _isTablet ? 60 : 50,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Mga Letra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(24, themeProvider),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Tapos na ang Pagsusulit!',
                    style: TextStyle(
                      color: const Color(0xFFFDE37C),
                      fontSize: _getResponsiveFontSize(16, themeProvider),
                      fontWeight: FontWeight.w600,
                      fontFamily: themeProvider.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Score display
                  Container(
                    padding: EdgeInsets.all(_isTablet ? 24 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFDE37C).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Score
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$score',
                              style: TextStyle(
                                color: const Color(0xFFFDE37C),
                                fontSize:
                                    _getResponsiveFontSize(48, themeProvider),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                            Text(
                              ' / $total',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    _getResponsiveFontSize(32, themeProvider),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Tamang Sagot',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: _getResponsiveFontSize(14, themeProvider),
                            fontFamily: themeProvider.fontFamily,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Percentage
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: readingPercentage >= 70
                                ? Colors.green.withOpacity(0.2)
                                : readingPercentage >= 50
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: readingPercentage >= 70
                                  ? Colors.green
                                  : readingPercentage >= 50
                                      ? Colors.orange
                                      : Colors.red,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${readingPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: readingPercentage >= 70
                                  ? Colors.green
                                  : readingPercentage >= 50
                                      ? Colors.orange
                                      : Colors.red,
                              fontSize:
                                  _getResponsiveFontSize(20, themeProvider),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Performance message
                  Text(
                    _getPerformanceMessage(readingPercentage),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(16, themeProvider),
                      fontFamily: themeProvider.fontFamily,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: _responsiveButtonHeight,
                    child: ElevatedButton(
                      onPressed: () async {
                        print(
                            '[AlphabetKnowledgeScreen] MAG PATULOY button pressed - starting completion process');

                        // NOTE: We don't stop TTS here to let it finish naturally
                        // Only "Tignan ang Sagot" button stops TTS during assessment
                        Navigator.of(dialogContext).pop(); // Close dialog

                        // Save Alphabet Knowledge results to category_results collection
                        if (userId.isNotEmpty) {
                          final finalScore = widget.provider.score;
                          final finalTotal = widget.provider.totalQuestions;
                          final scorePercentage = finalTotal > 0 
                              ? (finalScore / finalTotal) * 100
                              : 0.0;

                          try {
                            print(
                                '[AlphabetKnowledgeScreen] Saving Alphabet Knowledge results to category_results');
                            await _saveToCategoryResults(userId, finalScore,
                                finalTotal, scorePercentage);
                            print(
                                '[AlphabetKnowledgeScreen] Successfully saved to category_results collection');
                          } catch (e) {
                            print(
                                '[AlphabetKnowledgeScreen] Error saving to category_results: $e');
                          }

                          // Also handle failed category result if score is below 75%
                          if (scorePercentage < 75.0) {
                            print(
                                '[AlphabetKnowledgeScreen] Score below 75% - saving failed category result');
                            try {
                              await _saveFailedCategoryResult(userId,
                                  finalScore, finalTotal, scorePercentage);
                              print(
                                  '[AlphabetKnowledgeScreen] Failed category result saved successfully');
                            } catch (e) {
                              print(
                                  '[AlphabetKnowledgeScreen] Error saving failed category result: $e');
                            }
                          } else {
                            print(
                                '[AlphabetKnowledgeScreen] Score above 75% - clearing any existing failed records');
                            await _clearFailedCategoryResult(userId);
                          }
                        }

                        // Mark the lesson as completed
                        print(
                            '[AlphabetKnowledgeScreen] About to call _markLessonAsCompleted');
                        await _markLessonAsCompleted();
                        print(
                            '[AlphabetKnowledgeScreen] Finished _markLessonAsCompleted');

                        // Use a more robust navigation approach with error handling
                        if (mounted && context.mounted) {
                          try {
                            print(
                                '[AlphabetKnowledgeScreen] Navigating to HomeScreen');
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const HomeScreen(forceRefresh: true),
                              ),
                              (route) => false, // Remove all previous routes
                            );
                            print(
                                '[AlphabetKnowledgeScreen] Navigation to HomeScreen completed');
                          } catch (e) {
                            print(
                                '[AlphabetKnowledgeScreen] Error during navigation: $e');
                            // Fallback navigation
                            if (mounted && context.mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HomeScreen(forceRefresh: true),
                                ),
                              );
                            }
                          }
                        } else {
                          print(
                              '[AlphabetKnowledgeScreen] Widget not mounted, cannot navigate');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDE37C),
                        foregroundColor: const Color(0xFF1C2B4E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 8,
                      ),
                      child: Text(
                        'Magpatuloy',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(18, themeProvider),
                          fontWeight: FontWeight.bold,
                          fontFamily: themeProvider.fontFamily,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error showing final score dialog: $e');
      // Fallback navigation with error handling
      if (mounted) {
        try {
          print('[AlphabetKnowledgeScreen] Fallback navigation to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(forceRefresh: true),
            ),
            (route) => false, // Remove all previous routes
          );
          print('[AlphabetKnowledgeScreen] Fallback navigation completed');
        } catch (navError) {
          print(
              '[AlphabetKnowledgeScreen] Error in fallback navigation: $navError');
          // Last resort navigation
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(forceRefresh: true),
              ),
            );
          }
        }
      }
    }
  }

  // Helper method to get performance message based on percentage
  String _getPerformanceMessage(double percentage) {
    if (percentage >= 90) {
      return 'Napakagaling mo! Natapos mo ang gawain.';
    } else if (percentage >= 80) {
      return 'Magaling ka! Natapos mo ang gawain.';
    } else if (percentage >= 70) {
      return 'Mabuti! Natapos mo ang gawain.';
    } else if (percentage >= 50) {
      return 'Mabuti ang simula! Magsanay pa tayo.';
    } else {
      return 'Magsanay pa tayo. Kaya mo ʼyan!';
    }
  }

  void _navigateToPhonologicalMatching() {
    // Navigate to LoadingScreen which will then navigate to PhonologicalMatching
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: widget.provider, // Reuse the existing provider
          child: LoadingScreen(
            assessmentId: widget.assessmentId.toString(),
            provider: widget.provider,
            isPreAssessment: widget.isPreAssessment,
            assessmentType: widget.assessmentType, // Pass assessment type
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        _resumeBackgroundMusic();
        break;
      case AppLifecycleState.detached:
        // Background music disposal is handled by BackgroundMusicService
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF1C2B4E),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _errorMessage != null
                    ? _buildErrorState(theme)
                    : _buildQuestionContent(theme),
          ),
          // Left side confetti
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiControllerLeft,
              blastDirection: 0, // Shoot to the right
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 15,
              minBlastForce: 5,
              gravity: 0.8,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),
          // Right side confetti
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiControllerRight,
              blastDirection: 3.14159, // Shoot to the left (pi radians)
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 15,
              minBlastForce: 5,
              gravity: 0.1,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppThemeData theme) {
    return _buildLoadingAnimation();
  }

  Widget _buildErrorState(AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Padding(
        padding: _responsivePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              'Error: $_errorMessage',
              style: TextStyle(
                color: theme.textColor,
                fontSize: _getResponsiveFontSize(16, themeProvider),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.buttonTextColor,
              ),
              onPressed: _loadAssessment,
              child: Text(
                'Subukan Muli',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: _getResponsiveFontSize(16, themeProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent(AppThemeData theme) {
    final provider = widget.provider;
    final currentQuestion = provider.currentQuestion;
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (currentQuestion == null) {
      return Center(
        child: Text(
          'Wala pang tanong',
          style: TextStyle(
            color: theme.textColor,
            fontFamily: themeProvider.fontFamily,
            fontSize: _getResponsiveFontSize(16, themeProvider),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Removed exit button

        // Add slight top spacing then progress indicator
        const SizedBox(height: 8),
        _buildProgressIndicator(provider, theme),

        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _responsivePadding.horizontal / 2),
            child: _showFeedback
                ? _buildFeedbackContent(theme)
                : ListView(
                    children: [
                      SizedBox(height: _responsiveSpacing / 2),
                      _buildAlphabetQuestionContent(currentQuestion, theme),
                      SizedBox(height: _responsiveSpacing),
                      // Continue button
                      if (_userListened) _buildContinueButton(provider, theme),
                      SizedBox(height: _responsiveSpacing),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlphabetQuestionContent(Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dynamically extract additional data from MongoDB if available
    final originalData =
        widget.provider.getOriginalQuestionData(question.questionId);
    String? dynamicImageUrl = question.imageUrl;
    String? dynamicAudioUrl = question.audioUrl;

    // Check for alternative field names in MongoDB data
    if (originalData != null) {
      dynamicImageUrl = dynamicImageUrl ??
          originalData['questionImage'] ??
          originalData['imageUrl'] ??
          originalData['image'];
      dynamicAudioUrl = dynamicAudioUrl ??
          originalData['questionAudio'] ??
          originalData['audioUrl'] ??
          originalData['audio'];
    }

    return Column(
      children: [
        // Question text with TTS - dynamically loaded
        _buildQuestionText(question.questionText, theme, themeProvider),

        // Display image only after TTS button is shown - dynamically loaded from MongoDB
        if (_showImage && dynamicImageUrl != null && dynamicImageUrl.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: _responsiveSpacing),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildQuestionImage(
                  dynamicImageUrl,
                  _isLargeTablet
                      ? 200
                      : _isTablet
                          ? 150
                          : 100),
            ),
          ),

        // Question prompt removed as requested by user

        SizedBox(height: _responsiveSpacing),

        // Audio content - dynamically loaded from MongoDB
        if (dynamicAudioUrl != null && dynamicAudioUrl.isNotEmpty)
          Center(
            child: IconButton(
              icon: Icon(Icons.volume_up, color: theme.accentColor, size: 48),
              onPressed: () => _playAudio(dynamicAudioUrl!),
            ),
          ),

        SizedBox(height: _responsiveSpacing / 20),

        // Answer options - only show after user has listened, dynamically loaded from MongoDB
        if (_showChoices && question.options.isNotEmpty)
          ..._buildDynamicOptions(question, theme),
      ],
    );
  }

  // Build options dynamically based on MongoDB data structure
  List<Widget> _buildDynamicOptions(Question question, AppThemeData theme) {
    final originalData =
        widget.provider.getOriginalQuestionData(question.questionId);

    // Check if there are custom options in the original MongoDB data
    if (originalData != null && originalData['options'] != null) {
      try {
        final dynamicOptions = originalData['options'] as List;
        return dynamicOptions.map((optionData) {
          // Handle different option data structures
          String optionText = '';
          String optionId = '';
          bool isCorrect = false;

          if (optionData is Map<String, dynamic>) {
            optionText = optionData['optionText'] ??
                optionData['text'] ??
                optionData['option'] ??
                '';
            optionId = optionData['optionId'] ??
                optionData['id'] ??
                optionData['value'] ??
                optionText;
            isCorrect =
                optionData['isCorrect'] ?? optionData['correct'] ?? false;
          } else if (optionData is String) {
            optionText = optionData;
            optionId = optionData;
            isCorrect = false; // Will be determined by correctAnswer field
          }

          final dynamicOption = AssessmentOption(
            optionId: optionId,
            optionText: optionText,
            isCorrect: isCorrect,
          );

          return _buildOptionButton(dynamicOption, theme);
        }).toList();
      } catch (e) {
        print('[AlphabetKnowledgeScreen] Error parsing dynamic options: $e');
      }
    }

    // Fallback to default options from question model
    return question.options
        .map((option) => _buildOptionButton(option, theme))
        .toList();
  }

  Widget _buildProgressIndicator(
      AssessmentProvider provider, AppThemeData theme) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;
    final themeProvider = Provider.of<ThemeProvider>(context);

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = current / total;
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    return Container(
      height:
          48, // extra space so the pill isn't clipped when positioned with a negative top
      margin: EdgeInsets.symmetric(
          horizontal: _responsivePadding.horizontal / 2,
          vertical: _responsivePadding.vertical),
      child: Stack(
        clipBehavior:
            Clip.none, // allow the pill to draw outside the stack bounds
        children: [
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: current / total,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(197, 255, 204, 0),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: progressRatio < 0.1
                ? 0
                : progressRatio > 0.9
                    ? totalWidth - pillWidth
                    : pillPosition,
            top: -10, // requested positioning to overlap the bar nicely
            child: Container(
              height: 40,
              width: pillWidth,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(197, 255, 204, 0),
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$current/$total',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    fontSize: _getResponsiveFontSize(14, themeProvider),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(AssessmentOption option, AppThemeData theme) {
    final isSelected = _selectedOptionId == option.optionId;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isTTSEnabled = themeProvider.textToSpeechEnabled;
    final isThisOptionPlaying =
        _isTTSPlaying && _currentPlayingOptionId == option.optionId;

    return Padding(
      padding: EdgeInsets.only(bottom: _responsiveSpacing / 2),
      child: InkWell(
        onTap: () => _selectOption(option.optionId),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              vertical: _isTablet ? 20 : 16, horizontal: _isTablet ? 30 : 20),
          decoration: BoxDecoration(
            border: Border.all(
                color: theme.name == 'Blue' ? Colors.green : theme.accentColor,
                width: 2),
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? (theme.name == 'Blue' ? Colors.green : theme.accentColor)
                : (theme.name == 'Blue'
                    ? Colors.green.withOpacity(0.4)
                    : theme.accentColor.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.optionText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(18, themeProvider),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
              if (isTTSEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isThisOptionPlaying
                          ? _stopTTS
                          : () => _speakOptionText(
                              option.optionText, option.optionId),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isThisOptionPlaying
                              ? const Color(0xFFF7574A)
                              : theme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: (isThisOptionPlaying
                                      ? const Color(0xFFF7574A)
                                      : theme.accentColor)
                                  .withOpacity(0.3),
                              blurRadius: isThisOptionPlaying ? 8 : 0,
                              spreadRadius: isThisOptionPlaying ? 2 : 0,
                            ),
                          ],
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isThisOptionPlaying
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: isThisOptionPlaying ? 24 : 22,
                          ),
                        ),
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

  Widget _buildContinueButton(AssessmentProvider provider, AppThemeData theme) {
    final isButtonEnabled = _selectedOptionId != null;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SizedBox(
      width: double.infinity,
      height: _responsiveButtonHeight,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: (isButtonEnabled && _userListened)
                  ? const Color.fromARGB(197, 27, 172, 37)
                  : const Color.fromARGB(197, 117, 117, 117),
              offset: const Offset(0, 3), // Horizontal & vertical offset
              blurRadius: 0, // Softness of the shadow
              spreadRadius: 0, // Size expansion
            ),
          ],
          borderRadius: BorderRadius.circular(10),
        ),
        child: ElevatedButton(
          onPressed: (isButtonEnabled && _userListened) ? _goToNextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: (isButtonEnabled && _userListened)
                ? (theme.name == 'Blue'
                    ? const Color(0xFF1BAC24)
                    : theme.accentColor)
                : Colors.grey.shade600,
            disabledBackgroundColor: Colors.grey.shade600,
            foregroundColor: theme.buttonTextColor,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _showFeedback
                ? 'Magpatuloy'
                : (_showChoices ? 'Tingnan ang Sagot' : 'Tingnan ang Sagot'),
            style: TextStyle(
              fontSize: _getResponsiveFontSize(18, themeProvider),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: (isButtonEnabled && _userListened)
                  ? theme.buttonTextColor
                  : Colors.grey.shade800,
              fontFamily: themeProvider.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionText(
      String text, AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 24 : 0),
      margin: EdgeInsets.only(bottom: _responsiveSpacing),
      child: Column(
        children: [
          // Typewriter text display
          Text(
            _displayedText,
            style: TextStyle(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(19, themeProvider),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          // Show Nakinig na status when user has listened
          if (_userListened && themeProvider.textToSpeechEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.green.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.green,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nakinig na',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(14, themeProvider),
                          fontWeight: FontWeight.w600,
                          fontFamily: themeProvider.fontFamily,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // TTS button with heartbeat animation - only show after typewriter completes and user hasn't listened
          if (_showTTSButton &&
              themeProvider.textToSpeechEnabled &&
              !_userListened) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _heartbeatAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _heartbeatAnimation.value,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onTTSButtonPressed,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: theme.accentColor.withOpacity(0.15),
                              border: Border.all(
                                color: theme.accentColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    color: const Color(0xFFFFCC00),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pakinggan',
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(
                                        14, themeProvider),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: themeProvider.fontFamily,
                                    color: const Color(0xFFFFCC00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackContent(AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return const SizedBox.shrink();

    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == _selectedOptionId,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    final Color backgroundColor =
        _isCorrectAnswer ? const Color(0xFFCAFFCD) : const Color(0xFFFFF0F0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isTablet ? 32 : 24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isCorrectAnswer
                  ? const Color(0xFF00E10F)
                  : const Color(0xFFF7574A),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCorrectAnswer
                          ? const Color(0xFF00E10F)
                          : Colors.red,
                    ),
                    child: Icon(
                      _isCorrectAnswer ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isCorrectAnswer ? 'Tama!' : 'Mali!',
                    style: TextStyle(
                      color: _isCorrectAnswer ? Colors.green : Colors.red,
                      fontSize: _getResponsiveFontSize(32, themeProvider),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    vertical: _isTablet ? 20 : 16,
                    horizontal: _isTablet ? 28 : 20),
                decoration: BoxDecoration(
                  color: _isCorrectAnswer
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        _isCorrectAnswer ? const Color(0xFF00E10F) : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedOption.optionText,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(20, themeProvider),
                          fontWeight: FontWeight.bold,
                          color: _isCorrectAnswer
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                    Icon(
                      _isCorrectAnswer ? Icons.check_circle : Icons.cancel,
                      color: _isCorrectAnswer
                          ? const Color(0xFF00E10F)
                          : Colors.red,
                      size: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _feedbackDescription,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(16, themeProvider),
                  color: Colors.black87,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: _responsiveButtonHeight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: _isCorrectAnswer
                            ? const Color.fromARGB(197, 27, 172, 37)
                            : const Color.fromARGB(197, 247, 87, 74),
                        offset:
                            const Offset(0, 3), // Horizontal & vertical offset
                        blurRadius: 0, // Softness of the shadow
                        spreadRadius: 0, // Size expansion
                      ),
                    ],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: _goToNextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCorrectAnswer
                          ? const Color(0XFF1BAC24)
                          : Colors.red,
                      foregroundColor:
                          _isCorrectAnswer ? Colors.white : Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Magpatuloy',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(18, themeProvider),
                        fontWeight: FontWeight.bold,
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TTS functionality
  void _speakText(String text) {
    if (!mounted) return;

    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _currentPlayingOptionId = null;

      _ttsProvider!.speakText(
        text,
        speed: 0.4,
        onStart: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = true;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
        onError: () {
          print('ElevenLabs TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    }
  }

  void _speakOptionText(String text, String optionId) {
    if (!mounted) return;

    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        TtsPronunciation.forSpeech(text),
        speed: 0.4,
        onStart: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = true;
              _currentPlayingOptionId = optionId;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _currentPlayingOptionId = null;
            });
          }
        },
        onError: () {
          print('ElevenLabs TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _currentPlayingOptionId = null;
            });
          }
        },
      );
    }
  }

  void _stopTTS() {
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
      if (mounted) {
        setState(() {
          _isTTSPlaying = false;
          _currentPlayingOptionId = null;
        });
      }
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    print('Playing audio: $audioUrl');
  }

  Widget _buildQuestionImage(String imagePath, double height) {
    print('[AlphabetKnowledgeScreen] Loading dynamic image: $imagePath');

    // Handle different image sources dynamically
    if (imagePath.startsWith('assets/')) {
      // Local asset image
      return Image.asset(
        imagePath,
        fit: BoxFit.contain,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          print(
              '[AlphabetKnowledgeScreen] Error loading asset image: $imagePath - $error');
          return _buildImageErrorWidget(height);
        },
      );
    } else if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      // Network image from MongoDB
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFCC00)),
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print(
              '[AlphabetKnowledgeScreen] Error loading network image: $imagePath - $error');
          return _buildImageErrorWidget(height);
        },
      );
    } else if (imagePath.startsWith('data:image/')) {
      // Base64 encoded image from MongoDB
      try {
        final base64String = imagePath.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            print(
                '[AlphabetKnowledgeScreen] Error loading base64 image: $error');
            return _buildImageErrorWidget(height);
          },
        );
      } catch (e) {
        print('[AlphabetKnowledgeScreen] Error decoding base64 image: $e');
        return _buildImageErrorWidget(height);
      }
    } else {
      // Unknown image format, try as network image
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          print(
              '[AlphabetKnowledgeScreen] Error loading unknown format image: $imagePath - $error');
          return _buildImageErrorWidget(height);
        },
      );
    }
  }

  Widget _buildImageErrorWidget(double height) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            'Walang larawan',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Mark lesson as completed in database
  Future<void> _markLessonAsCompleted() async {
    try {
      // Use the cached AuthProvider — by completion time the widget may be
      // deactivated, so Provider.of(context) ancestor lookup would throw.
      final authProvider = _authProvider;
      if (authProvider == null) {
        print('[AlphabetKnowledgeScreen] Cannot mark lesson - no auth provider');
        return;
      }
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      if (userId.isEmpty) {
        print(
            '[AlphabetKnowledgeScreen] Cannot mark lesson as completed - no user ID');
        return;
      }

      // NOTE: Assessment results are now saved in the button onPressed handler before dialog close

      // Get the lesson index for Alphabet Knowledge (should be 1 based on the category order)
      const lessonIndex = 1; // Alphabet Knowledge is the first lesson

      print(
          '[AlphabetKnowledgeScreen] Marking lesson $lessonIndex (Alphabet Knowledge) as completed for user $userId');

      // Add to completed lessons in AuthProvider
      authProvider.addCompletedLesson(lessonIndex);

      // Save to database using DatabaseService
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Mark the lesson as completed in the database
      await dbService.markLessonAsCompleted(userId, lessonIndex);

      print(
          '[AlphabetKnowledgeScreen] Successfully marked lesson as completed');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error marking lesson as completed: $e');
    }
  }

  /// Save failed category result to failed_category_result collection
  Future<void> _saveFailedCategoryResult(
      String userId, int score, int total, double scorePercentage) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final failedCollection =
          dbService.getCollection('failed_category_result');

      final failedResult = {
        'studentId': int.parse(userId),
        'categoryName': 'Alphabet Knowledge',
        'score': scorePercentage,
        'totalQuestions': total,
        'correctAnswers': score,
        'attemptDate': DateTime.now().toIso8601String(),
        'assessmentId': widget.assessmentId,
        // Tag with the student's ACTUAL level (users.readingLevel), not the
        // per-category value _determineReadingLevelFromMainAssessment derives —
        // otherwise this record is tagged with a contradictory level.
        'readingLevel': _authProvider?.currentUser?.readingLevel ??
            widget.provider.readingLevel ??
            '',
        'isPassed': false,
        'passingThreshold': 75.0,
      };

      // Remove any existing failed records for this user and category first
      await failedCollection.deleteMany(where
          .eq('studentId', int.parse(userId))
          .eq('categoryName', 'Alphabet Knowledge'));

      // Insert new failed record
      await failedCollection.insertOne(failedResult);
      print(
          '[AlphabetKnowledgeScreen] Saved failed category result: Alphabet Knowledge (${scorePercentage.toStringAsFixed(1)}%)');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error saving failed category: $e');
      rethrow;
    }
  }

  /// Clear failed category result when user passes (score >= 75%)
  Future<void> _clearFailedCategoryResult(String userId) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final failedCollection =
          dbService.getCollection('failed_category_result');

      final deleteResult = await failedCollection.deleteMany(where
          .eq('studentId', int.parse(userId))
          .eq('categoryName', 'Alphabet Knowledge'));

      print(
          '[AlphabetKnowledgeScreen] Cleared failed status for Alphabet Knowledge (deleted ${deleteResult.nRemoved} records)');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error clearing failed category: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Save Alphabet Knowledge results to category_results collection
  /// Creates new record if user doesn't have one, or updates existing one
  Future<void> _saveToCategoryResults(
      String userId, int score, int total, double scorePercentage) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Get user data from test.users collection
      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection
          .findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print(
            '[AlphabetKnowledgeScreen] User not found in test.users collection');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel =
          userData['readingLevel'] as String? ?? '';

      print(
          '[AlphabetKnowledgeScreen] Saving to category_results - StudentId: $studentId, ReadingLevel: $readingLevel');

      // Create category data matching the MongoDB Atlas image structure
      final categoryData = {
        'categoryName': 'Alphabet Knowledge',
        'totalQuestions': total,
        'correctAnswers': score,
        'totalPossibleMatches': 0,
        'correctMatches': 0,
        'score': scorePercentage,
        'isPassed': scorePercentage >= 75.0,
        'passingThreshold': 75.0,
        'isCompleted': true,
        'lastQuestionAnswered': '',
        'interventionRequired': scorePercentage < 75.0,
        'interventionAttempts': 0,
        'interventionCompleted': false,
        'currentInterventionId': null,
        'interventionHistory': []
      };

      // Check if user already has a category_results record
      final categoryResultsCollection =
          dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection
          .findOne(where.eq('studentId', studentId));

      if (existingResult == null) {
        // Create new category_results record
        final newCategoryResult = {
          'studentId': studentId,
          'assessmentDate': DateTime.now().toIso8601String(),
          'categories': [categoryData],
          'overallScore': scorePercentage,
          'completedCategories': 1,
          'totalCategories': 5, // Total number of assessment categories
          'allCategoriesPassed': false, // Never true on first category — requires all 5
          'readingLevel': readingLevel,
          'readingLevelUpdated': false,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          '__v': 0
        };

        await categoryResultsCollection.insertOne(newCategoryResult);
        print(
            '[AlphabetKnowledgeScreen] Created new category_results record for student $studentId');
      } else {
        // Update existing record - add Alphabet Knowledge category
        final categories =
            List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

        // Check if Alphabet Knowledge category already exists
        final existingCategoryIndex = categories
            .indexWhere((cat) => cat['categoryName'] == 'Alphabet Knowledge');

        if (existingCategoryIndex >= 0) {
          // Update existing Alphabet Knowledge category
          categories[existingCategoryIndex] = categoryData;
        } else {
          // Add new Alphabet Knowledge category
          categories.add(categoryData);
        }

        // Calculate updated overall statistics
        final completedCategories =
            categories.where((cat) => cat['isCompleted'] == true).length;
        final allCategoriesPassed = categories.length >= 5 &&
            categories.every((cat) => cat['isPassed'] == true);
        final overallScore = categories.isNotEmpty
            ? categories
                    .map((cat) => (cat['score'] as num).toDouble())
                    .reduce((a, b) => a + b) /
                categories.length
            : scorePercentage;

        final updatedResult = {
          'assessmentDate': DateTime.now().toIso8601String(),
          'categories': categories,
          'overallScore': overallScore,
          'completedCategories': completedCategories,
          'totalCategories': 5,
          'allCategoriesPassed': allCategoriesPassed,
          'readingLevel': readingLevel,
          'readingLevelUpdated': false,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await categoryResultsCollection.updateOne(
            where.eq('studentId', studentId).eq('readingLevel', readingLevel),
            {'\$set': updatedResult});
        print(
            '[AlphabetKnowledgeScreen] Updated existing category_results record for student $studentId');
      }

      print(
          '[AlphabetKnowledgeScreen] Successfully saved Alphabet Knowledge results to category_results');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error saving to category_results: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _correctAnswerPlayer.dispose();
    _incorrectAnswerPlayer.dispose();
    // Background music disposal is handled by BackgroundMusicService
    
    // Only dispose congratulations sound player if it's not currently playing
    // This prevents cutting off the congratulations sound when the dialog appears
    if (!_isCongratsPlaying) {
      _congratsSoundPlayer.dispose();
    } else {
      // If it's playing, dispose it after a delay to let it finish
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) {
          _congratsSoundPlayer.dispose();
        }
      });
    }
    
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _fallbackAnimationController.dispose();
    _typewriterController.dispose();
    _heartbeatController.dispose();
    _stopTTS();
    super.dispose();
  }
}
