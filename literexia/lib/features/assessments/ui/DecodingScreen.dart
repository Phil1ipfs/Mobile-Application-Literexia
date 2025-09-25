import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:provider/provider.dart';
import 'package:literexia/features/assessments/ui/WordRecognitionScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/screens/home_screen.dart'; // Added this import
import '../../../utils/category_results_helper.dart';

class DecodingScreen extends StatefulWidget {
  final String assessmentId;
  final Function(String optionId)? onOptionSelected;
  final Function()? onContinue;
  final bool isPreAssessment; // Added parameter
  final String assessmentType; // New parameter for assessment type

  const DecodingScreen({
    Key? key,
    required this.assessmentId,
    this.onOptionSelected,
    this.onContinue,
    this.isPreAssessment = false, // Default to main assessment
    this.assessmentType = 'main_assessment', // Default to main assessment type
  }) : super(key: key);

  @override
  State<DecodingScreen> createState() => _DecodingScreenState();
}

class _DecodingScreenState extends State<DecodingScreen>
    with TickerProviderStateMixin {
  // TTS state for question text
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Audio players
  final AudioPlayer _correctSoundPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();
  final AudioPlayer _wrongSoundPlayer = AudioPlayer();
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _congratsSoundPlayer = AudioPlayer();

  // Confetti controllers for fireworks animation
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // Typewriter effect state
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedText = '';
  String _fullQuestionText = '';

  // Flow control state
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

  // Decoding-specific scoring
  int _decodingCorrectAnswers = 0;
  int _decodingTotalQuestions = 0;

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
    print('[DecodingScreen] ===== INITIALIZING DECODING SCREEN =====');
    print('[DecodingScreen] Assessment ID: ${widget.assessmentId}');
    print('[DecodingScreen] Is Pre-Assessment: ${widget.isPreAssessment}');
    print('[DecodingScreen] ===== DECODING SCREEN INITIALIZED =====');

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
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.idNumber.toString();
          if (userId != null && userId.isNotEmpty) {
            Provider.of<AssessmentProvider>(context, listen: false)
                .setCurrentUserId(userId);
            print('[DecodingScreen] Set userId in AssessmentProvider: $userId');
          }
        } catch (e) {
          print('[DecodingScreen] Failed setting userId in provider: $e');
        }

        // Start background music after providers are initialized
        _startBackgroundMusic();
      }
    });
  }

  Future<void> _loadDecodingData() async {
    try {
      print('[DecodingScreen] ===== STARTING DYNAMIC DECODING DATA LOAD =====');
      print('[DecodingScreen] Is Pre-Assessment: ${widget.isPreAssessment}');
      print('[DecodingScreen] Assessment Type: ${widget.assessmentType}');
      print('[DecodingScreen] ===== CALLING _loadDecodingData METHOD =====');
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);

      // Load decoding assessment based on assessment type
      if (widget.assessmentType == 'intervention_assessment') {
        // Load from intervention assessment database
        print('[DecodingScreen] Loading intervention assessment from MongoDB...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.currentUser?.idNumber.toString() ?? '';
        final readingLevel = authProvider.currentUser?.readingLevel ?? '';

        await assessmentProvider.loadInterventionAssessmentDirect(
          'Decoding',
          readingLevel,
          userId: userId,
        );
        print('[DecodingScreen] Intervention assessment loaded successfully');
      } else if (widget.isPreAssessment) {
        // Load from pre-assessment database
        print('[DecodingScreen] Loading pre-assessment from MongoDB...');
        await assessmentProvider.loadPreAssessment();
        print('[DecodingScreen] Pre-assessment loaded successfully');
      } else {
        // Load from main assessment database
        print('[DecodingScreen] Loading main assessment from MongoDB...');
        await assessmentProvider.loadDecodingMainAssessment();
        print('[DecodingScreen] Main assessment loaded successfully');
      }

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
      List<dynamic> dcQuestions;

      if (widget.isPreAssessment) {
        // PRE-ASSESSMENT: Try DC_ prefix first, then fallback to category
        print('[DecodingScreen] ===== PRE-ASSESSMENT DECODING LOADING =====');
        print(
            '[DecodingScreen] Total questions in pre-assessment: ${questions.length}');
        print(
            '[DecodingScreen] All question IDs: ${questions.map((q) => q.questionId).toList()}');

        // First try DC_ prefix
        dcQuestions =
            questions.where((q) => q.questionId.startsWith('DC_')).toList();
        print(
            '[DecodingScreen] DC Questions by prefix: ${dcQuestions.map((q) => q.questionId).toList()}');
        print(
            '[DecodingScreen] DC Questions by prefix count: ${dcQuestions.length}');

        // If no DC_ questions found, try category-based filtering
        if (dcQuestions.isEmpty) {
          print(
              '[DecodingScreen] No DC_ questions found, trying category-based filtering...');
          dcQuestions = questions
              .where((q) =>
                  q.category?.toLowerCase().contains('decoding') == true ||
                  q.category?.toLowerCase().contains('decode') == true)
              .toList();
          print(
              '[DecodingScreen] DC Questions by category: ${dcQuestions.map((q) => '${q.questionId} (${q.category})').toList()}');
          print(
              '[DecodingScreen] DC Questions by category count: ${dcQuestions.length}');
        }

        print(
            '[DecodingScreen] ===== END PRE-ASSESSMENT DECODING LOADING =====');
      } else {
        // MAIN ASSESSMENT: Use DC_ prefix only (unchanged)
        dcQuestions =
            questions.where((q) => q.questionId.startsWith('DC_')).toList();
        print(
            '[DecodingScreen] DC Questions found in main assessment: ${dcQuestions.map((q) => q.questionId).toList()}');
        print('[DecodingScreen] Total DC questions: ${dcQuestions.length}');
      }

      // Sort DC questions to ensure proper order
      dcQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

      // Set decoding-specific scoring variables
      _decodingTotalQuestions = dcQuestions.length;
      _decodingCorrectAnswers = 0; // Reset for new assessment

      // Log initial assessment state for main assessment
      if (!widget.isPreAssessment) {
        print('[DecodingScreen] ===== MAIN ASSESSMENT INITIALIZATION =====');
        print('[DecodingScreen] Starting Decoding Main Assessment');
        print('[DecodingScreen] Total DC Questions: $_decodingTotalQuestions');
        print(
            '[DecodingScreen] Initial Correct Answers: $_decodingCorrectAnswers');
        print('[DecodingScreen] Assessment Type: Main Assessment');
        print(
            '[DecodingScreen] ===== END MAIN ASSESSMENT INITIALIZATION =====');
      }

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
            print('[DecodingScreen] ===== EXTRACTING DISPLAY SEQUENCE =====');
            print(
                '[DecodingScreen] Original data keys: ${originalData.keys.toList()}');
            print(
                '[DecodingScreen] Original data displaySequence: ${originalData['displaySequence']}');
            _displaySequence = _extractListFromDynamic(originalData,
                ['displaySequence', 'sequence', 'display', 'initialSequence']);
            print(
                '[DecodingScreen] Extracted displaySequence: $_displaySequence');
            print(
                '[DecodingScreen] ===== END EXTRACTING DISPLAY SEQUENCE =====');
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
            print(
                '[DecodingScreen] displaySequence length: ${_displaySequence.length}');
            print('[DecodingScreen] displaySequence details:');
            for (int i = 0; i < _displaySequence.length; i++) {
              print(
                  '[DecodingScreen]   [$i]: "${_displaySequence[i]}" (length: ${_displaySequence[i].length})');
            }
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
    print(
        '[DecodingScreen] _extractListFromDynamic called with fieldNames: $fieldNames');
    for (String fieldName in fieldNames) {
      print('[DecodingScreen] Checking field: $fieldName');
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        print('[DecodingScreen] Found field $fieldName: ${data[fieldName]}');
        print('[DecodingScreen] Field type: ${data[fieldName].runtimeType}');
        try {
          final result = List<String>.from(data[fieldName]);
          print(
              '[DecodingScreen] Successfully parsed $fieldName as List<String>: $result');
          return result;
        } catch (e) {
          print('[DecodingScreen] Error parsing $fieldName as list: $e');
          // Try to convert individual items to string
          if (data[fieldName] is List) {
            final result =
                (data[fieldName] as List).map((e) => e.toString()).toList();
            print('[DecodingScreen] Converted $fieldName to strings: $result');
            return result;
          }
        }
      } else {
        print('[DecodingScreen] Field $fieldName not found or null');
      }
    }
    print('[DecodingScreen] No valid field found, returning empty list');
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
            // For main assessment, preserve underscores from displaySequence
            // For pre-assessment, keep blank position empty
            if (_displaySequence.isNotEmpty &&
                i < _displaySequence.length &&
                _displaySequence[i] == '_') {
              _droppedSequence[i] =
                  '_'; // Preserve underscore for main assessment
            } else {
              _droppedSequence[i] =
                  ''; // Keep blank position empty for pre-assessment
            }
          } else if (_displaySequence.isNotEmpty &&
              i < _displaySequence.length) {
            _droppedSequence[i] = _displaySequence[
                i]; // Pre-fill other positions with displaySequence letters
          }
        }
      }

      print(
          '[DecodingScreen] After initialization droppedSequence: $_droppedSequence');
      print('[DecodingScreen] droppedSequence details:');
      for (int i = 0; i < _droppedSequence.length; i++) {
        print(
            '[DecodingScreen]   [$i]: "${_droppedSequence[i]}" (length: ${_droppedSequence[i].length})');
      }
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
      await _congratsSoundPlayer.setAsset('assets/audio/congrats fx.mp3');
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

  Future<void> _playCongratsSound() async {
    try {
      await _congratsSoundPlayer.seek(Duration.zero);
      await _congratsSoundPlayer.play();
      print('[DecodingScreen] Playing congratulations sound');
    } catch (e) {
      print('[DecodingScreen] Error playing congratulations sound: $e');
    }
  }

  // Start background music
  Future<void> _startBackgroundMusic() async {
    try {
      // Stop any existing background music from HomeScreen to prevent duplication
      await HomeScreen.stopBackgroundMusic();

      await _backgroundMusicPlayer.setAsset('assets/audio/homeBg.mp3');
      await _backgroundMusicPlayer.setVolume(0.5);
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);
      await _backgroundMusicPlayer.play();
      print('[DecodingScreen] Background music started successfully');
    } catch (e) {
      print('[DecodingScreen] Background music error: $e');
    }
  }

  // Pause background music
  Future<void> _pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      print('[DecodingScreen] Background music paused');
    } catch (e) {
      print('[DecodingScreen] Error pausing music: $e');
    }
  }

  // Resume background music
  Future<void> _resumeBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.play();
      print('[DecodingScreen] Background music resumed');
    } catch (e) {
      print('[DecodingScreen] Error resuming music: $e');
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
            print(
                '[DecodingScreen] ===== EXTRACTING DISPLAY SEQUENCE FROM PROVIDER =====');
            print(
                '[DecodingScreen] Original data keys: ${originalData.keys.toList()}');
            print(
                '[DecodingScreen] Original data displaySequence: ${originalData['displaySequence']}');
            _displaySequence = _extractListFromDynamic(originalData,
                ['displaySequence', 'sequence', 'display', 'initialSequence']);
            print(
                '[DecodingScreen] Extracted displaySequence: $_displaySequence');
            print(
                '[DecodingScreen] ===== END EXTRACTING DISPLAY SEQUENCE FROM PROVIDER =====');
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

            // Note: Don't reset _decodingCorrectAnswers here as it should accumulate across questions
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
      final blankValue = _droppedSequence[_blankPosition!];
      // Consider completed if it has a letter (not empty and not underscore)
      // The underscore is a placeholder that should be replaced with a letter
      return blankValue.isNotEmpty && blankValue != '_';
    } else {
      // Multiple positions case (DC_001, DC_002, DC_003)
      return _droppedSequence.every((item) => item.isNotEmpty);
    }
  }

  // Handle removing dropped element (tap to remove)
  void _onDroppedElementTap(int index) {
    if (_showFeedback) return;

    final element = _droppedSequence[index];
    if (element.isNotEmpty &&
        (_blankPosition == null || index == _blankPosition)) {
      setState(() {
        if (_blankPosition != null && index == _blankPosition) {
          // For single-blank questions, reset to underscore (placeholder) for main assessment
          if (_displaySequence.isNotEmpty &&
              index < _displaySequence.length &&
              _displaySequence[index] == '_') {
            _droppedSequence[index] = '_'; // Reset to underscore placeholder
          } else {
            _droppedSequence[index] = ''; // Keep empty for pre-assessment
          }
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

  // Check if current answer is correct
  bool _isCurrentAnswerCorrect() {
    return _validateAnswer();
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

    // Record the response first to get current question info
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

    // Play effects based on answer
    if (isCorrect) {
      _playCorrectSound();
      _confettiControllerLeft.play();
      _confettiControllerRight.play();
      // Track correct answer for decoding-specific scoring
      _decodingCorrectAnswers++;

      // Log scoring for main assessment only
      if (!widget.isPreAssessment) {
        print('[DecodingScreen] ===== MAIN ASSESSMENT SCORING LOG =====');
        print('[DecodingScreen] ✅ CORRECT ANSWER!');
        print(
            '[DecodingScreen] Question: ${currentQuestion?.questionId ?? 'Unknown'}');
        print('[DecodingScreen] User Answer: ${_droppedSequence.join(',')}');
        print('[DecodingScreen] Correct Answer: ${_correctSequence.join(',')}');
        print(
            '[DecodingScreen] Decoding Correct Answers: $_decodingCorrectAnswers/$_decodingTotalQuestions');
        print(
            '[DecodingScreen] Decoding Percentage: ${_decodingTotalQuestions > 0 ? (_decodingCorrectAnswers / _decodingTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print('[DecodingScreen] ===== END MAIN ASSESSMENT SCORING LOG =====');
      }
    } else {
      _playWrongSound();

      // Log incorrect answer for main assessment only
      if (!widget.isPreAssessment) {
        print('[DecodingScreen] ===== MAIN ASSESSMENT SCORING LOG =====');
        print('[DecodingScreen] ❌ INCORRECT ANSWER');
        print(
            '[DecodingScreen] Question: ${currentQuestion?.questionId ?? 'Unknown'}');
        print('[DecodingScreen] User Answer: ${_droppedSequence.join(',')}');
        print('[DecodingScreen] Correct Answer: ${_correctSequence.join(',')}');
        print(
            '[DecodingScreen] Decoding Correct Answers: $_decodingCorrectAnswers/$_decodingTotalQuestions');
        print(
            '[DecodingScreen] Decoding Percentage: ${_decodingTotalQuestions > 0 ? (_decodingCorrectAnswers / _decodingTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print('[DecodingScreen] ===== END MAIN ASSESSMENT SCORING LOG =====');
      }
    }

    if (currentQuestion != null) {
      // Get the assessment's ObjectId for categoryId and user's reading level
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final userReadingLevel = currentUser?.readingLevel ?? 'Low Emerging';
      
      // Get the assessment's ObjectId from the loaded assessment data
      final categoryId = assessmentProvider.getAssessmentObjectId();

      // Save individual response in new MongoDB format
      await assessmentProvider.saveIndividualResponse(
        questionId: currentQuestion.questionId,
        category: 'Decoding',
        questionType: currentQuestion.questionType ?? 'decode',
        response: _droppedSequence.where((item) => item.isNotEmpty).toList(),
        isCorrect: isCorrect,
        responseTime: 0, // Could be tracked if needed
        categoryId: categoryId, // Add the missing categoryId
        readingLevel: userReadingLevel, // Add the missing readingLevel
      );

      // Note: answerCurrentQuestion() is now called in _proceedToNextQuestion()
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
    if (widget.assessmentType == 'intervention_assessment') {
      // Use intervention assessment flow
      _proceedToNextQuestionInterventionAssessment();
    } else if (widget.isPreAssessment) {
      // Use original pre-assessment flow
      _proceedToNextQuestionPreAssessment();
    } else {
      // Use new main assessment flow
      _proceedToNextQuestionMainAssessment();
    }
  }

  // Original method for pre-assessment flow (unchanged)
  void _proceedToNextQuestionPreAssessment() {
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);

    // First, answer the current question to move to the next one
    final currentQuestion = assessmentProvider.currentQuestion;
    if (currentQuestion != null) {
      print(
          '[DecodingScreen] Answering current question: ${currentQuestion.questionId}');
      assessmentProvider.answerCurrentQuestion(_droppedSequence.join(','));
    }

    // Check if assessment is complete first
    if (assessmentProvider.isAssessmentComplete) {
      print(
          '[DecodingScreen] Pre-assessment complete - navigating to WordRecognition');

      // Find the first WR question and set it as current question
      final allQuestions = assessmentProvider.assessment?.questions ?? [];
      final firstWrIndex =
          allQuestions.indexWhere((q) => q.questionId.startsWith('WR_'));

      if (firstWrIndex != -1) {
        assessmentProvider.currentQuestionIndex = firstWrIndex;
        final firstWrQuestion = allQuestions[firstWrIndex];
        print(
            '[DecodingScreen] Setting current question to first WR question: ${firstWrQuestion.questionId} at index $firstWrIndex');
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
              isPreAssessment: widget.isPreAssessment,
            ),
          ),
        ),
      );
      return;
    }

    // Check if we're still in DC questions or need to move to WR
    final nextQuestion = assessmentProvider.currentQuestion;

    // Debug logging for pre-assessment
    print('[DecodingScreen] ===== PRE-ASSESSMENT DEBUG =====');
    print(
        '[DecodingScreen] currentQuestionIndex: ${assessmentProvider.currentQuestionIndex}');
    print(
        '[DecodingScreen] nextQuestion: ${nextQuestion?.questionId ?? 'null'}');
    print(
        '[DecodingScreen] isAssessmentComplete: ${assessmentProvider.isAssessmentComplete}');
    print('[DecodingScreen] ===== END PRE-ASSESSMENT DEBUG =====');

    if (nextQuestion != null && nextQuestion.questionId.startsWith('DC_')) {
      // Still in DC questions, load the current question data
      print(
          '[DecodingScreen] Loading next DC question: ${nextQuestion.questionId}');
      _loadCurrentQuestionDataFromProvider();
    } else {
      // No more DC questions or moved to a different section
      print(
          '[DecodingScreen] Pre-assessment DC complete - navigating to WordRecognition');

      // Find the first WR question and set it as current question
      final allQuestions = assessmentProvider.assessment?.questions ?? [];
      final firstWrIndex =
          allQuestions.indexWhere((q) => q.questionId.startsWith('WR_'));

      if (firstWrIndex != -1) {
        assessmentProvider.currentQuestionIndex = firstWrIndex;
        final firstWrQuestion = allQuestions[firstWrIndex];
        print(
            '[DecodingScreen] Setting current question to first WR question: ${firstWrQuestion.questionId} at index $firstWrIndex');
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
              isPreAssessment: widget.isPreAssessment,
            ),
          ),
        ),
      );
    }
  }

  // New method specifically for main assessment flow
  void _proceedToNextQuestionMainAssessment() {
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);

    // First, answer the current question to move to the next one
    final currentQuestion = assessmentProvider.currentQuestion;
    if (currentQuestion != null) {
      print(
          '[DecodingScreen] Answering current question: ${currentQuestion.questionId}');
      assessmentProvider.answerCurrentQuestion(_droppedSequence.join(','));
    }

    // Check if assessment is complete first
    // Also check if we've reached the end of DC questions
    final allQuestions = assessmentProvider.assessment?.questions ?? [];
    final dcQuestions =
        allQuestions.where((q) => q.questionId.startsWith('DC_')).toList();
    final isAtLastDCQuestion =
        assessmentProvider.currentQuestionIndex > dcQuestions.length - 1;

    // Debug logging for main assessment only
    if (!widget.isPreAssessment) {
      print('[DecodingScreen] ===== COMPLETION CHECK DEBUG =====');
      print(
          '[DecodingScreen] currentQuestionIndex: ${assessmentProvider.currentQuestionIndex}');
      print('[DecodingScreen] dcQuestions.length: ${dcQuestions.length}');
      print(
          '[DecodingScreen] dcQuestions.length - 1: ${dcQuestions.length - 1}');
      print('[DecodingScreen] isAtLastDCQuestion: $isAtLastDCQuestion');
      print(
          '[DecodingScreen] isAssessmentComplete: ${assessmentProvider.isAssessmentComplete}');
      print('[DecodingScreen] ===== END COMPLETION CHECK DEBUG =====');
    }

    if (assessmentProvider.isAssessmentComplete || isAtLastDCQuestion) {
      // Log completion for main assessment only
      if (!widget.isPreAssessment) {
        print('[DecodingScreen] ===== MAIN ASSESSMENT COMPLETION LOG =====');
        print(
            '[DecodingScreen] Main assessment DC complete - showing score display');
        print(
            '[DecodingScreen] isAssessmentComplete: ${assessmentProvider.isAssessmentComplete}');
        print('[DecodingScreen] isAtLastDCQuestion: $isAtLastDCQuestion');
        print(
            '[DecodingScreen] currentQuestionIndex: ${assessmentProvider.currentQuestionIndex}');
        print('[DecodingScreen] totalDCQuestions: ${dcQuestions.length}');
        print(
            '[DecodingScreen] Final Decoding Score: $_decodingCorrectAnswers/$_decodingTotalQuestions');
        print(
            '[DecodingScreen] Final Decoding Percentage: ${_decodingTotalQuestions > 0 ? (_decodingCorrectAnswers / _decodingTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print(
            '[DecodingScreen] ===== END MAIN ASSESSMENT COMPLETION LOG =====');
      }

      // Show score display for main assessment
      _showMainAssessmentScoreDisplay();
      return;
    }

    // Check if we're still in DC questions
    final nextQuestion = assessmentProvider.currentQuestion;

    if (nextQuestion != null && nextQuestion.questionId.startsWith('DC_')) {
      // Still in DC questions, load the current question data
      print(
          '[DecodingScreen] Loading next DC question: ${nextQuestion.questionId}');
      _loadCurrentQuestionDataFromProvider();
    } else {
      // No more DC questions - show score display
      print(
          '[DecodingScreen] No more DC questions in main assessment - showing score display');
      _showMainAssessmentScoreDisplay();
    }
  }

  // New method specifically for intervention assessment flow
  void _proceedToNextQuestionInterventionAssessment() async {
    try {
      print('[DecodingScreen] ===== INTERVENTION ASSESSMENT PROGRESSION =====');

      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      if (currentQuestion != null) {
        // Get authentication provider for user details
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.currentUser?.idNumber.toString() ?? '';
        final readingLevel = authProvider.currentUser?.readingLevel ?? '';

        // Calculate scoring
        final isCorrect = _isCurrentAnswerCorrect();

        print('[DecodingScreen] ===== SAVING INTERVENTION RESPONSE =====');
        print('[DecodingScreen] QuestionId: ${currentQuestion.questionId}');
        print('[DecodingScreen] Category: Decoding');
        print('[DecodingScreen] Response: ${_droppedSequence.where((item) => item.isNotEmpty).toList()}');
        print('[DecodingScreen] Is Correct: $isCorrect');
        print('[DecodingScreen] ===== END SAVING INTERVENTION RESPONSE =====');

        // Save intervention response using the new method
        await assessmentProvider.saveInterventionResponse(
          studentId: userId,
          interventionAssessmentId: assessmentProvider.assessment?.assessmentId ?? '',
          questionId: currentQuestion.questionId,
          category: 'Decoding',
          response: _droppedSequence.where((item) => item.isNotEmpty).toList(),
          isCorrect: isCorrect,
          responseTime: 0,
          readingLevel: readingLevel,
        );

        print('[DecodingScreen] Successfully saved intervention response');

        // Move to next question
        assessmentProvider.answerCurrentQuestion(
          _droppedSequence.where((item) => item.isNotEmpty).toList().join(' ')
        );

        // Check if there are more questions in the intervention assessment
        final hasNextQuestion = assessmentProvider.hasNextQuestion;

        if (hasNextQuestion) {
          // Move to next intervention question
          print('[DecodingScreen] Moving to next intervention question');
          assessmentProvider.moveToNextQuestion();

          // Load next question data
          _loadCurrentQuestionDataFromProvider();
        } else {
          // Last intervention question completed
          print('[DecodingScreen] Intervention assessment completed - navigating back');

          // Navigate back to assessment screen
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      print('[DecodingScreen] Error in intervention assessment progression: $e');
    }
  }

  // New method specifically for Decoding main assessment scoring
  void _showMainAssessmentScoreDisplay() {
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Calculate Decoding-specific score
    final allQuestions = assessmentProvider.assessment?.questions ?? [];
    final dcQuestions =
        allQuestions.where((q) => q.questionId.startsWith('DC_')).toList();

    // Count correct answers for DC questions only
    int correctAnswers = 0;
    int totalDCQuestions = dcQuestions.length;

    // Count correct answers by checking the provider's score and responses
    // Since DecodingScreen uses saveIndividualResponse, we can count from the provider's internal data
    // For now, we'll use a simpler approach by checking the current score
    // This could be enhanced to be more precise by tracking DC-specific responses

    // Use the tracked decoding-specific scores instead of provider's total score

    // For Decoding-specific scoring, we need to count only DC questions
    // Since the provider tracks all responses, we'll use a different approach
    // We'll calculate based on the questions that have been answered correctly

    // Alternative approach: Use the provider's existing scoring mechanism
    // and estimate DC-specific score based on the current progress
    // Use the tracked decoding-specific scores
    correctAnswers = _decodingCorrectAnswers;
    totalDCQuestions = _decodingTotalQuestions;

    final percentage =
        totalDCQuestions > 0 ? (correctAnswers / totalDCQuestions) * 100 : 0.0;

    // Log score calculation and display for main assessment only
    if (!widget.isPreAssessment) {
      print('[DecodingScreen] ===== DECODING SCORE CALCULATION =====');
      print(
          '[DecodingScreen] Decoding Score: $correctAnswers/$totalDCQuestions, Percentage: $percentage%');
      print(
          '[DecodingScreen] _decodingCorrectAnswers: $_decodingCorrectAnswers');
      print(
          '[DecodingScreen] _decodingTotalQuestions: $_decodingTotalQuestions');
      print('[DecodingScreen] ===== END DECODING SCORE CALCULATION =====');

      print('[DecodingScreen] ===== SHOWING SCORE DISPLAY =====');
      print('[DecodingScreen] Displaying score dialog for main assessment');
      print('[DecodingScreen] Score: $correctAnswers/$totalDCQuestions');
      print('[DecodingScreen] Percentage: $percentage%');
      print('[DecodingScreen] ===== END SHOWING SCORE DISPLAY =====');
    }

    // Play congratulations sound when showing the assessment completed dialog
    _playCongratsSound();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width > 768 ? 500 : 350,
            padding: const EdgeInsets.all(24),
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
                    size: 50,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'DECODING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(24),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Assessment Completed!',
                  style: TextStyle(
                    color: const Color(0xFFFDE37C),
                    fontSize: themeProvider.getRealFontSize(16),
                    fontWeight: FontWeight.w600,
                    fontFamily: themeProvider.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Score display
                Container(
                  padding: const EdgeInsets.all(20),
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
                            '$correctAnswers',
                            style: TextStyle(
                              color: const Color(0xFFFDE37C),
                              fontSize: themeProvider.getRealFontSize(48),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                            ),
                          ),
                          Text(
                            ' / $totalDCQuestions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: themeProvider.getRealFontSize(32),
                              fontWeight: FontWeight.w600,
                              fontFamily: themeProvider.fontFamily,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Correct Answers',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: themeProvider.getRealFontSize(14),
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Percentage
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: percentage >= 70
                              ? Colors.green.withOpacity(0.2)
                              : percentage >= 50
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: percentage >= 70
                                ? Colors.green
                                : percentage >= 50
                                    ? Colors.orange
                                    : Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: percentage >= 70
                                ? Colors.green
                                : percentage >= 50
                                    ? Colors.orange
                                    : Colors.red,
                            fontSize: themeProvider.getRealFontSize(20),
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
                  _getPerformanceMessage(percentage),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(16),
                    fontFamily: themeProvider.fontFamily,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop(); // Close dialog

                      // Save Decoding results to category_results collection
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      final assessmentProvider =
                          Provider.of<AssessmentProvider>(context,
                              listen: false);
                      final userId =
                          authProvider.currentUser?.idNumber.toString() ?? '';
                      if (userId.isNotEmpty) {
                        try {
                          // Use DecodingScreen's own scoring system instead of AssessmentProvider
                          final finalScore = _decodingCorrectAnswers;
                          final finalTotal = _decodingTotalQuestions;
                          final scorePercentage = (finalScore / finalTotal) * 100;
                          
                          print('[DecodingScreen] Saving Decoding results to category_results');
                          print('[DecodingScreen] Using DecodingScreen scores: $_decodingCorrectAnswers/$_decodingTotalQuestions = $scorePercentage%');
                          await CategoryResultsHelper.updateCategoryResults(
                            userId, 
                            'Decoding', 
                            finalScore, 
                            finalTotal, 
                            scorePercentage
                          );
                          print('[DecodingScreen] Successfully saved to category_results collection');
                        } catch (e) {
                          print('[DecodingScreen] Error saving to category_results: $e');
                          print('[DecodingScreen] Continuing with navigation despite save error');
                        }
                      }

                      // Use a more robust navigation approach with error handling
                      if (mounted) {
                        try {
                          print('[DecodingScreen] Navigating to HomeScreen');
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(forceRefresh: true),
                            ),
                            (route) => false, // Remove all previous routes
                          );
                          print('[DecodingScreen] Navigation to HomeScreen completed');
                        } catch (e) {
                          print('[DecodingScreen] Error during navigation: $e');
                          // Fallback navigation
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(forceRefresh: true),
                            ),
                          );
                        }
                      } else {
                        print('[DecodingScreen] Widget not mounted, cannot navigate');
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
                      'MAG PATULOY',
                      style: TextStyle(
                        fontSize: themeProvider.getRealFontSize(18),
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
      print('[DecodingScreen] Error showing final score dialog: $e');
      // Fallback navigation with error handling
      if (mounted) {
        try {
          print('[DecodingScreen] Fallback navigation to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(forceRefresh: true),
            ),
            (route) => false, // Remove all previous routes
          );
          print('[DecodingScreen] Fallback navigation completed');
        } catch (navError) {
          print('[DecodingScreen] Error in fallback navigation: $navError');
          // Last resort navigation
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

  // Helper method to get performance message based on percentage
  String _getPerformanceMessage(double percentage) {
    if (percentage >= 90) {
      return 'Napakagaling! Mahusay na pagganap sa Decoding assessment.';
    } else if (percentage >= 80) {
      return 'Magaling! Mahusay na pagganap sa Decoding assessment.';
    } else if (percentage >= 70) {
      return 'Mabuti! Naisagawa mo nang maayos ang Decoding assessment.';
    } else if (percentage >= 50) {
      return 'Kailangan pa ng kaunting pagsasanay sa Decoding.';
    } else {
      return 'Kailangan ng mas maraming pagsasanay sa Decoding.';
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

    // Build DC question IDs based on assessment type
    List<String> dcIdsAll;
    if (widget.isPreAssessment) {
      // PRE-ASSESSMENT: Try DC_ prefix first, then fallback to category
      final dcQuestionsByPrefix = allQuestions
          .where((q) => q.questionId.startsWith('DC_'))
          .map((q) => q.questionId)
          .toSet()
          .toList();

      if (dcQuestionsByPrefix.isNotEmpty) {
        dcIdsAll = dcQuestionsByPrefix;
      } else {
        // Fallback to category-based filtering for pre-assessment only
        dcIdsAll = allQuestions
            .where((q) =>
                q.category?.toLowerCase().contains('decoding') == true ||
                q.category?.toLowerCase().contains('decode') == true)
            .map((q) => q.questionId)
            .toSet()
            .toList();
      }
    } else {
      // MAIN ASSESSMENT: Use DC_ prefix only (unchanged)
      dcIdsAll = allQuestions
          .where((q) => q.questionId.startsWith('DC_'))
          .map((q) => q.questionId)
          .toSet()
          .toList();
    }
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
    if (currentQuestion != null) {
      // Check if current question is a DC question based on assessment type
      bool isDCQuestion = false;
      if (widget.isPreAssessment) {
        // PRE-ASSESSMENT: Check both prefix and category
        isDCQuestion = currentQuestion.questionId.startsWith('DC_') ||
            currentQuestion.category?.toLowerCase().contains('decoding') ==
                true ||
            currentQuestion.category?.toLowerCase().contains('decode') == true;
      } else {
        // MAIN ASSESSMENT: Check prefix only (unchanged)
        isDCQuestion = currentQuestion.questionId.startsWith('DC_');
      }

      if (isDCQuestion) {
        final idx = dcIds.indexWhere((id) => id == currentQuestion.questionId);
        if (idx != -1) {
          current = idx + 1;
        }
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              margin: const EdgeInsets.only(bottom: 30, top: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _droppedSequence.asMap().entries.map((entry) {
                    final index = entry.key;
                    final isBlank = index == _blankPosition;

                    return Column(
                      children: [
                        DragTarget<String>(
                          onWillAccept: (data) =>
                              isBlank &&
                              (_droppedSequence.isEmpty ||
                                  _droppedSequence[index].isEmpty ||
                                  _droppedSequence[index] == '_'),
                          onAccept: (data) {
                            setState(() {
                              // If there's already a letter in the blank position (not underscore), return it to choices first
                              final currentValue = _droppedSequence[index];
                              if (currentValue.isNotEmpty &&
                                  currentValue != '_') {
                                _availableDragElements.add(currentValue);
                              }
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
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Drop zones for sequence (only for multiple-blank questions) - only show after user listened
          if (_showChoices && _blankPosition == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 30, top: 30),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _droppedSequence.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  // For multiple-blank questions, check if position is empty
                  final isEmpty = item.isEmpty ||
                      (index < _displaySequence.length &&
                          item == _displaySequence[index]);

                  return DragTarget<String>(
                    onWillAccept: (data) {
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
                        onTap: () => _onDroppedElementTap(index),
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

          const SizedBox(height: 20),
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
          print('[DecodingScreen] TTS started');
        },
        onComplete: () {
          print('[DecodingScreen] TTS completed');
        },
        onError: () {
          print('[DecodingScreen] TTS Error occurred');
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
    _backgroundMusicPlayer.dispose();
    _congratsSoundPlayer.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _typewriterController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }
}
