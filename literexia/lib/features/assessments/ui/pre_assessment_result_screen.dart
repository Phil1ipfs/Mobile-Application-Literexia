// lib/features/assessments/ui/pre_assessment_result_screen.dart
import 'dart:math' as Math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../features/settings/provider/theme_provider.dart';
import '../../../screens/student_reflect_screen.dart';
import '../../../services/database_service.dart';

class PreAssessmentResultScreen extends StatefulWidget {
  final String readingLevel;
  final int score;
  final int totalQuestions;
  final double? readingPercentage;
  // Add these missing properties
  final String assessmentType;
  final String? assessmentId;

  const PreAssessmentResultScreen({
    Key? key,
    required this.readingLevel,
    required this.score,
    required this.totalQuestions,
    this.readingPercentage,
    this.assessmentType = 'pre-assessment', // Default value
    this.assessmentId,
  }) : super(key: key);

  @override
  State<PreAssessmentResultScreen> createState() =>
      _PreAssessmentResultScreenState();
}

class _PreAssessmentResultScreenState extends State<PreAssessmentResultScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;

  // Multiple animation controllers for different effects
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _twinkleController;

  // Animations
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _twinkleAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _congratsPlayer = AudioPlayer();

  // Typewriter effect variables
  String _promptText = "";
  String _displayText = "";
  int _currentIndex = 0;
  bool _isTypingComplete = false;
  bool _hasSpokenText = false;
  Timer? _typewriterTimer;

  // TTS state
  bool _isTTSPlaying = false;

  // Store references to providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  @override
  void initState() {
    super.initState();

    // Initialize the prompt text
    _promptText = "Magaling! Natapos mo na ang pagsusulit.";

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    _setupAnimations();

    // Start confetti, background music, and typewriter effect after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
        _playCongratsMusic();
        _startTypewriterEffect();
      }
    });

    // Immediately update user profile when pre-assessment result screen is shown
    _updateUserProfileImmediately();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references safely during widget lifecycle
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
  }

  void _setupAnimations() {
    // Setup floating animation (up and down)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    // Setup rotation animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeInOut,
      ),
    );

    // Setup twinkling animation
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _twinkleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _twinkleController,
        curve: Curves.easeInOut,
      ),
    );
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
          // Handle error silently
          print('ElevenLabs TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    } else {
      print(
          'ElevenLabs TTS not available or enabled. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
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

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
      print('Error playing button audio: $e');
    }
  }

  void _playCongratsMusic() async {
    try {
      await _congratsPlayer.setAsset('assets/audio/congrats fx.mp3');
      await _congratsPlayer.play();
    } catch (e) {
      // Handle audio error silently
      print('Error playing congratulations music: $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    _twinkleController.dispose();
    _audioPlayer.dispose();
    _congratsPlayer.dispose();
    _typewriterTimer?.cancel();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    super.dispose();
  }

  Widget _getLevelStars(String level) {
    int trophyCount;

    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        trophyCount = 1;
        break;
      case "high emerging":
      case "early":
        trophyCount = 2;
        break;
      case "developing":
        trophyCount = 3;
        break;
      case "transitioning":
        trophyCount = 4;
        break;
      case "at grade level":
      case "fluent":
        trophyCount = 5;
        break;
      default:
        trophyCount = 1;
    }

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_floatController, _rotateController, _twinkleController]),
      builder: (context, child) {
        return Center(
          child: Transform.translate(
            offset: Offset(
                0,
                _floatAnimation.value *
                    Math.sin(_floatController.value * Math.pi * 2)),
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: Opacity(
                opacity: _twinkleAnimation.value,
                child: Lottie.asset(
                  'assets/animations/Trophy.json',
                  width: 450,
                  height: 450,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _getLevelStage(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
        return 1;
      case "high emerging":
        return 2;
      case "developing":
        return 3;
      case "transitioning":
        return 4;
      case "at grade level":
        return 5;
      case "emergent":
        return 1;
      case "early":
        return 2;
      case "fluent":
        return 3;
      default:
        return 0;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        return Colors.red.shade300;
      case "high emerging":
      case "early":
        return Colors.orange.shade300;
      case "developing":
        return Colors.yellow.shade300;
      case "transitioning":
        return Colors.blue.shade300;
      case "at grade level":
      case "fluent":
        return Colors.green.shade300;
      default:
        return Colors.amber;
    }
  }

  // Build score summary that includes reading percentage
  Widget _buildScoreSummary() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Score: ${widget.score}/${widget.totalQuestions}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          if (widget.readingPercentage != null)
            Text(
              'Reading: ${widget.readingPercentage!.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // Navigate to Student Reflect screen

  void _navigateToReflection() {
    // Stop any ongoing TTS and typewriter effect
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }
    _typewriterTimer?.cancel();

    // Play button audio
    _playButtonAudio();

    // Update the AuthProvider with this reading level to ensure it's available throughout the app
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      authProvider.updateUserReadingLevel(widget.readingLevel);
      if (widget.readingPercentage != null) {
        authProvider.updateReadingPercentage(widget.readingPercentage!);
      }
    }

    // Log the navigation with parameters for debugging
    print('Navigating to StudentReflectScreen from PreAssessmentResultScreen');
    print('Assessment Type: ${widget.assessmentType}');
    print('Assessment ID: ${widget.assessmentId}');
    print('Score: ${widget.score}/${widget.totalQuestions}');
    print('Reading Level: ${widget.readingLevel}');

    // For main assessments, ensure the next lesson is made available
    if (widget.assessmentType == 'main-assessment' &&
        widget.assessmentId != null) {
      // Try to extract lesson index from assessment ID
      int? lessonIndex;
      final assessmentId = widget.assessmentId.toString();

      // Parse from various patterns
      if (assessmentId.contains('lesson_')) {
        final parts = assessmentId.split('lesson_');
        if (parts.length > 1) {
          lessonIndex = int.tryParse(parts[1]);
        }
      } else if (assessmentId.contains('_')) {
        // Try to extract from patterns like "level_1", "aralin_1", etc.
        final parts = assessmentId.split('_');
        for (int i = 0; i < parts.length; i++) {
          if (i > 0 && RegExp(r'^\d+$').hasMatch(parts[i])) {
            lessonIndex = int.tryParse(parts[i]);
            break;
          }
        }
      } else {
        // If no pattern works, use first digit in string as fallback
        final match = RegExp(r'(\d+)').firstMatch(assessmentId);
        if (match != null) {
          lessonIndex = int.tryParse(match.group(1)!);
        }
      }

      // If we found a lesson index, mark it as completed and make next lesson available
      if (lessonIndex != null && authProvider.currentUser != null) {
        final userId = authProvider.currentUser!.idNumber.toString();
        print(
            'Explicitly marking lesson $lessonIndex as completed for user $userId');

        // Use the database service to mark the lesson as completed and make next one available
        final dbService = DatabaseService();
        dbService
            .markLessonAsCompletedAndUpdateNext(userId, lessonIndex)
            .then((_) {
          print(
              'Successfully marked lesson $lessonIndex as completed and made next lesson available');
        }).catchError((e) {
          print('Error marking lesson as completed: $e');
        });
      }
    }

    // Navigate to Student Reflect screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => StudentReflectScreen(
          assessmentType: widget.assessmentType,
          assessmentId: widget.assessmentId,
          score: widget.score,
          totalQuestions: widget.totalQuestions,
          onComplete: () {
            // Save assessment results to database after student reflection completion
            print('StudentReflectScreen completed, saving assessment results');
            _saveAssessmentResults();

            // Navigate to home screen after reflection with forceRefresh flag
            print(
                'StudentReflectScreen completed, navigating to HomeScreen with forceRefresh');
            Navigator.of(context).pushReplacementNamed(
              AppRouter.home,
              arguments: {
                'readingLevel': widget.readingLevel,
                'forceRefresh':
                    true, // Force refresh to show updated lesson availability
              },
            );
          },
        ),
      ),
    );
  }

  // TTS controls widget
  Widget _buildTTSControls(ThemeProvider themeProvider, AppThemeData theme) {
    if (!themeProvider.textToSpeechEnabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ElevatedButton.icon(
        onPressed: _isTTSPlaying
            ? () {
                if (_ttsProvider != null) {
                  _ttsProvider!.stopSpeaking();
                }
                setState(() {
                  _isTTSPlaying = false;
                });
              }
            : () {
                _speakPromptText();
              },
        icon: Icon(_isTTSPlaying ? Icons.stop : Icons.volume_up),
        label: Text(_isTTSPlaying ? 'Tumigil' : 'Pakinggan Muli'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isTTSPlaying ? Colors.red.shade400 : theme.accentColor,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(widget.readingLevel);
    // Calculate the level stage but don't display it in the UI
    final levelStage = _getLevelStage(widget.readingLevel);

    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated trophies based on level - centered and larger
                    _getLevelStars(widget.readingLevel),

                    // Continue to reflection button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 160),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(197, 255, 193, 7),
                            offset: const Offset(0, 3),
                            blurRadius: 0,
                            spreadRadius: 0,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _navigateToReflection,
                        child: const Text(
                          'MAG PATULOY',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 0, // Left to right (0 radians = right direction)
              maxBlastForce: 8,
              minBlastForce: 4,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              colors: [
                levelColor,
                Colors.amber,
                Colors.blue,
                Colors.pink,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Update user profile immediately when pre-assessment result screen is shown
  void _updateUserProfileImmediately() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) return;

      final userId = authProvider.currentUser!.idNumber.toString();
      
      print('[PreAssessmentResult] Immediately updating user profile for user: $userId');
      print('[PreAssessmentResult] Reading Level: ${widget.readingLevel}');
      print('[PreAssessmentResult] Reading Percentage: ${widget.readingPercentage}');

      // Update AuthProvider (memory) immediately
      authProvider.updateUserReadingLevel(widget.readingLevel);
      if (widget.readingPercentage != null) {
        authProvider.updateReadingPercentage(widget.readingPercentage!);
      }
      authProvider.setPreAssessmentCompleted(true);

      // Update database immediately
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final dbUpdateResult = await dbService.updateUserPreAssessmentStatus(
        userId,
        true,
        widget.readingLevel,
        widget.readingPercentage ?? 0.0,
      );

      if (dbUpdateResult) {
        print('[PreAssessmentResult] ✅ Successfully updated user profile in database immediately');
      } else {
        print('[PreAssessmentResult] ❌ Failed to update user profile in database');
      }
    } catch (e) {
      print('[PreAssessmentResult] Error updating user profile immediately: $e');
    }
  }

  // Save assessment results to database
  void _saveAssessmentResults() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) return;

      final userId = authProvider.currentUser!.idNumber.toString();
      final assessmentId = widget.assessmentId ?? 'PRE_ASSESSMENT_001';

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final success = await dbService.savePreAssessmentResult(
        userId: userId,
        assessmentId: assessmentId,
        score: widget.score,
        readingLevel: widget.readingLevel,
        readingPercentage: widget.readingPercentage ?? 0.0,
        answers: {}, // Empty answers map
        additionalData: {
          'assessmentType': widget.assessmentType,
          'timeTaken': 0,
          'totalQuestions': widget.totalQuestions,
        },
      );

      if (success) {
        print('[PreAssessmentResult] Assessment saved successfully');
      } else {
        print('[PreAssessmentResult] Failed to save assessment results to database');
      }
    } catch (e) {
      print('Error saving assessment results: $e');
    }
  }
}
