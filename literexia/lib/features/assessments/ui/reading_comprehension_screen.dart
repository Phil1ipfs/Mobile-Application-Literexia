import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:literexia/core/theme/app_theme.dart';
import 'package:just_audio/just_audio.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_result_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:flutter/services.dart';

class ReadingComprehensionScreen extends StatefulWidget {
  final Question question;
  final String assessmentType;
  final VoidCallback onComplete;
  final Function(String answer) onAnswerSubmitted;
  final int initialSentenceQuestionIndex;
  final bool
      handleAllRcQuestions; // New parameter to control navigation behavior
  final List<Question>? rcQuestionsList; // Pass RC questions list directly

  const ReadingComprehensionScreen({
    super.key,
    required this.question,
    required this.assessmentType,
    required this.onComplete,
    required this.onAnswerSubmitted,
    this.initialSentenceQuestionIndex = 0,
    this.handleAllRcQuestions = true, // Default to handling all RC questions
    this.rcQuestionsList, // Optional RC questions list
  });

  @override
  State<ReadingComprehensionScreen> createState() =>
      _ReadingComprehensionScreenState();
}

class _ReadingComprehensionScreenState
    extends State<ReadingComprehensionScreen> {
  bool _showPassage = false;
  bool _showContinueButton = false;
  bool _showSentenceQuestion = false;
  bool _showTextInput = false;
  String _currentQuestionText = '';
  String _currentPageText = '';
  String _currentSentenceQuestionText = '';
  Timer? _typewriterTimer;
  int _currentIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  String? _currentPassageImage;
  String? _correctAnswer;

  // Store provider reference to avoid context issues
  AssessmentProvider? _cachedProvider;

  // Flag to prevent double navigation
  bool _isNavigating = false;

  // Progress values - tracking RC questions
  List<Question> _rcQuestions = const [];
  int _currentSentenceQuestionIndex =
      0; // Track current sentence question within RC question
  int _currentPageIndex = 0; // Track current page within passages

  // Audio players
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _buttonAudioPlayer = AudioPlayer();
  final AudioPlayer _correctAnswerPlayer = AudioPlayer();
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer();

  // Feedback state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackDescription = '';

  // Confetti controller
  // Confetti controllers for fireworks animation
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // Track if submit button should be enabled
  bool _isSubmitEnabled = false;

  @override
  void initState() {
    super.initState();

    // Cache provider reference early to avoid context issues later
    try {
      _cachedProvider = Provider.of<AssessmentProvider>(context, listen: false);
      print('[ReadingComprehension] Provider cached successfully');
    } catch (e) {
      print('[ReadingComprehension] Failed to cache provider: $e');
    }

    // Always start from beginning - passages first, then sentence questions
    _currentSentenceQuestionIndex = 0;

    // Initialize confetti controller
    // Initialize confetti controllers
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Add listener to answer controller for submit button state
    _answerController.addListener(() {
      final isEnabled = _answerController.text.trim().isNotEmpty;
      if (_isSubmitEnabled != isEnabled) {
        setState(() {
          _isSubmitEnabled = isEnabled;
        });
      }
    });

    // Set current user ID in assessment provider for response tracking
    _setCurrentUserIdInProvider();

    // Start background music
    _startBackgroundMusic();

    _initializeReadingComprehension();
    _initializeRcProgressFromProvider();
  }

  void _setCurrentUserIdInProvider() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber;
      if (userId != null && _cachedProvider != null) {
        // Store user ID in provider if needed for response tracking
        print('[ReadingComprehension] Current user ID set: $userId');
        _cachedProvider!.setCurrentUserId(userId.toString());
      }
    } catch (e) {
      print('[ReadingComprehension] Error setting user ID: $e');
    }
  }

  // Determine RC question list and progress using provider data
  void _initializeRcProgressFromProvider() {
    try {
      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final allQuestions = provider.assessment?.questions ?? [];

      // CRITICAL: Validate assessment type matches expected type
      final providerAssessmentType = provider.assessment?.type ?? 'unknown';
      final isProviderPreAssessment = provider.isPreAssessment;
      final expectedIsPreAssessment = widget.assessmentType == 'pre_assessment';

      print('[ReadingComprehension] DATA SOURCE VALIDATION:');
      print(
          '[ReadingComprehension]   - Widget assessmentType: ${widget.assessmentType}');
      print(
          '[ReadingComprehension]   - Provider assessment type: $providerAssessmentType');
      print(
          '[ReadingComprehension]   - Provider isPreAssessment: $isProviderPreAssessment');
      print(
          '[ReadingComprehension]   - Expected isPreAssessment: $expectedIsPreAssessment');
      print(
          '[ReadingComprehension]   - Assessment ID: ${provider.assessment?.assessmentId}');

      // Check for assessment type mismatch
      if (isProviderPreAssessment != expectedIsPreAssessment) {
        print('[ReadingComprehension] ❌ ASSESSMENT TYPE MISMATCH DETECTED!');
        print(
            '[ReadingComprehension]   - Expected: ${expectedIsPreAssessment ? "pre_assessment" : "main_assessment"}');
        print(
            '[ReadingComprehension]   - Provider has: ${isProviderPreAssessment ? "pre_assessment" : "main_assessment"}');

        // Force reload correct assessment type
        if (!expectedIsPreAssessment) {
          print('[ReadingComprehension] 🔄 Force loading MAIN assessment...');
          _forceLoadMainAssessment();
          return;
        }
      }

      // DYNAMIC: Filter RC questions based on assessment type
      List<Question> sortedQuestions;

      if (expectedIsPreAssessment) {
        // Pre-assessment: Look for reading comprehension questions with various patterns
        sortedQuestions = allQuestions
            .where((q) =>
                q.questionTypeId == 'reading_comprehension' ||
                q.questionId.contains('RC') ||
                q.questionId.startsWith('PRE_RC') ||
                (q.passages != null && q.passages!.isNotEmpty) ||
                (q.sentenceQuestions != null &&
                    q.sentenceQuestions!.isNotEmpty))
            .toList();

        print(
            '[ReadingComprehension] Pre-assessment RC questions found: ${sortedQuestions.length}');
      } else {
        // Main assessment: Look for standard RC_ pattern
        sortedQuestions = allQuestions
            .where((q) =>
                q.questionId.startsWith('RC_') ||
                q.questionTypeId == 'reading_comprehension')
            .toList();

        print(
            '[ReadingComprehension] Main assessment RC questions found: ${sortedQuestions.length}');
      }

      // DYNAMIC: Sort based on assessment type
      if (expectedIsPreAssessment) {
        // Pre-assessment: Sort by question number or order
        sortedQuestions.sort((a, b) {
          final aOrder = a.questionNumber ?? a.order ?? 0;
          final bOrder = b.questionNumber ?? b.order ?? 0;
          return aOrder.compareTo(bOrder);
        });
      } else {
        // Main assessment: Sort by extracting the number after RC_
        sortedQuestions.sort((a, b) {
          if (a.questionId.startsWith('RC_') &&
              b.questionId.startsWith('RC_')) {
            final aNum = int.tryParse(a.questionId.substring(3)) ?? 0;
            final bNum = int.tryParse(b.questionId.substring(3)) ?? 0;
            return aNum.compareTo(bNum);
          } else {
            // Fallback to question number or order
            final aOrder = a.questionNumber ?? a.order ?? 0;
            final bOrder = b.questionNumber ?? b.order ?? 0;
            return aOrder.compareTo(bOrder);
          }
        });
      }

      // Store the sorted questions for use in progress indicator
      setState(() {
        _rcQuestions = sortedQuestions;
      });

      // ===== RC PROGRESS DEBUG =====
      print('[ReadingComprehension] RC question IDs: '
          '${sortedQuestions.map((q) => q.questionId).toList()}');
      print('[ReadingComprehension] Current RC: ${widget.question.questionId}');
      print('[ReadingComprehension] Current page index: $_currentPageIndex');
      print(
          '[ReadingComprehension] Current sentence question index: $_currentSentenceQuestionIndex');
      print(
          '[ReadingComprehension] Show passage: $_showPassage, Show continue: $_showContinueButton');
      print(
          '[ReadingComprehension] Total RC questions: ${sortedQuestions.length}');
      // ===== END RC PROGRESS DEBUG =====
    } catch (e) {
      // Keep defaults on error
      print('[ReadingComprehension] Progress init error: $e');
    }
  }

  // Force load main assessment when there's a type mismatch
  Future<void> _forceLoadMainAssessment() async {
    try {
      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);

      print('[ReadingComprehension] 🔄 Forcing main assessment load...');

      // Get the assessment ID that should be loaded (from router args or a default)
      final expectedAssessmentId =
          '683a4f2c168ffbb611dab962'; // Reading Comprehension ID from home screen

      // Force load the main assessment with Reading Comprehension category
      await provider.loadMainAssessment(
        expectedAssessmentId,
        category: 'Reading Comprehension',
      );

      print('[ReadingComprehension] ✅ Main assessment force load completed');

      // Retry initialization after loading
      _initializeRcProgressFromProvider();
    } catch (e) {
      print(
          '[ReadingComprehension] ❌ Failed to force load main assessment: $e');
      // Continue with existing data as fallback
      _initializeRcProgressFromProviderFallback();
    }
  }

  // Fallback method that continues even with mismatched data
  void _initializeRcProgressFromProviderFallback() {
    try {
      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final allQuestions = provider.assessment?.questions ?? [];

      print('[ReadingComprehension] ⚠️ Using fallback data initialization...');

      final expectedIsPreAssessment = widget.assessmentType == 'pre_assessment';

      // DYNAMIC: Filter RC questions based on assessment type (same logic as main method)
      List<Question> sortedQuestions;

      if (expectedIsPreAssessment) {
        // Pre-assessment: Look for reading comprehension questions with various patterns
        sortedQuestions = allQuestions
            .where((q) =>
                q.questionTypeId == 'reading_comprehension' ||
                q.questionId.contains('RC') ||
                q.questionId.startsWith('PRE_RC') ||
                (q.passages != null && q.passages!.isNotEmpty) ||
                (q.sentenceQuestions != null &&
                    q.sentenceQuestions!.isNotEmpty))
            .toList();

        print(
            '[ReadingComprehension] ⚠️ Fallback pre-assessment RC questions found: ${sortedQuestions.length}');
      } else {
        // Main assessment: Look for standard RC_ pattern
        sortedQuestions = allQuestions
            .where((q) =>
                q.questionId.startsWith('RC_') ||
                q.questionTypeId == 'reading_comprehension')
            .toList();

        print(
            '[ReadingComprehension] ⚠️ Fallback main assessment RC questions found: ${sortedQuestions.length}');
      }

      // DYNAMIC: Sort based on assessment type
      if (expectedIsPreAssessment) {
        // Pre-assessment: Sort by question number or order
        sortedQuestions.sort((a, b) {
          final aOrder = a.questionNumber ?? a.order ?? 0;
          final bOrder = b.questionNumber ?? b.order ?? 0;
          return aOrder.compareTo(bOrder);
        });
      } else {
        // Main assessment: Sort by extracting the number after RC_
        sortedQuestions.sort((a, b) {
          if (a.questionId.startsWith('RC_') &&
              b.questionId.startsWith('RC_')) {
            final aNum = int.tryParse(a.questionId.substring(3)) ?? 0;
            final bNum = int.tryParse(b.questionId.substring(3)) ?? 0;
            return aNum.compareTo(bNum);
          } else {
            // Fallback to question number or order
            final aOrder = a.questionNumber ?? a.order ?? 0;
            final bOrder = b.questionNumber ?? b.order ?? 0;
            return aOrder.compareTo(bOrder);
          }
        });
      }

      // Store the sorted questions for use in progress indicator
      setState(() {
        _rcQuestions = sortedQuestions;
      });

      print(
          '[ReadingComprehension] ⚠️ Fallback RC questions loaded: ${sortedQuestions.length}');
    } catch (e) {
      print('[ReadingComprehension] ❌ Fallback initialization failed: $e');
    }
  }

  void _initializeReadingComprehension() {
    print(
        '[ReadingComprehension] ===== INITIALIZING DYNAMIC READING COMPREHENSION FROM MONGODB =====');
    print(
        '[ReadingComprehension] Dynamic question: ${widget.question.questionId}');
    print(
        '[ReadingComprehension] Dynamic question data: ${widget.question.toMap()}');

    // Reset to always start from passages first, regardless of initialSentenceQuestionIndex
    _currentPageIndex = 0;
    _currentSentenceQuestionIndex = 0;

    // ===== DYNAMIC LOADED DATA DEBUG =====
    try {
      final q = widget.question;
      print('[ReadingComprehension] ===== DYNAMIC MONGODB DATA DEBUG =====');
      print('[ReadingComprehension] questionId: ${q.questionId}');
      print('[ReadingComprehension] questionText: ${q.questionText}');
      print('[ReadingComprehension] category: ${q.category}');
      print('[ReadingComprehension] questionType: ${q.questionType}');
      print('[ReadingComprehension] passages length: '
          '${q.passages?.length ?? 0}');
      print('[ReadingComprehension] sentenceQuestions length: '
          '${q.sentenceQuestions?.length ?? 0}');
      print('[ReadingComprehension] full map: ${q.toMap()}');

      // Debug dynamic passage structure
      if (q.passages != null) {
        for (int i = 0; i < q.passages!.length; i++) {
          final passage = q.passages![i];
          print('[ReadingComprehension] Dynamic Passage $i: $passage');
          print(
              '[ReadingComprehension] Passage keys: ${passage.keys.toList()}');
        }
      }

      // Debug dynamic sentence questions structure
      if (q.sentenceQuestions != null) {
        for (int i = 0; i < q.sentenceQuestions!.length; i++) {
          final sq = q.sentenceQuestions![i];
          print('[ReadingComprehension] Dynamic SentenceQuestion $i: $sq');
          print('[ReadingComprehension] SQ keys: ${sq.keys.toList()}');
        }
      }

      print(
          '[ReadingComprehension] ===== END DYNAMIC MONGODB DATA DEBUG =====');
    } catch (e) {
      print('[ReadingComprehension] Error in dynamic debug: $e');
    }

    // Dynamically extract question text with multiple field options
    final questionText = _extractDynamicQuestionText(widget.question);
    print('[ReadingComprehension] Dynamic question text: $questionText');

    _startTypewriterAnimation(questionText, (text) {
      setState(() {
        _currentQuestionText = text;
      });
    }, () {
      // After question text is complete, show passage
      setState(() {
        _showPassage = true;
      });
      _showPassageContent();
    });
  }

  // Dynamically extract question text with fallback options
  String _extractDynamicQuestionText(Question question) {
    // Try multiple possible field names
    final possibleFields = [
      'questionText',
      'text',
      'question',
      'title',
      'instruction'
    ];

    for (String field in possibleFields) {
      final value = question.toMap()[field];
      if (value != null &&
          value.toString().isNotEmpty &&
          value.toString() != 'null') {
        return value.toString();
      }
    }

    // For RC questions without questionText, use a default instruction
    if (question.questionId.startsWith('RC_')) {
      return 'Basahin ang mga pahina at sagutin ang mga tanong.';
    }

    return question.questionText ?? '';
  }

  void _showPassageContent() {
    print('[ReadingComprehension] Loading passage content...');
    print('[ReadingComprehension] Current page index: $_currentPageIndex');

    if (widget.question.passages != null &&
        widget.question.passages!.isNotEmpty &&
        _currentPageIndex < widget.question.passages!.length) {
      final passage = widget.question.passages![_currentPageIndex];
      print(
          '[ReadingComprehension] Loading page ${_currentPageIndex + 1}/${widget.question.passages!.length}');
      print('[ReadingComprehension] Dynamic passage data: $passage');

      // Dynamically extract image with multiple field name options
      _currentPassageImage = _extractDynamicImageFromPassage(passage);
      print('[ReadingComprehension] Dynamic pageImage: $_currentPassageImage');

      // Dynamically extract page text with multiple field name options
      final pageText = _extractDynamicTextFromPassage(passage);
      print('[ReadingComprehension] Dynamic page text: $pageText');

      _startTypewriterAnimation(pageText, (text) {
        setState(() {
          _currentPageText = text;
        });
      }, () {
        // After pageText is complete, show continue button
        setState(() {
          _showContinueButton = true;
        });
      });
    } else {
      print(
          '[ReadingComprehension] No more passages available or invalid page index');
      // If no more pages, proceed to sentence questions
      _proceedToSentenceQuestions();
    }
  }

  // Dynamically extract image from passage with multiple field name options
  String? _extractDynamicImageFromPassage(Map<String, dynamic> passage) {
    final possibleImageFields = [
      'pageImage',
      'image',
      'imageUrl',
      'img',
      'picture',
      'photo'
    ];

    for (String field in possibleImageFields) {
      if (passage.containsKey(field) && passage[field] != null) {
        final value = passage[field].toString();
        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    return null;
  }

  // Dynamically extract text from passage with multiple field name options
  String _extractDynamicTextFromPassage(Map<String, dynamic> passage) {
    final possibleTextFields = [
      'pageText',
      'text',
      'content',
      'passageText',
      'story',
      'passage'
    ];

    for (String field in possibleTextFields) {
      if (passage.containsKey(field) && passage[field] != null) {
        final value = passage[field].toString();
        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    return '';
  }

  void _proceedToSentenceQuestion() {
    _playButtonAudio();

    // Check if there are more pages to show
    if (widget.question.passages != null &&
        _currentPageIndex + 1 < widget.question.passages!.length) {
      // Move to next page
      _currentPageIndex++;
      print(
          '[ReadingComprehension] Moving to next page: ${_currentPageIndex + 1}/${widget.question.passages!.length}');

      setState(() {
        _showContinueButton = false;
        _currentPageText = '';
      });

      // Update progress for new page
      _initializeRcProgressFromProvider();

      // Load next page content
      _showPassageContent();
    } else {
      // All pages shown, proceed to sentence questions
      print(
          '[ReadingComprehension] All pages completed, proceeding to sentence questions');
      _proceedToSentenceQuestions();
    }
  }

  void _proceedToSentenceQuestions() {
    setState(() {
      _showPassage = false;
      _showContinueButton = false;
      _showSentenceQuestion = true;
      _currentQuestionText = '';
      _currentPageText = '';
    });

    // Update progress for sentence questions
    _initializeRcProgressFromProvider();

    _showCurrentSentenceQuestion();
  }

  void _showCurrentSentenceQuestion() {
    if (widget.question.sentenceQuestions != null &&
        widget.question.sentenceQuestions!.isNotEmpty &&
        _currentSentenceQuestionIndex <
            widget.question.sentenceQuestions!.length) {
      final sentenceQuestion =
          widget.question.sentenceQuestions![_currentSentenceQuestionIndex];
      print(
          '[ReadingComprehension] Showing dynamic sentence question ${_currentSentenceQuestionIndex + 1}/${widget.question.sentenceQuestions!.length}');
      print(
          '[ReadingComprehension] Dynamic sentence question data: $sentenceQuestion');

      // Dynamically extract question text with multiple field name options
      final questionText = _extractDynamicQuestionTextFromSQ(sentenceQuestion);

      // Dynamically extract correct answer with multiple field name options
      _correctAnswer = _extractDynamicCorrectAnswerFromSQ(sentenceQuestion);

      print(
          '[ReadingComprehension] Dynamic sentence question text: $questionText');
      print('[ReadingComprehension] Dynamic correct answer: $_correctAnswer');

      // Clear previous answer
      _answerController.clear();

      // Start sentence question typewriter animation
      _startTypewriterAnimation(questionText, (text) {
        setState(() {
          _currentSentenceQuestionText = text;
        });
      }, () {
        // After sentence question is complete, show text input
        setState(() {
          _showTextInput = true;
        });
      });
    } else {
      // No more sentence questions, complete this RC question
      print(
          '[ReadingComprehension] No more dynamic sentence questions for ${widget.question.questionId}');
      // Directly decide next step without re-invoking feedback flow
      if (_isLastRCQuestion()) {
        _navigateToResultScreenSafely();
      } else {
        _handleNextRCQuestion();
      }
    }
  }

  // Dynamically extract question text from sentence question with multiple field name options
  String _extractDynamicQuestionTextFromSQ(
      Map<String, dynamic> sentenceQuestion) {
    final possibleTextFields = [
      'questionText',
      'text',
      'question',
      'prompt',
      'ask'
    ];

    for (String field in possibleTextFields) {
      if (sentenceQuestion.containsKey(field) &&
          sentenceQuestion[field] != null) {
        final value = sentenceQuestion[field].toString();
        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    return '';
  }

  // Dynamically extract correct answer from sentence question with multiple field name options
  String? _extractDynamicCorrectAnswerFromSQ(
      Map<String, dynamic> sentenceQuestion) {
    final possibleAnswerFields = [
      'correctAnswer',
      'answer',
      'correct',
      'solution',
      'response'
    ];

    for (String field in possibleAnswerFields) {
      if (sentenceQuestion.containsKey(field) &&
          sentenceQuestion[field] != null) {
        final value = sentenceQuestion[field].toString();
        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    return null;
  }

  void _startTypewriterAnimation(
      String fullText, Function(String) onUpdate, VoidCallback onComplete) {
    _typewriterTimer?.cancel();
    _currentIndex = 0;

    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex < fullText.length) {
        _currentIndex++;
        onUpdate(fullText.substring(0, _currentIndex));
      } else {
        timer.cancel();
        onComplete();
      }
    });
  }

  void _submitAnswer() {
    final userAnswer = _answerController.text.trim();
    if (userAnswer.isNotEmpty) {
      _showFeedbackAndPlaySound(userAnswer);
    }
  }

  void _showFeedbackAndPlaySound(String userAnswer) {
    // Dynamically validate answer with enhanced comparison methods
    bool isCorrect = false;
    if (_correctAnswer != null) {
      isCorrect = _validateAnswerDynamically(userAnswer, _correctAnswer!);
    }

    String description;
    if (isCorrect) {
      description = 'Ito ang tamang sagot!';
    } else {
      description =
          'Hindi ito ang tamang sagot. Ang tamang sagot ay: $_correctAnswer';
    }

    setState(() {
      _showFeedback = true;
      _isCorrectAnswer = isCorrect;
      _feedbackDescription = description;
    });

    if (isCorrect) {
      _confettiControllerLeft.play();
      _confettiControllerRight.play();
      _playCorrectAnswerSound();
    } else {
      _playIncorrectAnswerSound();
    }
  }

  // Strict validation - only accepts exact matches (case-insensitive, whitespace trimmed)
  bool _validateAnswerDynamically(String userAnswer, String correctAnswer) {
    // Clean both answers by trimming whitespace and converting to lowercase
    final userCleaned = userAnswer.trim().toLowerCase();
    final correctCleaned = correctAnswer.trim().toLowerCase();

    // Only accept exact matches - no typos, no partial matches
    return userCleaned == correctCleaned;
  }


  void _proceedAfterFeedback() async {
    print('[ReadingComprehension] ===== _proceedAfterFeedback CALLED =====');
    print(
        '[ReadingComprehension] Current sentence question index: $_currentSentenceQuestionIndex');
    print(
        '[ReadingComprehension] Total sentence questions: ${widget.question.sentenceQuestions?.length ?? 0}');
    print(
        '[ReadingComprehension] Current question ID: ${widget.question.questionId}');
    print('[ReadingComprehension] Is navigating flag: $_isNavigating');

    if (_isNavigating) {
      print('[ReadingComprehension] Already navigating, skipping...');
      return;
    }

    _isNavigating = true;

    setState(() {
      _showFeedback = false;
      _showTextInput = false;
    });

    final userAnswer = _answerController.text.trim();
    print('[ReadingComprehension] User answer: "$userAnswer"');

    // Record answer to AssessmentProvider for proper score tracking
    if (_cachedProvider != null && _correctAnswer != null) {
      final isCorrect = _validateAnswerDynamically(userAnswer, _correctAnswer!);
      final questionKey = widget.question.questionId;

      // Save individual response in new MongoDB format
      await _cachedProvider!.saveIndividualResponse(
        questionId: questionKey,
        category: 'Reading Comprehension',
        questionType: widget.question.questionType ?? 'sentence',
        response: [userAnswer],
        isCorrect: isCorrect,
        responseTime: 0, // Could be tracked if needed
      );

      // Record the reading comprehension response using existing method for compatibility
      _cachedProvider!.recordReadingComprehensionResponse(
        questionKey,
        userAnswer,
        _correctAnswer!,
        isCorrect,
      );

      print(
          '[ReadingComprehension] Recorded answer: $userAnswer, Correct: $_correctAnswer, IsCorrect: $isCorrect');
    }

    widget.onAnswerSubmitted(userAnswer);

    if (_currentSentenceQuestionIndex + 1 <
        (widget.question.sentenceQuestions?.length ?? 0)) {
      _currentSentenceQuestionIndex++;
      print(
          '[ReadingComprehension] Moving to sentence question ${_currentSentenceQuestionIndex + 1}/${widget.question.sentenceQuestions!.length} in ${widget.question.questionId}');

      _isNavigating = false;
      _initializeRcProgressFromProvider();
      _showCurrentSentenceQuestion();
      return;
    }

    print(
        '[ReadingComprehension] No more sentence questions in current RC question, checking if last RC question...');

    if (_isLastRCQuestion()) {
      print(
          '[ReadingComprehension] This is the LAST RC question, navigating to result screen');
      _navigateToResultScreenSafely();
      return;
    }

    _handleNextRCQuestion();
  }

  // Determine if current RC question is the last one
  bool _isLastRCQuestion() {
    try {
      final currentId = widget.question.questionId;

      // Quick check by explicit last id
      if (currentId == 'RC_009') return true;

      // Build RC list from passed list or provider
      List<Question> rcQuestions = [];
      if (widget.rcQuestionsList != null &&
          widget.rcQuestionsList!.isNotEmpty) {
        rcQuestions = List<Question>.from(widget.rcQuestionsList!);
      } else if (_cachedProvider?.assessment?.questions != null) {
        rcQuestions = _cachedProvider!.assessment!.questions
            .where((q) => RegExp(r'^RC_\d{3}$').hasMatch(q.questionId))
            .toList();
        rcQuestions.sort((a, b) {
          final aNum = int.tryParse(a.questionId.substring(3)) ?? 0;
          final bNum = int.tryParse(b.questionId.substring(3)) ?? 0;
          return aNum.compareTo(bNum);
        });
      }

      if (rcQuestions.isEmpty) {
        // Fallback numeric heuristic
        if (currentId.startsWith('RC_')) {
          final numPart = int.tryParse(currentId.substring(3)) ?? 0;
          return numPart >= 9;
        }
        return false;
      }

      return rcQuestions.last.questionId == currentId;
    } catch (_) {
      return false;
    }
  }

  // Safe wrapper to navigate to result after a tiny delay
  void _navigateToResultScreenSafely() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      try {
        _navigateToResultScreen();
      } catch (_) {
        _fallbackNavigateToResult();
      }
    });
  }

  // Decide and navigate to the next RC question or return
  void _handleNextRCQuestion() {
    try {
      final currentId = widget.question.questionId;
      List<Question> rcQuestions = [];
      if (widget.rcQuestionsList != null &&
          widget.rcQuestionsList!.isNotEmpty) {
        rcQuestions = List<Question>.from(widget.rcQuestionsList!);
      } else if (_cachedProvider?.assessment?.questions != null) {
        rcQuestions = _cachedProvider!.assessment!.questions
            .where((q) => RegExp(r'^RC_\d{3}$').hasMatch(q.questionId))
            .toList();
        rcQuestions.sort((a, b) {
          final aNum = int.tryParse(a.questionId.substring(3)) ?? 0;
          final bNum = int.tryParse(b.questionId.substring(3)) ?? 0;
          return aNum.compareTo(bNum);
        });
      }

      final idx = rcQuestions.indexWhere((q) => q.questionId == currentId);
      if (idx >= 0 && idx + 1 < rcQuestions.length) {
        _navigateToNextRCQuestion(rcQuestions[idx + 1], rcQuestions);
      } else {
        _navigateToResultScreenSafely();
      }
    } catch (_) {
      _navigateToResultScreenSafely();
    }
  }

  // Navigate to the next RC question ensuring provider is preserved
  void _navigateToNextRCQuestion(
      Question nextQuestion, List<Question> rcQuestions) {
    try {
      final providerForNext = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (newContext) =>
              ChangeNotifierProvider<AssessmentProvider>.value(
            value: providerForNext,
            child: ReadingComprehensionScreen(
              question: nextQuestion,
              assessmentType: widget.assessmentType,
              onComplete: widget.onComplete,
              onAnswerSubmitted: widget.onAnswerSubmitted,
              handleAllRcQuestions: widget.handleAllRcQuestions,
              rcQuestionsList: rcQuestions,
            ),
          ),
        ),
      );
    } catch (_) {
      _navigateToResultScreenSafely();
    }
  }

  // Safely get provider (cached, then context)
  AssessmentProvider? _getProviderSafely() {
    if (_cachedProvider != null) return _cachedProvider;
    try {
      return Provider.of<AssessmentProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  // Fallback when provider-based navigation fails
  void _fallbackNavigateToResult() {
    try {
      widget.onComplete();
    } catch (_) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (_) {}
    }
  }

  void _navigateToResultScreen() {
    print('[ReadingComprehension] ===== _navigateToResultScreen CALLED =====');

    // Use enhanced safe provider getter
    AssessmentProvider? provider = _getProviderSafely();
    if (provider == null) {
      print('[ReadingComprehension] No provider found, using fallback');
      _fallbackNavigateToResult();
      return;
    }

    try {
      // Calculate assessment results
      int totalQuestions = provider.assessment?.questions.length ?? 0;
      int score = provider.score;
      String readingLevel = provider.readingLevel ?? 'Developing';
      double? readingPercentage = provider.readingPercentage;

      print('[ReadingComprehension] Provider status:');
      print(
          '[ReadingComprehension]   - Assessment loaded: ${provider.assessment != null}');
      print('[ReadingComprehension]   - Total questions: $totalQuestions');
      print('[ReadingComprehension]   - Current score: $score');
      print('[ReadingComprehension]   - Reading level: $readingLevel');
      print(
          '[ReadingComprehension]   - Reading percentage: $readingPercentage');
      print(
          '[ReadingComprehension]   - Assessment type: ${widget.assessmentType}');

      print(
          '[ReadingComprehension] Creating PreAssessmentResultScreen with Provider context...');
      print(
          '[ReadingComprehension] About to call Navigator.pushReplacement...');

      // Navigate with preserved Provider context
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (newContext) => ChangeNotifierProvider.value(
            value: provider,
            child: PreAssessmentResultScreen(
              readingLevel: readingLevel,
              score: score,
              totalQuestions: totalQuestions,
              readingPercentage: readingPercentage,
              assessmentType: widget.assessmentType,
              assessmentId: provider.assessment?.assessmentId?.toString() ??
                  'PRE_ASSESSMENT_001',
            ),
          ),
        ),
      );
      print(
          '[ReadingComprehension] Navigator.pushReplacement with Provider context called successfully');
      print(
          '[ReadingComprehension] Navigation should have completed - user should see result screen now');

      // Add a timeout to ensure navigation completes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          print(
              '[ReadingComprehension] Navigation timeout check - if still on same screen, something went wrong');
        }
      });
    } catch (e) {
      print('[ReadingComprehension] Error navigating to result screen: $e');
      print('[ReadingComprehension] Error stack trace: ${StackTrace.current}');
      // Fallback to original onComplete
      widget.onComplete();
    }
  }

  // Audio methods
  void _startBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.setAsset('assets/audio/homeBg.mp3');
      await _backgroundMusicPlayer.setVolume(0.3);
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);
      await _backgroundMusicPlayer.play();
      print('[ReadingComprehension] Background music started');
    } catch (e) {
      print('[ReadingComprehension] Background music error: $e');
    }
  }

  void _playButtonAudio() async {
    try {
      await _buttonAudioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _buttonAudioPlayer.play();
      print('[ReadingComprehension] Button audio played');
    } catch (e) {
      print('[ReadingComprehension] Button audio error: $e');
    }
  }

  void _playCorrectAnswerSound() async {
    try {
      await _correctAnswerPlayer.setAsset('assets/audio/assessmentsound.mp3');
      await _correctAnswerPlayer.play();
      print('[ReadingComprehension] Correct answer sound played');
    } catch (e) {
      print('[ReadingComprehension] Correct answer sound error: $e');
    }
  }

  void _playIncorrectAnswerSound() async {
    try {
      await _incorrectAnswerPlayer.setAsset('assets/audio/incorrectanswer.mp3');
      await _incorrectAnswerPlayer.play();
      print('[ReadingComprehension] Incorrect answer sound played');
    } catch (e) {
      print('[ReadingComprehension] Incorrect answer sound error: $e');
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _answerController.dispose();
    _backgroundMusicPlayer.dispose();
    _buttonAudioPlayer.dispose();
    _correctAnswerPlayer.dispose();
    _incorrectAnswerPlayer.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2B4E),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  children: [
                    // Progress bar (copied design from WordRecognitionScreen)
                    _buildProgressIndicator(context),
                    const SizedBox(height: 40),

                    // Main content area
                    _showFeedback
                        ? _buildFeedbackContent()
                        : (_showSentenceQuestion
                            ? _buildSentenceQuestionView()
                            : _buildPassageView()),
                  ],
                ),
              ),
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

  // Progress indicator design matching DecodingScreen style
  Widget _buildProgressIndicator(BuildContext context) {
    // DYNAMIC: Calculate progress based on assessment type
    int totalSteps;
    int currentPosition = 1;

    final isPreAssessment = widget.assessmentType == 'pre_assessment';

    if (isPreAssessment) {
      // Pre-assessment: Use actual count of RC questions or default to 1
      totalSteps = _rcQuestions.isNotEmpty ? _rcQuestions.length : 1;

      // Find current position in the list
      final currentIndex = _rcQuestions
          .indexWhere((q) => q.questionId == widget.question.questionId);
      currentPosition = currentIndex >= 0 ? currentIndex + 1 : 1;
    } else {
      // Main assessment: Use actual count of RC questions loaded
      totalSteps = _rcQuestions.isNotEmpty ? _rcQuestions.length : 10;

      // Extract current position from questionId (e.g., RC_003 -> position 3)
      try {
        final currentId = widget.question.questionId;
        print(
            '[ReadingComprehension] Progress Debug - Raw question ID: $currentId');

        if (currentId.startsWith('RC_')) {
          final numberPart = currentId.substring(3); // Remove "RC_" prefix
          print(
              '[ReadingComprehension] Progress Debug - Number part: $numberPart');
          currentPosition = int.tryParse(numberPart) ?? 1;
          print(
              '[ReadingComprehension] Progress Debug - Parsed position: $currentPosition');

          // Ensure currentPosition is within valid range
          if (currentPosition < 1) currentPosition = 1;
          if (currentPosition > totalSteps) currentPosition = totalSteps;

          print(
              '[ReadingComprehension] Progress Debug - Final position: $currentPosition');
        } else {
          print(
              '[ReadingComprehension] Progress Debug - Question ID does not start with RC_');
          // Fallback: try to find position in RC questions list
          final currentIndex = _rcQuestions
              .indexWhere((q) => q.questionId == widget.question.questionId);
          currentPosition = currentIndex >= 0 ? currentIndex + 1 : 1;
        }
      } catch (e) {
        print(
            '[ReadingComprehension] Error parsing question ID for progress: $e');
        print('[ReadingComprehension] Stack trace: ${StackTrace.current}');
        currentPosition = 1;
      }
    }

    // Debug logging
    print(
        '[ReadingComprehension] Progress Debug - Current RC: ${widget.question.questionId}');
    print(
        '[ReadingComprehension] Progress Debug - Extracted position: $currentPosition from questionId');
    print(
        '[ReadingComprehension] Progress Debug - Total steps: $totalSteps, Current position: $currentPosition');
    print(
        '[ReadingComprehension] Progress Debug - Progress display: $currentPosition/$totalSteps');

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = totalSteps == 0 ? 0.0 : currentPosition / totalSteps;
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: currentPosition / totalSteps,
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
                  '$currentPosition/$totalSteps',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Century Gothic',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Question text with typewriter animation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(0),
          child: Text(
            _currentQuestionText,
            style: const TextStyle(
              color: const Color(0xFFFDE37C),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Century Gothic',
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 20),

        if (_showPassage) ...[
          // Image from MongoDB
          if (_currentPassageImage != null && _currentPassageImage!.isNotEmpty)
            Container(
              width: 200,
              height: 200,
              margin: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _currentPassageImage!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentAmber,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppTheme.accentAmber,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Page text with typewriter animation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: Text(
              _currentPageText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Century Gothic',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 50),

        // Continue button with DecodingScreen design
        if (_showContinueButton)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 40),
            child: SizedBox(
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(197, 27, 172, 37),
                      offset:
                          const Offset(0, 4), // Horizontal & vertical offset
                      blurRadius: 0, // Softness of the shadow
                      spreadRadius: 0, // Size expansion
                    ),
                  ],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: _proceedToSentenceQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1BAC24), // Green when enabled
                    disabledBackgroundColor:
                        const Color(0xFFD9D9D9).withOpacity(0.5),
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'MAG PATULOY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Century Gothic',
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSentenceQuestionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show the passage image above the question when answering
        if (_currentPassageImage != null && _currentPassageImage!.isNotEmpty)
          Container(
            width: 200,
            height: 200,
            margin: const EdgeInsets.only(bottom: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _currentPassageImage!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentAmber,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: AppTheme.accentAmber,
                      size: 50,
                    ),
                  );
                },
              ),
            ),
          ),

        // Main question text (like "Tukuyin ang angkop na sagot")
        if (widget.question.questionText != null &&
            widget.question.questionText!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.question.questionText!,
              style: const TextStyle(
                color: AppTheme.accentAmber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Century Gothic',
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 40),

        // Sentence question text with typewriter animation (actual question from MongoDB)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Text(
            _currentSentenceQuestionText,
            style: const TextStyle(
              color: const Color(0xFFFDE37C),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Century Gothic',
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 60),

        if (_showTextInput) ...[
          // Answer input box with DecodingScreen style
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD966), width: 2),
            ),
            child: TextField(
              controller: _answerController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Century Gothic',
              ),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              enableSuggestions: false,
              autocorrect: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              inputFormatters: [
                // Allow only letters (A-Z, a-z) and spaces
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                // Explicitly deny numbers and common symbols as an extra guard
                FilteringTextInputFormatter.deny(
                  RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]'),
                ),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Type your answer here...',
                hintStyle: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Century Gothic',
                ),
                contentPadding: EdgeInsets.all(15),
              ),
              onSubmitted: (_) => _submitAnswer(),
            ),
          ),

          const SizedBox(height: 20),

          const SizedBox(height: 40),

          // Submit button with DecodingScreen design
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: _isSubmitEnabled
                        ? const Color.fromARGB(197, 27, 172, 37)
                        : const Color.fromARGB(197, 117, 117, 117),
                    offset: const Offset(0, 4), // Horizontal & vertical offset
                    blurRadius: 0, // Softness of the shadow
                    spreadRadius: 0, // Size expansion
                  ),
                ],
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: _isSubmitEnabled ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitEnabled
                      ? const Color(0xFF1BAC24) // Green when enabled
                      : Colors.grey.shade600,
                  disabledBackgroundColor: Colors.grey.shade600,
                  foregroundColor:
                      _isSubmitEnabled ? Colors.white : Colors.grey.shade800,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'TIGNAN ANG SAGOT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Century Gothic',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackContent() {
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Century Gothic',
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
                      child: Text(
                        _answerController.text.trim(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isCorrectAnswer
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontFamily: 'Century Gothic',
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
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontFamily: 'Century Gothic',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: _isCorrectAnswer
                            ? const Color.fromARGB(197, 27, 172, 37)
                            : const Color.fromARGB(197, 244, 67, 54),
                        offset:
                            const Offset(0, 4), // Horizontal & vertical offset
                        blurRadius: 0, // Softness of the shadow
                        spreadRadius: 0, // Size expansion
                      ),
                    ],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _playButtonAudio();
                      _proceedAfterFeedback();
                    },
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
                    child: const Text(
                      'MAG PATULOY',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Century Gothic',
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
}
