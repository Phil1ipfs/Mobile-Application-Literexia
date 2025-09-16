import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:provider/provider.dart';
import 'package:literexia/features/assessments/ui/WordRecognitionScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import 'package:literexia/features/auth/logic/auth_provider.dart';

class DecodingScreen extends StatefulWidget {
  final String assessmentId;
  final Function(String optionId)? onOptionSelected;
  final Function()? onContinue;

  const DecodingScreen({
    Key? key,
    required this.assessmentId,
    this.onOptionSelected,
    this.onContinue,
  }) : super(key: key);

  @override
  State<DecodingScreen> createState() => _DecodingScreenState();
}

class _DecodingScreenState extends State<DecodingScreen>
    with TickerProviderStateMixin {
  // TTS state for question text
  bool _isTTSPlaying = false;
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Audio players
  final AudioPlayer _correctSoundPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();
  final AudioPlayer _wrongSoundPlayer = AudioPlayer();

  // Confetti controllers for fireworks animation
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

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

  // Assessment data from database
  String _questionText = '';
  String? _questionImage;
  List<String> _displaySequence = [];
  List<String> _dragElements = [];
  List<String> _correctSequence = [];
  int? _blankPosition;
  bool _isLoading = true;
  String? _errorMessage;

  // Drag and drop state
  List<String> _droppedSequence = [];
  List<String> _availableDragElements = [];
  bool _isPakitsekEnabled = false;

  // Feedback state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();

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

    // Initialize confetti controller
    // Initialize confetti controllers
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Load decoding assessment data
    _loadDecodingData();

    // Preload audio files
    _preloadAudioFiles();

    // Initialize TTS and Theme providers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);

        // Ensure TTS is initialized
        if (_ttsProvider != null && !_ttsProvider!.isAvailable) {
          await _ttsProvider!.initialize();
          print(
              '[DecodingScreen] TTS initialized - Available: ${_ttsProvider!.isAvailable}');
          // Trigger a rebuild to update TTS button visibility
          if (mounted) {
            setState(() {});
          }
        }

        // Set current user ID in assessment provider for saving responses
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.idNumber?.toString();
          if (userId != null && userId.isNotEmpty) {
            Provider.of<AssessmentProvider>(context, listen: false)
                .setCurrentUserId(userId);
            print('[DecodingScreen] Set userId in AssessmentProvider: $userId');
          }
        } catch (e) {
          print('[DecodingScreen] Failed setting userId in provider: $e');
        }
      }
    });
  }

  Future<void> _loadDecodingData() async {
    try {
      print('[DecodingScreen] ===== STARTING DYNAMIC DECODING DATA LOAD =====');
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);

      // Load the complete pre-assessment data dynamically from MongoDB
      print('[DecodingScreen] Loading pre-assessment from MongoDB...');
      await assessmentProvider.loadPreAssessment();
      print('[DecodingScreen] Pre-assessment loaded successfully');

      // Debug: Check what's in the assessment
      final assessment = assessmentProvider.assessment;
      print('[DecodingScreen] Assessment: ${assessment?.title ?? "null"}');
      print(
          '[DecodingScreen] Assessment ID: ${assessment?.assessmentId ?? "null"}');

      final questions = assessment?.questions ?? [];
      print('[DecodingScreen] Total questions loaded: ${questions.length}');

      // Print all question IDs for debugging
      for (int i = 0; i < questions.length; i++) {
        print('[DecodingScreen] Question $i: ${questions[i].questionId}');
      }

      // Dynamically find DC questions from MongoDB data
      final dcQuestions =
          questions.where((q) => q.questionId.startsWith('DC_')).toList();

      // Sort DC questions to ensure proper order
      dcQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

      // Debug: Show all DC questions found
      print('[DecodingScreen] DC Questions found in database: ${dcQuestions.map((q) => q.questionId).toList()}');
      print('[DecodingScreen] Total DC questions: ${dcQuestions.length}');

      if (dcQuestions.isEmpty) {
        print(
            '[DecodingScreen] ❌ ERROR: No decoding questions found in MongoDB!');
        print(
            '[DecodingScreen] Available questions: ${questions.map((q) => q.questionId).toList()}');
        setState(() {
          _isLoading = false;
          _errorMessage = 'No decoding questions found in database';
        });
        return;
      }

      // Set current question to first DC question
      final firstDCQuestion = dcQuestions.first;
      final firstDCIndex = questions
          .indexWhere((q) => q.questionId == firstDCQuestion.questionId);

      if (firstDCIndex != -1) {
        assessmentProvider.currentQuestionIndex = firstDCIndex;
        print(
            '[DecodingScreen] Set current question index to: $firstDCIndex (${firstDCQuestion.questionId})');
      }

      // Get the current question data dynamically
      final currentQuestion = assessmentProvider.currentQuestion;

      // Safety check: If current question is not a DC question, navigate to appropriate screen
      if (currentQuestion != null &&
          !currentQuestion.questionId.startsWith('DC_')) {
        print(
            '[DecodingScreen] ⚠️  Current question ${currentQuestion.questionId} is not a DC question!');
        if (currentQuestion.questionId.startsWith('WR_')) {
          print(
              '[DecodingScreen] Redirecting to WordRecognitionScreen for ${currentQuestion.questionId}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToWordRecognition();
            }
          });
        } else if (currentQuestion.questionId.startsWith('RC_')) {
          print(
              '[DecodingScreen] Should navigate to ReadingComprehensionScreen for ${currentQuestion.questionId}');
          // Add RC navigation if needed
        }
        return;
      }

      if (currentQuestion != null &&
          currentQuestion.questionId.startsWith('DC_')) {
        print(
            '[DecodingScreen] Current question: ${currentQuestion.questionId}');

        // Get the original question data which contains the decoding data from MongoDB
        print(
            '[DecodingScreen] Attempting to get original data for: ${currentQuestion.questionId}');
        final originalData = assessmentProvider
            .getOriginalQuestionData(currentQuestion.questionId);

        if (originalData != null) {
          print('[DecodingScreen] ===== DYNAMIC MONGODB DATA =====');
          print(
              '[DecodingScreen] Raw data keys: ${originalData.keys.toList()}');
          print('[DecodingScreen] Raw data: $originalData');
          print('[DecodingScreen] ===== END DYNAMIC MONGODB DATA =====');

          // Dynamically extract image from MongoDB data
          String? questionImage = originalData['questionImage'] ??
              currentQuestion.imageUrl ??
              originalData['imageUrl'];

          print(
              '[DecodingScreen] Question image from originalData: ${originalData['questionImage']}');
          print(
              '[DecodingScreen] Question image from currentQuestion: ${currentQuestion.imageUrl}');
          print('[DecodingScreen] Final question image: $questionImage');

          // Dynamically extract all data from MongoDB with flexible field names
          setState(() {
            _questionText = originalData['questionText'] ??
                currentQuestion.questionText ??
                originalData['question'] ??
                '';
            _questionImage = questionImage;

            // Dynamically get the sequence data with fallback field names
            _displaySequence = _extractListFromDynamic(originalData,
                ['displaySequence', 'sequence', 'display', 'initialSequence']);
            _dragElements = _extractListFromDynamic(originalData, [
              'dragElements',
              'elements',
              'options',
              'choices',
              'dragItems'
            ]);
            _correctSequence = _extractListFromDynamic(originalData,
                ['correctSequence', 'correctAnswer', 'answer', 'solution']);
            _blankPosition = originalData['blankPosition'] ??
                originalData['blank'] ??
                originalData['blankIndex'];

            // If blankPosition is null but we have displaySequence, try to infer it from empty positions
            if (_blankPosition == null &&
                _displaySequence.isNotEmpty &&
                _correctSequence.length == 1) {
              for (int i = 0; i < _displaySequence.length; i++) {
                if (_displaySequence[i].isEmpty) {
                  _blankPosition = i;
                  print(
                      '[DecodingScreen] Inferred blankPosition from displaySequence: $_blankPosition');
                  break;
                }
              }
            }

            print('[DecodingScreen] ===== BEFORE INITIALIZATION =====');
            print('[DecodingScreen] displaySequence: $_displaySequence');
            print('[DecodingScreen] dragElements: $_dragElements');
            print('[DecodingScreen] correctSequence: $_correctSequence');
            print('[DecodingScreen] blankPosition: $_blankPosition');
            print('[DecodingScreen] ===== END BEFORE INITIALIZATION =====');

            // Initialize drag and drop state dynamically based on data structure
            _initializeDragDropState();
            _isLoading = false;
          });

          print('[DecodingScreen] ===== DYNAMIC LOADED DATA DEBUG =====');
          print('[DecodingScreen] Question text: $_questionText');
          print('[DecodingScreen] Question image: $_questionImage');
          print('[DecodingScreen] Display sequence: $_displaySequence');
          print('[DecodingScreen] Drag elements: $_dragElements');
          print('[DecodingScreen] Correct sequence: $_correctSequence');
          print('[DecodingScreen] Blank position: $_blankPosition');
          print(
              '[DecodingScreen] Dropped sequence after init: $_droppedSequence');
          print('[DecodingScreen] ===== END DYNAMIC LOADED DATA DEBUG =====');

          // Start the typewriter effect flow when assessment is loaded
          _startTypewriterFlow();
        } else {
          setState(() {
            _errorMessage = 'No decoding assessment data available in MongoDB';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No current decoding question available';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DecodingScreen] Error loading dynamic decoding data: $e');
      setState(() {
        _errorMessage = 'Error loading assessment from MongoDB: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method to extract list data dynamically with multiple field name options
  List<String> _extractListFromDynamic(
      Map<String, dynamic> data, List<String> fieldNames) {
    for (String fieldName in fieldNames) {
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        try {
          return List<String>.from(data[fieldName]);
        } catch (e) {
          print('[DecodingScreen] Error parsing $fieldName as list: $e');
          // Try to convert individual items to string
          if (data[fieldName] is List) {
            return (data[fieldName] as List).map((e) => e.toString()).toList();
          }
        }
      }
    }
    return [];
  }

  // Initialize drag and drop state based on dynamic data structure
  void _initializeDragDropState() {
    if (_blankPosition != null) {
      // Single blank question: start with displaySequence but one blank
      print('[DecodingScreen] Initializing single-blank question');
      print('[DecodingScreen] Original displaySequence: $_displaySequence');
      print('[DecodingScreen] Blank position: $_blankPosition');
      print('[DecodingScreen] Correct sequence: $_correctSequence');

      // Handle case where displaySequence is empty but we have correctSequence
      if (_displaySequence.isEmpty && _correctSequence.isNotEmpty) {
        // For DC_008 type questions where displaySequence is null
        // Create empty sequence based on correctSequence length (usually 1)
        print(
            '[DecodingScreen] DisplaySequence is empty, creating from correctSequence length');
        _displaySequence = List<String>.filled(_correctSequence.length, '');
        _droppedSequence = List<String>.filled(_correctSequence.length, '');
      } else {
        // For DC_009, DC_010 type questions where displaySequence has values
        // Initialize droppedSequence with displaySequence values
        _droppedSequence = List<String>.from(_displaySequence);
      }

      // Ensure blank position is within bounds
      if (_blankPosition! >= 0 && _blankPosition! < _droppedSequence.length) {
        // For single-blank questions, pre-fill non-blank positions with displaySequence letters
        // and keep the blank position empty for user input
        for (int i = 0; i < _droppedSequence.length; i++) {
          if (i == _blankPosition) {
            _droppedSequence[i] = ''; // Keep blank position empty
          } else if (_displaySequence.isNotEmpty &&
              i < _displaySequence.length) {
            _droppedSequence[i] = _displaySequence[
                i]; // Pre-fill other positions with displaySequence letters
          }
        }
      }

      print(
          '[DecodingScreen] After initialization droppedSequence: $_droppedSequence');
      print('[DecodingScreen] Final displaySequence: $_displaySequence');
    } else {
      // Multiple blank question: start all empty
      if (_displaySequence.isNotEmpty) {
        _droppedSequence = List<String>.filled(_displaySequence.length, '');
      } else if (_correctSequence.isNotEmpty) {
        _droppedSequence = List<String>.filled(_correctSequence.length, '');
        _displaySequence = List<String>.filled(_correctSequence.length, '');
      } else {
        _droppedSequence = [];
      }
    }

    _availableDragElements = List<String>.from(_dragElements);
    print('[DecodingScreen] Available drag elements: $_availableDragElements');
  }

  Future<void> _preloadAudioFiles() async {
    try {
      await _correctSoundPlayer.setAsset('assets/audio/assessmentsound.mp3');
      await _buttonSoundPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _wrongSoundPlayer.setAsset('assets/audio/incorrectanswer.mp3');
    } catch (e) {
      print('[DecodingScreen] Error preloading audio files: $e');
    }
  }

  Future<void> _playCorrectSound() async {
    try {
      await _correctSoundPlayer.seek(Duration.zero);
      await _correctSoundPlayer.play();
    } catch (e) {
      print('[DecodingScreen] Error playing correct sound: $e');
    }
  }

  Future<void> _playButtonSound() async {
    try {
      await _buttonSoundPlayer.seek(Duration.zero);
      await _buttonSoundPlayer.play();
    } catch (e) {
      print('[DecodingScreen] Error playing button sound: $e');
    }
  }

  Future<void> _playWrongSound() async {
    try {
      await _wrongSoundPlayer.seek(Duration.zero);
      await _wrongSoundPlayer.play();
    } catch (e) {
      print('[DecodingScreen] Error playing wrong sound: $e');
    }
  }

  // Dynamically load current question data from provider without reloading assessment
  void _loadCurrentQuestionDataFromProvider() {
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      if (currentQuestion != null &&
          currentQuestion.questionId.startsWith('DC_')) {
        // Get the original question data dynamically from MongoDB
        final originalData = assessmentProvider
            .getOriginalQuestionData(currentQuestion.questionId);

        if (originalData != null) {
          print('[DecodingScreen] ===== DYNAMIC CURRENT QUESTION DATA =====');
          print(
              '[DecodingScreen] Current question: ${currentQuestion.questionId}');
          print('[DecodingScreen] Original data: $originalData');

          setState(() {
            // Dynamically extract text with fallback options
            _questionText = originalData['questionText'] ??
                currentQuestion.questionText ??
                originalData['question'] ??
                '';

            // Dynamically extract image with multiple field options
            _questionImage = originalData['questionImage'] ??
                originalData['imageUrl'] ??
                currentQuestion.imageUrl;

            // Dynamically extract all sequence data
            _displaySequence = _extractListFromDynamic(originalData,
                ['displaySequence', 'sequence', 'display', 'initialSequence']);
            _dragElements = _extractListFromDynamic(originalData, [
              'dragElements',
              'elements',
              'options',
              'choices',
              'dragItems'
            ]);
            _correctSequence = _extractListFromDynamic(originalData,
                ['correctSequence', 'correctAnswer', 'answer', 'solution']);
            _blankPosition = originalData['blankPosition'] ??
                originalData['blank'] ??
                originalData['blankIndex'];

            // If blankPosition is null but we have displaySequence, try to infer it from empty positions
            if (_blankPosition == null &&
                _displaySequence.isNotEmpty &&
                _correctSequence.length == 1) {
              for (int i = 0; i < _displaySequence.length; i++) {
                if (_displaySequence[i].isEmpty) {
                  _blankPosition = i;
                  print(
                      '[DecodingScreen] Inferred blankPosition from displaySequence in current question load: $_blankPosition');
                  break;
                }
              }
            }

            print('[DecodingScreen] ===== BEFORE DYNAMIC INITIALIZATION =====');
            print('[DecodingScreen] displaySequence: $_displaySequence');
            print('[DecodingScreen] dragElements: $_dragElements');
            print('[DecodingScreen] correctSequence: $_correctSequence');
            print('[DecodingScreen] blankPosition: $_blankPosition');
            print(
                '[DecodingScreen] ===== END BEFORE DYNAMIC INITIALIZATION =====');

            // Reset drag and drop state for new question dynamically
            _initializeDragDropState();
            _isPakitsekEnabled = _checkIfCompleted();
            _showFeedback = false;
          });

          print(
              '[DecodingScreen] Dynamically loaded next question: ${currentQuestion.questionId}');

          // Start typewriter flow for next question
          _startTypewriterFlow();
        }
      }
    } catch (e) {
      print(
          '[DecodingScreen] Error dynamically loading current question data: $e');
    }
  }

  // Start the typewriter effect flow
  void _startTypewriterFlow() {
    _fullQuestionText = _questionText;
    _resetFlowState();
    _startTypewriterEffect();
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
    print('[DecodingScreen] Typewriter completed!');
    setState(() {
      _typewriterCompleted = true;
      _showTTSButton = true;
      _showImage = true;
      // Don't show choices until user clicks Pakinggan
      _showChoices = false;
      _userListened = false;
    });
    print(
        '[DecodingScreen] After typewriter completion: _showTTSButton = $_showTTSButton');
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

  // Check if all required positions are filled
  bool _checkIfCompleted() {
    if (_blankPosition != null) {
      // Single blank position case (DC_004, DC_005, DC_006)
      return _droppedSequence[_blankPosition!].isNotEmpty;
    } else {
      // Multiple positions case (DC_001, DC_002, DC_003)
      return _droppedSequence.every((item) => item.isNotEmpty);
    }
  }

  // Handle drag element selection (tap to place)
  void _onDragElementTap(String element) {
    if (_showFeedback) return;

    setState(() {
      // Guard: ensure dropped and display sequences have the same length
      if (_displaySequence.length != _droppedSequence.length &&
          _droppedSequence.isNotEmpty) {
        _displaySequence = List<String>.filled(_droppedSequence.length, '');
      }
      if (_blankPosition != null) {
        // Single blank position case
        if (_blankPosition! >= 0 &&
            _blankPosition! < _droppedSequence.length &&
            _droppedSequence[_blankPosition!].isEmpty) {
          _droppedSequence[_blankPosition!] = element;
          _availableDragElements.remove(element);
        }
      } else {
        // Multiple positions case - find first empty position
        for (int i = 0; i < _droppedSequence.length; i++) {
          if (_droppedSequence[i].isEmpty) {
            _droppedSequence[i] = element;
            _availableDragElements.remove(element);
            break;
          }
        }
      }

      _isPakitsekEnabled = _checkIfCompleted();
    });
  }

  // Handle removing dropped element (tap to remove)
  void _onDroppedElementTap(int index) {
    if (_showFeedback) return;

    final element = _droppedSequence[index];
    if (element.isNotEmpty &&
        (_blankPosition == null || index == _blankPosition)) {
      setState(() {
        if (_blankPosition != null && index == _blankPosition) {
          // For single-blank questions, reset to empty string
          _droppedSequence[index] = '';
        } else {
          // For multiple-blank questions, reset to original display sequence value
          _droppedSequence[index] = _displaySequence[index];
        }
        _availableDragElements.add(element);
        _isPakitsekEnabled = _checkIfCompleted();
      });
    }
  }

  // Validate the user's answer (case-insensitive)
  bool _validateAnswer() {
    if (_blankPosition != null) {
      // Single blank position case - compare case-insensitively
      return _droppedSequence[_blankPosition!].toLowerCase() ==
          _correctSequence[0].toLowerCase();
    } else {
      // Multiple positions case - compare case-insensitively
      for (int i = 0;
          i < _correctSequence.length && i < _droppedSequence.length;
          i++) {
        if (_droppedSequence[i].toLowerCase() !=
            _correctSequence[i].toLowerCase()) {
          return false;
        }
      }
      return true;
    }
  }

  // Handle PAKITSEK button press
  void _onPakitsekPressed() async {
    if (!_isPakitsekEnabled) return;

    _playButtonSound();

    final isCorrect = _validateAnswer();

    setState(() {
      _showFeedback = true;
      _isCorrectAnswer = isCorrect;
      _feedbackMessage = isCorrect
          ? 'Tama!\n\nAng iyong sagot ay tama!'
          : 'Mali!\n\nAng iyong sagot ay mali!';
    });

    // Play effects based on answer
    if (isCorrect) {
      _playCorrectSound();
      _confettiControllerLeft.play();
      _confettiControllerRight.play();
    } else {
      _playWrongSound();
    }

    // Record the response
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null) {
      // Save individual response in new MongoDB format
      await assessmentProvider.saveIndividualResponse(
        questionId: currentQuestion.questionId,
        category: 'decoding',
        questionType: currentQuestion.questionType ?? 'drag_drop',
        response: _droppedSequence.where((item) => item.isNotEmpty).toList(),
        isCorrect: isCorrect,
        responseTime: 0, // Could be tracked if needed
      );

      // Record the response using the existing method for compatibility
      assessmentProvider.answerCurrentQuestion(_droppedSequence.join(','));
    }
  }

  // Handle continue/proceed to next question
  void _onContinue() {
    _playButtonSound();
    if (_showFeedback) {
      // Proceed to next question after showing feedback
      _proceedToNextQuestion();
    }
  }

  // Proceed to next decoding question or exit
  void _proceedToNextQuestion() {
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);

    // answerCurrentQuestion() already moved to the next question
    // Just check if we're still in DC questions or need to move to WR
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null && currentQuestion.questionId.startsWith('DC_')) {
      // Still in DC questions, load the current question data
      print('[DecodingScreen] Loading next DC question: ${currentQuestion.questionId}');
      _loadCurrentQuestionDataFromProvider();
    } else {
      // No more DC questions or moved to a different section, go to WR
      print('[DecodingScreen] DC section complete, navigating to WordRecognition');

      // Find the first WR question and set it as current question
      final allQuestions = assessmentProvider.assessment?.questions ?? [];
      final firstWrIndex =
          allQuestions.indexWhere((q) => q.questionId.startsWith('WR_'));

      if (firstWrIndex != -1) {
        // Set current question to first WR question
        assessmentProvider.currentQuestionIndex = firstWrIndex;
        final firstWrQuestion = allQuestions[firstWrIndex];
        print(
            '[DecodingScreen] Setting current question to first WR question: ${firstWrQuestion.questionId} at index $firstWrIndex');
      } else {
        print('[DecodingScreen] No WR questions found in database!');
      }

      // Capture additional providers while context is still valid
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final ttsProvider = Provider.of<TTSProvider>(context, listen: false);

      // Navigate to WordRecognitionScreen with proper provider context
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: assessmentProvider),
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: ttsProvider),
            ],
            child: WordRecognitionScreen(
              assessmentId: widget.assessmentId,
              onContinue: widget.onContinue,
            ),
          ),
        ),
      );
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
            child: Column(
              children: [
                // Removed back arrow

                // Add slight top spacing then progress indicator
                const SizedBox(height: 8),
                _buildProgressIndicator(
                    Provider.of<AssessmentProvider>(context), theme),

                // Question text with TTS
                if (!_isLoading && _questionText.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildQuestionText(themeProvider),
                  ),
                ],

                // Main content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _showFeedback
                        ? _buildFeedbackContent(themeProvider)
                        : _buildDecodingContent(themeProvider),
                  ),
                ),

                // PAKITSEK/MAG PATULOY button - only show if user has listened
                if (_userListened)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _showFeedback
                            ? _onContinue
                            : ((_isPakitsekEnabled && _userListened)
                                ? _onPakitsekPressed
                                : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_showFeedback ||
                                  (_isPakitsekEnabled && _userListened))
                              ? const Color(0xFF1BAC24) // Green when enabled
                              : const Color(0xFFD9D9D9), // Grey when disabled
                          disabledBackgroundColor:
                              const Color(0xFFD9D9D9).withOpacity(0.5),
                          foregroundColor: (_showFeedback ||
                                  (_isPakitsekEnabled && _userListened))
                              ? Colors.white
                              : const Color(0xFF333333),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _showFeedback ? 'MAG PATULOY' : 'TIGNAN ANG SAGOT',
                          style: TextStyle(
                            fontSize: themeProvider.getRealFontSize(18),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  )
              ],
            ),
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

  // Progress indicator for DC questions (position within DC-only list)
  Widget _buildProgressIndicator(
      AssessmentProvider provider, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Build a de-duplicated, ordered list of DC question IDs from the loaded assessment
    final allQuestions = provider.assessment?.questions.isNotEmpty == true
        ? provider.assessment!.questions
        : provider.questions;
    final dcIdsAll = allQuestions
        .where((q) => q.questionId.startsWith('DC_'))
        .map((q) => q.questionId)
        .toSet()
        .toList();
    // Sort by numeric suffix if possible (DC_001 → 1)
    dcIdsAll.sort((a, b) {
      int parseNum(String id) {
        final numStr = id.replaceFirst('DC_', '');
        return int.tryParse(numStr) ?? 0;
      }

      return parseNum(a).compareTo(parseNum(b));
    });
    // Consider all DC questions found in MongoDB dynamically
    final dcIds = dcIdsAll.toList();
    final total = dcIds.isEmpty ? 1 : dcIds.length;

    // Determine current position within DC-only sequence
    int current = 1;
    final currentQuestion = provider.currentQuestion;
    if (currentQuestion != null &&
        currentQuestion.questionId.startsWith('DC_')) {
      final idx = dcIds.indexWhere((id) => id == currentQuestion.questionId);
      if (idx != -1) {
        current = idx + 1;
      }
    }

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = current / total;
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    return Container(
      height:
          48, // extra space so the pill isn't clipped when positioned with a negative top
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Stack(
        clipBehavior:
            Clip.none, // allow the pill to draw outside the stack bounds
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progressRatio,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE37C),
                borderRadius: BorderRadius.circular(10),
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
                borderRadius: BorderRadius.circular(20),
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

  // Question text with TTS functionality
  Widget _buildQuestionText(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    if (_questionText.isEmpty) return const SizedBox.shrink();

    // Debug TTS button visibility conditions
    print('[DecodingScreen] TTS Button Debug:');
    print('[DecodingScreen]   _showTTSButton: $_showTTSButton');
    print(
        '[DecodingScreen]   themeProvider.textToSpeechEnabled: ${themeProvider.textToSpeechEnabled}');
    print('[DecodingScreen]   _userListened: $_userListened');
    print(
        '[DecodingScreen]   Should show TTS button: ${_showTTSButton && !_userListened}');

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Typewriter text display
          Text(
            _displayedText,
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          // Show Nakinig na status when user has listened
          if (_userListened) ...[
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
                          fontSize: themeProvider.getRealFontSize(14),
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
          if (_showTTSButton && !_userListened) ...[
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
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
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

  // Main decoding content with drag and drop
  Widget _buildDecodingContent(ThemeProvider themeProvider) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDE37C)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white,
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Image section - only show after TTS button is shown
          if (_showImage &&
              _questionImage != null &&
              _questionImage!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: SizedBox(
                height: 140,
                child: _questionImage!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: _questionImage!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF7574A)),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported,
                                  color: Colors.white, size: 40),
                              Text('Image not available',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Image here',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
              ),
            ),
          ],

          // Drag elements section - only show after user listened
          if (_showChoices)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Text(
                    'Piliin ang mga letra:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: themeProvider.getRealFontSize(16),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _availableDragElements.map((element) {
                      return Draggable<String>(
                        data: element,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 60,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD966),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB8860B),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                element,
                                style: TextStyle(
                                  fontSize: themeProvider.getRealFontSize(24),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: Container(
                            width: 60,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD966),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                element,
                                style: TextStyle(
                                  fontSize: themeProvider.getRealFontSize(24),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: Container(
                          width: 60,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD966),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              element,
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(24),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Display sequence for single-blank questions (DC_004, DC_005, DC_006, DC_009, DC_010) - positioned below drag elements
          if (_showChoices &&
              _blankPosition != null &&
              _droppedSequence.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _droppedSequence.asMap().entries.map((entry) {
                  final index = entry.key;
                  final letter = entry.value;
                  final isBlank = index == _blankPosition;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        DragTarget<String>(
                          onWillAccept: (data) =>
                              isBlank &&
                              (_droppedSequence.isEmpty ||
                                  _droppedSequence[index].isEmpty),
                          onAccept: (data) {
                            setState(() {
                              _droppedSequence[index] = data;
                              _availableDragElements.remove(data);
                              _isPakitsekEnabled = _checkIfCompleted();
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovering = candidateData.isNotEmpty;
                            return GestureDetector(
                              onTap: isBlank &&
                                      _droppedSequence.isNotEmpty &&
                                      _droppedSequence[index].isNotEmpty
                                  ? () => _onDroppedElementTap(index)
                                  : null,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isBlank
                                      ? (isHovering
                                          ? const Color(0xFFFFD966)
                                              .withOpacity(0.3)
                                          : Colors.transparent)
                                      : const Color(0xFFFFD966)
                                          .withOpacity(0.8),
                                ),
                                child: Center(
                                  child: Text(
                                    _droppedSequence.isNotEmpty &&
                                            index < _droppedSequence.length
                                        ? _droppedSequence[index]
                                        : '',
                                    style: TextStyle(
                                      fontSize:
                                          themeProvider.getRealFontSize(20),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeProvider.fontFamily,
                                      color:
                                          isBlank ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 36,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Drop zones for sequence (only for multiple-blank questions) - only show after user listened
          if (_showChoices && _blankPosition == null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _droppedSequence.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  // For single-blank questions (like DC_009), only the blank position should be empty
                  final isEmpty = _blankPosition != null
                      ? (index == _blankPosition &&
                          item
                              .isEmpty) // Single-blank: only blank position is empty
                      : (item.isEmpty ||
                          item ==
                              _displaySequence[
                                  index]); // Multiple-blank: original logic
                  final isInteractive =
                      _blankPosition == null || index == _blankPosition;

                  return DragTarget<String>(
                    onWillAccept: (data) {
                      if (!isInteractive) return false;
                      // For single-blank questions, only accept at the blank position
                      if (_blankPosition != null) {
                        return index == _blankPosition &&
                            _droppedSequence[index].isEmpty;
                      }
                      // For multiple-blank questions, accept if currently empty
                      return isEmpty;
                    },
                    onAccept: (data) {
                      setState(() {
                        _droppedSequence[index] = data;
                        _availableDragElements.remove(data);
                        _isPakitsekEnabled = _checkIfCompleted();
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return GestureDetector(
                        onTap: isInteractive
                            ? () => _onDroppedElementTap(index)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isEmpty
                                ? (isHovering
                                    ? const Color(0xFFFFD966).withOpacity(0.3)
                                    : Colors.transparent)
                                : const Color(0xFFFFD966),
                            border: Border.all(
                              color: const Color(0xFFFFD966),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              isEmpty ? '' : item,
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(22),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                color: isEmpty ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Feedback content - shows correct/incorrect dialogs
  Widget _buildFeedbackContent(ThemeProvider themeProvider) {
    final Color backgroundColor =
        _isCorrectAnswer ? const Color(0xFFCAFFCD) : const Color(0xFFFFF0F0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
                      fontSize: themeProvider.getRealFontSize(32),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: _droppedSequence.map((item) {
                          return Text(
                            item,
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(20),
                              fontWeight: FontWeight.bold,
                              color: _isCorrectAnswer
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontFamily: themeProvider.fontFamily,
                            ),
                          );
                        }).toList(),
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
                _feedbackMessage,
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  color: Colors.black87,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  void _speakText(String text) {
    if (!mounted) return;

    print(
        '[DecodingScreen] _speakText called with text: ${text.substring(0, text.length.clamp(0, 50))}...');
    print(
        '[DecodingScreen] TTS Provider available: ${_ttsProvider?.isAvailable}');
    print(
        '[DecodingScreen] Theme TTS enabled: ${_themeProvider?.textToSpeechEnabled}');

    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      print('[DecodingScreen] Calling TTS speakText...');
      _ttsProvider!.speakText(
        text,
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
          print('[DecodingScreen] TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    } else {
      print('[DecodingScreen] TTS not available or disabled');
      print('[DecodingScreen] Provider null: ${_ttsProvider == null}');
      print(
          '[DecodingScreen] Provider available: ${_ttsProvider?.isAvailable}');
      print('[DecodingScreen] Theme provider null: ${_themeProvider == null}');
      print(
          '[DecodingScreen] Theme TTS enabled: ${_themeProvider?.textToSpeechEnabled}');
    }
  }

  void _stopTTS() {
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
      setState(() {
        _isTTSPlaying = false;
      });
    }
  }

  void _navigateToWordRecognition() {
    print('[DecodingScreen] Navigating to WordRecognitionScreen');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: Provider.of<AssessmentProvider>(context, listen: false),
          child: const WordRecognitionScreen(
            assessmentId: '',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopTTS();
    _correctSoundPlayer.dispose();
    _buttonSoundPlayer.dispose();
    _wrongSoundPlayer.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _typewriterController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }
}
