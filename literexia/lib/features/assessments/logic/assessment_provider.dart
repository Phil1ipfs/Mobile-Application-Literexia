// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import 'package:flutter/material.dart';
import '../repositories/assessment_repository.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../services/database_service.dart';

class AssessmentProvider extends ChangeNotifier {
  final AssessmentRepository _repository = AssessmentRepository();

  Assessment? _assessment;
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {};
  bool _isAssessmentComplete = false;
  int _score = 0;
  String? _errorMessage;
  String? _readingLevel;
  List<Question> _questions = [];

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

  // Getters
  Assessment? get assessment => _assessment;
  int get currentQuestionIndex => _currentQuestionIndex;
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
        'options': question.options
            .map((option) => {
                  'optionId': option.optionId,
                  'optionText': option.optionText,
                  'isCorrect': option.isCorrect,
                })
            .toList(),
      };

      print(
          '[AssessmentProvider] Stored data for question ${question.questionId}:');
      print('  - Passages: ${question.passages?.length ?? 0}');
      print(
          '  - Sentence Questions: ${question.sentenceQuestions?.length ?? 0}');
    }
  }

  /// Load PRE-ASSESSMENT for new users (called from login screen)
  Future<void> loadPreAssessment() async {
    try {
      print('[AssessmentProvider] ===== LOADING PRE-ASSESSMENT =====');
      print('[AssessmentProvider] Clearing previous assessment data');

      _clearAssessmentData();
      _isPreAssessment = true; // CRITICAL: Mark as pre-assessment

      print('[AssessmentProvider] Loading pre-assessment from repository');
      // Load pre-assessment from repository
      final assessment = await _repository.getPreAssessment();

      if (assessment != null) {
        _assessment = assessment;
        _questions = assessment.questions;

        // FIXED: Store raw question data for UI access
        _storeRawQuestionData(assessment);

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
  /// Now with proper reading level context
  Future<void> loadMainAssessment(dynamic assessmentId,
      {String? readingLevel}) async {
    try {
      print('[AssessmentProvider] ===== LOADING MAIN ASSESSMENT =====');
      print('[AssessmentProvider] Assessment ID: $assessmentId');
      print('[AssessmentProvider] Reading level: $readingLevel');

      // Determine the reading level to use
      String? targetReadingLevel = readingLevel;

      // If no reading level provided, try to get from current user context
      if (targetReadingLevel == null || targetReadingLevel.isEmpty) {
        print(
            '[AssessmentProvider] No reading level provided for main assessment');
      }

      print('[AssessmentProvider] Clearing previous assessment data');
      _clearAssessmentData();
      _isPreAssessment = false; // CRITICAL: Mark as main assessment

      print('[AssessmentProvider] Loading main assessment from repository');
      // Load main assessment from repository WITH reading level context
      final assessment = await _repository.getMainAssessment(assessmentId,
          readingLevel: targetReadingLevel);

      if (assessment != null) {
        _assessment = assessment;
        _questions = assessment.questions;

        // FIXED: Store raw question data for UI access
        _storeRawQuestionData(assessment);

        print(
            '[AssessmentProvider] Successfully loaded MAIN ASSESSMENT: ${assessment.title}');
        print(
            '[AssessmentProvider] Total questions: ${assessment.totalQuestions}');
        print('[AssessmentProvider] Questions loaded: ${_questions.length}');
        print(
            '[AssessmentProvider] Marked as MAIN ASSESSMENT: $_isPreAssessment');

        notifyListeners();
      } else {
        print(
            '[AssessmentProvider] Failed to load main assessment - no data returned');
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

  /// Determine reading level from PRE-ASSESSMENT (for new users)
  void _determineReadingLevelFromPreAssessment() {
    if (_assessment == null) return;

    print('[AssessmentProvider] Determining reading level from PRE-ASSESSMENT');

    // Calculate overall percentage
    final overallPercentage = (_score / totalQuestions) * 100;

    // Apply CRLA reading level criteria specifically for pre-assessment
    if (overallPercentage <= 20) {
      _readingLevel = "Low Emerging";
    } else if (overallPercentage <= 40) {
      _readingLevel = "High Emerging";
    } else if (overallPercentage <= 60) {
      _readingLevel = "Developing";
    } else if (overallPercentage <= 80) {
      _readingLevel = "Transitioning";
    } else {
      _readingLevel = "At Grade Level";
    }

    // For pre-assessment, set a base reading percentage
    _readingPercentage = overallPercentage;

    print(
        '[AssessmentProvider] PRE-ASSESSMENT - Overall percentage: $overallPercentage%');
    print(
        '[AssessmentProvider] PRE-ASSESSMENT - Determined reading level: $_readingLevel');
  }

  /// Determine reading level from MAIN ASSESSMENT (for lesson progression)
  void _determineReadingLevelFromMainAssessment() {
    // Use existing logic for main assessment
    if (_assessment == null) return;

    print(
        '[AssessmentProvider] Determining reading level from MAIN ASSESSMENT');

    // Calculate scores by category following the guide's category structure
    Map<String, int> categoryScores = {};
    Map<String, int> categoryTotals = {};

    // Initialize categories
    for (final question in _questions) {
      final category = _getCategoryName(question.questionTypeId);
      categoryTotals[category] = (categoryTotals[category] ?? 0) + 1;
      categoryScores[category] = categoryScores[category] ?? 0;
    }

    // Calculate correct answers per category
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final userAnswer = _userAnswers[question.questionId];

      if (userAnswer != null) {
        final selectedOption = question.options.firstWhere(
          (opt) => opt.optionId == userAnswer,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        if (selectedOption.isCorrect) {
          final category = _getCategoryName(question.questionTypeId);
          categoryScores[category] = (categoryScores[category] ?? 0) + 1;
        }
      }
    }

    // Calculate category percentages
    Map<String, double> categoryPercentages = {};
    categoryScores.forEach((category, correct) {
      final total = categoryTotals[category] ?? 1;
      categoryPercentages[category] = (correct / total) * 100;
    });

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
        '[AssessmentProvider] MAIN ASSESSMENT - Category scores: $categoryPercentages');
    print(
        '[AssessmentProvider] MAIN ASSESSMENT - Overall percentage: $overallPercentage%');
    print(
        '[AssessmentProvider] MAIN ASSESSMENT - Determined reading level: $_readingLevel');
  }

  /// Map question type IDs to CRLA category names
  String _getCategoryName(String questionTypeId) {
    switch (questionTypeId) {
      case 'alphabet_knowledge':
        return 'Alphabet Knowledge';
      case 'phonological_awareness':
        return 'Phonological Awareness';
      case 'word_recognition':
        return 'Word Recognition';
      case 'reading_comprehension':
        return 'Reading Comprehension';
      case 'decoding':
        return 'Decoding';
      default:
        return 'Other';
    }
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
  Future<void> saveResults(String userId) async {
    try {
      print('[AssessmentProvider] ===== SAVING ASSESSMENT RESULTS =====');
      print('[AssessmentProvider] User ID: $userId');
      print(
          '[AssessmentProvider] Assessment Type: ${_isPreAssessment ? "PRE-ASSESSMENT" : "MAIN ASSESSMENT"}');
      print(
          '[AssessmentProvider] Reading Level: ${_readingLevel ?? "Undefined"}');
      print('[AssessmentProvider] Score: $_score/$totalQuestions');
      print('[AssessmentProvider] Reading Percentage: $_readingPercentage%');

      if (_assessment == null) {
        print(
            '[AssessmentProvider] Error: No assessment available to save results');
        return;
      }

      // Create correct answers map for validation
      Map<String, dynamic> correctAnswers = {};
      for (final question in _questions) {
        final correctOption = question.options.firstWhere(
          (opt) => opt.isCorrect,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );
        correctAnswers[question.questionId] = correctOption.optionId;
      }

      // CRITICAL: Route to correct save method based on assessment type
      bool saveSuccess = false;

      if (_isPreAssessment) {
        print(
            '[AssessmentProvider] ===== ROUTING TO PRE-ASSESSMENT SAVE =====');
        // Save to Pre_Assessment.user_response
        saveSuccess = await _repository.saveUserResponses(
          assessmentId: _assessment!.assessmentId,
          userId: userId,
          answers: _userAnswers,
          score: _score,
          readingLevel: _readingLevel ?? 'Undefined',
          readingPercentage: _readingPercentage,
          additionalData: {
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'assessmentStartTime': _assessmentStartTime?.toIso8601String(),
            'assessmentEndTime': DateTime.now().toIso8601String(),
            'readingMetrics': _readingMetrics,
            'assessmentType': 'pre_assessment',
            'isPreAssessment': true,
            'completedAt': DateTime.now().millisecondsSinceEpoch,
          },
        );
      } else {
        print(
            '[AssessmentProvider] ===== ROUTING TO MAIN ASSESSMENT SAVE =====');
        // Save to student_responses → category_results
        saveSuccess = await _repository.saveUserResponses(
          assessmentId: _assessment!.assessmentId,
          userId: userId,
          answers: _userAnswers,
          score: _score,
          readingLevel: _readingLevel ?? 'Undefined',
          readingPercentage: _readingPercentage,
          additionalData: {
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'assessmentStartTime': _assessmentStartTime?.toIso8601String(),
            'assessmentEndTime': DateTime.now().toIso8601String(),
            'readingMetrics': _readingMetrics,
            'assessmentType': 'main_assessment',
            'isPreAssessment': false,
            'completedAt': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }

      if (saveSuccess) {
        print(
            '[AssessmentProvider] ===== SUCCESSFULLY SAVED ${_isPreAssessment ? "PRE" : "MAIN"} ASSESSMENT RESULTS =====');

        // IMPORTANT: For pre-assessments, also update user profile
        if (_isPreAssessment) {
          print(
              '[AssessmentProvider] Updating user profile for pre-assessment completion');
          await _repository.updateUserReadingLevel(
            userId: userId,
            readingLevel: _readingLevel ?? 'Undefined',
            readingPercentage: _readingPercentage,
            preAssessmentCompleted: true,
          );
        }
      } else {
        print(
            '[AssessmentProvider] ===== FAILED TO SAVE ASSESSMENT RESULTS =====');
        throw Exception(
            'Failed to save ${_isPreAssessment ? "pre" : "main"} assessment results');
      }
    } catch (e) {
      print('[AssessmentProvider] Error saving results: $e');
      // Rethrow to allow caller to handle
      throw e;
    }
  }

  /// ENHANCED: Save detailed results with comprehensive data
  Future<void> saveDetailedResults(String userId, String assessmentId) async {
    if (_assessment == null) return;

    try {
      print('[AssessmentProvider] ===== SAVING DETAILED RESULTS =====');
      print('[AssessmentProvider] User: $userId, Assessment: $assessmentId');
      print(
          '[AssessmentProvider] Assessment Type: ${_isPreAssessment ? "PRE-ASSESSMENT" : "MAIN ASSESSMENT"}');

      // Calculate comprehensive metrics
      final timeTaken = _calculateTimeTaken();
      final categoryBreakdown = _calculateCategoryBreakdown();

      // Use DatabaseService directly for detailed saving
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      if (_isPreAssessment) {
        print(
            '[AssessmentProvider] ===== SAVING DETAILED PRE-ASSESSMENT RESULTS =====');

        // For pre-assessments, we need specialized data formatting
        // Calculate reading comprehension metrics specifically for pre-assessment
        int correctInReadingComp = 0;
        int readingCompQuestions = 0;

        // Count reading comprehension questions and correct answers
        for (final question in _questions) {
          if (question.questionTypeId == 'reading_comprehension') {
            readingCompQuestions++;
            final userAnswer = _userAnswers[question.questionId];
            if (userAnswer != null) {
              final selectedOption = question.options.firstWhere(
                (opt) => opt.optionId == userAnswer,
                orElse: () => AssessmentOption(
                    optionId: '', optionText: '', isCorrect: false),
              );

              if (selectedOption.isCorrect) {
                correctInReadingComp++;
              }
            }
          }
        }

        // Build category scores for pre-assessment
        Map<String, dynamic> categoryScores = {};
        categoryBreakdown.forEach((category, data) {
          categoryScores[category] = {
            'total': data['totalQuestions'] ?? 0,
            'correct': data['correctAnswers'] ?? 0,
            'score': data['score'] ?? 0,
          };
        });

        // Build difficulty breakdown (simplified)
        Map<String, dynamic> difficultyBreakdown = {
          'low_emerging': {'questions': 5, 'correct': 0, 'score': 0},
          'high_emerging': {'questions': 6, 'correct': 0, 'score': 0},
          'developing': {'questions': 8, 'correct': 0, 'score': 0},
          'transitioning': {'questions': 5, 'correct': 0, 'score': 0},
          'at_grade_level': {'questions': 1, 'correct': 0, 'score': 0},
        };

        // Calculate part1 score (questions 1-20 for pre-assessment)
        int part1Score = 0;
        for (int i = 0; i < min(20, _questions.length); i++) {
          final question = _questions[i];
          final userAnswer = _userAnswers[question.questionId];
          if (userAnswer != null) {
            final selectedOption = question.options.firstWhere(
              (opt) => opt.optionId == userAnswer,
              orElse: () => AssessmentOption(
                  optionId: '', optionText: '', isCorrect: false),
            );

            if (selectedOption.isCorrect) {
              part1Score++;
            }
          }
        }

        // Use our special method to save pre-assessment results
        final success = await dbService.savePreAssessmentResult(
          userId: userId,
          assessmentId: assessmentId,
          score: _score,
          readingLevel: _readingLevel ?? "Undefined",
          readingPercentage: _readingPercentage,
          answers: _userAnswers,
          additionalData: {
            'totalQuestions': totalQuestions,
            'part1Score': part1Score,
            'categoryScores': categoryScores,
            'difficultyBreakdown': difficultyBreakdown,
            'correctInReadingComp': correctInReadingComp,
            'readingCompQuestions': readingCompQuestions,
            'timeTaken': timeTaken,
            'allCategoriesPassed': _score >= (totalQuestions * 0.75),
          },
        );

        if (success) {
          print(
              '[AssessmentProvider] Pre-assessment detailed results saved successfully');
        } else {
          throw Exception('Failed to save detailed pre-assessment results');
        }
      } else {
        print(
            '[AssessmentProvider] ===== SAVING DETAILED MAIN ASSESSMENT RESULTS =====');

        // For main assessments, follow the guide's category_results structure
        final categoryResultId = await dbService.saveCategoryResult({
          'studentId': userId,
          'assessmentType': 'main-assessment',
          'assessmentDate': DateTime.now().toIso8601String(),
          'categories': categoryBreakdown.values.toList(),
          'overallScore': (_score / totalQuestions * 100).round(),
          'allCategoriesPassed': _score >= (totalQuestions * 0.75).round(),
          'readingLevel': _readingLevel ?? "Undefined",
          'readingLevelUpdated': true,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'isPreAssessment': false,
        });

        // Update student responses with category result ID
        if (categoryResultId.isNotEmpty) {
          await dbService.updateStudentResponsesCategoryId(
              userId, categoryResultId);
        }

        // Mark assessment as completed
        await dbService.markAssessmentAsCompleted(userId, assessmentId);

        print(
            '[AssessmentProvider] Main assessment detailed results saved successfully');
      }
    } catch (e) {
      print(
          '[AssessmentProvider] Error saving detailed assessment results: $e');
      throw e;
    }
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
      final category = _getCategoryName(question.questionTypeId);
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
          final category = _getCategoryName(question.questionTypeId);
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

  /// Get original question data (for reading comprehension passages)
  dynamic getOriginalQuestionData(String questionId) {
    return _rawQuestionData[questionId];
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
}
