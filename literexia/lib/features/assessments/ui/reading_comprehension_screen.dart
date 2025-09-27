import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:literexia/core/theme/app_theme.dart';
import 'package:just_audio/just_audio.dart';
import 'package:literexia/services/background_music_service.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_result_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:literexia/screens/home_screen.dart';
import '../../../utils/category_results_helper.dart';

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
  final AudioPlayer _buttonAudioPlayer = AudioPlayer();
  final AudioPlayer _correctAnswerPlayer = AudioPlayer();
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer();
  final AudioPlayer _congratsSoundPlayer = AudioPlayer();

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

  // Track Reading Comprehension responses to group them by questionId
  Map<String, Map<String, dynamic>> _readingComprehensionResponses = {};

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
    // Call async method without await
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
  Future<void> _initializeRcProgressFromProvider() async {
    try {
      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final allQuestions = provider.assessment?.questions ?? [];

      // CRITICAL: Validate assessment type matches expected type
      final providerAssessmentType = provider.assessment?.type ?? 'unknown';
      final isProviderPreAssessment = provider.isPreAssessment;
      final expectedIsPreAssessment = widget.assessmentType == 'pre_assessment';
      final isInterventionAssessment =
          widget.assessmentType == 'intervention_assessment';

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
          '[ReadingComprehension]   - Is Intervention Assessment: $isInterventionAssessment');
      print(
          '[ReadingComprehension]   - Assessment ID: ${provider.assessment?.assessmentId}');

      // Handle intervention assessment
      if (isInterventionAssessment) {
        print('[ReadingComprehension] 🔄 Loading INTERVENTION assessment...');
        await _loadInterventionAssessment();
        return;
      }

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
      await _initializeRcProgressFromProvider();
    } catch (e) {
      print(
          '[ReadingComprehension] ❌ Failed to force load main assessment: $e');
      // Continue with existing data as fallback
      _initializeRcProgressFromProviderFallback();
    }
  }

  // Load intervention assessment for Reading Comprehension
  Future<void> _loadInterventionAssessment() async {
    try {
      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);

      // Get authentication provider for user details
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      final readingLevel = authProvider.currentUser?.readingLevel ?? '';

      print('[ReadingComprehension] Loading intervention assessment...');
      print('[ReadingComprehension] User ID: $userId');
      print('[ReadingComprehension] Reading Level: $readingLevel');

      // Load intervention assessment data
      await provider.loadInterventionAssessmentDirect(
        'Reading Comprehension',
        readingLevel,
        userId: userId,
      );

      print(
          '[ReadingComprehension] Intervention assessment loaded successfully');

      // Retry initialization after loading
      await _initializeRcProgressFromProvider();
    } catch (e) {
      print(
          '[ReadingComprehension] ❌ Failed to load intervention assessment: $e');
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
      print('[ReadingComprehension] ===== ANSWER VALIDATION =====');
      print('[ReadingComprehension] User Answer: "$userAnswer"');
      print('[ReadingComprehension] Correct Answer: "$_correctAnswer"');
      print('[ReadingComprehension] Assessment Type: ${widget.assessmentType}');

      isCorrect = _validateAnswerDynamically(userAnswer, _correctAnswer!);

      print('[ReadingComprehension] Validation Result: $isCorrect');
      print('[ReadingComprehension] ===== END ANSWER VALIDATION =====');
    } else {
      print(
          '[ReadingComprehension] ❌ Cannot validate answer - correct answer is null');
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

    // Save intervention response if this is an intervention assessment
    if (widget.assessmentType == 'intervention_assessment') {
      _saveInterventionResponse(userAnswer, isCorrect);
    }

    if (isCorrect) {
      _confettiControllerLeft.play();
      _confettiControllerRight.play();
      _playCorrectAnswerSound();
    } else {
      _playIncorrectAnswerSound();
    }
  }

  // Dynamically validate answer with multiple comparison strategies
  bool _validateAnswerDynamically(String userAnswer, String correctAnswer) {
    // Clean both answers
    final userLower = userAnswer.toLowerCase().trim();
    final correctLower = correctAnswer.toLowerCase().trim();

    // Exact match
    if (userLower == correctLower) {
      return true;
    }

    // Contains match (both directions)
    if (correctLower.contains(userLower) || userLower.contains(correctLower)) {
      return true;
    }

    // Remove common prefixes/suffixes for better matching
    final userClean = _cleanAnswerForComparison(userLower);
    final correctClean = _cleanAnswerForComparison(correctLower);

    if (userClean == correctClean) {
      return true;
    }

    // Levenshtein distance for typos (allow 1-2 character differences)
    if (_calculateLevenshteinDistance(userLower, correctLower) <= 2) {
      return true;
    }

    return false;
  }

  // Clean answer by removing common prefixes/suffixes
  String _cleanAnswerForComparison(String answer) {
    String cleaned = answer;

    // Remove common prefixes
    final prefixes = ['si ', 'ang ', 'sa ', 'ni ', 'kay '];
    for (String prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }

    // Remove common punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[.,!?;:]'), '');

    return cleaned.trim();
  }

  // Calculate Levenshtein distance for fuzzy matching
  int _calculateLevenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) {
      return _calculateLevenshteinDistance(s2, s1);
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    List<int> previousRow = List.generate(s2.length + 1, (i) => i);

    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];

      for (int j = 0; j < s2.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (s1[i] != s2[j] ? 1 : 0);

        currentRow.add([insertions, deletions, substitutions]
            .reduce((a, b) => a < b ? a : b));
      }

      previousRow = currentRow;
    }

    return previousRow.last;
  }

  // NEW: Update database record with final grouped response when question is completed
  // ONLY applies to Reading Comprehension in main assessments
  Future<void> _updateReadingComprehensionDatabaseRecord(
      String questionId) async {
    try {
      // CRITICAL: Only apply grouping logic for Reading Comprehension in main assessments
      if (widget.assessmentType != 'main_assessment') {
        print(
            '[ReadingComprehension] Not main assessment - skipping database update');
        return;
      }

      if (!_readingComprehensionResponses.containsKey(questionId)) {
        print(
            '[ReadingComprehension] No tracked responses found for $questionId');
        return;
      }

      final responseData = _readingComprehensionResponses[questionId]!;
      final responses = List<String>.from(responseData['responses']);
      final isCorrect = responseData['isCorrect'] as bool;
      final categoryId = responseData['categoryId'];
      final readingLevel = responseData['readingLevel'] as String;

      print(
          '[ReadingComprehension] ===== UPDATING DATABASE RECORD FOR $questionId =====');
      print(
          '[ReadingComprehension] Assessment Type: ${widget.assessmentType} (Main Assessment Grouping)');
      print('[ReadingComprehension] Final responses: $responses');
      print('[ReadingComprehension] Final isCorrect: $isCorrect');

      // Save the final grouped response to database (creates new record with all responses)
      await _cachedProvider!.saveIndividualResponse(
        questionId: questionId,
        category: 'Reading Comprehension',
        questionType: 'text_input',
        response: responses,
        isCorrect: isCorrect,
        responseTime: 0,
        categoryId: categoryId,
        readingLevel: readingLevel,
      );

      print(
          '[ReadingComprehension] Successfully updated database record for $questionId');
      print('[ReadingComprehension] ===== END UPDATING DATABASE RECORD =====');
    } catch (e) {
      print(
          '[ReadingComprehension] Error updating database record for $questionId: $e');
    }
  }

  // NEW: Save grouped Reading Comprehension responses to avoid multiple records per questionId
  // ONLY applies to Reading Comprehension in main assessments
  Future<void> _saveGroupedReadingComprehensionResponse({
    required String questionKey,
    required String userAnswer,
    required bool isCorrect,
    required dynamic categoryId,
    required String userReadingLevel,
  }) async {
    try {
      print(
          '[ReadingComprehension] ===== SAVING GROUPED READING COMPREHENSION RESPONSE =====');

      // CRITICAL: Only apply grouping logic for Reading Comprehension in main assessments
      if (widget.assessmentType != 'main_assessment') {
        print(
            '[ReadingComprehension] Not main assessment - using individual response saving');
        await _cachedProvider!.saveIndividualResponse(
          questionId: questionKey,
          category: 'Reading Comprehension',
          questionType: 'text_input',
          response: [userAnswer],
          isCorrect: isCorrect,
          responseTime: 0,
          categoryId: categoryId,
          readingLevel: userReadingLevel,
        );
        return;
      }

      // Format questionId to match database structure (RC_001, RC_002, etc.)
      String formattedQuestionId = questionKey;
      if (questionKey.startsWith('RC_')) {
        // Extract number and format with leading zeros
        final numberPart = questionKey.substring(3);
        final number = int.tryParse(numberPart) ?? 1;
        formattedQuestionId = 'RC_${number.toString().padLeft(3, '0')}';
      }

      print('[ReadingComprehension] Original Question ID: $questionKey');
      print(
          '[ReadingComprehension] Formatted Question ID: $formattedQuestionId');
      print('[ReadingComprehension] User Answer: "$userAnswer"');
      print('[ReadingComprehension] Is Correct: $isCorrect');
      print(
          '[ReadingComprehension] Assessment Type: ${widget.assessmentType} (Main Assessment Grouping Enabled)');

      // Always track responses locally - don't save to database until question is completed
      if (!_readingComprehensionResponses.containsKey(formattedQuestionId)) {
        // First response for this questionId - track locally only
        _readingComprehensionResponses[formattedQuestionId] = {
          'responses': [userAnswer],
          'isCorrect': isCorrect,
          'categoryId': categoryId,
          'readingLevel': userReadingLevel,
        };

        print(
            '[ReadingComprehension] Started tracking response for $formattedQuestionId');
        print('[ReadingComprehension] Response: $userAnswer');
      } else {
        // Update existing response - add to response array and update correctness
        final existingData =
            _readingComprehensionResponses[formattedQuestionId]!;
        final currentResponses = List<String>.from(existingData['responses']);
        currentResponses.add(userAnswer);

        // Update correctness - if any answer is wrong, mark as incorrect
        bool overallCorrect = existingData['isCorrect'] && isCorrect;

        // Update local tracking
        _readingComprehensionResponses[formattedQuestionId] = {
          'responses': currentResponses,
          'isCorrect': overallCorrect,
          'categoryId': categoryId,
          'readingLevel': userReadingLevel,
        };

        print(
            '[ReadingComprehension] Updated tracking for $formattedQuestionId');
        print(
            '[ReadingComprehension] Total responses: ${currentResponses.length}');
        print('[ReadingComprehension] Overall isCorrect: $overallCorrect');
        print('[ReadingComprehension] Response array: $currentResponses');
      }

      print(
          '[ReadingComprehension] ===== END SAVING GROUPED READING COMPREHENSION RESPONSE =====');
    } catch (e) {
      print('[ReadingComprehension] Error saving grouped response: $e');
      // Fallback to individual response if grouping fails
      await _cachedProvider!.saveIndividualResponse(
        questionId: questionKey,
        category: 'Reading Comprehension',
        questionType: 'text_input',
        response: [userAnswer],
        isCorrect: isCorrect,
        responseTime: 0,
        categoryId: categoryId,
        readingLevel: userReadingLevel,
      );
    }
  }

  // Save intervention response for Reading Comprehension
  Future<void> _saveInterventionResponse(
      String userAnswer, bool isCorrect) async {
    try {
      print('[ReadingComprehension] ===== SAVING INTERVENTION RESPONSE =====');

      final provider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);

      // Get authentication provider for user details
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      final readingLevel = authProvider.currentUser?.readingLevel ?? '';

      // Get current question details
      final currentQuestion = widget.question;
      final sentenceQuestions = currentQuestion.sentenceQuestions ?? [];

      String questionId = currentQuestion.questionId;
      if (sentenceQuestions.isNotEmpty &&
          _currentSentenceQuestionIndex < sentenceQuestions.length) {
        // Use the specific sentence question ID if available
        questionId =
            '${currentQuestion.questionId}_${_currentSentenceQuestionIndex + 1}';
      }

      print('[ReadingComprehension] Question ID: $questionId');
      print('[ReadingComprehension] Category: Reading Comprehension');
      print('[ReadingComprehension] User Answer: $userAnswer');
      print('[ReadingComprehension] Is Correct: $isCorrect');
      print(
          '[ReadingComprehension] ===== END SAVING INTERVENTION RESPONSE =====');

      // Save intervention response using the new method
      await provider.saveInterventionResponse(
        studentId: userId,
        interventionAssessmentId: provider.assessment?.assessmentId ?? '',
        questionId: questionId,
        category: 'Reading Comprehension',
        response: [userAnswer], // Reading comprehension responses are arrays
        isCorrect: isCorrect,
        responseTime: 0,
        readingLevel: readingLevel,
      );

      print('[ReadingComprehension] Successfully saved intervention response');
    } catch (e) {
      print('[ReadingComprehension] Error saving intervention response: $e');
    }
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

      print('[ReadingComprehension] ===== RECORDING ANSWER =====');
      print('[ReadingComprehension] Question ID: $questionKey');
      print('[ReadingComprehension] User Answer: "$userAnswer"');
      print('[ReadingComprehension] Correct Answer: "$_correctAnswer"');
      print('[ReadingComprehension] Is Correct: $isCorrect');
      print('[ReadingComprehension] Assessment Type: ${widget.assessmentType}');
      print(
          '[ReadingComprehension] Current Score Before Recording: ${_cachedProvider!.score}');

      // Get the assessment's ObjectId for categoryId and user's reading level
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final userReadingLevel = currentUser?.readingLevel ?? 'Low Emerging';

      // Get the assessment's ObjectId from the loaded assessment data
      final categoryId = _cachedProvider!.getAssessmentObjectId();

      // FIXED: Group responses by main questionId instead of creating separate records
      // For Reading Comprehension, we need to accumulate responses for the same questionId
      await _saveGroupedReadingComprehensionResponse(
        questionKey: questionKey,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        categoryId: categoryId,
        userReadingLevel: userReadingLevel,
      );

      // Record the reading comprehension response using existing method for compatibility
      _cachedProvider!.recordReadingComprehensionResponse(
        questionKey,
        userAnswer,
        _correctAnswer!,
        isCorrect,
      );

      print('[ReadingComprehension] Answer recorded successfully');
      print(
          '[ReadingComprehension] Current Score After Recording: ${_cachedProvider!.score}');
      print(
          '[ReadingComprehension] Total Responses Count: ${_cachedProvider!.responses.length}');
      print('[ReadingComprehension] ===== END RECORDING ANSWER =====');
    } else {
      print(
          '[ReadingComprehension] ❌ Cannot record answer - Provider: ${_cachedProvider != null}, Correct Answer: $_correctAnswer');
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

    // Pre-assessment logic
    print('[ReadingComprehension] ===== PROGRESSION =====');
    print('[ReadingComprehension] Using existing logic');
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
      if (currentId == 'RC_10') return true;

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
          return numPart >= 10;
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

  // ===== NEW METHODS FOR MAIN ASSESSMENT READING COMPREHENSION =====

  // Main assessment specific scoring method for Reading Comprehension
  void _scoreMainAssessmentReadingComprehension() {
    try {
      print(
          '[ReadingComprehension] ===== SCORING MAIN ASSESSMENT READING COMPREHENSION =====');

      final assessmentProvider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      print(
          '[ReadingComprehension] Starting to score question: ${currentQuestion?.questionId}');
      print(
          '[ReadingComprehension] Current total score before this question: ${assessmentProvider.score}');

      // For Reading Comprehension main assessment, we need to calculate the total score
      // by checking all questions and only counting those that are completely correct
      int totalCorrectQuestions = 0;
      if (assessmentProvider.assessment != null) {
        print(
            '[ReadingComprehension] Calculating total correct questions for Reading Comprehension...');
        for (int i = 0;
            i < assessmentProvider.assessment!.questions.length;
            i++) {
          final question = assessmentProvider.assessment!.questions[i];
          if (question.sentenceQuestions != null) {
            final sentenceQuestions = question.sentenceQuestions!;
            print(
                '[ReadingComprehension] Checking question ${question.questionId} with ${sentenceQuestions.length} sentence questions');

            // Check if all sentence questions for this questionId are correct
            int correctAnswers = 0;
            int totalAnswers = sentenceQuestions.length;

            // Count all correct responses for this questionId
            for (var response in assessmentProvider.responses) {
              if (response['questionId'] == question.questionId &&
                  response['category'] == 'Reading Comprehension') {
                final isCorrect = response['isCorrect'] as bool;
                final userAnswer = response['userAnswer'] as String? ?? '';
                if (isCorrect) {
                  correctAnswers++;
                  print(
                      '[ReadingComprehension] ✅ Found correct response for ${question.questionId}: "$userAnswer"');
                } else {
                  print(
                      '[ReadingComprehension] ❌ Found incorrect response for ${question.questionId}: "$userAnswer"');
                }
              }
            }

            print(
                '[ReadingComprehension] Question ${question.questionId}: $correctAnswers correct out of $totalAnswers total sentence questions');

            // All-or-nothing scoring: only count if ALL sentence questions are correct
            if (correctAnswers == totalAnswers && totalAnswers > 0) {
              totalCorrectQuestions++;
              print(
                  '[ReadingComprehension] ✅ Question ${question.questionId}: All correct - counted');
            } else {
              print(
                  '[ReadingComprehension] ❌ Question ${question.questionId}: Not all correct - not counted');
            }
          }
        }

        print(
            '[ReadingComprehension] Total correct questions: $totalCorrectQuestions out of 10');
      }

      // Main assessment scoring is now handled in the _showFinalScoreDialog method
      // This ensures consistent scoring logic throughout the assessment
      if (currentQuestion == null) {
        print(
            '[ReadingComprehension] No current question available for scoring');
      }

      // Only proceed with main assessment scoring logic
      if (widget.assessmentType != 'main_assessment') {
        print(
            '[ReadingComprehension] Not main assessment - skipping scoring logic');
        return;
      }
    } catch (e) {
      print(
          '[ReadingComprehension] Error scoring main assessment reading comprehension: $e');
    }
  }

  // Main assessment specific progression method for Reading Comprehension
  void _proceedMainAssessmentReadingComprehension() async {
    try {
      print(
          '[ReadingComprehension] ===== PROCEEDING MAIN ASSESSMENT READING COMPREHENSION =====');

      // Check if there are more sentence questions in current question
      final assessmentProvider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      if (currentQuestion != null) {
        // Check if there are more sentence questions in the current question
        if (_currentSentenceQuestionIndex + 1 <
            (currentQuestion.sentenceQuestions?.length ?? 0)) {
          print(
              '[ReadingComprehension] More sentence questions in current question, proceeding to next sentence question');
          _proceedMainAssessmentAfterFeedback();
          return;
        }

        // No more sentence questions, score the current question and move to next question
        _scoreMainAssessmentReadingComprehension();

        final currentId = currentQuestion.questionId;
        print('[ReadingComprehension] Current question ID: $currentId');

        // Format questionId to match database structure (RC_001, RC_002, etc.)
        String formattedQuestionId = currentId;
        if (currentId.startsWith('RC_')) {
          // Extract number and format with leading zeros
          final numberPart = currentId.substring(3);
          final number = int.tryParse(numberPart) ?? 1;
          formattedQuestionId = 'RC_${number.toString().padLeft(3, '0')}';
        }
        print(
            '[ReadingComprehension] Formatted question ID for database: $formattedQuestionId');

        // Update database record with final grouped response for current question
        await _updateReadingComprehensionDatabaseRecord(formattedQuestionId);

        // Check if this is the last RC question (RC_10)
        if (currentId == 'RC_10') {
          print(
              '[ReadingComprehension] RC_10 completed - showing final score and navigating to home');
          print('[ReadingComprehension] Widget mounted: $mounted');
          print('[ReadingComprehension] Context valid: ${context.mounted}');

          // Final score summary
          print(
              '[ReadingComprehension] ===== FINAL MAIN ASSESSMENT SUMMARY =====');
          print(
              '[ReadingComprehension] 🏁 All Reading Comprehension questions completed!');
          print(
              '[ReadingComprehension] 📊 Final Score: ${assessmentProvider.score}');
          print(
              '[ReadingComprehension] 📝 Total Responses: ${assessmentProvider.responses.length}');
          print(
              '[ReadingComprehension] ===== END FINAL MAIN ASSESSMENT SUMMARY =====');

          // Mark assessment as completed
          assessmentProvider.markAssessmentCompleted();

          // Show final score dialog after a short delay to ensure the assessment is completed
          Future.delayed(const Duration(milliseconds: 500), () {
            print(
                '[ReadingComprehension] Delayed dialog check - mounted: $mounted');
            if (mounted) {
              print('[ReadingComprehension] Calling _showFinalScoreDialog()');
              _showFinalScoreDialog();
            } else {
              print(
                  '[ReadingComprehension] Widget not mounted, cannot show dialog');
            }
          });
        } else {
          // Move to next RC question
          print('[ReadingComprehension] Moving to next RC question');
          assessmentProvider.moveToNextQuestion();

          // Load next question data without reloading entire assessment
          _loadNextMainAssessmentQuestion();
        }
      }
    } catch (e) {
      print(
          '[ReadingComprehension] Error proceeding main assessment reading comprehension: $e');
    }
  }

  // Load next question data for main assessment (without reloading entire assessment)
  void _loadNextMainAssessmentQuestion() {
    try {
      print(
          '[ReadingComprehension] ===== LOADING NEXT MAIN ASSESSMENT QUESTION =====');

      final assessmentProvider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;

      if (currentQuestion != null) {
        print(
            '[ReadingComprehension] Next Question: ${currentQuestion.questionId}');
        print(
            '[ReadingComprehension] Question Text: ${currentQuestion.questionText}');

        // Update UI state with new question data
        setState(() {
          _currentPageIndex = 0;
          _currentSentenceQuestionIndex = 0;
          _showPassage = false;
          _showContinueButton = false;
          _showSentenceQuestion = false;
          _showTextInput = false;
          _currentQuestionText = '';
          _currentPageText = '';
          _currentSentenceQuestionText = '';
          _currentPassageImage = null;
          _correctAnswer = null;
          _showFeedback = false;
          _isCorrectAnswer = false;
          _feedbackDescription = '';
          _isSubmitEnabled = false;
        });

        print(
            '[ReadingComprehension] ===== MAIN ASSESSMENT LOADED DATA DEBUG =====');
        print(
            '[ReadingComprehension] Passages: ${currentQuestion.passages?.length ?? 0}');
        print(
            '[ReadingComprehension] Sentence Questions: ${currentQuestion.sentenceQuestions?.length ?? 0}');
        print(
            '[ReadingComprehension] ===== END MAIN ASSESSMENT LOADED DATA DEBUG =====');

        // Initialize the new question using the current question from provider
        _initializeMainAssessmentQuestion(currentQuestion);
      } else {
        print('[ReadingComprehension] No current question available');
      }
    } catch (e) {
      print(
          '[ReadingComprehension] Error loading next main assessment question: $e');
    }
  }

  // Initialize main assessment question using provider's current question
  void _initializeMainAssessmentQuestion(Question question) {
    print(
        '[ReadingComprehension] ===== INITIALIZING MAIN ASSESSMENT QUESTION =====');
    print('[ReadingComprehension] Question ID: ${question.questionId}');
    print('[ReadingComprehension] Question Data: ${question.toMap()}');

    // Reset to always start from passages first
    _currentPageIndex = 0;
    _currentSentenceQuestionIndex = 0;

    // Debug question data
    try {
      print(
          '[ReadingComprehension] ===== MAIN ASSESSMENT QUESTION DEBUG =====');
      print('[ReadingComprehension] questionId: ${question.questionId}');
      print('[ReadingComprehension] questionText: ${question.questionText}');
      print(
          '[ReadingComprehension] passages length: ${question.passages?.length ?? 0}');
      print(
          '[ReadingComprehension] sentenceQuestions length: ${question.sentenceQuestions?.length ?? 0}');

      // Debug passage structure
      if (question.passages != null) {
        for (int i = 0; i < question.passages!.length; i++) {
          final passage = question.passages![i];
          print('[ReadingComprehension] Passage $i: $passage');
        }
      }

      // Debug sentence questions structure
      if (question.sentenceQuestions != null) {
        for (int i = 0; i < question.sentenceQuestions!.length; i++) {
          final sq = question.sentenceQuestions![i];
          print('[ReadingComprehension] SentenceQuestion $i: $sq');
        }
      }

      print(
          '[ReadingComprehension] ===== END MAIN ASSESSMENT QUESTION DEBUG =====');
    } catch (e) {
      print(
          '[ReadingComprehension] Error in main assessment question debug: $e');
    }

    // Extract question text with multiple field options
    final questionText = _extractDynamicQuestionText(question);
    print(
        '[ReadingComprehension] Main assessment question text: $questionText');

    _startTypewriterAnimation(questionText, (text) {
      setState(() {
        _currentQuestionText = text;
      });
    }, () {
      // After question text is complete, show passage
      setState(() {
        _showPassage = true;
      });
      _showMainAssessmentPassageContent(question);
    });
  }

  // Show passage content for main assessment using provider's question
  void _showMainAssessmentPassageContent(Question question) {
    print('[ReadingComprehension] Loading main assessment passage content...');
    print('[ReadingComprehension] Current page index: $_currentPageIndex');

    if (question.passages != null &&
        question.passages!.isNotEmpty &&
        _currentPageIndex < question.passages!.length) {
      final passage = question.passages![_currentPageIndex];
      print(
          '[ReadingComprehension] Loading page ${_currentPageIndex + 1}/${question.passages!.length}');
      print('[ReadingComprehension] Main assessment passage data: $passage');

      // Dynamically extract image with multiple field name options
      _currentPassageImage = _extractDynamicImageFromPassage(passage);
      print(
          '[ReadingComprehension] Main assessment pageImage: $_currentPassageImage');

      // Dynamically extract page text with multiple field name options
      final pageText = _extractDynamicTextFromPassage(passage);
      print('[ReadingComprehension] Main assessment page text: $pageText');

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
      _proceedToMainAssessmentSentenceQuestions(question);
    }
  }

  // Proceed to sentence questions for main assessment
  void _proceedToMainAssessmentSentenceQuestions(Question question) {
    setState(() {
      _showPassage = false;
      _showContinueButton = false;
      _showSentenceQuestion = true;
      _currentQuestionText = '';
      _currentPageText = '';
    });

    _showMainAssessmentCurrentSentenceQuestion(question);
  }

  // Handle main assessment passage progression (continue button)
  void _proceedMainAssessmentToSentenceQuestion() {
    print(
        '[ReadingComprehension] ===== MAIN ASSESSMENT PASSAGE PROGRESSION =====');

    final assessmentProvider = _cachedProvider ??
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null) {
      // Check if there are more pages to show
      if (currentQuestion.passages != null &&
          _currentPageIndex + 1 < currentQuestion.passages!.length) {
        // Move to next page
        _currentPageIndex++;
        print(
            '[ReadingComprehension] Moving to next page: ${_currentPageIndex + 1}/${currentQuestion.passages!.length}');

        setState(() {
          _showContinueButton = false;
          _currentPageText = '';
        });

        // Load next page content using main assessment method
        _showMainAssessmentPassageContent(currentQuestion);
      } else {
        // All pages shown, proceed to sentence questions
        print(
            '[ReadingComprehension] All pages completed, proceeding to sentence questions');
        _proceedToMainAssessmentSentenceQuestions(currentQuestion);
      }
    } else {
      print(
          '[ReadingComprehension] No current question available for main assessment');
    }

    print(
        '[ReadingComprehension] ===== END MAIN ASSESSMENT PASSAGE PROGRESSION =====');
  }

  // Show current sentence question for main assessment
  void _showMainAssessmentCurrentSentenceQuestion(Question question) {
    if (question.sentenceQuestions != null &&
        question.sentenceQuestions!.isNotEmpty &&
        _currentSentenceQuestionIndex < question.sentenceQuestions!.length) {
      final sentenceQuestion =
          question.sentenceQuestions![_currentSentenceQuestionIndex];
      print(
          '[ReadingComprehension] Showing main assessment sentence question ${_currentSentenceQuestionIndex + 1}/${question.sentenceQuestions!.length}');
      print(
          '[ReadingComprehension] Main assessment sentence question data: $sentenceQuestion');

      // Dynamically extract question text with multiple field name options
      final questionText = _extractDynamicQuestionTextFromSQ(sentenceQuestion);

      // Dynamically extract correct answer with multiple field name options
      _correctAnswer = _extractDynamicCorrectAnswerFromSQ(sentenceQuestion);

      print(
          '[ReadingComprehension] Main assessment sentence question text: $questionText');
      print(
          '[ReadingComprehension] Main assessment correct answer: $_correctAnswer');

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
          '[ReadingComprehension] No more main assessment sentence questions for ${question.questionId}');
      // This should not happen in main assessment as we handle progression differently
      print(
          '[ReadingComprehension] ERROR: No more sentence questions in main assessment');
    }
  }

  // Handle main assessment feedback and progression (completely separate from pre-assessment)
  void _proceedMainAssessmentAfterFeedback() async {
    print('[ReadingComprehension] ===== MAIN ASSESSMENT AFTER FEEDBACK =====');
    print(
        '[ReadingComprehension] Current sentence question index: $_currentSentenceQuestionIndex');
    print('[ReadingComprehension] Assessment Type: ${widget.assessmentType}');
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
      final assessmentProvider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;
      final questionKey =
          currentQuestion?.questionId ?? widget.question.questionId;

      print(
          '[ReadingComprehension] ===== RECORDING MAIN ASSESSMENT ANSWER =====');
      print('[ReadingComprehension] Question ID: $questionKey');
      print('[ReadingComprehension] User Answer: "$userAnswer"');
      print('[ReadingComprehension] Correct Answer: "$_correctAnswer"');
      print(
          '[ReadingComprehension] Is Correct: ${isCorrect ? "✅ YES" : "❌ NO"}');
      print('[ReadingComprehension] Assessment Type: ${widget.assessmentType}');
      print(
          '[ReadingComprehension] Current Score Before Recording: ${_cachedProvider!.score}');

      // Get the assessment's ObjectId for categoryId and user's reading level
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final userReadingLevel = currentUser?.readingLevel ?? 'Low Emerging';

      // Get the assessment's ObjectId from the loaded assessment data
      final categoryId = _cachedProvider!.getAssessmentObjectId();

      // FIXED: Group responses by main questionId instead of creating separate records
      // For Reading Comprehension, we need to accumulate responses for the same questionId
      await _saveGroupedReadingComprehensionResponse(
        questionKey: questionKey,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        categoryId: categoryId,
        userReadingLevel: userReadingLevel,
      );

      // Record the reading comprehension response using existing method for compatibility
      _cachedProvider!.recordReadingComprehensionResponse(
        questionKey,
        userAnswer,
        _correctAnswer!,
        isCorrect,
      );

      print('[ReadingComprehension] Answer recorded successfully');
      print(
          '[ReadingComprehension] Current Score After Recording: ${_cachedProvider!.score}');
      print(
          '[ReadingComprehension] Total Responses Count: ${_cachedProvider!.responses.length}');
      print(
          '[ReadingComprehension] ===== END RECORDING MAIN ASSESSMENT ANSWER =====');
    } else {
      print(
          '[ReadingComprehension] ❌ Cannot record answer - Provider: ${_cachedProvider != null}, Correct Answer: $_correctAnswer');
    }

    widget.onAnswerSubmitted(userAnswer);

    // Check if there are more sentence questions in current question
    final assessmentProvider = _cachedProvider ??
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null) {
      if (_currentSentenceQuestionIndex + 1 <
          (currentQuestion.sentenceQuestions?.length ?? 0)) {
        _currentSentenceQuestionIndex++;
        print(
            '[ReadingComprehension] Moving to main assessment sentence question ${_currentSentenceQuestionIndex + 1}/${currentQuestion.sentenceQuestions!.length} in ${currentQuestion.questionId}');

        _isNavigating = false;
        _showMainAssessmentCurrentSentenceQuestion(currentQuestion);
        return;
      }
    } else {
      print(
          '[ReadingComprehension] No current question available for main assessment');
      // Reset navigating flag even if no current question
      _isNavigating = false;
    }

    print(
        '[ReadingComprehension] No more sentence questions in current RC question, proceeding to main assessment progression...');
    print(
        '[ReadingComprehension] ===== END MAIN ASSESSMENT AFTER FEEDBACK =====');

    // Reset navigating flag before proceeding
    _isNavigating = false;

    // Proceed to main assessment progression
    _proceedMainAssessmentReadingComprehension();
  }

  // Show final score dialog for main assessment
  void _showFinalScoreDialog() {
    try {
      if (!mounted) {
        print('[ReadingComprehension] Widget not mounted, cannot show dialog');
        return;
      }

      // Only show final score dialog for main assessment
      if (widget.assessmentType != 'main_assessment') {
        print(
            '[ReadingComprehension] Not main assessment - skipping final score dialog');
        return;
      }

      final assessmentProvider = _cachedProvider ??
          Provider.of<AssessmentProvider>(context, listen: false);

      // Calculate the correct score specifically for Reading Comprehension main assessment
      int totalCorrectQuestions = 0;
      if (assessmentProvider.assessment != null) {
        print('[ReadingComprehension] Recalculating score for final dialog...');
        for (int i = 0;
            i < assessmentProvider.assessment!.questions.length;
            i++) {
          final question = assessmentProvider.assessment!.questions[i];
          if (question.sentenceQuestions != null) {
            final sentenceQuestions = question.sentenceQuestions!;

            // Check if all sentence questions for this questionId are correct
            int correctAnswers = 0;
            int totalAnswers = sentenceQuestions.length;

            // Count all correct responses for this questionId
            for (var response in assessmentProvider.responses) {
              if (response['questionId'] == question.questionId &&
                  response['category'] == 'Reading Comprehension') {
                final isCorrect = response['isCorrect'] as bool;
                final userAnswer = response['userAnswer'] as String? ?? '';
                if (isCorrect) {
                  correctAnswers++;
                  print(
                      '[ReadingComprehension] ✅ Found correct response for ${question.questionId}: "$userAnswer"');
                } else {
                  print(
                      '[ReadingComprehension] ❌ Found incorrect response for ${question.questionId}: "$userAnswer"');
                }
              }
            }

            print(
                '[ReadingComprehension] Question ${question.questionId}: $correctAnswers correct out of $totalAnswers total sentence questions');

            // All-or-nothing scoring: only count if ALL sentence questions are correct
            if (correctAnswers == totalAnswers && totalAnswers > 0) {
              totalCorrectQuestions++;
              print(
                  '[ReadingComprehension] ✅ Question ${question.questionId}: All correct - counted');
            } else {
              print(
                  '[ReadingComprehension] ❌ Question ${question.questionId}: Not all correct - not counted');
            }
          }
        }
      }

      // For Reading Comprehension main assessment, total is 10 questions (RC_1 to RC_10)
      int totalQuestions = 10;

      print('[ReadingComprehension] Total questions: $totalQuestions');

      // Enhanced final score logging
      print('[ReadingComprehension] ===== FINAL SCORE DIALOG =====');
      print(
          '[ReadingComprehension] ===== MAIN ASSESSMENT READING COMPREHENSION COMPLETED =====');
      print('[ReadingComprehension] Final Score: $totalCorrectQuestions');
      print('[ReadingComprehension] Total Questions: $totalQuestions');
      print('[ReadingComprehension] ===== END FINAL SCORE DIALOG =====');

      // Use a more robust approach to show the dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('[ReadingComprehension] PostFrameCallback - mounted: $mounted');
        if (mounted) {
          print('[ReadingComprehension] About to show dialog');
          // Play congratulations sound when showing the assessment completed dialog
          _playCongratsSound();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              print('[ReadingComprehension] Dialog builder called');
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2B4E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFDE37C),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trophy icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFDE37C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Color(0xFF1C2B4E),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          'READING COMPREHENSION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Century Gothic',
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        const Text(
                          'Assessment Completed!',
                          style: TextStyle(
                            color: Color(0xFFFDE37C),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Century Gothic',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Score section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3B5C),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Score display
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$totalCorrectQuestions',
                                    style: const TextStyle(
                                      color: Color(0xFFFDE37C),
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Century Gothic',
                                    ),
                                  ),
                                  Text(
                                    ' / $totalQuestions',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Century Gothic',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // "Correct Answers" text
                              const Text(
                                'Correct Answers',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Century Gothic',
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Percentage
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${((totalCorrectQuestions / totalQuestions) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Century Gothic',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Motivational message
                        Text(
                          _getPerformanceMessage(
                              (totalCorrectQuestions / totalQuestions) * 100),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Century Gothic',
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 25),

                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();

                              // Save Reading Comprehension results to category_results collection
                              final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);
                              final assessmentProvider =
                                  Provider.of<AssessmentProvider>(context,
                                      listen: false);
                              final userId = authProvider.currentUser?.idNumber
                                      .toString() ??
                                  '';
                              if (userId.isNotEmpty) {
                                try {
                                  // Use Reading Comprehension's own "Pack 1 Pack All" scoring system
                                  final finalScore =
                                      totalCorrectQuestions; // Question IDs where all sentences were correct
                                  final finalTotal =
                                      totalQuestions; // Total Question IDs (10)
                                  final scorePercentage =
                                      (finalScore / finalTotal) * 100;

                                  print(
                                      '[ReadingComprehensionScreen] Saving Reading Comprehension results to category_results');
                                  print(
                                      '[ReadingComprehensionScreen] Using Reading Comprehension scores: $finalScore/$finalTotal = $scorePercentage%');
                                  await CategoryResultsHelper
                                      .updateCategoryResults(
                                          userId,
                                          'Reading Comprehension',
                                          finalScore,
                                          finalTotal,
                                          scorePercentage);
                                  print(
                                      '[ReadingComprehensionScreen] Successfully saved to category_results collection');
                                } catch (e) {
                                  print(
                                      '[ReadingComprehensionScreen] Error saving to category_results: $e');
                                  print(
                                      '[ReadingComprehensionScreen] Continuing with navigation despite save error');
                                }
                              }

                              // Use a more robust navigation approach with error handling
                              if (mounted) {
                                try {
                                  print(
                                      '[ReadingComprehensionScreen] Navigating to HomeScreen');
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HomeScreen(forceRefresh: true),
                                    ),
                                    (route) =>
                                        false, // Remove all previous routes
                                  );
                                  print(
                                      '[ReadingComprehensionScreen] Navigation to HomeScreen completed');
                                } catch (e) {
                                  print(
                                      '[ReadingComprehensionScreen] Error during navigation: $e');
                                  // Fallback navigation
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HomeScreen(forceRefresh: true),
                                    ),
                                  );
                                }
                              } else {
                                print(
                                    '[ReadingComprehensionScreen] Widget not mounted, cannot navigate');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDE37C),
                              foregroundColor: const Color(0xFF1C2B4E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'MAG PATULOY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Century Gothic',
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
      });
    } catch (e) {
      print('[ReadingComprehension] Error showing final score dialog: $e');
      // Fallback navigation with error handling
      if (mounted) {
        try {
          print('[ReadingComprehension] Fallback navigation to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(forceRefresh: true),
            ),
            (route) => false, // Remove all previous routes
          );
          print('[ReadingComprehension] Fallback navigation completed');
        } catch (navError) {
          print(
              '[ReadingComprehension] Error in fallback navigation: $navError');
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
      return 'Napakagaling! Mahusay na pagganap sa Reading Comprehension assessment.';
    } else if (percentage >= 80) {
      return 'Magaling! Mahusay na pagganap sa Reading Comprehension assessment.';
    } else if (percentage >= 70) {
      return 'Mabuti! Naisagawa mo nang maayos ang Reading Comprehension assessment.';
    } else if (percentage >= 50) {
      return 'Kailangan pa ng kaunting pagsasanay sa Reading Comprehension.';
    } else {
      return 'Kailangan ng mas maraming pagsasanay sa Reading Comprehension.';
    }
  }

  // ===== END NEW METHODS FOR MAIN ASSESSMENT READING COMPREHENSION =====

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
      await BackgroundMusicService.startBackgroundMusic(
        track: 'assets/audio/homeBg.mp3',
        volume: 0.3,
      );
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

  Future<void> _playCongratsSound() async {
    try {
      await _congratsSoundPlayer.setAsset('assets/audio/congrats fx.mp3');
      await _congratsSoundPlayer.seek(Duration.zero);
      await _congratsSoundPlayer.play();
      print('[ReadingComprehension] Playing congratulations sound');
    } catch (e) {
      print('[ReadingComprehension] Error playing congratulations sound: $e');
    }
  }

  // Calculate pill position helper method
  double _calculatePillPosition(
      double progressRatio, double totalWidth, double pillWidth) {
    if (progressRatio < 0.1) {
      return 0;
    } else if (progressRatio > 0.9) {
      return totalWidth - pillWidth;
    } else {
      return (totalWidth - pillWidth) * progressRatio;
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _answerController.dispose();
    _buttonAudioPlayer.dispose();
    _correctAnswerPlayer.dispose();
    _incorrectAnswerPlayer.dispose();
    _congratsSoundPlayer.dispose();
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
        final assessmentProvider = _cachedProvider ??
            Provider.of<AssessmentProvider>(context, listen: false);
        final currentId = assessmentProvider.currentQuestion?.questionId ??
            widget.question.questionId;

        if (currentId.startsWith('RC_')) {
          final numberPart = currentId.substring(3); // Remove "RC_" prefix
          currentPosition = int.tryParse(numberPart) ?? 1;

          // Ensure currentPosition is within valid range
          if (currentPosition < 1) currentPosition = 1;
          if (currentPosition > totalSteps) currentPosition = totalSteps;
        } else {
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
    final assessmentProvider = _cachedProvider ??
        Provider.of<AssessmentProvider>(context, listen: false);

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = totalSteps == 0 ? 0.0 : currentPosition / totalSteps;
    final pillWidth = 80.0;

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
            widthFactor: progressRatio,
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
            left: _calculatePillPosition(progressRatio, totalWidth, pillWidth),
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
          padding: const EdgeInsets.all(20),
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

        const SizedBox(height: 40),

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

          const SizedBox(height: 40),

          // Page text with typewriter animation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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

        const SizedBox(height: 20),

        // Continue button with sophisticated design
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
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Check if this is main assessment or pre-assessment
                    if (widget.assessmentType != 'pre_assessment') {
                      _proceedMainAssessmentToSentenceQuestion();
                    } else {
                      _proceedToSentenceQuestion();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BAC24),
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

          // Submit button with sophisticated design
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: _isSubmitEnabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1BAC24).withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitEnabled ? _submitAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSubmitEnabled
                    ? const Color(0xFF1BAC24) // Green when enabled
                    : const Color(0xFFD9D9D9), // Grey when disabled
                disabledBackgroundColor:
                    const Color(0xFFD9D9D9).withOpacity(0.5),
                foregroundColor:
                    _isSubmitEnabled ? Colors.white : const Color(0xFF333333),
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
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (_isCorrectAnswer
                              ? const Color(0XFF1BAC24)
                              : Colors.red)
                          .withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _playButtonAudio();
                    // Check if this is main assessment or pre-assessment
                    if (widget.assessmentType != 'pre_assessment') {
                      _proceedMainAssessmentAfterFeedback();
                    } else {
                      _proceedAfterFeedback();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCorrectAnswer ? const Color(0XFF1BAC24) : Colors.red,
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
            ],
          ),
        ),
      ],
    );
  }
}
