// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import 'package:flutter/material.dart'; // Add this import for BuildContext
import '../repositories/assessment_repository.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../main.dart';

class AssessmentProvider extends ChangeNotifier {
  final AssessmentRepository _repository = AssessmentRepository();

  Assessment? _assessment;
  List<QuestionType> _questionTypes = [];
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {};
  bool _isAssessmentComplete = false;
  int _score = 0;
  String? _errorMessage;
  String? _readingLevel;

  // Track reading metrics
  double _readingPercentage = 0.0;
  Map<String, int> _readingMetrics = {
    'totalContentViewed': 0,
    'totalContentAvailable': 0,
    'timeSpentReading': 0, // in seconds
  };

  // Getters
  Assessment? get assessment => _assessment;
  List<QuestionType> get questionTypes => _questionTypes;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion =>
      _assessment?.questions.length != null &&
              _currentQuestionIndex < _assessment!.questions.length
          ? _assessment!.questions[_currentQuestionIndex]
          : null;
  bool get isAssessmentComplete => _isAssessmentComplete;
  int get score => _score;
  int get totalQuestions => _assessment?.totalQuestions ?? 0;
  String? get errorMessage => _errorMessage;
  String? get readingLevel => _readingLevel;
  double get readingPercentage => _readingPercentage;

  // Get the display name for the current question's type
  String get currentQuestionTypeName {
    if (currentQuestion == null || _questionTypes.isEmpty) {
      return 'Unknown question type';
    }

    // Find matching question type
    final matchingType = _questionTypes.firstWhere(
      (type) => type.typeId == currentQuestion!.questionTypeId,
      orElse:
          () => QuestionType(
            typeId: 'unknown',
            typeName: 'Unknown Question Type',
          ),
    );

    return matchingType.typeName;
  }

  // Set assessment directly (for testing or direct initialization)
  void setAssessment(Assessment assessment) {
    _assessment = assessment;
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _isAssessmentComplete = false;
    _score = 0;
    _readingLevel = null;
    _errorMessage = null;
    _readingPercentage = 0.0;
    _readingMetrics = {
      'totalContentViewed': 0,
      'totalContentAvailable': 0,
      'timeSpentReading': 0,
    };
    notifyListeners();
  }

  // Load assessment data
  Future<void> loadAssessment(dynamic assessmentId) async {
    try {
      _errorMessage = null;
      print('[AssessmentProvider] Loading assessment with ID: $assessmentId');

      // Create assessment if it doesn't exist
      await _repository.createAssessment();

      // Fetch the assessment
      final assessmentData = await _repository.getAssessment(assessmentId);
      if (assessmentData == null) {
        throw Exception('Assessment not found in database');
      }

      print('[AssessmentProvider] Assessment loaded: ${assessmentData.title}');

      _assessment = assessmentData;
      _questionTypes = await _repository.getQuestionTypes();

      print(
        '[AssessmentProvider] Question types loaded: ${_questionTypes.length}',
      );

      // Reset assessment state
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _isAssessmentComplete = false;
      _score = 0;
      _readingLevel = null;
      _readingPercentage = 0.0;
      _readingMetrics = {
        'totalContentViewed': 0,
        'totalContentAvailable': 0,
        'timeSpentReading': 0,
      };

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load assessment: $e';
      print('[AssessmentProvider] Error: $_errorMessage');
      notifyListeners();
      rethrow;
    }
  }

