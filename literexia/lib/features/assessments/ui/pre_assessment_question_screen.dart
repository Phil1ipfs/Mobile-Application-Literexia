// lib/features/assessments/ui/pre_assessment_question_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/repositories/assessment_repository.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../services/database_service.dart';
import 'package:confetti/confetti.dart'; // Add this package for fireworks animation

import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/logic/auth_provider.dart';

import 'pre_assessment_result_screen.dart';

class PreAssessmentQuestionScreen extends StatefulWidget {
  final dynamic assessmentId;
  final AssessmentProvider provider;
  final String? category; // Add category parameter
  final Function(
          String readingLevel, int score, int total, double readingPercentage)?
      onAssessmentComplete;

  const PreAssessmentQuestionScreen({
    super.key,
    required this.assessmentId,
    required this.provider,
    this.category, // Make category optional but available
    this.onAssessmentComplete,
  });

  @override
  State<PreAssessmentQuestionScreen> createState() =>
      _PreAssessmentQuestionScreenState();
}

class _PreAssessmentQuestionScreenState
    extends State<PreAssessmentQuestionScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedOptionId;

  // Reading comprehension flow management
  int _flowStep =
      0; // 0: initial instruction, 1: passage viewing, 2: question with choices
  int _currentPassageIndex = 0; // For tracking position in multi-page passages

  // Timer for tracking time spent reading
  DateTime? _readingStartTime;

  // Track content viewed for reading percentage calculation
  int _contentViewed = 0;

  // Audio players
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _correctAnswerPlayer = AudioPlayer();
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer(); // For wrong answers

  // TTS state
  bool _isTTSPlaying = false;
  String? _currentPlayingOptionId; // Track which option is being read
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Feedback state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackDescription = '';

  // Confetti controller for fireworks animation
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Debug the assessment ID before loading
    if (widget.assessmentId != null) {
      Future.microtask(() async {
        final repository = AssessmentRepository();
        await repository.debugAssessmentQueries(widget.assessmentId.toString());
      });
    }

    _loadAssessment();

    // Initialize providers after a short delay to ensure context is available
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);

        // Start background music after providers are initialized
        _startBackgroundMusic();
      }
    });
  }

  // New method to start background music
  void _startBackgroundMusic() async {
    try {
      // Load the background music
      await _backgroundMusicPlayer.setAsset('assets/audio/homeBg.mp3');

      // Set volume to 30%
      await _backgroundMusicPlayer.setVolume(0.3);

      // Enable looping for continuous playback
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);

      // Start playing
      await _backgroundMusicPlayer.play();

      print(
          '[PreAssessmentQuestionScreen] Background music started successfully');
    } catch (e) {
      // Handle audio error silently
      print('[PreAssessmentQuestionScreen] Background music error: $e');
    }
  }

  // New method to pause background music
  void _pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      print('[PreAssessmentQuestionScreen] Background music paused');
    } catch (e) {
      print('[PreAssessmentQuestionScreen] Error pausing music: $e');
    }
  }

  // New method to resume background music
  void _resumeBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.play();
      print('[PreAssessmentQuestionScreen] Background music resumed');
    } catch (e) {
      print('[PreAssessmentQuestionScreen] Error resuming music: $e');
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

  // Enhanced method to play correct answer sound with fireworks
  void _playCorrectAnswerSound() async {
    try {
      // Reset player to ensure clean playback
      await _correctAnswerPlayer.stop();

      // Load and play the assessment sound
      await _correctAnswerPlayer.setAsset('assets/audio/assessmentsound.mp3');

      // Temporarily lower background music volume
      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer
          .setVolume(currentVolume * 0.3); // Reduce to 30% of current volume

      // Play the sound
      await _correctAnswerPlayer.play();

      // Start fireworks animation
      _confettiController.play();

      // Restore background music volume after sound plays
      _correctAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
        }
      });
    } catch (e) {
      print('Correct answer sound error: $e');
    }
  }

  // New method to play incorrect answer sound
  void _playIncorrectAnswerSound() async {
    try {
      // Reset player to ensure clean playback
      await _incorrectAnswerPlayer.stop();

      // Load and play the wrong answer sound
      await _incorrectAnswerPlayer.setAsset('assets/audio/wronganswer.mp3');

      // Temporarily lower background music volume
      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer
          .setVolume(currentVolume * 0.3); // Reduce to 30% of current volume

      // Play the sound
      await _incorrectAnswerPlayer.play();

      // Restore background music volume after sound plays
      _incorrectAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
        }
      });
    } catch (e) {
      print('Incorrect answer sound error: $e');
    }
  }

  // In your _loadAssessment method, add this validation:
Future<void> _loadAssessment() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    // Get user's reading level for validation
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userReadingLevel = authProvider.currentUser?.readingLevel;
    
    print('[PreAssessmentQuestionScreen] Loading assessment:');
    print('[PreAssessmentQuestionScreen]   - Assessment ID: ${widget.assessmentId}');
    print('[PreAssessmentQuestionScreen]   - User Reading Level: $userReadingLevel');
    print('[PreAssessmentQuestionScreen]   - Expected Category: ${widget.category}');

    final bool isPreAssessment = widget.assessmentId == 'PRE_ASSESSMENT_001' ||
        widget.assessmentId.toString().contains('PRE') ||
        widget.assessmentId == 1;

    if (isPreAssessment) {
      print('[PreAssessmentQuestionScreen] Loading PRE-ASSESSMENT');
      await widget.provider.loadPreAssessment();
    } else {
      print('[PreAssessmentQuestionScreen] Loading MAIN ASSESSMENT');
      
      // CRITICAL: Pass both reading level and category
      await widget.provider.loadMainAssessment(
        widget.assessmentId,
        readingLevel: userReadingLevel,  // User's actual reading level
        category: widget.category,       // Selected category
      );
    }

    // VALIDATION: Check if loaded assessment matches user's reading level
    if (!isPreAssessment && widget.provider.assessment != null) {
      final loadedAssessment = widget.provider.assessment!;
      print('[PreAssessmentQuestionScreen] VALIDATION:');
      print('[PreAssessmentQuestionScreen]   - Loaded Assessment ID: ${loadedAssessment.assessmentId}');
      print('[PreAssessmentQuestionScreen]   - Questions Count: ${loadedAssessment.questions.length}');
      print('[PreAssessmentQuestionScreen]   - Current Category: ${widget.provider.currentCategory}');
      
      // Verify this is the right assessment for the user
      if (widget.category != null && widget.provider.currentCategory != widget.category) {
        print('[PreAssessmentQuestionScreen] ⚠️ WARNING: Category mismatch!');
        print('[PreAssessmentQuestionScreen]     Expected: ${widget.category}');
        print('[PreAssessmentQuestionScreen]     Loaded: ${widget.provider.currentCategory}');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  } catch (e) {
    print('[PreAssessmentQuestionScreen] Error loading assessment: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
}

  // Enhanced selectOption method to show feedback
  void _selectOption(String optionId) {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;

    // Find the selected option
    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == optionId,
      orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    // Get the description from the selected option
    String description = selectedOption.explanation ?? '';
    
    // If no explanation is available, use a generic one based on correctness
    if (description.isEmpty) {
      if (selectedOption.isCorrect) {
        description = 'Ito ang tamang sagot.';
      } else {
        // Try to find the correct answer for reference
        final correctOption = currentQuestion.options.firstWhere(
          (option) => option.isCorrect,
          orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );
        description = 'Hindi ito ang tamang sagot. Ang tamang sagot ay: ${correctOption.optionText}';
      }
    }

    // Set state to show feedback
    setState(() {
      _selectedOptionId = optionId;
      _showFeedback = true;
      _isCorrectAnswer = selectedOption.isCorrect;
      _feedbackDescription = description;
    });

    // Play appropriate sound effect
    if (selectedOption.isCorrect) {
      _playCorrectAnswerSound();
    } else {
      _playIncorrectAnswerSound();
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    // Implementation for audio playback
    print('Playing audio: $audioUrl');
    // Actual implementation would use an audio player package
  }

  // NEW: Method to go back to previous question
  void _goToPreviousQuestion() {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;

    // If we're showing feedback, just hide it and don't go back
    if (_showFeedback) {
      setState(() {
        _showFeedback = false;
      });
      return;
    }

    // If we're in reading comprehension flow and not at the first step
    if (currentQuestion.questionTypeId == 'reading_comprehension') {
      if (_flowStep == 2) {
        // Go back to passage viewing (or previous passage)
        setState(() {
          _flowStep = 1;
          _selectedOptionId = null;
          // If there were multiple passages, we could go back to the last one
          // For simplicity, we'll go back to the last passage
          final passages = _getPassageData(currentQuestion);
          if (passages is List && passages.isNotEmpty) {
            _currentPassageIndex = passages.length - 1;
          }
        });
        return;
      } else if (_flowStep == 1) {
        // If we're viewing passages and there are multiple passages
        final passages = _getPassageData(currentQuestion);
        if (passages is List && _currentPassageIndex > 0) {
          // Go to previous passage
          setState(() {
            _currentPassageIndex--;
          });
          return;
        } else {
          // Go back to instruction step
          setState(() {
            _flowStep = 0;
            _currentPassageIndex = 0;
          });
          return;
        }
      } else if (_flowStep == 0) {
        // We're at the instruction step, go to previous question
        _goBackToActualPreviousQuestion();
        return;
      }
    } else {
      // For regular questions, just go to previous question
      _goBackToActualPreviousQuestion();
    }
  }

  // Helper method to actually go back to the previous question
  void _goBackToActualPreviousQuestion() {
    if (widget.provider.canGoToPreviousQuestion()) {
      widget.provider.goToPreviousQuestion();
      setState(() {
        _selectedOptionId = null;
        _showFeedback = false;
        _flowStep = 0;
        _currentPassageIndex = 0;
        _readingStartTime = null;
      });
    }
  }

  // NEW: Check if back navigation is available
  bool _canGoBack() {
    // If showing feedback, always allow going back to hide feedback
    if (_showFeedback) return true;

    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return false;

    // If we're in reading comprehension flow
    if (currentQuestion.questionTypeId == 'reading_comprehension') {
      // If we're at step 2 (question), we can go back to passage
      if (_flowStep == 2) return true;

      // If we're at step 1 (passage) and there are multiple passages
      if (_flowStep == 1) {
        final passages = _getPassageData(currentQuestion);
        if (passages is List && _currentPassageIndex > 0) return true;
        // Or we can go back to instruction
        return true;
      }

      // If we're at step 0 (instruction), check if there's a previous question
      if (_flowStep == 0) {
        return widget.provider.canGoToPreviousQuestion();
      }
    } else {
      // For regular questions, check if there's a previous question
      return widget.provider.canGoToPreviousQuestion();
    }

    return false;
  }

  // NEW: Show confirmation dialog when trying to exit on first question
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final theme = themeProvider.currentTheme;

        return AlertDialog(
          backgroundColor: theme.primaryColor,
          title: Text(
            'Umalis sa Pagsusulit?',
            style: TextStyle(
              color: theme.textColor,
              fontFamily: themeProvider.fontFamily,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Sigurado ka bang gusto mong umalis? Ang inyong progreso ay mawawala.',
            style: TextStyle(
              color: theme.textColor,
              fontFamily: themeProvider.fontFamily,
              fontSize: themeProvider.getRealFontSize(16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Magpatuloy',
                style: TextStyle(
                  color: theme.accentColor,
                  fontFamily: themeProvider.fontFamily,
                  fontSize: themeProvider.getRealFontSize(16),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _stopTTS();
                _backgroundMusicPlayer.dispose();
                Navigator.of(context).pop(); // Close assessment
              },
              child: Text(
                'Umalis',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: themeProvider.fontFamily,
                  fontSize: themeProvider.getRealFontSize(16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Modified to handle feedback state
  void _goToNextStep() {
    // If showing feedback, hide it and continue
    if (_showFeedback) {
      setState(() {
        _showFeedback = false;
      });
      
      // Process the answer and move to the next question
      _processAnswerAndMoveNext();
      return;
    }

    // Play button audio when continuing
    _playButtonAudio();

    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;

    // For reading comprehension questions
    if (currentQuestion.questionTypeId == 'reading_comprehension') {
      // If we're at the instruction step, start tracking reading time
      if (_flowStep == 0) {
        _readingStartTime = DateTime.now();

        // Check if we have passage data before moving to step 1
        final passages = _getPassageData(currentQuestion);

        if (passages != null &&
            ((passages is List && passages.isNotEmpty) || passages is Map)) {
          setState(() {
            _flowStep = 1; // Move to passage viewing
            _currentPassageIndex = 0; // Start with first passage
          });
          print(
              '[PreAssessmentQuestionScreen] Moving to passage view, found valid passage data');
        } else {
          // No passages, skip directly to question
          print(
              '[PreAssessmentQuestionScreen] No passage data found, skipping to question');
          setState(() {
            _flowStep = 2; // Skip to question step
            _selectedOptionId = null;
          });
        }
      }
      // If we're showing passages and there are more passages
      else if (_flowStep == 1) {
        final passages = _getPassageData(currentQuestion);

        // Record content viewed for reading percentage
        if (passages is List && _currentPassageIndex < passages.length) {
          final passage = passages[_currentPassageIndex];
          if (passage['pageText'] != null) {
            _contentViewed += passage['pageText'].toString().length;
            widget.provider
                .recordContentViewed(passage['pageText'].toString().length);
          }
        } else if (passages is Map && passages['pageText'] != null) {
          // Handle single passage case
          _contentViewed += passages['pageText'].toString().length;
          widget.provider
              .recordContentViewed(passages['pageText'].toString().length);
        }

        // If there are multiple passages and we're not at the last one
        if (passages is List && _currentPassageIndex < passages.length - 1) {
          setState(() {
            _currentPassageIndex++; // Move to next passage
          });
        } else {
          // No more passages, move to the question
          // Stop tracking reading time and record duration
          if (_readingStartTime != null) {
            final readingDuration =
                DateTime.now().difference(_readingStartTime!);
            widget.provider.recordReadingTime(readingDuration.inSeconds);
            _readingStartTime = null;
          }

          setState(() {
            _flowStep = 2; // Show the question
            _selectedOptionId = null; // Reset selected option
          });
        }
      }
      // If we're showing the question with options and an option is selected
      else if (_flowStep == 2 && _selectedOptionId != null) {
        // Check if the selected answer is correct and show feedback
        final selectedOption = currentQuestion.options.firstWhere(
          (option) => option.optionId == _selectedOptionId!,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        // Set up feedback state
        setState(() {
          _showFeedback = true;
          _isCorrectAnswer = selectedOption.isCorrect;
          _feedbackDescription = selectedOption.explanation ?? 
              (selectedOption.isCorrect ? 'Ito ang tamang sagot!' : 'Hindi ito ang tamang sagot.');
        });

        // Play correct answer sound for reading comprehension questions if the answer is correct
        if (selectedOption.isCorrect) {
          _playCorrectAnswerSound();
        } else {
          _playIncorrectAnswerSound();
        }
      }
    }
    // For regular questions (non-reading comprehension)
    else {
      if (_selectedOptionId != null) {
        // Check if the answer is correct and show feedback
        final selectedOption = currentQuestion.options.firstWhere(
          (option) => option.optionId == _selectedOptionId!,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        // Set up feedback state
        setState(() {
          _showFeedback = true;
          _isCorrectAnswer = selectedOption.isCorrect;
          _feedbackDescription = selectedOption.explanation ?? 
              (selectedOption.isCorrect ? 'Ito ang tamang sagot!' : 'Hindi ito ang tamang sagot.');
        });

        // Play the appropriate sound
        if (selectedOption.isCorrect) {
          _playCorrectAnswerSound();
        } else {
          _playIncorrectAnswerSound();
        }
      }
    }
  }

  // Helper method to process answer and move to next question
  void _processAnswerAndMoveNext() {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null || _selectedOptionId == null) return;

    // Submit the answer and move to next question
    widget.provider.answerCurrentQuestion(_selectedOptionId!);

    // Check if assessment is complete
    if (widget.provider.isAssessmentComplete) {
      _handleAssessmentComplete();
    } else {
      // Reset for the next question
      setState(() {
        _selectedOptionId = null;
        _flowStep = 0; // Back to initial instruction for next question
        _currentPassageIndex = 0; // Reset passage index
      });
    }
  }

  void _handleAssessmentComplete() {
  // Calculate reading level
  final score = widget.provider.score;
  final total = widget.provider.totalQuestions;
  final readingPercentage = widget.provider.getEffectiveReadingPercentage();
  final readingLevel = widget.provider.readingLevel ?? "Undefined";

  // Update user's reading level in the database
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userId = authProvider.currentUser?.idNumber.toString() ?? '';

  if (userId.isEmpty) {
    print('Error: No user ID available for completing assessment');
    return;
  }

  print('[PreAssessmentScreen] ASSESSMENT COMPLETED - Saving results for user $userId');
  print('[PreAssessmentScreen] Reading Level: $readingLevel, Score: $score/$total, Percentage: $readingPercentage%');

  // Update AuthProvider memory model
  authProvider.updateUserReadingLevel(readingLevel);
  authProvider.updateReadingPercentage(readingPercentage);
  authProvider.setPreAssessmentCompleted(true);

  final isMainAssessment = !(widget.assessmentId == 'PRE_ASSESSMENT_001' || 
                           widget.assessmentId.toString().contains('PRE') || 
                           widget.assessmentId == 1);
                           
  print('[PreAssessmentScreen] Is Main Assessment (Aralin): $isMainAssessment');

  try {
    // Save basic assessment results
    widget.provider.saveResults(userId);

    // Save detailed results
    widget.provider.saveDetailedResults(userId, widget.assessmentId.toString())
        .then((_) {
      print('[PreAssessmentScreen] Successfully saved detailed assessment results to DB');
      
      // For main assessments, update lesson completion using category mapping
      if (isMainAssessment) {
        _updateLessonCompletionByCategory(userId);
      }
    }).catchError((e) {
      print('[PreAssessmentScreen] Error saving detailed assessment results: $e');
      _directlyUpdateUserProfile(userId, readingLevel, readingPercentage);
    });

    // Update user profile with new reading level
    widget.provider.updateUserReadingLevel(
      authProvider,
      readingLevel,
      readingPercentage: readingPercentage,
    );
  } catch (e) {
    print('[PreAssessmentScreen] Error during assessment completion: $e');
    _directlyUpdateUserProfile(userId, readingLevel, readingPercentage);
  }

  // Call completion callback if provided
  if (widget.onAssessmentComplete != null) {
    widget.onAssessmentComplete!(readingLevel, score, total, readingPercentage);
  }

  // Pause background music before navigating to results
  _pauseBackgroundMusic();

  // Navigate to results screen
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => PreAssessmentResultScreen(
        readingLevel: readingLevel,
        score: score,
        totalQuestions: total,
        readingPercentage: readingPercentage,
        assessmentType: isMainAssessment ? 'main-assessment' : 'pre-assessment',
        assessmentId: widget.assessmentId.toString(),
      ),
    ),
  );
}


  // Add a direct database update method as fallback
  void _directlyUpdateUserProfile(
      String userId, String readingLevel, double readingPercentage) {
    print(
        '[PreAssessmentScreen] FALLBACK: Directly updating user profile in database');
    try {
      // Get database service
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        dbService.initialize();
      }

      // Directly update user document with completed pre-assessment
      dbService.updateUserPreAssessmentStatus(userId, true, readingLevel);

      print(
          '[PreAssessmentScreen] Successfully applied fallback user profile update');
    } catch (e) {
      print('[PreAssessmentScreen] Fallback profile update also failed: $e');
    }
  }

  void _updateLessonCompletionByCategory(String userId) {
  try {
    // Get the category from the current assessment
    final category = widget.category ?? _getCurrentAssessmentCategory();
    
    if (category == null || category.isEmpty) {
      print('[PreAssessmentScreen] No category found for lesson completion tracking');
      return;
    }

    // Map categories to lesson indices
    final categoryToLessonMap = {
      'Alphabet Knowledge': 1,
      'Phonological Awareness': 2,
      'Decoding': 3,
      'Word Recognition': 4,
      'Reading Comprehension': 5,
    };

    final lessonIndex = categoryToLessonMap[category];
    
    if (lessonIndex != null) {
      print('[PreAssessmentScreen] Marking lesson $lessonIndex (Category: $category) as completed for user $userId');
      
      final dbService = DatabaseService();
      dbService.markLessonAsCompletedAndUpdateNext(userId, lessonIndex).then((_) {
        print('[PreAssessmentScreen] Successfully marked lesson $lessonIndex as completed');
        
        // Update AuthProvider with completed lesson
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.addCompletedLesson(lessonIndex);
        
      }).catchError((e) {
        print('[PreAssessmentScreen] Error marking lesson as completed: $e');
      });
    } else {
      print('[PreAssessmentScreen] Unknown category: $category, cannot determine lesson index');
    }
  } catch (e) {
    print('[PreAssessmentScreen] Error in _updateLessonCompletionByCategory: $e');
  }
}

String? _getCurrentAssessmentCategory() {
  // Try to get category from provider
  if (widget.provider.currentCategory != null) {
    return widget.provider.currentCategory;
  }
  
  // Try to get from current question
  final currentQuestion = widget.provider.currentQuestion;
  if (currentQuestion != null) {
    return widget.provider.getCategoryName(currentQuestion.questionTypeId);
  }
  
  return null;
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
      backgroundColor: theme.primaryColor,
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _errorMessage != null
                    ? _buildErrorState(theme)
                    : _buildQuestionContent(theme),
          ),
          // Add confetti controller for fireworks animation
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -1.0, // Emit downward
              emissionFrequency: 0.05,
              numberOfParticles: 30,
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
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
      ),
    );
  }

  Widget _buildErrorState(AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                fontSize: themeProvider.getRealFontSize(16),
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
                  fontSize: themeProvider.getRealFontSize(16),
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
            fontSize: themeProvider.getRealFontSize(16),
          ),
        ),
      );
    }

    return Column(
      children: [
        // MODIFIED: Back button instead of close button
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: Icon(
              _canGoBack() ? Icons.arrow_back : Icons.close,
              color: theme.textColor,
            ),
            onPressed: () {
              if (_canGoBack()) {
                _goToPreviousQuestion();
              } else {
                // Show confirmation dialog when trying to exit on first question
                _showExitConfirmation();
              }
            },
          ),
        ),

        // Progress indicator (e.g., "1/5")
        _buildProgressIndicator(provider, theme),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _showFeedback 
                ? _buildFeedbackContent(theme) // Show feedback when answer selected
                : ListView(
                    children: [
                      const SizedBox(height: 10),

                      // Content changes based on question type and flow step
                      _buildFlowContent(currentQuestion, theme),

                      const SizedBox(height: 20),

                      // Continue button
                      _buildContinueButton(provider, theme),

                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // New method to build feedback content
  Widget _buildFeedbackContent(AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return const SizedBox.shrink();

    // Find the selected option
    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == _selectedOptionId,
      orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    // Colors for feedback
    final Color backgroundColor = _isCorrectAnswer 
        ? const Color(0xFFE3FFEC) // Light green for correct
        : const Color(0xFFFFF0F0); // Light red for incorrect

    final Color textColor = _isCorrectAnswer 
        ? Colors.green 
        : Colors.red;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Feedback card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
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
              // Feedback header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCorrectAnswer ? Colors.green : Colors.red,
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
                      color: textColor,
                      fontSize: themeProvider.getRealFontSize(32),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Selected answer display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: _isCorrectAnswer 
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCorrectAnswer ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedOption.optionText,
                        style: TextStyle(
                          fontSize: themeProvider.getRealFontSize(20),
                          fontWeight: FontWeight.bold,
                          color: _isCorrectAnswer ? Colors.green[700] : Colors.red[700],
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                    Icon(
                      _isCorrectAnswer ? Icons.check_circle : Icons.cancel,
                      color: _isCorrectAnswer ? Colors.green : Colors.red,
                      size: 30,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Explanation text
              Text(
                _feedbackDescription,
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  color: Colors.black87,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'MAG PATULOY',
                    style: TextStyle(
                      fontSize: themeProvider.getRealFontSize(18),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
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

  Widget _buildFlowContent(Question question, AppThemeData theme) {
    // Handle reading comprehension questions differently
    if (question.questionTypeId == 'reading_comprehension') {
      return _buildReadingComprehensionContent(question, theme);
    } else {
      // For non-reading comprehension questions - simple display
      return _buildRegularQuestionContent(question, theme);
    }
  }

  Widget _buildReadingComprehensionContent(
      Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_flowStep == 0) {
      // Step 1: Show just the instruction
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              color: theme.accentColor,
              size: 60,
            ),
            const SizedBox(height: 20),
            _buildQuestionText(question.questionText, theme, themeProvider),
          ],
        ),
      );
    } else if (_flowStep == 1) {
      // Step 2: Show the passage
      // Extract passage from metadata
      dynamic passageData = _getPassageData(question);

      if (passageData is List && passageData.isNotEmpty) {
        // Get the current passage based on index
        if (_currentPassageIndex >= passageData.length) {
          _currentPassageIndex = passageData.length - 1;
        }

        final currentPassage = passageData[_currentPassageIndex];
        String passageText =
            currentPassage['pageText'] ?? 'No passage content available';
        String? passageImage = currentPassage['pageImage'];
        int pageNumber =
            currentPassage['pageNumber'] ?? (_currentPassageIndex + 1);

        // Track total content available for reading percentage calculation
        if (_currentPassageIndex == 0) {
          int totalContent = 0;
          for (var passage in passageData) {
            if (passage['pageText'] != null) {
              totalContent += passage['pageText'].toString().length;
            }
          }
          widget.provider.recordAvailableContent(totalContent);
        }

        return Column(
          children: [
            // Page indicator
            Text(
              'Page $pageNumber of ${passageData.length}',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(14),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Show passage image if available
            if (passageImage != null && passageImage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    passageImage,
                    fit: BoxFit.contain,
                    height: 180,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(theme.accentColor),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image,
                          color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              ),

            // Passage content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: theme.accentColor, width: 1),
              ),
              child: Text(
                passageText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: themeProvider.getRealFontSize(16),
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),

            // Add TTS button for passage text
            if (themeProvider.textToSpeechEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isTTSPlaying
                        ? _stopTTS
                        : () => _speakText(passageText),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _isTTSPlaying ? Colors.red : theme.accentColor,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isTTSPlaying ? Colors.red : theme.accentColor)
                                    .withOpacity(0.3),
                            blurRadius: _isTTSPlaying ? 8 : 0,
                            spreadRadius: _isTTSPlaying ? 1 : 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isTTSPlaying
                                  ? Icons.stop_rounded
                                  : Icons.menu_book_rounded,
                              color: Colors.white,
                              size: _isTTSPlaying ? 22 : 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTTSPlaying
                                ? 'Ihinto ang Pagbasa'
                                : 'Basahin ang Teksto',
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(14),
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
              ),
          ],
        );
      } else if (passageData != null) {
        // Handle single passage case
        String passageText =
            passageData['pageText'] ?? 'No passage content available';
        String? passageImage = passageData['pageImage'];

        // Record content for reading percentage
        if (passageText.isNotEmpty) {
          widget.provider.recordAvailableContent(passageText.length);
        }

        return Column(
          children: [
            // Show passage image if available
            if (passageImage != null && passageImage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    passageImage,
                    fit: BoxFit.contain,
                    height: 180,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image,
                          color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              ),

            // Passage content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: theme.accentColor, width: 1),
              ),
              child: Text(
                passageText,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: themeProvider.getRealFontSize(16),
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),

            // Add TTS button for passage text
            if (themeProvider.textToSpeechEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isTTSPlaying
                        ? _stopTTS
                        : () => _speakText(passageText),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _isTTSPlaying ? Colors.red : theme.accentColor,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isTTSPlaying ? Colors.red : theme.accentColor)
                                    .withOpacity(0.3),
                            blurRadius: _isTTSPlaying ? 8 : 0,
                            spreadRadius: _isTTSPlaying ? 1 : 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isTTSPlaying
                                  ? Icons.stop_rounded
                                  : Icons.menu_book_rounded,
                              color: _isTTSPlaying
                                  ? Colors.red
                                  : theme.accentColor,
                              size: _isTTSPlaying ? 24 : 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTTSPlaying
                                ? 'Ihinto ang Pagbasa'
                                : 'Basahin ang Teksto',
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(14),
                              fontWeight: FontWeight.w600,
                              fontFamily: themeProvider.fontFamily,
                              color: _isTTSPlaying
                                  ? Colors.red
                                  : theme.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      } else {
        // No passage data available - skip passage step and go directly to question
        setState(() {
          _flowStep = 2; // Skip to question step
          _selectedOptionId = null;
        });
        return const SizedBox.shrink();
      }
    } else if (_flowStep == 2) {
      // Step 3: Show the question and choices
      // Extract question from metadata
      dynamic sentenceQuestion = _getSentenceQuestionData(question);
      String questionText =
          sentenceQuestion?['questionText'] ?? question.questionText;
      String? questionImage = sentenceQuestion?['questionImage'];

      // Use the options from the question model, but if they're empty, generate them from sentence question
      List<AssessmentOption> options = question.options;
      if (options.isEmpty && sentenceQuestion != null) {
        options = _generateReadingComprehensionOptions(sentenceQuestion);
      }

      return Column(
        children: [
          // Question text with TTS
          _buildQuestionText(questionText, theme, themeProvider),

          // Question image if available
          if (questionImage != null && questionImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  questionImage,
                  fit: BoxFit.contain,
                  height: 150,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    alignment: Alignment.center,
                    child:
                        Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                ),
              ),
            ),

          // Options - display message if no options available
          options.isEmpty
              ? Center(
                  child: Text(
                    'No answer options available',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: themeProvider.getRealFontSize(16),
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                )
              : Column(
                  children: options
                      .map((option) => _buildOptionButton(option, theme))
                      .toList(),
                ),
        ],
      );
    }

    // Fallback - should not reach here
    return const SizedBox.shrink();
  }

  // Helper method to get passage data from question
  dynamic _getPassageData(Question question) {
    // First try to get raw data from the provider (this is the key fix)
    final rawData =
        widget.provider.getOriginalQuestionData(question.questionId);

    if (rawData != null && rawData['passages'] != null) {
      print('[_getPassageData] Found passages in raw question data');
      return rawData['passages'];
    }

    // Fallback to using the passages field directly from the Question model
    if (question.passages != null && question.passages!.isNotEmpty) {
      print(
          '[_getPassageData] Found ${question.passages!.length} passages in question model');
      return question.passages;
    }

    print('[_getPassageData] No passages found for ${question.questionId}');
    return null;
  }

  // Helper method to get sentence question data from question
  dynamic _getSentenceQuestionData(Question question) {
    // First try to get raw data from the provider
    final rawData =
        widget.provider.getOriginalQuestionData(question.questionId);

    if (rawData != null && rawData['sentenceQuestions'] != null) {
      print(
          '[_getSentenceQuestionData] Found sentence questions in raw question data');
      return rawData['sentenceQuestions'] is List &&
              rawData['sentenceQuestions'].isNotEmpty
          ? rawData['sentenceQuestions'][0]
          : null;
    }

    // Fallback to using the sentenceQuestions field directly from the Question model
    if (question.sentenceQuestions != null &&
        question.sentenceQuestions!.isNotEmpty) {
      print(
          '[_getSentenceQuestionData] Found sentence questions in question model');
      return question.sentenceQuestions!.first;
    }

    print(
        '[_getSentenceQuestionData] No sentence questions found for ${question.questionId}');
    return null;
  }

  // FIXED: Generate proper options for reading comprehension questions
  List<AssessmentOption> _generateReadingComprehensionOptions(
      dynamic sentenceQuestion) {
    if (sentenceQuestion != null) {
      String correctAnswer = sentenceQuestion['correctAnswer'] ?? '';
      String incorrectAnswer = sentenceQuestion['incorrectAnswer'] ?? '';

      if (correctAnswer.isNotEmpty && incorrectAnswer.isNotEmpty) {
        return [
          AssessmentOption(
            optionId: '1',
            optionText: correctAnswer,
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: incorrectAnswer,
            isCorrect: false,
          ),
        ];
      }
    }

    // Return empty list if no proper data found
    return [];
  }

  Widget _buildRegularQuestionContent(Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Question text with TTS
        _buildQuestionText(question.questionText, theme, themeProvider),

        // Display image if available
        if (question.hasImage && question.imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                question.imageUrl!,
                fit: BoxFit.contain,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  // If network image fails, try loading as asset
                  return Image.asset(
                    question.imageUrl!,
                    fit: BoxFit.contain,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Question prompt (e.g., "ASO", "BO + LA", etc.)
        if (question.displayedText != null &&
            question.displayedText!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.accentColor),
            ),
            child: Center(
              child: Text(
                question.displayedText!,
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: themeProvider.getRealFontSize(40),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Audio content
        if (question.hasAudio && question.audioUrl != null)
          Center(
            child: IconButton(
              icon: Icon(Icons.volume_up, color: theme.accentColor, size: 48),
              onPressed: () => _playAudio(question.audioUrl!),
            ),
          ),

        const SizedBox(height: 10),

        // Answer options
        ...question.options.map((option) => _buildOptionButton(option, theme)),
      ],
    );
  }

  Widget _buildProgressIndicator(
      AssessmentProvider provider, AppThemeData theme) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Calculate the total width and the position for the progress pill
    final totalWidth =
        MediaQuery.of(context).size.width - 40; // 40 for left and right margins
    final progressRatio = current / total;

    // Calculate the position of the pill
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Stack(
        children: [
          // Background track
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Progress indicator - yellow filled portion
          FractionallySizedBox(
            widthFactor: progressRatio,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Position the pill with better accuracy
          // For beginning of progress (0-10%), keep pill at start
          // For end of progress (90-100%), keep pill at end
          // For middle, align pill with progress
          Positioned(
            left: progressRatio < 0.1
                ? 0
                : progressRatio > 0.9
                    ? totalWidth - pillWidth
                    : pillPosition,
            top: 0,
            child: Container(
              height: 40,
              width: pillWidth,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$current/$total',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    fontSize: themeProvider.getRealFontSize(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced option button with improved TTS functionality
  Widget _buildOptionButton(AssessmentOption option, AppThemeData theme) {
    final isSelected = _selectedOptionId == option.optionId;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isTTSEnabled = themeProvider.textToSpeechEnabled;
    final isThisOptionPlaying =
        _isTTSPlaying && _currentPlayingOptionId == option.optionId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _selectOption(option.optionId),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.accentColor, width: 2),
            borderRadius: BorderRadius.circular(30),
            color: isSelected
                ? theme.accentColor
                : theme.accentColor.withOpacity(0.4),
          ),
          child: Row(
            children: [
              // Option text
              Expanded(
                child: Text(
                  option.optionText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(18),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),

              // Enhanced TTS button for the option
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
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isThisOptionPlaying
                              ? Colors.red
                              : theme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: (isThisOptionPlaying
                                      ? Colors.red
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
    // FIXED: Make button clickable during reading comprehension flow
    final isButtonEnabled = _selectedOptionId != null || // A choice is selected
        (_flowStep <= 1 &&
            provider.currentQuestion?.questionTypeId ==
                'reading_comprehension'); // In reading flow (including passages)

    final continueBtnText = _getContinueButtonText();
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _goToNextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isButtonEnabled ? theme.accentColor : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade600,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          continueBtnText,
          style: TextStyle(
            fontSize: themeProvider.getRealFontSize(18),
            fontWeight: FontWeight.bold,
            color:
                isButtonEnabled ? theme.buttonTextColor : Colors.grey.shade800,
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      ),
    );
  }

  // Helper to get context-appropriate continue button text
  String _getContinueButtonText() {
    final provider = widget.provider;

    // Default from assessment
    final defaultText =
        provider.assessment?.continueButtonText ?? 'MAG PATULOY';

    // If in reading passage flow
    if (provider.currentQuestion?.questionTypeId == 'reading_comprehension') {
      if (_flowStep == 0) {
        return 'SIMULAN ANG PAGBASA'; // Start Reading
      } else if (_flowStep == 1) {
        final passages = _getPassageData(provider.currentQuestion!);
        if (passages is List && _currentPassageIndex < passages.length - 1) {
          return 'SUSUNOD NA PAHINA'; // Next Page
        } else {
          return 'SAGUTIN ANG TANONG'; // Answer the Question
        }
      }
    }

    // Default continue text
    return defaultText;
  }

  Widget _buildQuestionText(
      String text, AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.accentColor, width: 1),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          if (themeProvider.textToSpeechEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isTTSPlaying ? _stopTTS : () => _speakText(text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _isTTSPlaying
                            ? Colors.red.withOpacity(0.15)
                            : theme.accentColor.withOpacity(0.15),
                        border: Border.all(
                          color: _isTTSPlaying ? Colors.red : theme.accentColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isTTSPlaying ? Colors.red : theme.accentColor)
                                    .withOpacity(0.3),
                            blurRadius: _isTTSPlaying ? 8 : 0,
                            spreadRadius: _isTTSPlaying ? 1 : 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isTTSPlaying
                                  ? Icons.stop_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: _isTTSPlaying ? 22 : 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTTSPlaying ? 'Ihinto' : 'Pakinggan',
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(14),
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  // TTS functionality for main text
  void _speakText(String text) {
    if (!mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      // Reset playing option ID
      _currentPlayingOptionId = null;

      _ttsProvider!.speakText(
        text,
        speed: 0.4, // Explicitly set slower speed
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
          // Handle error silently
          print('TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    } else {
      print(
          'TTS not available or enabled. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
    }
  }

  // TTS functionality for option text
  void _speakOptionText(String text, String optionId) {
    if (!mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        text,
        speed: 0.4, // Explicitly set slower speed
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
          // Handle error silently
          print('TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _currentPlayingOptionId = null;
            });
          }
        },
      );
    } else {
      print(
          'TTS not available or enabled. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
    }
  }

  // Stop any ongoing TTS
  void _stopTTS() {
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
      setState(() {
        _isTTSPlaying = false;
        _currentPlayingOptionId = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _correctAnswerPlayer.dispose();
    _incorrectAnswerPlayer.dispose(); // Dispose new audio player
    _backgroundMusicPlayer.dispose(); // Dispose background music player
    _confettiController.dispose(); // Dispose confetti controller
    _stopTTS(); // Stop TTS when disposing
    super.dispose();
  }
}