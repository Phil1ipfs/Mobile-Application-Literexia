import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import '../../../config/router.dart';
import 'package:literexia/Tutorial/ReadingComprehension_tutorial.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/screens/home_screen.dart';

class WordRecognitionScreen extends StatefulWidget {
  final String assessmentId;
  final Function(String optionId)? onOptionSelected;
  final Function()? onContinue;
  final bool isPreAssessment; // Added parameter

  const WordRecognitionScreen({
    Key? key,
    required this.assessmentId,
    this.onOptionSelected,
    this.onContinue,
    this.isPreAssessment = false, // Default to main assessment
  }) : super(key: key);

  @override
  State<WordRecognitionScreen> createState() => _WordRecognitionScreenState();
}

class _WordRecognitionScreenState extends State<WordRecognitionScreen>
    with TickerProviderStateMixin {
  // TTS state for question text
  bool _isTTSPlaying = false;
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Audio players
  final AudioPlayer _correctSoundPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();
  final AudioPlayer _wrongSoundPlayer = AudioPlayer();

  // Confetti controller
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
  String _displayWord = '';
  List<String> _blankOptions = [];
  List<String> _correctAnswer = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Word recognition state
  List<String> _selectedWords = [];
  List<String> _availableOptions = [];
  bool _isPakitsekEnabled = false;

  // Feedback state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackMessage = '';

  // Word Recognition-specific scoring for main assessment
  int _wordRecognitionCorrectAnswers = 0;
  int _wordRecognitionTotalQuestions = 0;

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

    // Load word recognition assessment data
    _loadWordRecognitionData();

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
              '[WordRecognitionScreen] TTS initialized - Available: ${_ttsProvider!.isAvailable}');
          // Trigger a rebuild to update TTS button visibility
          if (mounted) {
            setState(() {});
          }
        }

        // Set current user ID and reading level in assessment provider for saving responses
        try {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.idNumber.toString();
          final readingLevel = authProvider.currentUser?.readingLevel;
          
          if (userId != null && userId.isNotEmpty) {
            final assessmentProvider = Provider.of<AssessmentProvider>(context, listen: false);
            assessmentProvider.setCurrentUserId(userId);
            
            if (readingLevel != null && readingLevel.isNotEmpty) {
              assessmentProvider.setCurrentUserReadingLevel(readingLevel);
            }
            
            print('[WordRecognitionScreen] Set userId in AssessmentProvider: $userId');
            print('[WordRecognitionScreen] Set reading level in AssessmentProvider: $readingLevel');
          }
        } catch (e) {
          print(
              '[WordRecognitionScreen] Failed setting userId in provider: $e');
        }
      }
    });
  }

  Future<void> _loadWordRecognitionData() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print(
            '[WordRecognitionScreen] ===== STARTING DYNAMIC WORD RECOGNITION DATA LOAD FROM MONGODB (Attempt ${retryCount + 1}) =====');
        final assessmentProvider =
            Provider.of<AssessmentProvider>(context, listen: false);

        // Load data based on assessment type
        if (widget.isPreAssessment) {
          // Load the complete pre-assessment data dynamically from MongoDB
          print(
              '[WordRecognitionScreen] Loading dynamic pre-assessment (WR questions)...');
          await assessmentProvider.loadPreAssessment();
          print(
              '[WordRecognitionScreen] Dynamic pre-assessment loaded successfully');
        } else {
          // Load main assessment data
          print(
              '[WordRecognitionScreen] Loading main assessment (WR questions)...');
          await assessmentProvider.loadWordRecognitionMainAssessment();
          print('[WordRecognitionScreen] Main assessment loaded successfully');
        }

        // Debug: Check what's in the dynamic assessment
        final assessment = assessmentProvider.assessment;
        print(
            '[WordRecognitionScreen] Dynamic Assessment: ${assessment?.title ?? "null"}');
        print(
            '[WordRecognitionScreen] Dynamic Assessment ID: ${assessment?.assessmentId ?? "null"}');

        final questions = assessment?.questions ?? [];
        print(
            '[WordRecognitionScreen] Total dynamic questions loaded: ${questions.length}');

        // Print all question IDs for debugging
        for (int i = 0; i < questions.length; i++) {
          print(
              '[WordRecognitionScreen] Dynamic Question $i: ${questions[i].questionId}');
        }

        // Dynamically find WR questions from MongoDB data
        final wrQuestions =
            questions.where((q) => q.questionId.startsWith('WR_')).toList();

        // Sort WR questions to ensure proper order
        wrQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

        // Set Word Recognition-specific scoring variables for main assessment
        _wordRecognitionTotalQuestions = wrQuestions.length;
        _wordRecognitionCorrectAnswers = 0; // Reset for new assessment

        // Log initial assessment state for main assessment
        if (!widget.isPreAssessment) {
          print(
              '[WordRecognitionScreen] ===== MAIN ASSESSMENT INITIALIZATION =====');
          print(
              '[WordRecognitionScreen] Starting Word Recognition Main Assessment');
          print(
              '[WordRecognitionScreen] Total WR Questions: $_wordRecognitionTotalQuestions');
          print(
              '[WordRecognitionScreen] Initial Correct Answers: $_wordRecognitionCorrectAnswers');
          print('[WordRecognitionScreen] Assessment Type: Main Assessment');
          print(
              '[WordRecognitionScreen] ===== END MAIN ASSESSMENT INITIALIZATION =====');
        }

        if (wrQuestions.isEmpty) {
          print(
              '[WordRecognitionScreen] ❌ ERROR: No WR questions found in MongoDB!');
          print(
              '[WordRecognitionScreen] Available questions: ${questions.map((q) => q.questionId).toList()}');
          setState(() {
            _isLoading = false;
            _errorMessage = 'No word recognition questions found in database';
          });
          return;
        }

        // Set current question to first WR question
        final firstWRQuestion = wrQuestions.first;
        final firstWRIndex = questions
            .indexWhere((q) => q.questionId == firstWRQuestion.questionId);

        if (firstWRIndex != -1) {
          assessmentProvider.currentQuestionIndex = firstWRIndex;
          print(
              '[WordRecognitionScreen] Set current question index to: $firstWRIndex (${firstWRQuestion.questionId})');
        } else {
          print(
              '[WordRecognitionScreen] ❌ ERROR: Could not find index for first WR question: ${firstWRQuestion.questionId}');
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Could not locate word recognition questions in assessment';
          });
          return;
        }

        // Get the current question data dynamically from MongoDB
        final currentQuestion = assessmentProvider.currentQuestion;
        if (currentQuestion != null &&
            currentQuestion.questionId.startsWith('WR_')) {
          print(
              '[WordRecognitionScreen] Current dynamic question: ${currentQuestion.questionId}');

          // Get the original question data which contains the word recognition data from MongoDB
          print(
              '[WordRecognitionScreen] Attempting to get dynamic original data for: ${currentQuestion.questionId}');
          final originalData = assessmentProvider
              .getOriginalQuestionData(currentQuestion.questionId);

          if (originalData != null) {
            print(
                '[WordRecognitionScreen] ===== DYNAMIC MONGODB ORIGINAL DATA =====');
            print(
                '[WordRecognitionScreen] Raw data keys: ${originalData.keys.toList()}');
            print('[WordRecognitionScreen] Raw data: $originalData');
            print(
                '[WordRecognitionScreen] ===== END DYNAMIC MONGODB ORIGINAL DATA =====');

            // Dynamically extract image from multiple possible field names
            String? questionImage =
                _extractImageFromDynamic(originalData, currentQuestion);
            print(
                '[WordRecognitionScreen] Final dynamic question image: $questionImage');

            setState(() {
              // Dynamically extract question text with fallback options
              _questionText = originalData['questionText'] ??
                  currentQuestion.questionText ??
                  originalData['question'] ??
                  originalData['text'] ??
                  '';
              _questionImage = questionImage;

              // Dynamically extract word recognition data with multiple field name options
              _displayWord = _extractStringFromDynamic(originalData, [
                'displayWord',
                'sentence',
                'text',
                'display',
                'wordDisplay'
              ]);
              _blankOptions = _extractListFromDynamic(originalData,
                  ['blankOptions', 'options', 'choices', 'words', 'blanks']);
              _correctAnswer = _extractListFromDynamic(originalData, [
                'correctAnswer',
                'answer',
                'correct',
                'solution',
                'answers'
              ]);

              // Initialize word recognition state dynamically based on data structure
              _selectedWords = List<String>.filled(_correctAnswer.length, '');
              _availableOptions = List<String>.from(_blankOptions);
              _isLoading = false;
            });

            // Start the typewriter effect flow when dynamic assessment is loaded
            _startTypewriterFlow();

            print(
                '[WordRecognitionScreen] ===== DYNAMIC LOADED DATA DEBUG =====');
            print('[WordRecognitionScreen] Question text: $_questionText');
            print('[WordRecognitionScreen] Question image: $_questionImage');
            print('[WordRecognitionScreen] Display word: $_displayWord');
            print('[WordRecognitionScreen] Blank options: $_blankOptions');
            print('[WordRecognitionScreen] Correct answer: $_correctAnswer');
            print(
                '[WordRecognitionScreen] Correct answer length: ${_correctAnswer.length}');
            print('[WordRecognitionScreen] Selected words: $_selectedWords');
            print(
                '[WordRecognitionScreen] Selected words length: ${_selectedWords.length}');
            print(
                '[WordRecognitionScreen] ===== END DYNAMIC LOADED DATA DEBUG =====');

            // Success - break out of retry loop
            return;
          } else {
            print(
                '[WordRecognitionScreen] ❌ ERROR: No original data found for question: ${currentQuestion.questionId}');
            if (retryCount < maxRetries - 1) {
              retryCount++;
              print(
                  '[WordRecognitionScreen] Retrying data load (attempt ${retryCount + 1}/$maxRetries)...');
              await Future.delayed(
                  Duration(seconds: 2 * retryCount)); // Exponential backoff
              continue;
            } else {
              setState(() {
                _errorMessage =
                    'No word recognition assessment data available in MongoDB';
                _isLoading = false;
              });
              return;
            }
          }
        } else {
          print(
              '[WordRecognitionScreen] ❌ ERROR: Current question is not a WR question: ${currentQuestion?.questionId ?? "null"}');
          if (retryCount < maxRetries - 1) {
            retryCount++;
            print(
                '[WordRecognitionScreen] Retrying data load (attempt ${retryCount + 1}/$maxRetries)...');
            await Future.delayed(
                Duration(seconds: 2 * retryCount)); // Exponential backoff
            continue;
          } else {
            setState(() {
              _errorMessage = 'No current word recognition question available';
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print(
            '[WordRecognitionScreen] Error loading dynamic word recognition data (attempt ${retryCount + 1}): $e');

        if (retryCount < maxRetries - 1) {
          retryCount++;
          print(
              '[WordRecognitionScreen] Retrying data load (attempt ${retryCount + 1}/$maxRetries)...');
          await Future.delayed(
              Duration(seconds: 2 * retryCount)); // Exponential backoff
        } else {
          setState(() {
            _errorMessage =
                'Error loading dynamic assessment from MongoDB after $maxRetries attempts: $e';
            _isLoading = false;
          });
          return;
        }
      }
    }
  }

  // Helper method to dynamically extract image from multiple possible field names
  String? _extractImageFromDynamic(
      Map<String, dynamic> originalData, Question currentQuestion) {
    final possibleImageFields = [
      'questionImage',
      'imageUrl',
      'image',
      'img',
      'picture'
    ];

    for (String field in possibleImageFields) {
      if (originalData.containsKey(field) && originalData[field] != null) {
        final value = originalData[field].toString();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return currentQuestion.imageUrl;
  }

  // Helper method to dynamically extract string from multiple possible field names
  String _extractStringFromDynamic(
      Map<String, dynamic> data, List<String> fieldNames) {
    for (String fieldName in fieldNames) {
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        return data[fieldName].toString();
      }
    }
    return '';
  }

  // Helper method to dynamically extract list from multiple possible field names
  List<String> _extractListFromDynamic(
      Map<String, dynamic> data, List<String> fieldNames) {
    for (String fieldName in fieldNames) {
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        try {
          if (data[fieldName] is List) {
            return List<String>.from(
                (data[fieldName] as List).map((e) => e.toString()));
          } else if (data[fieldName] is String) {
            // Handle comma-separated string
            return data[fieldName]
                .toString()
                .split(',')
                .map((s) => s.trim())
                .toList();
          }
        } catch (e) {
          print('[WordRecognitionScreen] Error parsing $fieldName as list: $e');
        }
      }
    }
    return [];
  }

  Future<void> _preloadAudioFiles() async {
    try {
      await _correctSoundPlayer.setAsset('assets/audio/assessmentsound.mp3');
      await _buttonSoundPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _wrongSoundPlayer.setAsset('assets/audio/incorrectanswer.mp3');
    } catch (e) {
      print('[WordRecognitionScreen] Error preloading audio files: $e');
    }
  }

  Future<void> _playCorrectSound() async {
    try {
      await _correctSoundPlayer.seek(Duration.zero);
      await _correctSoundPlayer.play();
    } catch (e) {
      print('[WordRecognitionScreen] Error playing correct sound: $e');
    }
  }

  Future<void> _playButtonSound() async {
    try {
      await _buttonSoundPlayer.seek(Duration.zero);
      await _buttonSoundPlayer.play();
    } catch (e) {
      print('[WordRecognitionScreen] Error playing button sound: $e');
    }
  }

  Future<void> _playWrongSound() async {
    try {
      await _wrongSoundPlayer.seek(Duration.zero);
      await _wrongSoundPlayer.play();
    } catch (e) {
      print('[WordRecognitionScreen] Error playing wrong sound: $e');
    }
  }

  // Dynamically load current question data from provider without reloading assessment
  void _loadCurrentQuestionDataFromProvider() {
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      if (currentQuestion != null &&
          currentQuestion.questionId.startsWith('WR_')) {
        // Get the original question data dynamically from MongoDB
        final originalData = assessmentProvider
            .getOriginalQuestionData(currentQuestion.questionId);

        if (originalData != null) {
          setState(() {
            // Dynamically extract question text with multiple fallback options
            _questionText = originalData['questionText'] ??
                currentQuestion.questionText ??
                originalData['question'] ??
                originalData['text'] ??
                '';

            // Dynamically extract image
            _questionImage =
                _extractImageFromDynamic(originalData, currentQuestion);

            // Dynamically extract word recognition data
            _displayWord = _extractStringFromDynamic(originalData,
                ['displayWord', 'sentence', 'text', 'display', 'wordDisplay']);
            _blankOptions = _extractListFromDynamic(originalData,
                ['blankOptions', 'options', 'choices', 'words', 'blanks']);
            _correctAnswer = _extractListFromDynamic(originalData,
                ['correctAnswer', 'answer', 'correct', 'solution', 'answers']);

            // Reset word recognition state for new question dynamically
            _selectedWords = List<String>.filled(_correctAnswer.length, '');
            _availableOptions = List<String>.from(_blankOptions);
            _isPakitsekEnabled = _checkIfCompleted();
            _showFeedback = false;
          });

          print(
              '[WordRecognitionScreen] ===== NEXT QUESTION LOADED DEBUG =====');
          print(
              '[WordRecognitionScreen] Dynamically loaded next question: ${currentQuestion.questionId}');
          print('[WordRecognitionScreen] Correct answer: $_correctAnswer');
          print(
              '[WordRecognitionScreen] Correct answer length: ${_correctAnswer.length}');
          print('[WordRecognitionScreen] Selected words: $_selectedWords');
          print(
              '[WordRecognitionScreen] Selected words length: ${_selectedWords.length}');
          print(
              '[WordRecognitionScreen] ===== END NEXT QUESTION LOADED DEBUG =====');

          // Start typewriter flow for next dynamic question
          _startTypewriterFlow();
        } else {
          print(
              '[WordRecognitionScreen] ❌ ERROR: No original data found for current question: ${currentQuestion.questionId}');
          setState(() {
            _errorMessage = 'Question data not available. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        print(
            '[WordRecognitionScreen] ❌ ERROR: Current question is not a WR question: ${currentQuestion?.questionId ?? "null"}');
        // Try to find and set the first WR question
        _ensureCorrectWRQuestionIndex();
      }
    } catch (e) {
      print(
          '[WordRecognitionScreen] Error dynamically loading current question data: $e');
      setState(() {
        _errorMessage = 'Error loading question data: $e';
        _isLoading = false;
      });
    }
  }

  // Ensure the current question index is set to a WR question
  void _ensureCorrectWRQuestionIndex() {
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final questions = assessmentProvider.assessment?.questions ?? [];

      // Find WR questions
      final wrQuestions =
          questions.where((q) => q.questionId.startsWith('WR_')).toList();
      wrQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

      if (wrQuestions.isNotEmpty) {
        final firstWRQuestion = wrQuestions.first;
        final firstWRIndex = questions
            .indexWhere((q) => q.questionId == firstWRQuestion.questionId);

        if (firstWRIndex != -1) {
          assessmentProvider.currentQuestionIndex = firstWRIndex;
          print(
              '[WordRecognitionScreen] Corrected current question index to: $firstWRIndex (${firstWRQuestion.questionId})');
          // Retry loading the question data
          _loadCurrentQuestionDataFromProvider();
        } else {
          setState(() {
            _errorMessage = 'Could not locate word recognition questions';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No word recognition questions found in assessment';
          _isLoading = false;
        });
      }
    } catch (e) {
      print(
          '[WordRecognitionScreen] Error ensuring correct WR question index: $e');
      setState(() {
        _errorMessage = 'Error setting up word recognition questions: $e';
        _isLoading = false;
      });
    }
  }

  // Check if all required positions are filled
  bool _checkIfCompleted() {
    return _selectedWords.every((word) => word.isNotEmpty);
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

  // Build sentence with selected word replacing the underscore
  List<InlineSpan> _buildSentenceWithSelectedWord() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    List<InlineSpan> spans = [];

    // Handle multiple selected words for questions like WR_009 and WR_010
    // Check if we need to generate dynamic blanks based on correctAnswer length
    String workingDisplayWord = _displayWord;

    // For WR_009 and WR_010 type questions (multiple correctAnswer), generate blanks dynamically
    if (_correctAnswer.length > 1 && !_displayWord.contains('___')) {
      // Create blanks based on correctAnswer length
      List<String> blanksList =
          List.generate(_correctAnswer.length, (index) => '___');
      workingDisplayWord = blanksList.join(' ');
    }

    // Split the sentence by underscore and build TextSpans
    // Handle different underscore formats: ____ (4 underscores), ___ (3 underscores), or _ (1 underscore)
    final parts = workingDisplayWord.contains('____')
        ? workingDisplayWord.split('____')
        : workingDisplayWord.contains('___')
            ? workingDisplayWord.split('___')
            : workingDisplayWord.split('_');
    int selectedWordIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      // Add the text part
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: themeProvider.getRealFontSize(24),
            fontWeight: FontWeight.bold,
            fontFamily: themeProvider.fontFamily,
          ),
        ));
      }

      // Add the selected word or underscore (except for the last part)
      if (i < parts.length - 1 && selectedWordIndex < _selectedWords.length) {
        final selectedWord = _selectedWords[selectedWordIndex];
        if (selectedWord.isNotEmpty) {
          // Show selected word with yellow background and black text
          spans.add(WidgetSpan(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD966), // Yellow background
                borderRadius: BorderRadius.circular(10), // Corner radius 10
              ),
              child: Text(
                selectedWord,
                style: TextStyle(
                  color: Colors.black,
                  fontSize:
                      themeProvider.getRealFontSize(18), // Smaller font size
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ));
        } else {
          // Show underscore when no word is selected
          spans.add(TextSpan(
            text: '___',
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(24),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
          ));
        }
        selectedWordIndex++;
      }
    }

    return spans;
  }

  // Build sentence with selected word for feedback dialog (black text for regular parts)
  List<InlineSpan> _buildSentenceWithSelectedWordForFeedback() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    List<InlineSpan> spans = [];

    // Handle multiple selected words for questions like WR_009 and WR_010
    // Check if we need to generate dynamic blanks based on correctAnswer length
    String workingDisplayWord = _displayWord;

    // For WR_009 and WR_010 type questions (multiple correctAnswer), generate blanks dynamically
    if (_correctAnswer.length > 1 && !_displayWord.contains('___')) {
      // Create blanks based on correctAnswer length
      List<String> blanksList =
          List.generate(_correctAnswer.length, (index) => '___');
      workingDisplayWord = blanksList.join(' ');
    }

    // Split the sentence by underscore and build TextSpans
    // Handle different underscore formats: ____ (4 underscores), ___ (3 underscores), or _ (1 underscore)
    final parts = workingDisplayWord.contains('____')
        ? workingDisplayWord.split('____')
        : workingDisplayWord.contains('___')
            ? workingDisplayWord.split('___')
            : workingDisplayWord.split('_');
    int selectedWordIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      // Add the text part with black color for feedback
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            color: Colors.black87, // Black text for feedback dialog
            fontSize: themeProvider.getRealFontSize(20),
            fontWeight: FontWeight.bold,
            fontFamily: themeProvider.fontFamily,
          ),
        ));
      }

      // Add the selected word or underscore (except for the last part)
      if (i < parts.length - 1 && selectedWordIndex < _selectedWords.length) {
        final selectedWord = _selectedWords[selectedWordIndex];
        if (selectedWord.isNotEmpty) {
          // Show selected word with yellow background and black text
          spans.add(WidgetSpan(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD966), // Yellow background
                borderRadius: BorderRadius.circular(10), // Corner radius 10
              ),
              child: Text(
                selectedWord,
                style: TextStyle(
                  color: Colors.black,
                  fontSize:
                      themeProvider.getRealFontSize(18), // Smaller font size
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ));
        } else {
          // Show underscore when no word is selected
          spans.add(TextSpan(
            text: '___',
            style: TextStyle(
              color: Colors.black87, // Black text for feedback dialog
              fontSize: themeProvider.getRealFontSize(20),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
          ));
        }
        selectedWordIndex++;
      }
    }

    return spans;
  }

  // Handle option selection (tap to place)
  void _onOptionTap(String option) {
    if (_showFeedback) return;

    setState(() {
      // Find first empty position to fill
      for (int i = 0; i < _selectedWords.length; i++) {
        if (_selectedWords[i].isEmpty) {
          _selectedWords[i] = option;
          _availableOptions.remove(option);
          break;
        }
      }

      _isPakitsekEnabled = _checkIfCompleted();
    });
  }

  // Handle removing selected word (tap to remove)
  void _onSelectedWordTap(int index) {
    if (_showFeedback) return;

    final word = _selectedWords[index];
    if (word.isNotEmpty) {
      setState(() {
        _selectedWords[index] = '';
        _availableOptions.add(word);
        _isPakitsekEnabled = _checkIfCompleted();
      });
    }
  }

  // Validate the user's answer (case-insensitive)
  bool _validateAnswer() {
    if (_selectedWords.length != _correctAnswer.length) return false;

    for (int i = 0; i < _correctAnswer.length; i++) {
      if (_selectedWords[i].toLowerCase() != _correctAnswer[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  // Handle PAKITSEK button press
  void _onPakitsekPressed() async {
    if (!_isPakitsekEnabled) return;

    _playButtonSound();

    final isCorrect = _validateAnswer();

    // Get current question info for logging
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

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
      // Track correct answer for Word Recognition-specific scoring
      _wordRecognitionCorrectAnswers++;

      // Log scoring for main assessment only
      if (!widget.isPreAssessment) {
        print(
            '[WordRecognitionScreen] ===== MAIN ASSESSMENT SCORING LOG =====');
        print('[WordRecognitionScreen] ✅ CORRECT ANSWER!');
        print(
            '[WordRecognitionScreen] Question: ${currentQuestion?.questionId ?? 'Unknown'}');
        print(
            '[WordRecognitionScreen] User Answer: ${_selectedWords.join(',')}');
        print(
            '[WordRecognitionScreen] Correct Answer: ${_correctAnswer.join(',')}');
        print(
            '[WordRecognitionScreen] Word Recognition Correct Answers: $_wordRecognitionCorrectAnswers/$_wordRecognitionTotalQuestions');
        print(
            '[WordRecognitionScreen] Word Recognition Percentage: ${_wordRecognitionTotalQuestions > 0 ? (_wordRecognitionCorrectAnswers / _wordRecognitionTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print(
            '[WordRecognitionScreen] ===== END MAIN ASSESSMENT SCORING LOG =====');
      }
    } else {
      _playWrongSound();

      // Log incorrect answer for main assessment only
      if (!widget.isPreAssessment) {
        print(
            '[WordRecognitionScreen] ===== MAIN ASSESSMENT SCORING LOG =====');
        print('[WordRecognitionScreen] ❌ INCORRECT ANSWER');
        print(
            '[WordRecognitionScreen] Question: ${currentQuestion?.questionId ?? 'Unknown'}');
        print(
            '[WordRecognitionScreen] User Answer: ${_selectedWords.join(',')}');
        print(
            '[WordRecognitionScreen] Correct Answer: ${_correctAnswer.join(',')}');
        print(
            '[WordRecognitionScreen] Word Recognition Correct Answers: $_wordRecognitionCorrectAnswers/$_wordRecognitionTotalQuestions');
        print(
            '[WordRecognitionScreen] Word Recognition Percentage: ${_wordRecognitionTotalQuestions > 0 ? (_wordRecognitionCorrectAnswers / _wordRecognitionTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print(
            '[WordRecognitionScreen] ===== END MAIN ASSESSMENT SCORING LOG =====');
      }
    }

    // Record the response

    if (currentQuestion != null) {
      // Save individual response in new MongoDB format
      await assessmentProvider.saveIndividualResponse(
        questionId: currentQuestion.questionId,
        category: 'Word Recognition',
        questionType: currentQuestion.questionType ?? 'word',
        response: _selectedWords.where((word) => word.isNotEmpty).toList(),
        isCorrect: isCorrect,
        responseTime: 0, // Could be tracked if needed
      );

      // Record the response using the existing method for compatibility
      assessmentProvider.answerCurrentQuestion(_selectedWords.join(','));
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

  // Proceed to next word recognition question or exit
  void _proceedToNextQuestion() {
    if (widget.isPreAssessment) {
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

    // Check if assessment is complete first
    if (assessmentProvider.isAssessmentComplete) {
      print(
          '[WordRecognitionScreen] Pre-assessment complete - checking for reading comprehension');
      _checkForReadingComprehension();
      return;
    }

    // answerCurrentQuestion() already moved to the next question
    // Just check if we're still in WR questions or need to move to RC
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null &&
        currentQuestion.questionId.startsWith('WR_')) {
      // Still in WR questions, load the current question data
      print(
          '[WordRecognitionScreen] Loading next WR question: ${currentQuestion.questionId}');
      _loadCurrentQuestionDataFromProvider();
    } else {
      // No more WR questions or moved to a different section, check for reading comprehension
      print(
          '[WordRecognitionScreen] WR section complete, checking for reading comprehension');
      _checkForReadingComprehension();
    }
  }

  // New method specifically for main assessment flow
  void _proceedToNextQuestionMainAssessment() {
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);

    // Check if assessment is complete first
    if (assessmentProvider.isAssessmentComplete) {
      // Log completion for main assessment only
      if (!widget.isPreAssessment) {
        print(
            '[WordRecognitionScreen] ===== MAIN ASSESSMENT COMPLETION LOG =====');
        print(
            '[WordRecognitionScreen] Main assessment complete - showing score display');
        print(
            '[WordRecognitionScreen] isAssessmentComplete: ${assessmentProvider.isAssessmentComplete}');
        print(
            '[WordRecognitionScreen] Final Word Recognition Score: $_wordRecognitionCorrectAnswers/$_wordRecognitionTotalQuestions');
        print(
            '[WordRecognitionScreen] Final Word Recognition Percentage: ${_wordRecognitionTotalQuestions > 0 ? (_wordRecognitionCorrectAnswers / _wordRecognitionTotalQuestions * 100).toStringAsFixed(1) : '0.0'}%');
        print(
            '[WordRecognitionScreen] ===== END MAIN ASSESSMENT COMPLETION LOG =====');
      }

      // Show score display for main assessment
      _showMainAssessmentScoreDisplay();
      return;
    }

    // answerCurrentQuestion() already moved to the next question
    // Just check if we're still in WR questions or need to show score
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null &&
        currentQuestion.questionId.startsWith('WR_')) {
      // Still in WR questions, load the current question data
      print(
          '[WordRecognitionScreen] Loading next WR question: ${currentQuestion.questionId}');
      _loadCurrentQuestionDataFromProvider();
    } else {
      // No more WR questions - show score display
      print(
          '[WordRecognitionScreen] No more WR questions in main assessment - showing score display');
      _showMainAssessmentScoreDisplay();
    }
  }

  // New method specifically for Word Recognition main assessment scoring
  void _showMainAssessmentScoreDisplay() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Use the tracked Word Recognition-specific scores
    int correctAnswers = _wordRecognitionCorrectAnswers;
    int totalWRQuestions = _wordRecognitionTotalQuestions;

    final percentage =
        totalWRQuestions > 0 ? (correctAnswers / totalWRQuestions) * 100 : 0.0;

    // Log score calculation and display for main assessment only
    if (!widget.isPreAssessment) {
      print(
          '[WordRecognitionScreen] ===== WORD RECOGNITION SCORE CALCULATION =====');
      print(
          '[WordRecognitionScreen] Word Recognition Score: $correctAnswers/$totalWRQuestions, Percentage: $percentage%');
      print(
          '[WordRecognitionScreen] _wordRecognitionCorrectAnswers: $_wordRecognitionCorrectAnswers');
      print(
          '[WordRecognitionScreen] _wordRecognitionTotalQuestions: $_wordRecognitionTotalQuestions');
      print(
          '[WordRecognitionScreen] ===== END WORD RECOGNITION SCORE CALCULATION =====');

      print('[WordRecognitionScreen] ===== SHOWING SCORE DISPLAY =====');
      print(
          '[WordRecognitionScreen] Displaying score dialog for main assessment');
      print('[WordRecognitionScreen] Score: $correctAnswers/$totalWRQuestions');
      print('[WordRecognitionScreen] Percentage: $percentage%');
      print('[WordRecognitionScreen] ===== END SHOWING SCORE DISPLAY =====');
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
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
                  'WORD RECOGNITION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
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
                    fontSize: 16,
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
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                            ),
                          ),
                          Text(
                            ' / $totalWRQuestions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
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
                          fontSize: 14,
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
                            fontSize: 20,
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
                    fontSize: 16,
                    fontFamily: themeProvider.fontFamily,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
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
                        fontSize: 18,
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
  }

  // Helper method to get performance message based on score
  String _getPerformanceMessage(double percentage) {
    if (percentage >= 90) {
      return 'Napakagaling! Mahusay na pagganap sa Word Recognition assessment.';
    } else if (percentage >= 80) {
      return 'Magaling! Magandang pagganap sa Word Recognition assessment.';
    } else if (percentage >= 70) {
      return 'Mabuti! Katanggap-tanggap na pagganap sa Word Recognition assessment.';
    } else if (percentage >= 50) {
      return 'Kailangan pa ng pagsasanay sa Word Recognition assessment.';
    } else {
      return 'Kailangan ng mas maraming pagsasanay sa Word Recognition assessment.';
    }
  }

  void _checkForReadingComprehension() async {
    final provider = Provider.of<AssessmentProvider>(context, listen: false);

    print(
        '[WordRecognitionScreen] Checking for RC_* questions in pre-assessment...');
    final all = provider.assessment?.questions ?? [];

    // STRICT: Only take RC_001..RC_XXX questions
    final rcQuestions =
        all.where((q) => RegExp(r'^RC_\d{3}$').hasMatch(q.questionId)).toList();

    rcQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));
    print(
        '[WordRecognitionScreen] RC IDs found: ${rcQuestions.map((q) => q.questionId).toList()}');

    if (rcQuestions.isNotEmpty) {
      _navigateToReadingComprehension(rcQuestions.first);
      return;
    }

    // No RC questions, finish assessment
    print(
        '[WordRecognitionScreen] No RC_* questions found, completing assessment');
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _navigateToReadingComprehension(question) async {
    print(
        '[WordRecognitionScreen] Navigating to Reading Comprehension for question: ${question.questionId}');

    // Always use existing providers from context - never create new ones
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final ttsProvider = Provider.of<TTSProvider>(context, listen: false);

    print('[WordRecognitionScreen] Using existing providers from context');

    // Load pre-assessment data for the assessment provider
    try {
      await assessmentProvider.loadPreAssessment();
      print('[WordRecognitionScreen] Pre-assessment data loaded successfully');
    } catch (loadError) {
      print(
          '[WordRecognitionScreen] Failed to load pre-assessment data: $loadError');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load assessment data. Please try again.')),
        );
        return;
      }
    }

    // Use pushReplacement to navigate to reading comprehension
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (newContext) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AssessmentProvider>.value(
              value: assessmentProvider,
            ),
            ChangeNotifierProvider<ThemeProvider>.value(
              value: themeProvider,
            ),
            ChangeNotifierProvider<TTSProvider>.value(
              value: ttsProvider,
            ),
          ],
          child: const ReadingComprehensionTutorial(),
        ),
      ),
    );
  }

  void _handleReadingComprehensionAnswer(
      question, String userAnswer, AssessmentProvider provider) {
    // Validate answer against sentence questions
    bool isCorrect = false;
    if (question.sentenceQuestions != null &&
        question.sentenceQuestions!.isNotEmpty) {
      final sentenceQuestion = question.sentenceQuestions!.first;
      final correctAnswer = sentenceQuestion['correctAnswer']?.toString() ?? '';

      // Case-insensitive comparison and partial matching
      final correctLower = correctAnswer.toLowerCase();
      final userLower = userAnswer.toLowerCase();
      isCorrect =
          correctLower.contains(userLower) || userLower.contains(correctLower);
    }

    // Submit the answer through the assessment provider
    provider.answerCurrentQuestion(userAnswer);
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
                const SizedBox(height: 20),
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
                        : _buildWordRecognitionContent(themeProvider),
                  ),
                ),

                // PAKITSEK/MAG PATULOY button - only show if user has listened
                if (_userListened)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: (_showFeedback ||
                                      (_isPakitsekEnabled && _userListened))
                                  ? const Color.fromARGB(197, 27, 172, 37)
                                  : const Color.fromARGB(197, 117, 117, 117),
                              offset: const Offset(
                                  0, 4), // Horizontal & vertical offset
                              blurRadius: 0, // Softness of the shadow
                              spreadRadius: 0, // Size expansion
                            ),
                          ],
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                                : Colors.grey.shade600,
                            disabledBackgroundColor: Colors.grey.shade600,
                            foregroundColor: (_showFeedback ||
                                    (_isPakitsekEnabled && _userListened))
                                ? Colors.white
                                : Colors.grey.shade800,
                            shadowColor: Colors.transparent,
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
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Confetti widget
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

  // Helper method to calculate pill position
  double _calculatePillPosition(
      double totalWidth, double pillWidth, double progressRatio) {
    if (progressRatio < 0.1) {
      return 0;
    } else if (progressRatio > 0.9) {
      return totalWidth - pillWidth;
    } else {
      return (totalWidth - pillWidth) * progressRatio;
    }
  }

  // Progress indicator for WR questions (position within WR-only list)
  Widget _buildProgressIndicator(
      AssessmentProvider provider, AppThemeData theme) {
    // Get WR-specific progress by filtering and de-duplicating WR questions from database
    final allQuestions = provider.assessment?.questions ?? [];
    final Map<String, dynamic> idToQuestion = {};
    for (final q in allQuestions) {
      final id = q.questionId;
      if (id.startsWith('WR_') &&
          id.length == 6 &&
          RegExp(r'^WR_\d{3}$').hasMatch(id)) {
        idToQuestion[id] = q; // de-duplicate by ID
      }
    }

    // Convert to list and ensure proper order (WR_001 .. WR_005)
    final wrQuestions = idToQuestion.values.toList();
    wrQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

    final currentWRQuestion = provider.currentQuestion;

    int current = 1;
    // For main assessment, show all questions; for pre-assessment, cap at 10
    final total = widget.isPreAssessment
        ? wrQuestions.length.clamp(0, 10) // Pre-assessment: cap at 10
        : wrQuestions.length; // Main assessment: show all questions

    if (currentWRQuestion != null &&
        currentWRQuestion.questionId.startsWith('WR_')) {
      final currentWRIndex = wrQuestions
          .indexWhere((q) => q.questionId == currentWRQuestion.questionId);
      if (currentWRIndex != -1) {
        current = (currentWRIndex + 1).clamp(1, total);
      }
    }

    print(
        '[WordRecognitionScreen] WR Questions found: ${wrQuestions.map((q) => q.questionId).toList()}');
    print(
        '[WordRecognitionScreen] Current WR Question: ${currentWRQuestion?.questionId}');
    print(
        '[WordRecognitionScreen] Progress: $current/$total (WR questions only)');
    final themeProvider = Provider.of<ThemeProvider>(context);

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = total == 0 ? 0.0 : current / total;
    final pillWidth = 80.0;
    final pillPosition =
        _calculatePillPosition(totalWidth, pillWidth, progressRatio);

    return Container(
      height:
          48, // extra space so the pill isn't clipped when positioned with a negative top
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                    offset: Offset(0, 4),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: pillPosition,
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
                    offset: Offset(0, 5),
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

    return Container(
      padding: const EdgeInsets.all(0),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.accentColor, width: 1),
      ),
      child: Column(
        children: [
          // Typewriter text display
          Text(
            _displayedText,
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(16),
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

  // Main word recognition content
  Widget _buildWordRecognitionContent(ThemeProvider themeProvider) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDE37C)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading word recognition questions...',
              style: TextStyle(
                color: Colors.white,
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we connect to the database',
              style: TextStyle(
                color: Colors.white70,
                fontSize: themeProvider.getRealFontSize(14),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load Questions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: themeProvider.getRealFontSize(20),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: themeProvider.getRealFontSize(15),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadWordRecognitionData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE37C),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(16),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Display sentence with blank spaces - only show after user has listened
          if (_showChoices && _displayWord.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(14),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                  children: _buildSentenceWithSelectedWord(),
                ),
              ),
            ),
          ],

          // Selected words display (blank boxes) - only show after user has listened
          if (_showChoices)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _selectedWords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final word = entry.value;
                  final isEmpty = word.isEmpty;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: !isEmpty ? () => _onSelectedWordTap(index) : null,
                      child: Container(
                        width: 120,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFFFD966), width: 3),
                          borderRadius: BorderRadius.circular(10),
                          color: isEmpty
                              ? Colors.transparent
                              : const Color(
                                  0xFFFFD966), // Yellow fill when word is selected
                        ),
                        child: Center(
                          child: Text(
                            isEmpty
                                ? '_____'
                                : word, // Show underscore when empty, word when filled
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(15),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                              color: isEmpty
                                  ? Colors.white
                                  : Colors.black, // Black text when filled
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Option buttons section - only show after user has listened
          if (_showChoices)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  // First row of options (first 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _availableOptions.take(2).map((option) {
                      return Expanded(
                        child: Container(
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(197, 255, 217, 102),
                                offset: const Offset(0, 4),
                                blurRadius: 0,
                                spreadRadius: 0,
                              ),
                            ],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _onOptionTap(option),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD966),
                              foregroundColor: Colors.black,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(14),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Second row of options (next 2)
                  if (_availableOptions.length > 2) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _availableOptions.skip(2).take(2).map((option) {
                        return Expanded(
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(197, 255, 217, 102),
                                  offset: const Offset(0, 4),
                                  blurRadius: 0,
                                  spreadRadius: 0,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _onOptionTap(option),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD966),
                                foregroundColor: Colors.black,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: themeProvider.getRealFontSize(14),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  // Third row and beyond for additional options (if more than 4)
                  if (_availableOptions.length > 4) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _availableOptions.skip(4).map((option) {
                        return Expanded(
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(197, 255, 217, 102),
                                  offset: const Offset(0, 4),
                                  blurRadius: 0,
                                  spreadRadius: 0,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _onOptionTap(option),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD966),
                                foregroundColor: Colors.black,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: themeProvider.getRealFontSize(18),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

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
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            color: _isCorrectAnswer
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontSize: themeProvider.getRealFontSize(20),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                          ),
                          children: _buildSentenceWithSelectedWordForFeedback(),
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
        '[WordRecognitionScreen] _speakText called with text: ${text.substring(0, text.length.clamp(0, 50))}...');
    print(
        '[WordRecognitionScreen] TTS Provider available: ${_ttsProvider?.isAvailable}');
    print(
        '[WordRecognitionScreen] Theme TTS enabled: ${_themeProvider?.textToSpeechEnabled}');

    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      print('[WordRecognitionScreen] Calling TTS speakText...');
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
          print('[WordRecognitionScreen] TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    } else {
      print('[WordRecognitionScreen] TTS not available or disabled');
      print('[WordRecognitionScreen] Provider null: ${_ttsProvider == null}');
      print(
          '[WordRecognitionScreen] Provider available: ${_ttsProvider?.isAvailable}');
      print(
          '[WordRecognitionScreen] Theme provider null: ${_themeProvider == null}');
      print(
          '[WordRecognitionScreen] Theme TTS enabled: ${_themeProvider?.textToSpeechEnabled}');
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
