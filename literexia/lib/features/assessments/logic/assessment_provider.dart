// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import 'package:flutter/material.dart';
import '../repositories/assessment_repository.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../services/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AssessmentProvider extends ChangeNotifier {
  final AssessmentRepository _repository = AssessmentRepository();
  final DatabaseService _databaseService = DatabaseService();

  Assessment? _assessment;
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {};
  bool _isAssessmentComplete = false;
  int _score = 0;
  String? _errorMessage;
  String? _readingLevel;
  List<Question> _questions = [];

  // Track the current assessment category (for main assessments)
  String? _currentCategory;
  String? get currentCategory => _currentCategory;

  // Track if this is a pre-assessment or main assessment
  bool _isPreAssessment = false;

  // Track reading metrics
  double _readingPercentage = 0.0;
  Map<String, int> _readingMetrics = {
    'totalContentViewed': 0,
    'totalContentAvailable': 0,
    'timeSpentReading': 0,
  };

  DateTime? _assessmentStartTime;
  Map<String, dynamic> _rawQuestionData = {};

  // Track responses from specialized assessment screens
  List<Map<String, dynamic>> _responses = [];
  String? _currentUserId; // Track current user ID for individual response saving

  // Getters
  Assessment? get assessment => _assessment;
  int get currentQuestionIndex => _currentQuestionIndex;
  List<Question> get questions => _questions;
  Question? get currentQuestion => _assessment?.questions.length != null &&
          _currentQuestionIndex < _assessment!.questions.length
      ? _assessment!.questions[_currentQuestionIndex]
      : null;
  bool get isAssessmentComplete => _isAssessmentComplete;
  int get score => _score;
  int get totalQuestions => _assessment?.totalQuestions ?? 0;
  String? get errorMessage => _errorMessage;
  String? get readingLevel => _readingLevel;
  double get readingPercentage => _readingPercentage;
  bool get isPreAssessment => _isPreAssessment;
  List<Map<String, dynamic>> get responses => _responses;

  // Setters
  set currentQuestionIndex(int index) {
    _currentQuestionIndex = index;
    notifyListeners();
  }

  // Constructor
  AssessmentProvider() {
    _assessmentStartTime = DateTime.now();
  }

  /// Store raw question data for access by UI components
  void _storeRawQuestionData(Assessment assessment) {
    print(
        '[AssessmentProvider] Storing raw question data for ${assessment.questions.length} questions');

    _rawQuestionData.clear();

    for (final question in assessment.questions) {
      // Store the raw question data using the question ID as key
      _rawQuestionData[question.questionId] = {
        'questionId': question.questionId,
        'questionText': question.questionText,
        'questionTypeId': question.questionTypeId,
        'passages': question.passages,
        'sentenceQuestions': question.sentenceQuestions,
        'questionSet': question.questionSet,  // Add this field for phonological awareness questions
        // Add decoding-specific fields
        'questionImage': question.imageUrl,  // For decoding questions
        'displaySequence': question.displaySequence,  // For decoding drag/drop
        'dragElements': question.dragElements,  // Available letters for dragging
        'correctSequence': question.correctSequence,  // Correct answer sequence
        'options': question.options
            .map((option) => {
                  'optionId': option.optionId,
                  'optionText': option.optionText,
                  'isCorrect': option.isCorrect,
                })
            .toList(),
        // Add word recognition-specific fields
        'displayWord': question.sentenceWithBlank,  // Sentence with blanks for word recognition
        'blankOptions': question.wordChoices,  // Available word choices
        'correctAnswer': question.correctAnswer != null ? [question.correctAnswer!] : [],  // Convert to list for word recognition
      };

      print(
          '[AssessmentProvider] Stored data for question ${question.questionId}:');
      print('  - Passages: ${question.passages?.length ?? 0}');
      print(
          '  - Sentence Questions: ${question.sentenceQuestions?.length ?? 0}');
      print('  - QuestionSet: ${question.questionSet != null ? "Available" : "Not Available"}');
      if (question.questionSet != null) {
        final questionSet = question.questionSet!;
        if (questionSet['audioTexts'] != null) {
          print('    - AudioTexts length: ${(questionSet['audioTexts'] as List).length}');
        }
        if (questionSet['matchingOptions'] != null) {
          print('    - MatchingOptions length: ${(questionSet['matchingOptions'] as List).length}');
        }
      }
    }
  }

  /// Load PRE-ASSESSMENT for new users (called from login screen)
  Future<void> loadPreAssessment([String? assessmentId]) async {
    try {
      print('[AssessmentProvider] ===== LOADING PRE-ASSESSMENT =====');
      print('[AssessmentProvider] Assessment ID: ${assessmentId ?? "default"}');
      print('[AssessmentProvider] Clearing previous assessment data');

      _clearAssessmentData();
      _isPreAssessment = true; // CRITICAL: Mark as pre-assessment

      print('[AssessmentProvider] Loading pre-assessment from repository');
      // Load pre-assessment from repository (assessmentId is optional for backwards compatibility)
      final assessment = await _repository.getPreAssessment(assessmentId);

      if (assessment != null) {
        _assessment = assessment;
        _questions = assessment.questions;

        // FIXED: Store raw question data for UI access
        _storeRawQuestionData(assessment);
        
        // Debug: Check specific PA_001 question data
        Question? pa001Question;
        try {
          pa001Question = assessment.questions.firstWhere((q) => q.questionId == 'PA_001');
        } catch (e) {
          // PA_001 not found
          pa001Question = null;
        }
        if (pa001Question != null && pa001Question.questionId == 'PA_001') {
          print('[AssessmentProvider] ===== PA_001 RAW DATA DEBUG =====');
          print('[AssessmentProvider] PA_001 questionId: ${pa001Question.questionId}');
          print('[AssessmentProvider] PA_001 questionType: ${pa001Question.questionType}');
          print('[AssessmentProvider] PA_001 has questionSet: ${pa001Question.questionSet != null}');
          if (pa001Question.questionSet != null) {
            final qs = pa001Question.questionSet!;
            print('[AssessmentProvider] PA_001 questionSet keys: ${qs.keys.toList()}');
            print('[AssessmentProvider] PA_001 audioTexts: ${qs['audioTexts']}');
            print('[AssessmentProvider] PA_001 audioTexts length: ${qs['audioTexts']?.length}');
            print('[AssessmentProvider] PA_001 matchingOptions: ${qs['matchingOptions']}');
            print('[AssessmentProvider] PA_001 matchingOptions length: ${qs['matchingOptions']?.length}');
            print('[AssessmentProvider] PA_001 correctPairs: ${qs['correctPairs']}');
            print('[AssessmentProvider] PA_001 correctPairs length: ${qs['correctPairs']?.length}');
          }
          print('[AssessmentProvider] ===== END PA_001 RAW DATA DEBUG =====');
        } else {
          print('[AssessmentProvider] ❌ PA_001 question not found in loaded data');
        }

        // Debug WR_001 question data
        Question? wr001Question;
        try {
          wr001Question = assessment.questions.firstWhere((q) => q.questionId == 'WR_001');
        } catch (e) {
          wr001Question = null;
        }
        if (wr001Question != null && wr001Question.questionId == 'WR_001') {
          print('[AssessmentProvider] ===== WR_001 MONGODB RAW DATA DEBUG =====');
          print('[AssessmentProvider] WR_001 questionId: ${wr001Question.questionId}');
          print('[AssessmentProvider] WR_001 questionType: ${wr001Question.questionType}');
          print('[AssessmentProvider] WR_001 sentenceWithBlank: ${wr001Question.sentenceWithBlank}');
          print('[AssessmentProvider] WR_001 wordChoices: ${wr001Question.wordChoices}');
          print('[AssessmentProvider] WR_001 correctAnswer: ${wr001Question.correctAnswer}');
          
          // Check the original questions data from the assessment
          if (assessment.originalQuestionsData != null) {
            final originalWR001 = assessment.originalQuestionsData!.firstWhere(
              (q) => q['questionId'] == 'WR_001',
              orElse: () => {},
            );
            if (originalWR001.isNotEmpty) {
              print('[AssessmentProvider] WR_001 original MongoDB keys: ${originalWR001.keys.toList()}');
              print('[AssessmentProvider] WR_001 original displayWord: ${originalWR001['displayWord']}');
              print('[AssessmentProvider] WR_001 original sentenceWithBlank: ${originalWR001['sentenceWithBlank']}');
              print('[AssessmentProvider] WR_001 original blankOptions: ${originalWR001['blankOptions']}');
              print('[AssessmentProvider] WR_001 original wordChoices: ${originalWR001['wordChoices']}');
              print('[AssessmentProvider] WR_001 original correctAnswer: ${originalWR001['correctAnswer']}');
            }
          }
          print('[AssessmentProvider] ===== END WR_001 MONGODB RAW DATA DEBUG =====');
        } else {
          print('[AssessmentProvider] ❌ WR_001 question not found in loaded data');
        }

        print(
            '[AssessmentProvider] Successfully loaded PRE-ASSESSMENT: ${assessment.title}');
        print(
            '[AssessmentProvider] Total questions: ${assessment.totalQuestions}');
        print('[AssessmentProvider] Questions loaded: ${_questions.length}');
        print(
            '[AssessmentProvider] Marked as PRE-ASSESSMENT: $_isPreAssessment');

        notifyListeners();
      } else {
        print(
            '[AssessmentProvider] Failed to load pre-assessment - no data returned');
        throw Exception('Pre-assessment not available');
      }
    } catch (e) {
      print('[AssessmentProvider] Error loading pre-assessment: $e');
      _errorMessage = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// Load MAIN ASSESSMENT for users who completed pre-assessment (called from home screen)
  /// Now with proper reading level context and category
  Future<void> loadMainAssessment(dynamic assessmentId, {String? readingLevel, String? category}) async {
  try {
    print('[AssessmentProvider] ===== LOADING MAIN ASSESSMENT =====');
    print('[AssessmentProvider] Assessment ID: $assessmentId');
    print('[AssessmentProvider] Reading level: $readingLevel');
    print('[AssessmentProvider] Category: $category');

    // Determine the reading level to use
    String? targetReadingLevel = readingLevel;

    // If no reading level provided, try to get from current user context
    if (targetReadingLevel == null || targetReadingLevel.isEmpty) {
      print('[AssessmentProvider] No reading level provided for main assessment');
    }

    print('[AssessmentProvider] Clearing previous assessment data');
    _clearAssessmentData();
    _isPreAssessment = false; // CRITICAL: Mark as main assessment

    // Extract category from assessmentId if not provided
    String? targetCategory = category;
    if (targetCategory == null || targetCategory.isEmpty) {
      // Try to extract category from assessmentId
      if (assessmentId is String) {
        if (assessmentId.contains("alphabet") || assessmentId.contains("AK_")) {
          targetCategory = "Alphabet Knowledge";
        } else if (assessmentId.contains("phono") || assessmentId.contains("PA_")) {
          targetCategory = "Phonological Awareness";
        } else if (assessmentId.contains("decod") || assessmentId.contains("DC_")) {
          targetCategory = "Decoding";
        } else if (assessmentId.contains("word") || assessmentId.contains("WR_")) {
          targetCategory = "Word Recognition";
        } else if (assessmentId.contains("read") || assessmentId.contains("RC_")) {
          targetCategory = "Reading Comprehension";
        }
      }
    }

    print('[AssessmentProvider] Determined category: $targetCategory');

    print('[AssessmentProvider] Loading main assessment from repository');
    // Load main assessment from repository WITH reading level and category context
    final assessment = await _repository.getMainAssessment(
      assessmentId,
      readingLevel: targetReadingLevel,
      category: targetCategory
    );

    if (assessment != null) {
      _assessment = assessment;
      _questions = assessment.questions;

      // Store the category for later use
      _currentCategory = targetCategory;

      // FIXED: Store raw question data for UI access
      _storeRawQuestionData(assessment);

      print('[AssessmentProvider] Successfully loaded MAIN ASSESSMENT: ${assessment.title}');
      print('[AssessmentProvider] Total questions: ${assessment.totalQuestions}');
      print('[AssessmentProvider] Questions loaded: ${_questions.length}');
      print('[AssessmentProvider] Marked as MAIN ASSESSMENT: $_isPreAssessment');
      print('[AssessmentProvider] Assessment category: $_currentCategory');

      notifyListeners();
    } else {
      print('[AssessmentProvider] Failed to load main assessment - no data returned');
      throw Exception('Main assessment not available');
    }
  } catch (e) {
    print('[AssessmentProvider] Error loading main assessment: $e');
    _errorMessage = e.toString();
    notifyListeners();
    throw e;
  }
}

  /// Enhanced method to load assessment with reading level awareness
  Future<void> loadAssessmentWithReadingLevel(
      dynamic assessmentId, String userReadingLevel) async {
    print('[AssessmentProvider] Loading assessment with reading level context');
    print(
        '[AssessmentProvider] Assessment ID: $assessmentId, User Reading Level: $userReadingLevel');

    // Determine assessment type and load accordingly
    if (assessmentId == 1 ||
        assessmentId == 'PRE_ASSESSMENT_001' ||
        assessmentId.toString().contains('PRE')) {
      // This is a pre-assessment
      await loadPreAssessment();
    } else {
      // This is a main assessment - pass reading level for filtering
      await loadMainAssessment(assessmentId, readingLevel: userReadingLevel);
    }
  }

  /// Clear assessment data
  void _clearAssessmentData() {
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _score = 0;
    _assessmentStartTime = DateTime.now();
    _rawQuestionData.clear();
    _clearResponses();
    _readingPercentage = 0.0;
    _readingMetrics = {
      'totalContentViewed': 0,
      'totalContentAvailable': 0,
      'timeSpentReading': 0,
    };
    _errorMessage = null;
    _readingLevel = null;
    _isAssessmentComplete = false;
    // NOTE: Don't reset _isPreAssessment here - it should be set explicitly when loading assessments
  }

  /// Resume assessment from saved progress
  Future<void> resumeFromSavedProgress(String userId, int lessonIndex) async {
    try {
      print('[AssessmentProvider] Attempting to resume from saved progress for lesson $lessonIndex');
      
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Get saved progress from database
      final progressData = await dbService.getLessonProgress(userId, lessonIndex);
      
      if (progressData != null && progressData['currentQuestion'] != null) {
        final savedQuestionIndex = (progressData['currentQuestion'] as int) - 1; // Convert to 0-based index
        final totalQuestions = progressData['totalQuestions'] as int? ?? 0;
        
        if (savedQuestionIndex >= 0 && savedQuestionIndex < totalQuestions && _assessment != null && savedQuestionIndex < _assessment!.questions.length) {
          _currentQuestionIndex = savedQuestionIndex;
          print('[AssessmentProvider] Resumed from question ${savedQuestionIndex + 1} of $totalQuestions');
          notifyListeners();
        } else {
          print('[AssessmentProvider] Invalid saved progress: question $savedQuestionIndex not in valid range');
        }
      } else {
        print('[AssessmentProvider] No valid saved progress found for lesson $lessonIndex');
      }
    } catch (e) {
      print('[AssessmentProvider] Error resuming from saved progress: $e');
    }
  }

  /// Answer the current question and move to the next
  void answerCurrentQuestion(String answerId) {
    if (_assessment == null || currentQuestion == null || _isAssessmentComplete)
      return;

    print(
        '[AssessmentProvider] Answering question: ${currentQuestion!.questionId} with option: $answerId');

    // Save user's answer
    _userAnswers[currentQuestion!.questionId] = answerId;

    // Check if the answer is correct
    final selectedOption = currentQuestion!.options.firstWhere(
      (option) => option.optionId == answerId,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );

    if (selectedOption.isCorrect) {
      _score++;
      print('[AssessmentProvider] Correct answer! Current score: $_score');
    } else {
      print('[AssessmentProvider] Incorrect answer. Current score: $_score');
    }

    // Move to next question or complete the assessment
    if (_currentQuestionIndex < _assessment!.questions.length - 1) {
      _currentQuestionIndex++;
      print(
          '[AssessmentProvider] Moving to question index: $_currentQuestionIndex');
    } else {
      // Assessment is complete
      _isAssessmentComplete = true;

      // Determine reading level - different logic for pre vs main assessment
      if (_isPreAssessment) {
        _determineReadingLevelFromPreAssessment();
      } else {
        _determineReadingLevelFromMainAssessment();
      }

      print(
          '[AssessmentProvider] Assessment completed with final score: $_score/${_assessment!.questions.length}');
      print('[AssessmentProvider] Reading percentage: $_readingPercentage%');
      print('[AssessmentProvider] Reading level: $_readingLevel');
      print(
          '[AssessmentProvider] Assessment type: ${_isPreAssessment ? "PRE-ASSESSMENT" : "MAIN ASSESSMENT"}');
    }

    notifyListeners();
  }

  /// Determine reading level from PRE-ASSESSMENT using CRLA methodology
  void _determineReadingLevelFromPreAssessment() {
    if (_assessment == null) return;

    print('[AssessmentProvider] Determining reading level from PRE-ASSESSMENT using CRLA methodology');

    // Calculate overall reading percentage
    int readingPercentage = ((_score / totalQuestions) * 100).round();

    // For CRLA methodology, calculate required scores
    int part1Score = 0;
    int comprehensionScore = 0;

    // Calculate part 1 score and comprehension score from responses
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final userAnswer = _userAnswers[question.questionId];
      final category = getCategoryName(question.questionTypeId);

      if (userAnswer != null) {
        final selectedOption = question.options.firstWhere(
          (opt) => opt.optionId == userAnswer,
          orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        if (selectedOption.isCorrect) {
          if (category == 'Reading Comprehension') {
            comprehensionScore++;
          } else {
            part1Score++;
          }
        }
      }
    }

    // Determine reading level using CRLA methodology
    String readingLevel = _determineReadingLevelUsingCRLA(part1Score, readingPercentage, comprehensionScore);
    
    _readingLevel = readingLevel;
    _readingPercentage = readingPercentage.toDouble();

    print('[AssessmentProvider] PRE-ASSESSMENT - Part 1 Score: $part1Score');
    print('[AssessmentProvider] PRE-ASSESSMENT - Reading Percentage: $readingPercentage%');
    print('[AssessmentProvider] PRE-ASSESSMENT - Comprehension Score: $comprehensionScore');
    print('[AssessmentProvider] PRE-ASSESSMENT - Determined reading level: $_readingLevel');
  }



  /// Determine reading level using CRLA methodology with specific thresholds
  String _determineReadingLevelUsingCRLA(int part1Score, int readingPercentage, int comprehensionScore) {
    // CRLA Reading Level Criteria based on PDF methodology
    
    // Low Emerging: 0-16 Part 1 score
    if (part1Score >= 0 && part1Score <= 16) {
      return 'Low Emerging';
    }

    // For Part 1 scores 17-30, check reading percentage and comprehension
    if (part1Score >= 17 && part1Score <= 30) {
      // High Emerging: <25% reading percentage
      if (readingPercentage < 25) {
        return 'High Emerging';
      }
      
      // Developing: 26-50% reading percentage AND ≥1 comprehension correct
      if (readingPercentage >= 26 && readingPercentage <= 50 && comprehensionScore >= 1) {
        return 'Developing';
      }
      
      // Transitioning: 51-75% reading percentage AND 2-3 comprehension correct
      if (readingPercentage >= 51 && readingPercentage <= 75 && comprehensionScore >= 2 && comprehensionScore <= 3) {
        return 'Transitioning';
      }
      
      // At Grade Level: 76-100% reading percentage AND 4-5 comprehension correct
      if (readingPercentage >= 76 && readingPercentage <= 100 && comprehensionScore >= 4 && comprehensionScore <= 5) {
        return 'At Grade Level';
      }
    }

    // Fallback to High Emerging if no criteria met
    return 'High Emerging';
  }

  /// Determine reading level from MAIN ASSESSMENT (for lesson progression)
  void _determineReadingLevelFromMainAssessment() {
    // Use existing logic for main assessment
    if (_assessment == null) return;

    print(
        '[AssessmentProvider] Determining reading level from MAIN ASSESSMENT');


    // Determine reading level based on overall performance
    final overallPercentage = (_score / totalQuestions) * 100;
    _readingPercentage = overallPercentage;

    // Apply CRLA reading level criteria
    if (overallPercentage < 25) {
      _readingLevel = "Low Emerging";
    } else if (overallPercentage < 50) {
      _readingLevel = "High Emerging";
    } else if (overallPercentage < 65) {
      _readingLevel = "Developing";
    } else if (overallPercentage < 80) {
      _readingLevel = "Transitioning";
    } else {
      _readingLevel = "At Grade Level";
    }

    print(
        '[AssessmentProvider] MAIN ASSESSMENT - Overall percentage: $overallPercentage%');
    print(
        '[AssessmentProvider] MAIN ASSESSMENT - Determined reading level: $_readingLevel');
  }

  /// Map question type IDs to CRLA category names
  String getCategoryName(String questionTypeId) {
    final typeId = questionTypeId.toLowerCase();

    // Map Filipino terms for Alphabet Knowledge
    if (typeId == 'patinig' || typeId == 'katinig') {
      return 'Alphabet Knowledge';
    }
    if (typeId.contains('alphabet') || typeId == 'alphabet_knowledge' || typeId == 'ak') {
      return 'Alphabet Knowledge';
    } else if (typeId.contains('phono') || typeId == 'phonological_awareness' || typeId == 'pa' || typeId == 'malapantig') {
      return 'Phonological Awareness';
    } else if (typeId.contains('decod') || typeId == 'decoding' || typeId == 'dc' || typeId == 'word') {
      return 'Decoding';
    } else if (typeId.contains('word_recognition') || typeId == 'wr') {
      return 'Word Recognition';
    } else if (typeId.contains('reading_comprehension') || typeId == 'rc' || typeId == 'sentence') {
      return 'Reading Comprehension';
    }

    print('[AssessmentProvider] WARNING: Unknown question type ID: $questionTypeId');
    return 'Other';
  }

  /// Record reading activity - call when content is displayed
  void recordContentViewed(int contentSize) {
    _readingMetrics['totalContentViewed'] =
        (_readingMetrics['totalContentViewed'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  /// Record available content - call when loading new content
  void recordAvailableContent(int contentSize) {
    _readingMetrics['totalContentAvailable'] =
        (_readingMetrics['totalContentAvailable'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  /// Record time spent reading
  void recordReadingTime(int seconds) {
    _readingMetrics['timeSpentReading'] =
        (_readingMetrics['timeSpentReading'] ?? 0) + seconds;
  }

  /// Update reading percentage based on metrics
  void _updateReadingPercentage() {
    final contentViewed = _readingMetrics['totalContentViewed'] ?? 0;
    final contentAvailable = _readingMetrics['totalContentAvailable'] ?? 0;

    if (contentAvailable > 0) {
      _readingPercentage = (contentViewed / contentAvailable) * 100;
    } else {
      // Fallback to score-based percentage
      final scorePercent = _assessment != null && totalQuestions > 0
          ? (_score / totalQuestions) * 100
          : 0.0;
      _readingPercentage = scorePercent;
    }
  }

  /// ENHANCED: Save results with proper routing based on assessment type
  // In assessment_provider.dart - Update saveResults method
Future<void> saveResults(String userId) async {
  try {
    print('[AssessmentProvider] ===== SAVING ASSESSMENT RESULTS =====');
    
    // CRITICAL FIX: Convert userId to integer
    dynamic studentIdValue;
    try {
      studentIdValue = int.parse(userId);
      print('[AssessmentProvider] Converted studentId to integer: $studentIdValue');
    } catch (e) {
      print('[AssessmentProvider] WARNING: Could not convert userId to integer, keeping as string: $userId');
      studentIdValue = userId;
    }
    
    print('[AssessmentProvider] User ID: $studentIdValue (${studentIdValue.runtimeType})');
    print('[AssessmentProvider] Assessment Type: ${_isPreAssessment ? "PRE-ASSESSMENT" : "MAIN ASSESSMENT"}');
    
    if (_assessment == null) {
      print('[AssessmentProvider] Error: No assessment available to save results');
      return;
    }

    // Create correct answers map and question categories
    Map<String, dynamic> correctAnswers = {};
    Map<String, String> questionCategories = {};
    
    for (final question in _questions) {
      final correctOption = question.options.firstWhere(
        (opt) => opt.isCorrect,
        orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
      );
      correctAnswers[question.questionId] = correctOption.optionId;
      
      final questionCategory = getCategoryName(question.questionTypeId);
      questionCategories[question.questionId] = questionCategory;
    }

    // Check if results already exist
    final dbService = DatabaseService();
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }

    final assessmentId = _assessment!.assessmentId.toString();
    final hasExistingResults = await dbService.hasCompletedAssessment(userId, assessmentId);

    if (hasExistingResults) {
      print('[AssessmentProvider] Assessment results already exist for user $userId and assessment $assessmentId');
      return;
    }

    bool saveSuccess = false;

    // Save results with INTEGER studentId
    saveSuccess = await _repository.saveUserResponses(
      assessmentId: _assessment!.assessmentId,
      userId: userId, // Pass as string, will be converted in repository
      answers: _userAnswers,
      score: _score,
      readingLevel: _readingLevel ?? 'Undefined',
      readingPercentage: _readingPercentage,
      additionalData: {
        'correctAnswers': correctAnswers,
        'questionCategories': questionCategories,
        'totalQuestions': totalQuestions,
        'assessmentStartTime': _assessmentStartTime?.toIso8601String(),
        'assessmentEndTime': DateTime.now().toIso8601String(),
        'readingMetrics': _readingMetrics,
        'assessmentType': _isPreAssessment ? 'pre_assessment' : 'main_assessment',
        'isPreAssessment': _isPreAssessment,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
        'category': _currentCategory,
        'studentIdInteger': studentIdValue, // Pass the integer version
      },
    );

    if (saveSuccess) {
      print('[AssessmentProvider] Successfully saved assessment results');
      
      if (_isPreAssessment) {
        await _repository.updateUserReadingLevel(
          userId: userId,
          readingLevel: _readingLevel ?? 'Undefined',
          readingPercentage: _readingPercentage,
          preAssessmentCompleted: true,
        );
      }
      
      await saveDetailedResults(userId, _assessment!.assessmentId.toString());
    } else {
      print('[AssessmentProvider] Failed to save assessment results');
      throw Exception('Failed to save assessment results');
    }
  } catch (e) {
    print('[AssessmentProvider] Error saving results: $e');
    throw e;
  }
}

  // Updated saveDetailedResults method to properly handle category information
  Future<void> saveDetailedResults(String userId, String assessmentId) async {
  try {
    final dbService = DatabaseService();
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }

    // Check if detailed results already exist
    final hasExistingResults = await dbService.hasCompletedAssessment(userId, assessmentId);
    if (hasExistingResults) {
      print('[AssessmentProvider] Detailed results already exist for user $userId and assessment $assessmentId');
      return;
    }

    // CRITICAL FIX: Convert userId to integer
    dynamic studentIdValue;
    try {
      studentIdValue = int.parse(userId);
      print('[AssessmentProvider] saveDetailedResults - Converted studentId to integer: $studentIdValue');
    } catch (e) {
      print('[AssessmentProvider] saveDetailedResults - WARNING: Could not convert userId to integer: $e');
      studentIdValue = userId;
    }

    final bool isPreAssessment = assessmentId == 'PRE_ASSESSMENT_001' || 
                               assessmentId.toString().contains('PRE') || 
                               assessmentId == '1';
    
    // Prepare assessment data with INTEGER studentId
    final assessmentData = {
      'studentId': studentIdValue, // Use integer value
      'assessmentId': assessmentId,
      'assessmentType': isPreAssessment ? 'pre-assessment' : 'main-assessment',
      'assessmentDate': DateTime.now().toIso8601String(),
      'overallScore': score,
      'readingLevel': readingLevel,
      'readingLevelUpdated': true,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'isPreAssessment': isPreAssessment,
    };

    // Add reading percentage if available
    if (_readingPercentage > 0) {
      assessmentData['readingPercentage'] = _readingPercentage;
    }

    // Add current category if available
    if (_currentCategory != null && _currentCategory!.isNotEmpty) {
      assessmentData['primaryCategory'] = _currentCategory;
    }

    print('[AssessmentProvider] Saving detailed assessment results:');
    print('[AssessmentProvider]   - studentId: $studentIdValue (${studentIdValue.runtimeType})');
    print('[AssessmentProvider]   - assessmentType: ${assessmentData['assessmentType']}');
    print('[AssessmentProvider]   - isPreAssessment: $isPreAssessment');

    final result = await dbService.saveAssessmentResult(assessmentData);
    
    if (result) {
      print('[AssessmentProvider] Successfully saved detailed assessment results with integer studentId');
    } else {
      print('[AssessmentProvider] Failed to save detailed assessment results');
      throw Exception('Failed to save detailed assessment results');
    }

    
  } catch (e) {
    print('[AssessmentProvider] Error saving detailed assessment results: $e');
    rethrow;
  }
}

  List<Map<String, dynamic>> _getSpecificCategoryScore(String categoryName) {
    // Initialize counts
    int totalQuestions = 0;
    int correctAnswers = 0;
    
    // Count questions and correct answers for this specific category
    for (final question in _questions) {
      // Only count questions for this category
      if (getCategoryName(question.questionTypeId) == categoryName) {
        totalQuestions++;
        
        final userAnswer = _userAnswers[question.questionId];
        if (userAnswer != null) {
          final selectedOption = question.options.firstWhere(
            (opt) => opt.optionId == userAnswer,
            orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
          );
          if (selectedOption.isCorrect) {
            correctAnswers++;
          }
        }
      }
    }
    
    // If no questions were found for this category, use default values
    if (totalQuestions == 0) {
      totalQuestions = 5; // Default to 5 questions per category
    }
    
    // Calculate score
    final score = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
    
    // Create the category score entry
    return [{
      'categoryName': categoryName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'score': score,
      'isPassed': score >= 75,
      'passingThreshold': 75,
    }];
  }

  // Helper method to check if specific category passed
  bool _isCategoryPassed(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) {
      return false;
    }
    
    final categoryScores = _getSpecificCategoryScore(categoryName);
    if (categoryScores.isEmpty) return false;
    
    return categoryScores.first['isPassed'] == true;
  }

  /// Update user reading level following the guide's user profile structure
  Future<void> updateUserReadingLevel(
      AuthProvider authProvider, String readingLevel,
      {double? readingPercentage}) async {
    final userId = authProvider.currentUser?.idNumber;
    if (userId == null) {
      print(
          '[AssessmentProvider] Error: Cannot update reading level - No user ID available');
      return;
    }

    try {
      final percentage = readingPercentage ?? _readingPercentage;

      print(
          '[AssessmentProvider] Updating user profile for $userId with reading level $readingLevel and percentage $percentage%');

      // Update AuthProvider (memory)
      authProvider.updateUserReadingLevel(readingLevel);
      authProvider.updateReadingPercentage(percentage);
      authProvider.setPreAssessmentCompleted(true);

      // Update database using DatabaseService directly
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final result = await dbService.updateUserPreAssessmentStatus(
        userId,
        true,
        readingLevel,
        percentage,
      );

      if (result) {
        print(
            '[AssessmentProvider] Successfully updated user profile in database');
      } else {
        print('[AssessmentProvider] Failed to update user profile in database');
      }
    } catch (e) {
      print('[AssessmentProvider] Error updating user reading level: $e');
    }
  }

  /// Calculate category breakdown following the guide's category structure
  Map<String, dynamic> _calculateCategoryBreakdown() {
    Map<String, dynamic> categoryBreakdown = {};
    Map<String, int> categoryTotals = {};
    Map<String, int> categoryCorrect = {};

    // Initialize categories
    for (final question in _questions) {
      final category = getCategoryName(question.questionTypeId);
      categoryTotals[category] = (categoryTotals[category] ?? 0) + 1;
      categoryCorrect[category] = categoryCorrect[category] ?? 0;
    }

    // Calculate correct answers per category
    for (final question in _questions) {
      final userAnswer = _userAnswers[question.questionId];
      if (userAnswer != null) {
        final selectedOption = question.options.firstWhere(
          (opt) => opt.optionId == userAnswer,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        if (selectedOption.isCorrect) {
          final category = getCategoryName(question.questionTypeId);
          categoryCorrect[category] = (categoryCorrect[category] ?? 0) + 1;
        }
      }
    }

    // Build category breakdown
    categoryTotals.forEach((category, total) {
      final correct = categoryCorrect[category] ?? 0;
      final score = total > 0 ? (correct / total * 100).round() : 0;

      categoryBreakdown[category] = {
        'categoryName': category,
        'totalQuestions': total,
        'correctAnswers': correct,
        'score': score,
        'isPassed': score >= 75,
        'passingThreshold': 75,
      };
    });

    return categoryBreakdown;
  }

  /// Calculate time taken for the assessment
  int _calculateTimeTaken() {
    if (_assessmentStartTime == null) return 0;

    final trackedTime = _readingMetrics['timeSpentReading'] ?? 0;
    if (trackedTime > 0) return trackedTime;

    final now = DateTime.now();
    final difference = now.difference(_assessmentStartTime!);
    return difference.inSeconds;
  }

  /// Get effective reading percentage
  double getEffectiveReadingPercentage() {
    if (_readingPercentage > 0) {
      return _readingPercentage;
    }

    if (_assessment != null && totalQuestions > 0) {
      return (_score / totalQuestions) * 100;
    }

    return 50.0; // Default fallback
  }


  /// Reset the assessment to start over
  void resetAssessment() {
    _clearAssessmentData();
    notifyListeners();
  }

  // Helper function for determining min value (used in part1Score calculation)
  int min(int a, int b) {
    return a < b ? a : b;
  }

  bool canGoToPreviousQuestion() {
    return currentQuestionIndex > 0;
  }

  void goToPreviousQuestion() {
    if (canGoToPreviousQuestion()) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Move to next question or complete the assessment
  void moveToNextQuestion() {
    if (_assessment == null || _isAssessmentComplete) return;

    if (_currentQuestionIndex < _assessment!.questions.length - 1) {
      _currentQuestionIndex++;
      print('[AssessmentProvider] Moving to question index: $_currentQuestionIndex');
    } else {
      // Assessment is complete
      _isAssessmentComplete = true;
      print('[AssessmentProvider] Assessment completed');
    }

    notifyListeners();
  }

  List<Map<String, dynamic>> _getAllCategoryScores() {
    final allCategories = [
      'Alphabet Knowledge',
      'Phonological Awareness',
      'Decoding',
      'Word Recognition', 
      'Reading Comprehension'
    ];

    Map<String, int> categoryTotals = {};
    Map<String, int> categoryCorrect = {};
    
    // Initialize all categories
    for (final category in allCategories) {
      categoryTotals[category] = 0;
      categoryCorrect[category] = 0;
    }

    print('[AssessmentProvider] Processing ${_questions.length} questions');
    print('[AssessmentProvider] Assessment type: ${_isPreAssessment ? "PRE" : "MAIN"}');
    print('[AssessmentProvider] Current category: $_currentCategory');

    // CRITICAL FIX: Different logic for pre vs main assessments
    if (_isPreAssessment) {
      // PRE-ASSESSMENT: Distribute questions across all categories based on question IDs
      for (final question in _questions) {
        String category = _detectCategoryFromQuestionId(question.questionId);
        
        categoryTotals[category] = (categoryTotals[category] ?? 0) + 1;
        
        // Check both _userAnswers (for regular questions) and _responses (for specialized screens)
        bool isCorrect = false;
        
        // First check _userAnswers (used by AlphabetKnowledgeScreen via answerCurrentQuestion)
        final userAnswer = _userAnswers[question.questionId];
        if (userAnswer != null) {
          final selectedOption = question.options.firstWhere(
            (opt) => opt.optionId == userAnswer,
            orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
          );
          isCorrect = selectedOption.isCorrect;
        } else {
          // Check _responses (used by specialized screens like PhonologicalMatching, etc.)
          final responseList = _responses.where((r) => r['questionId'] == question.questionId).toList();
          final response = responseList.isNotEmpty ? responseList.first : null;
          if (response != null) {
            isCorrect = response['isCorrect'] ?? false;
          } else {
            // Check for Reading Comprehension sub-questions (RC_XXX_0, RC_XXX_1, etc.)
            final rcResponses = _responses.where((r) => r['questionId'].toString().startsWith('${question.questionId}_')).toList();
            if (rcResponses.isNotEmpty) {
              // For RC questions, calculate percentage of correct sub-questions
              final correctRcCount = rcResponses.where((r) => r['isCorrect'] == true).length;
              isCorrect = correctRcCount > (rcResponses.length / 2); // Consider correct if more than 50% are right
            }
          }
        }
        
        if (isCorrect) {
          categoryCorrect[category] = (categoryCorrect[category] ?? 0) + 1;
        }
        
        print('[AssessmentProvider] PRE-Q ${question.questionId} -> $category (Correct: $isCorrect)');
      }
    } else {
      // MAIN ASSESSMENT: All questions belong to the current assessment's category
      final targetCategory = _currentCategory ?? 'Unknown';
      
      if (allCategories.contains(targetCategory)) {
        // FIXED: For Reading Comprehension, count individual sentence questions, not RC questions
        if (targetCategory == 'Reading Comprehension') {
          // Count all individual sentence questions from _responses
          final rcResponses = _responses.where((r) => 
            r['category'] == 'Reading Comprehension' || 
            r['questionId'].toString().contains('RC_')).toList();
          
          categoryTotals[targetCategory] = rcResponses.length; // Total individual questions answered
          
          final correctCount = rcResponses.where((r) => r['isCorrect'] == true).length;
          categoryCorrect[targetCategory] = correctCount;
          
          print('[AssessmentProvider] RC MAIN - Total responses: ${rcResponses.length}');
          print('[AssessmentProvider] RC MAIN - Correct responses: $correctCount');
          
          // Debug each response
          for (final response in rcResponses) {
            print('[AssessmentProvider] RC Response: ${response['questionId']} = ${response['isCorrect'] ? "✅" : "❌"}');
          }
        } else {
          // Other categories use the original logic
          categoryTotals[targetCategory] = _questions.length;
          
          int correctCount = 0;
          for (final question in _questions) {
            bool isCorrect = false;
            
            // First check _userAnswers (used by AlphabetKnowledgeScreen via answerCurrentQuestion)
            final userAnswer = _userAnswers[question.questionId];
            if (userAnswer != null) {
              final selectedOption = question.options.firstWhere(
                (opt) => opt.optionId == userAnswer,
                orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
              );
              isCorrect = selectedOption.isCorrect;
            } else {
              // Check _responses (used by specialized screens like PhonologicalMatching, etc.)
              final responseList = _responses.where((r) => r['questionId'] == question.questionId).toList();
              final response = responseList.isNotEmpty ? responseList.first : null;
              if (response != null) {
                isCorrect = response['isCorrect'] ?? false;
              }
            }
            
            if (isCorrect) {
              correctCount++;
            }
            
            print('[AssessmentProvider] MAIN-Q ${question.questionId} -> $targetCategory (Correct: $isCorrect)');
          }
          
          categoryCorrect[targetCategory] = correctCount;
        }
      } else {
        print('[AssessmentProvider] WARNING: Unknown category $targetCategory');
      }
    }

    // Build results
    List<Map<String, dynamic>> categoryScores = [];
    for (final category in allCategories) {
      final total = categoryTotals[category] ?? 0;
      final correct = categoryCorrect[category] ?? 0;
      final score = total > 0 ? ((correct / total) * 100).round() : 0;
      
      categoryScores.add({
        'categoryName': category,
        'totalQuestions': total,
        'correctAnswers': correct,
        'score': score,
        'isPassed': score >= 75,
        'passingThreshold': 75,
      });
      
      if (total > 0) {
        print('[AssessmentProvider] Category $category: $correct/$total (${score}%)');
      }
    }

    return categoryScores;
  }

  /// Helper method to detect category from question ID
  String _detectCategoryFromQuestionId(String questionId) {
    final id = questionId.toUpperCase();
    
    if (id.startsWith('AK_') || id.contains('_AK_') || id.startsWith('PRE_AK')) {
      return 'Alphabet Knowledge';
    } else if (id.startsWith('PA_') || id.contains('_PA_') || id.startsWith('PRE_PA')) {
      return 'Phonological Awareness';
    } else if (id.startsWith('DC_') || id.contains('_DC_') || id.startsWith('PRE_DC')) {
      return 'Decoding';
    } else if (id.startsWith('WR_') || id.contains('_WR_') || id.startsWith('PRE_WR')) {
      return 'Word Recognition';
    } else if (id.startsWith('RC_') || id.contains('_RC_') || id.startsWith('PRE_RC')) {
      return 'Reading Comprehension';
    } else {
      // Fallback based on current assessment category
      return _currentCategory ?? 'Alphabet Knowledge';
    }
  }

  // Helper method for max value
  int max(int a, int b) {
    return a > b ? a : b;
  }


  /// Validate assessment loading and category distribution
  void validateAssessmentLoading() {
    print('\n========== ASSESSMENT VALIDATION ==========');
    
    if (_assessment == null) {
      print('❌ ERROR: No assessment loaded');
      return;
    }
    
    print('Assessment Type: ${_isPreAssessment ? "PRE" : "MAIN"}');
    print('Assessment ID: ${_assessment!.assessmentId}');
    print('Current Category: $_currentCategory');
    print('Questions Loaded: ${_questions.length}');
    
    if (_isPreAssessment) {
      print('✅ PRE-ASSESSMENT: Should have questions from multiple categories');
      
      // Count questions by category
      Map<String, int> categoryCount = {};
      for (final q in _questions) {
        final category = _detectCategoryFromQuestionId(q.questionId);
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
      
      categoryCount.forEach((category, count) {
        print('   - $category: $count questions');
      });
      
    } else {
      print('✅ MAIN ASSESSMENT: Should have questions from ONE category only');
      print('   - Expected Category: $_currentCategory');
      print('   - Question Count: ${_questions.length}');
      
      // Verify all questions belong to the same category
      Set<String> categories = {};
      for (final q in _questions) {
        // For main assessments, all questions should map to current category
        categories.add(_currentCategory ?? 'Unknown');
      }
      
      if (categories.length == 1) {
        print('   - ✅ All questions belong to: ${categories.first}');
      } else {
        print('   - ❌ Questions span multiple categories: $categories');
      }
    }
    
    print('==========================================\n');
  }



  // NEW: Get original question data for phonological questions
  Map<String, dynamic>? getOriginalQuestionData(String questionId) {
    // First try to get from rawQuestionData (most reliable source)
    if (_rawQuestionData.containsKey(questionId)) {
      return _rawQuestionData[questionId];
    }

    // Try to get from assessment's originalQuestionsData if available
    if (_assessment?.originalQuestionsData != null && _assessment!.originalQuestionsData!.isNotEmpty) {
      try {
        final questionData = _assessment!.originalQuestionsData!
            .firstWhere((q) => q['questionId'] == questionId);
        return questionData;
      } catch (e) {
        print('[AssessmentProvider] Question not found in originalQuestionsData: $questionId');
      }
    }

    // Fallback: try to find in current questions list
    if (_questions.isNotEmpty) {
      try {
        final question = _questions.firstWhere((q) => q.questionId == questionId);
        // If question has questionSet data, return it
        if (question.questionSet != null) {
          return {'questionSet': question.questionSet};
        }
      } catch (e) {
        print('[AssessmentProvider] Question not found in questions list: $questionId');
      }
    }

    print('[AssessmentProvider] No original question data found for: $questionId');
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // CATEGORY ASSESSMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Load assessment data for a specific category
  Future<void> loadCategoryAssessment({
    required String category,
    String? readingLevel,
    int? assessmentId,
  }) async {
    try {
      _errorMessage = null;
      _isAssessmentComplete = false;
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _score = 0;
      _currentCategory = category;
      _isPreAssessment = false;
      _assessmentStartTime = DateTime.now();
      
      print('[AssessmentProvider] Loading category assessment: $category');
      
      // Load from database
      final dbService = DatabaseService();
      final assessmentData = await dbService.loadAssessmentByCategory(
        category: category,
        readingLevel: readingLevel,
        assessmentId: assessmentId,
      );
      
      if (assessmentData == null) {
        _errorMessage = 'No assessment found for category: $category';
        print('[AssessmentProvider] $_errorMessage');
        notifyListeners();
        return;
      }
      
      // Parse assessment data
      _assessment = Assessment.fromMap(assessmentData);
      _questions = _assessment!.questions;
      
      // Store raw question data for complex question types
      _storeRawQuestionData(_assessment!);
      
      print('[AssessmentProvider] Loaded ${_questions.length} questions for category: $category');
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load category assessment: $e';
      print('[AssessmentProvider] Error: $_errorMessage');
      notifyListeners();
    }
  }

  /// Load Alphabet Knowledge Assessment specifically from main_assessment collection
  Future<void> loadAlphabetKnowledgeAssessment({String? readingLevel}) async {
    try {
      print('[AssessmentProvider] ===== LOADING ALPHABET KNOWLEDGE ASSESSMENT FROM MAIN_ASSESSMENT =====');

      _clearAssessmentData();
      _isPreAssessment = false; // CRITICAL: Mark as main assessment
      _currentCategory = 'Alphabet Knowledge';

      // Get the user's reading level - either from parameter or from database
      String? userReadingLevel = readingLevel;
      
      if (userReadingLevel == null) {
        print('[AssessmentProvider] No reading level provided, attempting to get from database');
        userReadingLevel = await _getCurrentUserReadingLevel();
      }

      print('[AssessmentProvider] Current user reading level: $userReadingLevel');

      if (userReadingLevel == null) {
        throw Exception('Unable to determine user reading level');
      }

      print('[AssessmentProvider] Loading from main_assessment collection with category: Alphabet Knowledge and readingLevel: $userReadingLevel');

      // Load the Alphabet Knowledge assessment that matches the user's reading level
      final assessment = await _repository.getMainAssessment(
        'alphabet_knowledge_${userReadingLevel.toLowerCase().replaceAll(' ', '_')}', // Create specific ID based on reading level
        readingLevel: userReadingLevel, // Match the user's specific reading level
        category: 'Alphabet Knowledge',
      );

      if (assessment == null) {
        throw Exception('No Alphabet Knowledge assessment found for reading level: $userReadingLevel');
      }
      
      print('[AssessmentProvider] Main assessment loaded with ${assessment.questions.length} questions');
      
      // Verify this is actually an Alphabet Knowledge assessment
      final alphabetQuestions = assessment.questions.where((question) {
        // Check if the question belongs to Alphabet Knowledge category
        final isAlphabetKnowledge = question.category?.toLowerCase() == 'alphabet knowledge' ||
                                   question.questionId.startsWith('AK_') ||
                                   question.questionTypeId == 'alphabet_knowledge';
        
        print('[AssessmentProvider] Question ${question.questionId}: category=${question.category}, type=${question.questionType}, isAlphabetKnowledge=$isAlphabetKnowledge');
        return isAlphabetKnowledge;
      }).toList();
      
      print('[AssessmentProvider] Found ${alphabetQuestions.length} alphabet knowledge questions');
      
      if (alphabetQuestions.isEmpty) {
        throw Exception('No Alphabet Knowledge questions found in the assessment');
      }
      
      // Update the assessment with filtered questions if needed
      if (alphabetQuestions.length != assessment.questions.length) {
        final filteredAssessment = Assessment(
          assessmentId: assessment.assessmentId,
          title: assessment.title,
          description: assessment.description,
          totalQuestions: alphabetQuestions.length,
          continueButtonText: assessment.continueButtonText,
          language: assessment.language,
          type: assessment.type,
          status: assessment.status,
          questions: alphabetQuestions,
          categoryCounts: {'Alphabet Knowledge': alphabetQuestions.length},
        );
        
        _assessment = filteredAssessment;
        _questions = alphabetQuestions;
      } else {
        _assessment = assessment;
        _questions = assessment.questions;
      }

      // Store raw question data for UI access
      _storeRawQuestionData(_assessment!);

      print('[AssessmentProvider] Successfully loaded ALPHABET KNOWLEDGE ASSESSMENT from main_assessment:');
      print('[AssessmentProvider] - Title: ${_assessment!.title}');
      print('[AssessmentProvider] - Total questions: ${_assessment!.totalQuestions}');
      print('[AssessmentProvider] - Questions loaded: ${_questions.length}');
      print('[AssessmentProvider] - Assessment category: $_currentCategory');
      print('[AssessmentProvider] - Assessment type: ${_assessment!.type}');

      notifyListeners();
    } catch (e) {
      print('[AssessmentProvider] Error loading alphabet knowledge assessment: $e');
      _errorMessage = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// Load Phonological Awareness Assessment from main_assessment collection
  Future<void> loadPhonologicalAwarenessAssessment({String? readingLevel}) async {
    try {
      print('[AssessmentProvider] ===== LOADING PHONOLOGICAL AWARENESS FROM MAIN_ASSESSMENT =====');
      
      _clearAssessmentData();
      _isPreAssessment = false; // Mark as main assessment
      _currentCategory = 'Phonological Awareness';
      
      // Get the user's reading level if not provided
      String? userReadingLevel = readingLevel;
      if (userReadingLevel == null) {
        userReadingLevel = await _getCurrentUserReadingLevel();
      }
      
      print('[AssessmentProvider] Loading Phonological Awareness from main_assessment collection');
      print('[AssessmentProvider] User reading level: $userReadingLevel');
      
      // Load from main_assessment collection
      final assessment = await _repository.getPhonologicalAwarenessAssessment(
        readingLevel: userReadingLevel,
      );
      
      if (assessment == null) {
        throw Exception('No Phonological Awareness assessment found in main_assessment collection');
      }
      
      print('[AssessmentProvider] Successfully loaded Phonological Awareness assessment');
      print('[AssessmentProvider] Questions count: ${assessment.questions.length}');
      
      // Filter questions for Phonological Awareness category
      final phonologicalQuestions = assessment.questions.where((question) {
        // Check if the question belongs to Phonological Awareness category
        // Based on the MongoDB data structure, phonological awareness questions have:
        // - questionId starting with "PA_"
        // - questionType of "malapantig"
        // - questionTypeId of "phonological_awareness"
        final isPhonologicalAwareness = question.questionId.startsWith('PA_') || 
                                       question.questionType == 'malapantig' ||
                                       question.questionTypeId == 'phonological_awareness';
        
        print('[AssessmentProvider] Question ${question.questionId}: type=${question.questionType}, typeId=${question.questionTypeId}, isPhonologicalAwareness=$isPhonologicalAwareness');
        return isPhonologicalAwareness;
      }).toList();
      
      print('[AssessmentProvider] Filtered ${phonologicalQuestions.length} phonological awareness questions');
      for (final question in phonologicalQuestions) {
        print('[AssessmentProvider] ===== QUESTION DEBUG ${question.questionId} =====');
        print('[AssessmentProvider] Question ID: ${question.questionId}');
        print('[AssessmentProvider] Question Type: ${question.questionType}');
        print('[AssessmentProvider] Question TypeId: ${question.questionTypeId}');
        print('[AssessmentProvider] Has questionSet: ${question.questionSet != null}');
        
        if (question.questionSet != null) {
          final questionSet = question.questionSet!;
          print('[AssessmentProvider] Raw questionSet data: $questionSet');
          print('[AssessmentProvider] AudioTexts: ${questionSet['audioTexts']}');
          print('[AssessmentProvider] AudioTexts length: ${questionSet['audioTexts']?.length ?? 0}');
          print('[AssessmentProvider] MatchingOptions: ${questionSet['matchingOptions']}');
          print('[AssessmentProvider] MatchingOptions length: ${questionSet['matchingOptions']?.length ?? 0}');
          print('[AssessmentProvider] CorrectPairs: ${questionSet['correctPairs']}');
          print('[AssessmentProvider] CorrectPairs length: ${questionSet['correctPairs']?.length ?? 0}');
        } else {
          print('[AssessmentProvider] ❌ No questionSet found for ${question.questionId}');
        }
        print('[AssessmentProvider] ===== END QUESTION DEBUG ${question.questionId} =====');
      }
      
      if (phonologicalQuestions.isEmpty) {
        throw Exception('No phonological awareness questions found in main_assessment collection');
      }
      
      // Set the assessment and questions
      _assessment = assessment;
      _questions = phonologicalQuestions;

      // Store raw question data for UI access
      _storeRawQuestionData(assessment);

      print('[AssessmentProvider] Successfully loaded PHONOLOGICAL AWARENESS ASSESSMENT: ${assessment.title}');
      print('[AssessmentProvider] Total questions: ${assessment.totalQuestions}');
      print('[AssessmentProvider] Questions loaded: ${_questions.length}');
      print('[AssessmentProvider] Assessment category: $_currentCategory');
      print('[AssessmentProvider] Current question index: $_currentQuestionIndex');
      print('[AssessmentProvider] Assessment ID: ${assessment.assessmentId}');

      notifyListeners();
    } catch (e) {
      print('[AssessmentProvider] Error loading phonological awareness assessment: $e');
      _errorMessage = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// Load questions for a specific category
  Future<List<Question>> loadCategoryQuestions({
    required String category,
    String? readingLevel,
    int? limit,
  }) async {
    try {
      print('[AssessmentProvider] Loading questions for category: $category');
      
      final dbService = DatabaseService();
      final questionsData = await dbService.loadQuestionsByCategory(
        category: category,
        readingLevel: readingLevel,
        limit: limit,
      );
      
      final List<Question> questions = [];
      for (final questionData in questionsData) {
        try {
          questions.add(Question.fromMap(questionData));
        } catch (e) {
          print('[AssessmentProvider] Error parsing question: $e');
        }
      }
      
      print('[AssessmentProvider] Loaded ${questions.length} questions for category: $category');
      return questions;
    } catch (e) {
      print('[AssessmentProvider] Error loading category questions: $e');
      return [];
    }
  }

  /// Get available categories
  Future<List<String>> getAvailableCategories({String? readingLevel}) async {
    try {
      final dbService = DatabaseService();
      final categories = await dbService.getAvailableCategories(
        readingLevel: readingLevel,
      );
      
      print('[AssessmentProvider] Available categories: $categories');
      return categories;
    } catch (e) {
      print('[AssessmentProvider] Error getting available categories: $e');
      return [];
    }
  }

  /// Initialize category assessment with specific data
  void initializeCategoryAssessment({
    required String category,
    required List<Question> questions,
    String? readingLevel,
  }) {
    try {
      _errorMessage = null;
      _isAssessmentComplete = false;
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _score = 0;
      _currentCategory = category;
      _isPreAssessment = false;
      _assessmentStartTime = DateTime.now();
      _questions = questions;
      
      // Create assessment object
      _assessment = Assessment(
        assessmentId: 'category_${category.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        title: '$category Assessment',
        description: 'Assessment for $category category',
        totalQuestions: questions.length,
        type: 'main_assessment',
        questions: questions,
        category: category,
        primaryCategory: category,
        readingLevel: readingLevel,
        isActive: true,
      );
      
      // Store raw question data
      _storeRawQuestionData(_assessment!);
      
      print('[AssessmentProvider] Initialized category assessment: $category with ${questions.length} questions');
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize category assessment: $e';
      print('[AssessmentProvider] Error: $_errorMessage');
      notifyListeners();
    }
  }

  /// Get category-specific data for current question
  Map<String, dynamic>? getCurrentQuestionCategoryData() {
    final currentQ = currentQuestion;
    if (currentQ == null) return null;
    
    final categoryData = <String, dynamic>{};
    
    // Add category-specific fields
    if (currentQ.dragElements != null) {
      categoryData['dragElements'] = currentQ.dragElements;
    }
    if (currentQ.correctSequence != null) {
      categoryData['correctSequence'] = currentQ.correctSequence;
    }
    if (currentQ.wordChoices != null) {
      categoryData['wordChoices'] = currentQ.wordChoices;
    }
    if (currentQ.sentenceWithBlank != null) {
      categoryData['sentenceWithBlank'] = currentQ.sentenceWithBlank;
    }
    if (currentQ.correctAnswer != null) {
      categoryData['correctAnswer'] = currentQ.correctAnswer;
    }
    if (currentQ.displaySequence != null) {
      categoryData['displaySequence'] = currentQ.displaySequence;
    }
    if (currentQ.questionSet != null) {
      categoryData['questionSet'] = currentQ.questionSet;
    }
    
    return categoryData.isNotEmpty ? categoryData : null;
  }

  /// Check if current assessment is category-specific
  bool get isCategoryAssessment => _currentCategory != null;
  
  /// Get current category name
  String? get categoryName => _currentCategory;

  /// Record response from specialized assessment screens (e.g., Reading Comprehension)
  void recordReadingComprehensionResponse(
    String questionKey,
    String userAnswer,
    String correctAnswer,
    bool isCorrect,
  ) {
    print('[AssessmentProvider] ===== RECORDING RC RESPONSE =====');
    print('[AssessmentProvider] Question Key: $questionKey');
    print('[AssessmentProvider] User Answer: $userAnswer');
    print('[AssessmentProvider] Correct Answer: $correctAnswer');
    print('[AssessmentProvider] Is Correct: $isCorrect');
    print('[AssessmentProvider] Responses before: ${_responses.length}');
    
    // Add response to tracking list
    _responses.add({
      'questionId': questionKey,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'timestamp': DateTime.now().toIso8601String(),
      'category': 'Reading Comprehension',
    });

    print('[AssessmentProvider] Responses after: ${_responses.length}');
    print('[AssessmentProvider] ===== END RECORDING RC RESPONSE =====');

    // Update score if correct (same as other categories)
    if (isCorrect) {
      _score++;
      print('[AssessmentProvider] Correct RC answer! Current score: $_score');
    } else {
      print('[AssessmentProvider] Incorrect RC answer. Current score: $_score');
    }
    
    print('[AssessmentProvider] Recorded RC response: $questionKey = $userAnswer (${isCorrect ? "✓" : "✗"})');
    notifyListeners();
  }

  /// Record response from other specialized screens
  void recordResponse(
    String questionId,
    String userAnswer,
    String correctAnswer,
    bool isCorrect,
    String category,
  ) {
    _responses.add({
      'questionId': questionId,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'timestamp': DateTime.now().toIso8601String(),
      'category': category,
    });

    // Update score if correct
    if (isCorrect) {
      _score++;
    }

    print('[AssessmentProvider] Recorded $category response: $questionId = $userAnswer (${isCorrect ? "✓" : "✗"})');
    notifyListeners();
  }

  /// Clear responses (called when starting new assessment)
  void _clearResponses() {
    _responses.clear();
  }

  /// Set current user ID for tracking purposes
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    print('[AssessmentProvider] Current user ID set: $userId');
  }

  /// Save individual question response to MongoDB in new format
  Future<void> saveIndividualResponse({
    required String questionId,
    required String category,
    required String questionType,
    required List<String> response,
    required bool isCorrect,
    required int responseTime,
  }) async {
    if (_currentUserId == null) {
      print('[AssessmentProvider] Error: No user ID set for saving individual response');
      return;
    }

    try {
      final responseData = {
        'studentId': int.tryParse(_currentUserId!) ?? _currentUserId,
        'assessmentId': _assessment?.assessmentId ?? 'PRE_ASSESSMENT_001',
        'questionId': questionId,
        'category': category,
        'questionType': questionType,
        'response': response,
        'isCorrect': isCorrect,
        'responseTime': responseTime,
        'answeredAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      final result = await _databaseService.saveIndividualQuestionResponse(responseData);

      if (result) {
        print('[AssessmentProvider] Successfully saved individual response for $questionId');
      } else {
        print('[AssessmentProvider] Failed to save individual response for $questionId');
      }
    } catch (e) {
      print('[AssessmentProvider] Error saving individual response: $e');
    }
  }

  /// Record phonological response (specific to PhonologicalMatching screen)
  void recordPhonologicalResponse(
    String questionId,
    List<Map<String, String>> responseData,
    int correctMatches,
    int totalMatches,
    bool isOverallCorrect,
  ) {
    // Store the complex phonological response data
    _responses.add({
      'questionId': questionId,
      'userAnswer': responseData.toString(), // Convert to string for storage
      'correctAnswer': 'N/A', // No single correct answer for matching
      'isCorrect': isOverallCorrect,
      'timestamp': DateTime.now().toIso8601String(),
      'category': 'Phonological Awareness',
      'correctMatches': correctMatches,
      'totalMatches': totalMatches,
      'responseData': responseData,
    });

    // Update score if correct
    if (isOverallCorrect) {
      _score++;
    }

    print('[AssessmentProvider] Recorded Phonological response: $questionId = $correctMatches/$totalMatches (${isOverallCorrect ? "✓" : "✗"})');
    notifyListeners();
  }

  /// Load Reading Comprehension Assessment from main_assessment collection
  Future<void> loadReadingComprehensionAssessment({String? readingLevel}) async {
    try {
      print('[AssessmentProvider] ===== LOADING READING COMPREHENSION FROM MAIN_ASSESSMENT =====');
      print('[AssessmentProvider] Target reading level: $readingLevel');

      _clearAssessmentData();
      _isPreAssessment = false; // Mark as main assessment
      _currentCategory = 'Reading Comprehension';

      // Get the user's reading level - either from parameter or from database
      String? userReadingLevel = readingLevel;
      
      if (userReadingLevel == null) {
        print('[AssessmentProvider] No reading level provided, attempting to get from database');
        userReadingLevel = await _getCurrentUserReadingLevel();
      }

      print('[AssessmentProvider] Current user reading level: $userReadingLevel');

      if (userReadingLevel == null) {
        throw Exception('Unable to determine user reading level');
      }

      print('[AssessmentProvider] Loading Reading Comprehension from main_assessment collection');

      // Load the Reading Comprehension assessment from the repository
      final assessment = await _repository.getReadingComprehensionAssessment(
        readingLevel: userReadingLevel,
      );

      if (assessment == null) {
        throw Exception('No Reading Comprehension assessment found for reading level: $userReadingLevel');
      }
      
      print('[AssessmentProvider] Main assessment loaded with ${assessment.questions.length} questions');
      
      // Verify this is actually a Reading Comprehension assessment
      final rcQuestions = assessment.questions.where((question) {
        // Check if the question belongs to Reading Comprehension category
        final isReadingComprehension = question.category?.toLowerCase() == 'reading comprehension' ||
                                     question.questionId.startsWith('RC_') ||
                                     question.questionTypeId == 'reading_comprehension';
        
        print('[AssessmentProvider] Question ${question.questionId}: category=${question.category}, type=${question.questionType}, isReadingComprehension=$isReadingComprehension');
        return isReadingComprehension;
      }).toList();
      
      print('[AssessmentProvider] Found ${rcQuestions.length} reading comprehension questions');
      
      if (rcQuestions.isEmpty) {
        throw Exception('No Reading Comprehension questions found in the assessment');
      }
      
      // Update the assessment with filtered questions if needed
      if (rcQuestions.length != assessment.questions.length) {
        final filteredAssessment = Assessment(
          assessmentId: assessment.assessmentId,
          title: assessment.title,
          description: assessment.description,
          totalQuestions: rcQuestions.length,
          continueButtonText: assessment.continueButtonText,
          language: assessment.language,
          type: assessment.type,
          status: assessment.status,
          questions: rcQuestions,
          categoryCounts: {'Reading Comprehension': rcQuestions.length},
        );
        
        _assessment = filteredAssessment;
        _questions = rcQuestions;
      } else {
        _assessment = assessment;
        _questions = assessment.questions;
      }

      // Store raw question data for UI access
      _storeRawQuestionData(_assessment!);

      print('[AssessmentProvider] Successfully loaded READING COMPREHENSION ASSESSMENT from main_assessment:');
      print('[AssessmentProvider] - Title: ${_assessment!.title}');
      print('[AssessmentProvider] - Total questions: ${_assessment!.totalQuestions}');
      print('[AssessmentProvider] - Questions loaded: ${_questions.length}');
      print('[AssessmentProvider] - Assessment category: $_currentCategory');
      print('[AssessmentProvider] - Assessment type: ${_assessment!.type}');

      notifyListeners();
    } catch (e) {
      print('[AssessmentProvider] Error loading reading comprehension assessment: $e');
      _errorMessage = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// Load specific Phonological Awareness question from database
  Future<Question?> loadPhonologicalAwarenessQuestion(String questionId, {String? readingLevel}) async {
    try {
      print('[AssessmentProvider] Loading Phonological Awareness question: $questionId');
      
      // Get the user's reading level if not provided
      String? userReadingLevel = readingLevel;
      if (userReadingLevel == null) {
        userReadingLevel = await _getCurrentUserReadingLevel();
      }
      
      // Load the specific question from the repository
      final question = await _repository.getPhonologicalAwarenessQuestion(
        questionId,
        readingLevel: userReadingLevel,
      );
      
      if (question != null) {
        print('[AssessmentProvider] Successfully loaded question: ${question.questionId}');
        print('[AssessmentProvider] - QuestionSet: ${question.questionSet != null}');
        if (question.questionSet != null) {
          print('[AssessmentProvider] - AudioTexts: ${question.questionSet!['audioTexts']?.length ?? 0}');
          print('[AssessmentProvider] - MatchingOptions: ${question.questionSet!['matchingOptions']?.length ?? 0}');
          print('[AssessmentProvider] - CorrectPairs: ${question.questionSet!['correctPairs']?.length ?? 0}');
        }
      } else {
        print('[AssessmentProvider] Question not found: $questionId');
      }
      
      return question;
    } catch (e) {
      print('[AssessmentProvider] Error loading Phonological Awareness question: $e');
      return null;
    }
  }

  /// Load specific Reading Comprehension question from database
  Future<Question?> loadReadingComprehensionQuestion(String questionId, {String? readingLevel}) async {
    try {
      print('[AssessmentProvider] Loading Reading Comprehension question: $questionId');
      
      // Get the user's reading level if not provided
      String? userReadingLevel = readingLevel;
      if (userReadingLevel == null) {
        userReadingLevel = await _getCurrentUserReadingLevel();
      }
      
      // Load the specific question from the repository
      final question = await _repository.getReadingComprehensionQuestion(
        questionId,
        readingLevel: userReadingLevel,
      );
      
      if (question != null) {
        print('[AssessmentProvider] Successfully loaded question: ${question.questionId}');
        print('[AssessmentProvider] - Passages: ${question.passages?.length ?? 0}');
        print('[AssessmentProvider] - Sentence Questions: ${question.sentenceQuestions?.length ?? 0}');
      } else {
        print('[AssessmentProvider] Question not found: $questionId');
      }
      
      return question;
    } catch (e) {
      print('[AssessmentProvider] Error loading Reading Comprehension question: $e');
      return null;
    }
  }

  /// Test method to verify Reading Comprehension database connection
  Future<bool> testReadingComprehensionConnection() async {
    try {
      print('[AssessmentProvider] ===== TESTING READING COMPREHENSION CONNECTION =====');
      
      // Test loading Reading Comprehension assessment
      await loadReadingComprehensionAssessment();
      
      if (_assessment != null && _questions.isNotEmpty) {
        print('[AssessmentProvider] ✅ SUCCESS: Reading Comprehension data loaded from database');
        print('[AssessmentProvider] - Assessment ID: ${_assessment!.assessmentId}');
        print('[AssessmentProvider] - Questions loaded: ${_questions.length}');
        print('[AssessmentProvider] - Category: $_currentCategory');
        
        // Test loading a specific question
        if (_questions.isNotEmpty) {
          final firstQuestion = _questions.first;
          print('[AssessmentProvider] Testing specific question: ${firstQuestion.questionId}');
          print('[AssessmentProvider] - Passages: ${firstQuestion.passages?.length ?? 0}');
          print('[AssessmentProvider] - Sentence Questions: ${firstQuestion.sentenceQuestions?.length ?? 0}');
        }
        
        return true;
      } else {
        print('[AssessmentProvider] ❌ FAILED: No Reading Comprehension data loaded');
        return false;
      }
    } catch (e) {
      print('[AssessmentProvider] ❌ ERROR: Failed to test Reading Comprehension connection: $e');
      return false;
    }
  }

  /// Get the current user's reading level from the users collection
  Future<String?> _getCurrentUserReadingLevel() async {
    try {
      // First try to get reading level from AuthProvider if available
      try {
        // This is a fallback - try to get reading level from AuthProvider context
        // Note: This might not work in all contexts, but it's worth trying
        print('[AssessmentProvider] Attempting to get reading level from AuthProvider context');
        // We can't directly access AuthProvider here, so we'll rely on the database lookup
      } catch (e) {
        print('[AssessmentProvider] Could not access AuthProvider context: $e');
      }

      // Get the current user ID from the provider
      if (_currentUserId == null) {
        print('[AssessmentProvider] No current user ID set, cannot determine reading level');
        return null;
      }

      print('[AssessmentProvider] Getting reading level for user: $_currentUserId');

      // Connect to the "test" database to get user data
      final uri = dotenv.env['MONGO_URI'];
      if (uri == null || uri.isEmpty) {
        throw Exception('MONGO_URI not found in .env');
      }

      // Modify URI to point to "test" database
      final testUri = uri.replaceFirstMapped(
        RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
        (m) => 'mongodb${m[1] ?? ''}://${m[2]}/test',
      );

      print('[AssessmentProvider] Connecting to test database for user data');
      final testDb = await Db.create(testUri);
      await testDb.open();

      final usersCollection = testDb.collection('users');
      
      // Find user by idNumber
      final userDoc = await usersCollection.findOne(where.eq('idNumber', _currentUserId));
      
      if (userDoc != null) {
        final readingLevel = userDoc['readingLevel']?.toString();
        print('[AssessmentProvider] Found user reading level: $readingLevel');
        await testDb.close();
        return readingLevel;
      } else {
        print('[AssessmentProvider] User not found with idNumber: $_currentUserId');
        await testDb.close();
        return null;
      }
    } catch (e) {
      print('[AssessmentProvider] Error getting user reading level: $e');
      return null;
    }
  }
}
