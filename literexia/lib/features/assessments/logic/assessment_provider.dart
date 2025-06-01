// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import '../repositories/assessment_repository.dart';
import '../../../services/database_service.dart';

class AssessmentProvider with ChangeNotifier {
  final AssessmentRepository _repository = AssessmentRepository();
  final DatabaseService _dbService = DatabaseService();

  Assessment? _currentAssessment;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _userResponses = {};
  bool _isPreAssessment = false;
  String? _readingLevel;
  Map<String, dynamic>? _assessmentMetadata;
  int _currentQuestionIndex = 0;
  bool _isAssessmentComplete = false;
  int _score = 0;
  Map<String, dynamic> _rawQuestionData = {};

  // New properties for category_results based assessments
  String? _categoryResultsId;
  String? _currentCategory;
  List<String> _availableCategories = [];
  bool _isResumingAssessment = false;
  Map<String, dynamic> _readingMetrics = {
    'totalContentViewed': 0,
    'totalContentAvailable': 0,
    'timeSpentReading': 0,
  };

  // Getters
  Assessment? get currentAssessment => _currentAssessment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, String> get userResponses => _userResponses;
  bool get isPreAssessment => _isPreAssessment;
  String? get readingLevel => _readingLevel;
  Map<String, dynamic>? get assessmentMetadata => _assessmentMetadata;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isAssessmentComplete => _isAssessmentComplete;
  int get score => _score;
  int get totalQuestions => _currentAssessment?.questions.length ?? 0;
  Question? get currentQuestion =>
      _currentAssessment?.questions.length != null &&
              _currentQuestionIndex < _currentAssessment!.questions.length
          ? _currentAssessment!.questions[_currentQuestionIndex]
          : null;
  String? get categoryResultsId => _categoryResultsId;
  String? get currentCategory => _currentCategory;
  List<String> get availableCategories => _availableCategories;
  bool get isResumingAssessment => _isResumingAssessment;

  /// Load pre-assessment
  Future<void> loadPreAssessment() async {
    await loadAssessment(isPreAssessment: true);
  }

  /// Load main assessment
  Future<void> loadMainAssessment(
      {String? readingLevel, String? assessmentId}) async {
    await loadAssessment(
      isPreAssessment: false,
      readingLevel: readingLevel,
      assessmentId: assessmentId,
    );
  }

