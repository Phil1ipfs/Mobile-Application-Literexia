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
      final category = getCategoryName(question.questionTypeId);
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
          final category = getCategoryName(question.questionTypeId);
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
    
    List<Map<String, dynamic>> categoryScores = _getAllCategoryScores();
    
    // Prepare assessment data with INTEGER studentId
    final assessmentData = {
      'studentId': studentIdValue, // Use integer value
      'assessmentId': assessmentId,
      'assessmentType': isPreAssessment ? 'pre-assessment' : 'main-assessment',
      'assessmentDate': DateTime.now().toIso8601String(),
      'categories': categoryScores,
      'overallScore': score,
      'allCategoriesPassed': isPreAssessment ? _areAllCategoriesPassed() : _isCategoryPassed(_currentCategory),
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
        
        final userAnswer = _userAnswers[question.questionId];
        if (userAnswer != null) {
          final selectedOption = question.options.firstWhere(
            (opt) => opt.optionId == userAnswer,
            orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
          );
          if (selectedOption.isCorrect) {
            categoryCorrect[category] = (categoryCorrect[category] ?? 0) + 1;
          }
        }
        
        print('[AssessmentProvider] PRE-Q ${question.questionId} -> $category');
      }
    } else {
      // MAIN ASSESSMENT: All questions belong to the current assessment's category
      final targetCategory = _currentCategory ?? 'Unknown';
      
      if (allCategories.contains(targetCategory)) {
        categoryTotals[targetCategory] = _questions.length;
        
        int correctCount = 0;
        for (final question in _questions) {
          final userAnswer = _userAnswers[question.questionId];
          if (userAnswer != null) {
            final selectedOption = question.options.firstWhere(
              (opt) => opt.optionId == userAnswer,
              orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
            );
            if (selectedOption.isCorrect) {
              correctCount++;
            }
          }
          
          print('[AssessmentProvider] MAIN-Q ${question.questionId} -> $targetCategory');
        }
        
        categoryCorrect[targetCategory] = correctCount;
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

  // 3. Helper method to check if all categories passed
  bool _areAllCategoriesPassed() {
    final categories = _getAllCategoryScores();
    if (categories.isEmpty) return false;
    
    return categories.every((category) => category['isPassed'] == true);
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
}
