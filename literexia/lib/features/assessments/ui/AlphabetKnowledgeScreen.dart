// lib/features/assessments/ui/alphabet_knowledge_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/repositories/assessment_repository.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'dart:io';

// Import necessary model and provider classes
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/services/database_service.dart';
import 'package:literexia/screens/home_screen.dart';
import 'PhonologicalMatching.dart';

class AlphabetKnowledgeScreen extends StatefulWidget {
  final dynamic assessmentId;
  final AssessmentProvider provider;
  final Function(
          String readingLevel, int score, int total, double readingPercentage)?
      onAssessmentComplete;

  const AlphabetKnowledgeScreen({
    super.key,
    required this.assessmentId,
    required this.provider,
    this.onAssessmentComplete,
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
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer();

  // TTS state
  bool _isTTSPlaying = false;
  String? _currentPlayingOptionId;
  TTSProvider? _ttsProvider;
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

    // Initialize providers first to ensure context is available
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);

        // Set current user ID in assessment provider for response tracking FIRST
        _setCurrentUserIdInProvider();

        // Debug the assessment ID before loading
        if (widget.assessmentId != null) {
          Future.microtask(() async {
            final repository = AssessmentRepository();
            await repository.debugAssessmentQueries(widget.assessmentId.toString());
          });
        }

        // Load assessment AFTER user ID is set
        _loadAssessment();

        // Start background music after providers are initialized
        _startBackgroundMusic();
      }
    });
  }

  // Start background music
  void _startBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.setAsset('assets/audio/homeBg.mp3');
      await _backgroundMusicPlayer.setVolume(0.3);
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);
      await _backgroundMusicPlayer.play();
      print('[AlphabetKnowledgeScreen] Background music started successfully');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Background music error: $e');
    }
  }

  // Pause background music
  void _pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      print('[AlphabetKnowledgeScreen] Background music paused');
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error pausing music: $e');
    }
  }

  // Resume background music
  void _resumeBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.play();
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
        print('[AlphabetKnowledgeScreen] Set user ID in assessment provider: $userId');
      } else {
        print('[AlphabetKnowledgeScreen] WARNING: No current user found for setting user ID');
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

      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer.setVolume(currentVolume * 0.3);

      await _correctAnswerPlayer.play();

      _correctAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
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

      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer.setVolume(currentVolume * 0.3);

      await _incorrectAnswerPlayer.play();

      _incorrectAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
        }
      });
    } catch (e) {
      print('Incorrect answer sound error: $e');
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
                'Mag hintay lamang...',
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

      // Get user's reading level from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userReadingLevel = authProvider.currentUser?.readingLevel;
      print('[AlphabetKnowledgeScreen] User reading level: $userReadingLevel');

      if (userReadingLevel == null || userReadingLevel.isEmpty) {
        throw Exception('User reading level not found');
      }

      // Load alphabet knowledge assessment dynamically from MongoDB with reading level
      await widget.provider.loadAlphabetKnowledgeAssessment(readingLevel: userReadingLevel);

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
          _errorMessage = 'Error loading dynamic assessment from MongoDB: $e';
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
        _displayedText =
            _fullQuestionText.substring(0, _typewriterAnimation.value);
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
            'Hindi ito ang tamang sagot. Ang tamang sagot ay: ${correctOption.optionText}';
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
      orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    final correctOption = currentQuestion.options.firstWhere(
      (option) => option.isCorrect,
      orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    final isCorrect = selectedOption.isCorrect;

    // Save individual response in new MongoDB format
    await widget.provider.saveIndividualResponse(
      questionId: currentQuestion.questionId,
      category: 'alphabet_knowledge',
      questionType: currentQuestion.questionType ?? 'multiple_choice',
      response: [selectedOption.optionText],
      isCorrect: isCorrect,
      responseTime: 0, // Could be tracked if needed
    );

    // Record the response using the existing method for compatibility
    widget.provider.answerCurrentQuestion(_selectedOptionId!);

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

  void _handleAssessmentComplete() async {
    final score = widget.provider.score;
    final total = widget.provider.totalQuestions;
    final readingPercentage = widget.provider.getEffectiveReadingPercentage();
    final readingLevel = widget.provider.readingLevel ?? "Undefined";

    print('[AlphabetKnowledgeScreen] ALPHABET KNOWLEDGE COMPLETED');
    print(
        '[AlphabetKnowledgeScreen] Score: $score/$total, Percentage: $readingPercentage%');

    // Check if user should level up (75% threshold)
    final passedThreshold = readingPercentage >= 75.0;
    
    if (passedThreshold) {
      // User passed! Level up and show celebration
      await _handleLevelUp(score, total, readingPercentage);
    } else {
      // User failed, show "Nice try" popup
      await _showFailedPopup(score, total, readingPercentage);
    }
  }

  // Handle level up to next reading level
  Future<void> _handleLevelUp(int score, int total, double readingPercentage) async {
    try {
      // Get current user and reading level
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        print('[AlphabetKnowledgeScreen] No current user found for level up');
        return;
      }

      final currentReadingLevel = currentUser.readingLevel ?? "Low Emerging";
      String nextReadingLevel = "Low Emerging";
      
      // Determine next reading level
      switch (currentReadingLevel) {
        case "Low Emerging":
          nextReadingLevel = "High Emerging";
          break;
        case "High Emerging":
          nextReadingLevel = "Developing";
          break;
        case "Developing":
          nextReadingLevel = "Transitioning";
          break;
        case "Transitioning":
          nextReadingLevel = "At Grade Level";
          break;
        case "At Grade Level":
          nextReadingLevel = "At Grade Level"; // Already at max level
          break;
        default:
          nextReadingLevel = "High Emerging"; // Default fallback
      }

      print('[AlphabetKnowledgeScreen] Leveling up from $currentReadingLevel to $nextReadingLevel');

      // Update user's reading level in database
      final dbService = DatabaseService();
      final success = await dbService.updateUserPreAssessmentCompletion(
        currentUser.idNumber.toString(),
        nextReadingLevel,
        readingPercentage,
      );

      if (success) {
        // Update the user in AuthProvider
        await authProvider.updateUserReadingLevel(nextReadingLevel);
        
        // Show level up celebration
        _showLevelUpCelebration(currentReadingLevel, nextReadingLevel, score, total);
      } else {
        print('[AlphabetKnowledgeScreen] Failed to update user reading level in database');
        // Still show celebration but log the error
        _showLevelUpCelebration(currentReadingLevel, nextReadingLevel, score, total);
      }
    } catch (e) {
      print('[AlphabetKnowledgeScreen] Error during level up: $e');
      // Show error but still allow user to continue
      _showLevelUpCelebration("Unknown", "High Emerging", score, total);
    }
  }

  // Show level up celebration with confetti
  void _showLevelUpCelebration(String fromLevel, String toLevel, int score, int total) {
    // Trigger confetti animation
    _confettiControllerLeft.play();
    _confettiControllerRight.play();

    // Show level up dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2B4E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                    // Congratulations text
                    Text(
                      'CONGRATULATIONS!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 15),
                  
                  // Level up text
                  Text(
                    'You leveled up!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  
                  // Level progression
                  Text(
                    '$fromLevel → $toLevel',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  
                  // Score display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Text(
                      'Score: $score/$total (${((score / total) * 100).round()}%)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _pauseBackgroundMusic();
                        // Navigate to home screen with refresh flag to show updated lessons
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(forceRefresh: true),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: const Color(0xFF1C2B4E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Show failed attempt popup
  Future<void> _showFailedPopup(int score, int total, double readingPercentage) async {
    _pauseBackgroundMusic();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2B4E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nice try icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Nice try text
                  Text(
                    'Nice Try!',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  
                  // Score display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Text(
                      'Score: $score/$total (${readingPercentage.round()}%)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Teacher intervention message
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                    child: Text(
                      'Wait for teacher intervention to continue your learning journey.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // OK button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate back to home screen with refresh flag
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(forceRefresh: true),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: Provider.of<ThemeProvider>(context, listen: false).fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void _navigateToPhonologicalMatching() {
    // Navigate to PhonologicalMatchingScreen with current parameters and provide AssessmentProvider
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: widget.provider, // Reuse the existing provider
          child: PhonologicalMatchingScreen(
            assessmentId: widget.assessmentId.toString(),
            onOptionSelected: (optionId) {
              print('[PhonologicalMatching] Selected option: $optionId');
            },
            onContinue: () {
              print('[PhonologicalMatching] Continue to next assessment');
              // Navigate to next assessment phase
              Navigator.of(context).pop();
            },
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
        _backgroundMusicPlayer.dispose();
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
                'Try Again',
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
          'No questions available',
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
            height: 8,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progressRatio,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE37C),
                borderRadius: BorderRadius.circular(30),
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
                color: const Color(0xFFFDE37C),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
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
                color: theme.name == 'Blue'
                    ? const Color(0xFF4CAF50)
                    : theme.accentColor,
                width: 2),
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? (theme.name == 'Blue'
                    ? const Color(0xFF4CAF50)
                    : theme.accentColor)
                : (theme.name == 'Blue'
                    ? const Color(0xFF4CAF50).withOpacity(0.4)
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          _showFeedback
              ? 'MAG PATULOY'
              : (_showChoices ? 'TIGNAN ANG SAGOT' : 'TIGNAN ANG SAGOT'),
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
    );
  }

  Widget _buildQuestionText(
      String text, AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 24 : 16),
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
                                    color: Colors.white,
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
                                    color: Colors.white,
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
                      color: _isCorrectAnswer
                          ? const Color(0xFF00E10F)
                          : Colors.red,
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
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCorrectAnswer ? const Color(0XFF1BAC24) : Colors.red,
                    foregroundColor:
                        _isCorrectAnswer ? Colors.white : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'MAG PATULOY',
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
        text,
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
      setState(() {
        _isTTSPlaying = false;
        _currentPlayingOptionId = null;
      });
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
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF7574A)),
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
            'Image not available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _correctAnswerPlayer.dispose();
    _incorrectAnswerPlayer.dispose();
    _backgroundMusicPlayer.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _fallbackAnimationController.dispose();
    _typewriterController.dispose();
    _heartbeatController.dispose();
    _stopTTS();
    super.dispose();
  }
}