  /// Load assessment based on type and reading level
  Future<void> loadAssessment({
    required bool isPreAssessment,
    String? readingLevel,
    String? assessmentId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _isPreAssessment = isPreAssessment;
      _readingLevel = readingLevel;
      notifyListeners();

      if (isPreAssessment) {
        _currentAssessment = await _repository.getPreAssessment();
      } else {
        if (readingLevel == null || readingLevel.isEmpty) {
          throw Exception('Reading level is required for main assessment');
        }
        _currentAssessment = await _repository.getMainAssessment(
          assessmentId,
          readingLevel: readingLevel,
        );
      }

      if (_currentAssessment == null) {
        throw Exception('No assessment found for the specified criteria');
      }

      // Initialize metadata for tracking
      _assessmentMetadata = {
        'startTime': DateTime.now().toIso8601String(),
        'assessmentType':
            isPreAssessment ? 'pre_assessment' : 'main_assessment',
        'readingLevel': readingLevel,
        'assessmentId': _currentAssessment!.assessmentId,
      };

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize a new main assessment following the guide's flow
  Future<void> initializeMainAssessment(String readingLevel) async {
    try {
      _isLoading = true;
      _error = null;
      _isPreAssessment = false;
      _readingLevel = readingLevel;
      notifyListeners();

      // Get the user ID
      final userId = _dbService.currentUserId ?? 'unknown';

      // Initialize assessment following the guide's flow
      final result =
          await _repository.initializeMainAssessment(userId, readingLevel);

      // Set properties from result
      _categoryResultsId = result['categoryResultsId'];
      _currentCategory = result['currentCategory'];
      _availableCategories = List<String>.from(result['availableCategories']);
      _isResumingAssessment = result['isResumingAssessment'];

      if (_categoryResultsId == null || _currentCategory == null) {
        throw Exception('Failed to initialize assessment');
      }

      // Load questions for the current category
      await loadCategoryQuestions();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // In AssessmentProvider's loadCategoryQuestions method
  Future<void> loadCategoryQuestions() async {
    try {
      if (_currentCategory == null || _readingLevel == null) {
        throw Exception('Category or reading level not set');
      }

      _isLoading = true;
      notifyListeners();

      // Add diagnostic logging
      print('=========== QUESTION LOADING DIAGNOSTICS ===========');
      print('Reading Level: $_readingLevel');
      print('Category: $_currentCategory');
      print('CategoryResultsID: $_categoryResultsId');
      print('UserID: ${_dbService.currentUserId}');

      // Get questions for the current category
      print('Fetching questions from repository...');
      final questions = await _repository.getQuestionsForCurrentCategory(
        readingLevel: _readingLevel!,
        category: _currentCategory!,
      );

      // Log questions received
      print('Received ${questions.length} questions from repository');
      if (questions.isEmpty) {
        print('WARNING: No questions returned from repository!');
      } else {
        // Log first question details to verify format
        print('First question ID: ${questions[0].questionId}');
        print('First question text: ${questions[0].questionText}');
        print('First question has ${questions[0].options.length} options');
      }

      if (questions.isEmpty) {
        throw Exception('No questions found for category: $_currentCategory');
      }

      // Create assessment model
      _currentAssessment = Assessment(
        assessmentId: _categoryResultsId,
        title: 'Assessment: $_currentCategory',
        description: 'Assessment for $_readingLevel reading level',
        totalQuestions: questions.length,
        type: 'main_assessment',
        questions: questions,
        readingLevel: _readingLevel,
        category: _currentCategory,
      );
      // Update totalQuestions in category_results
      if (_categoryResultsId != null) {
        await _dbService.updateCategoryTotalQuestions(
          categoryResultsId: _categoryResultsId!,
          categoryName: _currentCategory!,
          totalQuestions: questions.length,
        );
      }

      // Set starting question index
      if (_isResumingAssessment) {
        await _setResumeQuestionIndex();
      } else {
        _currentQuestionIndex = 0;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
    print(
        'Assessment created with ${_currentAssessment?.questions.length ?? 0} questions');
    print('================================================');
  }

  /// Set the question index when resuming an assessment
  Future<void> _setResumeQuestionIndex() async {
    if (_categoryResultsId == null ||
        _currentCategory == null ||
        _currentAssessment == null) {
      return;
    }

    try {
      final categoryResults = await _dbService.getCategoryResultsForStudent(
        _dbService.currentUserId ?? 'unknown',
      );

      if (categoryResults != null) {
        final categories = categoryResults['categories'] as List;
        final currentCategoryObj = categories.firstWhere(
          (c) => c['categoryName'] == _currentCategory,
          orElse: () => null,
        );

        if (currentCategoryObj != null &&
            currentCategoryObj['lastQuestionAnswered'] != null) {
          final lastAnsweredId = currentCategoryObj['lastQuestionAnswered'];

          // Find the index of the last answered question
          int lastIndex = -1;
          for (int i = 0; i < _currentAssessment!.questions.length; i++) {
            if (_currentAssessment!.questions[i].questionId == lastAnsweredId) {
              lastIndex = i;
              break;
            }
          }

          // Set current index to the next question
          if (lastIndex != -1 &&
              lastIndex < _currentAssessment!.questions.length - 1) {
            _currentQuestionIndex = lastIndex + 1;
          } else {
            _currentQuestionIndex = 0;
          }
        }
      }
    } catch (e) {
      print('Error setting resume question index: $e');
      _currentQuestionIndex = 0;
    }
  }

  /// Save user response for a question
  void saveResponse(String questionId, String selectedOption) {
    _userResponses[questionId] = selectedOption;
    notifyListeners();
  }

  /// Answer current question following the guide's flow
  Future<void> answerCurrentQuestion(String optionId) async {
    if (_currentAssessment == null ||
        currentQuestion == null ||
        _categoryResultsId == null ||
        _currentCategory == null) {
      _error = 'Assessment not properly initialized';
      notifyListeners();
      return;
    }

    try {
      // Find the selected option
      final selectedOption = currentQuestion!.options.firstWhere(
        (opt) => opt.optionId == optionId,
        orElse: () =>
            AssessmentOption(optionId: '', optionText: '', isCorrect: false),
      );

      // Record the answer in category_results
      await _dbService.recordAnswerInCategoryResults(
        categoryResultsId: _categoryResultsId!,
        categoryName: _currentCategory!,
        questionId: currentQuestion!.questionId,
        selectedOption: optionId,
        isCorrect: selectedOption.isCorrect,
        responseTime: 0, // Could track this if needed
      );

      // Store in local state
      _userResponses[currentQuestion!.questionId] = optionId;

      // Update score if correct
      if (selectedOption.isCorrect) {
        _score++;
      }

      // Move to next question or complete category
      if (_currentQuestionIndex < _currentAssessment!.questions.length - 1) {
        _currentQuestionIndex++;
        notifyListeners();
      } else {
        // Category completed - check if there are more categories
        await _handleCategoryCompletion();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Handle category completion and determine next steps
  Future<void> _handleCategoryCompletion() async {
    try {
      if (_categoryResultsId == null || _currentCategory == null) {
        throw Exception('Assessment not properly initialized');
      }

      // Update category metrics
      await _dbService.updateCategoryMetrics(
          _categoryResultsId!, _currentCategory!);

      // Get latest category results
      final userId = _dbService.currentUserId ?? 'unknown';
      final categoryResults =
          await _dbService.getCategoryResultsForStudent(userId);

      if (categoryResults == null) {
        throw Exception('Failed to retrieve category results');
      }

      if (categoryResults['allCategoriesCompleted'] == true) {
        // All categories completed
        _isAssessmentComplete = true;
        notifyListeners();
        return;
      }

      // Find next incomplete category
      String? nextCategory;
      final categories = categoryResults['categories'] as List;
      for (final category in categories) {
        if (category['isCompleted'] != true) {
          nextCategory = category['categoryName'];
          break;
        }
      }

      if (nextCategory != null) {
        // Load next category
        _currentCategory = nextCategory;
        await loadCategoryQuestions();
      } else {
        // All categories completed
        _isAssessmentComplete = true;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Check if can go to previous question
  bool canGoToPreviousQuestion() {
    return _currentQuestionIndex > 0;
  }

  /// Go to previous question
  void goToPreviousQuestion() {
    if (canGoToPreviousQuestion()) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Record content viewed
  void recordContentViewed(int contentSize) {
    _readingMetrics['totalContentViewed'] =
        (_readingMetrics['totalContentViewed'] ?? 0) + contentSize;
    notifyListeners();
  }

  /// Record available content
  void recordAvailableContent(int contentSize) {
    _readingMetrics['totalContentAvailable'] =
        (_readingMetrics['totalContentAvailable'] ?? 0) + contentSize;
    notifyListeners();
  }

  /// Record reading time
  void recordReadingTime(int seconds) {
    _readingMetrics['timeSpentReading'] =
        (_readingMetrics['timeSpentReading'] ?? 0) + seconds;
    notifyListeners();
  }

  /// Get effective reading percentage
  double getEffectiveReadingPercentage() {
    final contentViewed = _readingMetrics['totalContentViewed'] ?? 0;
    final contentAvailable = _readingMetrics['totalContentAvailable'] ?? 0;

    if (contentAvailable > 0) {
      return (contentViewed / contentAvailable) * 100;
    }

    // Fallback to score-based percentage
    return _currentAssessment != null && totalQuestions > 0
        ? (_score / totalQuestions) * 100
        : 0.0;
  }

  /// Get original question data
  dynamic getOriginalQuestionData(String questionId) {
    return _rawQuestionData[questionId];
  }

  /// Get assessment results following the guide's structure
  Future<Map<String, dynamic>> getAssessmentResults() async {
    try {
      if (_isPreAssessment) {
        // For pre-assessment, calculate scores directly
        return await _calculatePreAssessmentResults();
      } else {
        // For main assessment, get from category_results
        if (_categoryResultsId == null) {
          throw Exception('Assessment not properly initialized');
        }

        final userId = _dbService.currentUserId ?? 'unknown';
        return await _repository.getAssessmentResults(userId);
      }
    } catch (e) {
      throw Exception('Error getting assessment results: $e');
    }
  }

  /// Calculate pre-assessment results
  Future<Map<String, dynamic>> _calculatePreAssessmentResults() async {
    if (_currentAssessment == null) {
      throw Exception('No assessment loaded');
    }

    try {
      int totalQuestions = _currentAssessment!.questions.length;
      int correctAnswers = 0;
      Map<String, int> categoryScores = {};

      for (final question in _currentAssessment!.questions) {
        final userAnswer = _userResponses[question.questionId];
        final correctOption = question.options.firstWhere(
          (opt) => opt.isCorrect,
          orElse: () =>
              AssessmentOption(optionId: '', optionText: '', isCorrect: false),
        );

        if (userAnswer == correctOption.optionId) {
          correctAnswers++;
          categoryScores[question.questionTypeId] =
              (categoryScores[question.questionTypeId] ?? 0) + 1;
        }
      }

      final score = (correctAnswers / totalQuestions * 100).round();

      // Calculate reading level based on score for pre-assessment
      final newReadingLevel = _calculateReadingLevelFromScore(score);

      return {
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'categoryScores': categoryScores,
        'readingLevel': newReadingLevel,
        'isPreAssessment': true,
        'assessmentId': _currentAssessment!.assessmentId,
        'completionTime': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Error calculating results: $e');
    }
  }

  /// Save assessment results
  Future<bool> saveResults() async {
    try {
      if (_currentAssessment == null) {
        throw Exception('No assessment loaded');
      }

      final results = await getAssessmentResults();
      final userId = _dbService.currentUserId ?? 'unknown';

      // Save to appropriate database based on assessment type
      return await _repository.saveUserResponses(
        assessmentId: _currentAssessment!.assessmentId,
        userId: userId,
        answers: _userResponses,
        score: results['score'],
        readingLevel: results['readingLevel'],
        readingPercentage: results['score'] / 100,
        additionalData: {
          'correctAnswers': _getCorrectAnswers(),
          'categoryScores': results['categoryScores'],
          'metadata': _assessmentMetadata,
          'isPreAssessment': _isPreAssessment,
        },
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reset assessment state
  void reset() {
    _currentAssessment = null;
    _userResponses = {};
    _error = null;
    _isLoading = false;
    _assessmentMetadata = null;
    _currentQuestionIndex = 0;
    _isAssessmentComplete = false;
    _score = 0;
    _rawQuestionData = {};
    _categoryResultsId = null;
    _currentCategory = null;
    _availableCategories = [];
    _isResumingAssessment = false;
    _readingMetrics = {
      'totalContentViewed': 0,
      'totalContentAvailable': 0,
      'timeSpentReading': 0,
    };
    notifyListeners();
  }

  /// Helper method to calculate reading level from pre-assessment score
  String _calculateReadingLevelFromScore(int score) {
    if (score >= 90) return 'At Grade Level';
    if (score >= 70) return 'Transitioning';
    if (score >= 50) return 'Developing';
    if (score >= 30) return 'High Emerging';
    return 'Low Emerging';
  }

  /// Helper method to get correct answers for validation
  Map<String, String> _getCorrectAnswers() {
    final correctAnswers = <String, String>{};
    if (_currentAssessment == null) return correctAnswers;

    for (final question in _currentAssessment!.questions) {
      final correctOption = question.options.firstWhere(
        (opt) => opt.isCorrect,
        orElse: () =>
            AssessmentOption(optionId: '', optionText: '', isCorrect: false),
      );
      correctAnswers[question.questionId] = correctOption.optionId;
    }
    return correctAnswers;
  }

  /// Check if user has completed all categories
  Future<bool> hasCompletedAllCategories() async {
    if (_categoryResultsId == null) return false;

    try {
      final userId = _dbService.currentUserId ?? 'unknown';
      final results = await _repository.getAssessmentResults(userId);
      return results['allCategoriesCompleted'] == true;
    } catch (e) {
      print('Error checking category completion: $e');
      return false;
    }
  }

  /// Get available categories for student's reading level
  Future<List<String>> getAvailableCategories(String readingLevel) async {
    try {
      return await _dbService.getAvailableCategoriesForLevel(readingLevel);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<void> saveDetailedResults(String userId, String assessmentId) async {
    // TODO: Implement saving logic here, e.g., send data to database or API.
    print(
        'Saving detailed results for user $userId and assessment $assessmentId');
    // Simulate async operation
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  String toString() {
    return 'AssessmentProvider(currentAssessment: $_currentAssessment, isLoading: $_isLoading, error: $_error, userResponses: $_userResponses, isPreAssessment: $_isPreAssessment, readingLevel: $_readingLevel, assessmentMetadata: $_assessmentMetadata, currentQuestionIndex: $_currentQuestionIndex, isAssessmentComplete: $_isAssessmentComplete, score: $_score, categoryResultsId: $_categoryResultsId, currentCategory: $_currentCategory, availableCategories: $_availableCategories, isResumingAssessment: $_isResumingAssessment)';
  }
}

// This code provides a comprehensive implementation of an assessment provider