  // Record reading activity - call this when content is displayed to the student
  void recordContentViewed(int contentSize) {
    _readingMetrics['totalContentViewed'] =
        (_readingMetrics['totalContentViewed'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  // Record available content - call this when loading new content
  void recordAvailableContent(int contentSize) {
    _readingMetrics['totalContentAvailable'] =
        (_readingMetrics['totalContentAvailable'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  // Record time spent reading - call this periodically during assessment
  void recordReadingTime(int seconds) {
    _readingMetrics['timeSpentReading'] =
        (_readingMetrics['timeSpentReading'] ?? 0) + seconds;
  }

  // Update reading percentage based on metrics
  void _updateReadingPercentage() {
    final contentViewed = _readingMetrics['totalContentViewed'] ?? 0;
    final contentAvailable = _readingMetrics['totalContentAvailable'] ?? 0;

    if (contentAvailable > 0) {
      _readingPercentage = (contentViewed / contentAvailable) * 100;
    } else {
      _readingPercentage = 0.0;
    }
  }

  // Answer the current question and move to the next
  void answerCurrentQuestion(String answerId) {
    if (_assessment == null || currentQuestion == null || _isAssessmentComplete)
      return;

    print(
      '[AssessmentProvider] Answering question: ${currentQuestion!.questionId} with option: $answerId',
    );

    // Save user's answer
    _userAnswers[currentQuestion!.questionId] = answerId;

    // Check if the answer is correct
    final selectedOption = currentQuestion!.options.firstWhere(
      (option) => option.optionId == answerId,
      orElse: () => throw Exception('Option not found'),
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
        '[AssessmentProvider] Moving to question index: $_currentQuestionIndex',
      );
    } else {
      // Assessment is complete
      _isAssessmentComplete = true;

      // Determine reading level based on score and reading percentage
      _determineReadingLevel();

      print(
        '[AssessmentProvider] Assessment completed with final score: $_score/${_assessment!.questions.length}',
      );
      print('[AssessmentProvider] Reading percentage: $_readingPercentage%');
      print('[AssessmentProvider] Reading level: $_readingLevel');

      // Save results to database
      _saveResults();
    }

    notifyListeners();
  }

  // Determine reading level based on score and reading percentage
  void _determineReadingLevel() {
    if (_assessment == null) return;

    // Get total questions for percentage calculation
    final totalQuestions = _assessment!.questions.length;

    // Calculate score percentage (out of 100%)
    final scorePercentage =
        totalQuestions > 0 ? (_score / totalQuestions) * 100 : 0;

    // Map to Reading Profile Stage based on score and reading percentage
    if (_score == 0) {
      if (_readingPercentage < 25) {
        _readingLevel = "Low Emerging";
      } else {
        _readingLevel = "High Emerging";
      }
    } else if (_score == 1) {
      if (_readingPercentage >= 26 && _readingPercentage <= 50) {
        _readingLevel = "Developing";
      } else if (_readingPercentage < 26) {
        _readingLevel = "High Emerging";
      } else {
        _readingLevel = "Developing";
      }
    } else if (_score >= 2 && _score <= 3) {
      if (_readingPercentage >= 51 && _readingPercentage <= 75) {
        _readingLevel = "Transitioning";
      } else if (_readingPercentage < 51) {
        _readingLevel = "Developing";
      } else {
        _readingLevel = "Transitioning";
      }
    } else if (_score >= 4) {
      if (_readingPercentage >= 76) {
        _readingLevel = "At Grade Level";
      } else {
        _readingLevel = "Transitioning";
      }
    } else {
      // Fallback
      _readingLevel = "Low Emerging";
    }
  }

  // Get description for the determined reading level
  String getReadingLevelDescription() {
    switch (_readingLevel) {
      case "Low Emerging":
        return "Learner with the scores 0 to 16 upon the administration of Part 1: Task 1 and 2.";
      case "High Emerging":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads less than 25% and cannot answer any of the questions.";
      case "Developing":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 26-50% and answers at least 1 question correctly.";
      case "Transitioning":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 51-75% and answers at least 2-3 questions correctly.";
      case "At Grade Level":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 76-100% and answers at least 4 to 5 questions correctly.";
      default:
        return "Reading level not determined.";
    }
  }

  // Modified save results method to avoid using navigatorKey if possible
  Future<void> _saveResults() async {
    try {
      print('[AssessmentProvider] Saving assessment results');

      if (_assessment != null) {
        // Instead of using navigatorKey, we'll just save what we can for now
        // In real implementation, you'd need to pass the user ID from elsewhere
        final userId =
            'current_user_id'; // This will be replaced in the updateUserReadingLevel method

        await _repository.saveUserResponses(
          assessmentId: _assessment!.assessmentId,
          userId: userId,
          answers: _userAnswers,
          score: _score,
          readingLevel: _readingLevel,
          readingPercentage: _readingPercentage,
        );
      }
    } catch (e) {
      print('[AssessmentProvider] Error saving results: $e');
    }
  }

  // New method that takes both AuthProvider and readingLevel parameter
  Future<void> updateUserReadingLevel(
    AuthProvider authProvider,
    String readingLevel,
  ) async {
    try {
      if (authProvider.currentUser != null) {
        _readingLevel = readingLevel;
        final userId = authProvider.currentUser!.idNumber;

        print(
          '[AssessmentProvider] Updating user with ID: $userId to reading level: $readingLevel',
        );

        // Save user responses with the actual user ID
        if (_assessment != null) {
          final responsesSaved = await _repository.saveUserResponses(
            assessmentId: _assessment!.assessmentId,
            userId: userId,
            answers: _userAnswers,
            score: _score,
            readingLevel: readingLevel,
            readingPercentage: _readingPercentage,
          );
          print('[AssessmentProvider] User responses saved: $responsesSaved');
        }

        // Update the user's reading level in their profile
        final levelUpdated = await _repository.updateUserReadingLevel(
          userId: userId,
          readingLevel: readingLevel,
          readingPercentage: _readingPercentage,
        );
        print('[AssessmentProvider] User reading level updated: $levelUpdated');

        // Also update in auth provider for local app state
        authProvider.updateUserReadingLevel(readingLevel);
      } else {
        print(
          '[AssessmentProvider] Cannot update reading level - no current user',
        );
      }
    } catch (e) {
      print('[AssessmentProvider] Error updating user reading level: $e');
    }
  }

  // Reset the assessment to start over
  void resetAssessment() {
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _isAssessmentComplete = false;
    _score = 0;
    _readingLevel = null;
    _readingPercentage = 0.0;
    _readingMetrics = {
      'totalContentViewed': 0,
      'totalContentAvailable': 0,
      'timeSpentReading': 0,
    };
    notifyListeners();
  }
}
