// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import 'package:flutter/material.dart';  // Add this import for BuildContext
import '../repositories/assessment_repository.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../services/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;

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
  List<Question> _questions = [];
  
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
  
  // Get the display name for the current question's type
  String get currentQuestionTypeName {
    if (currentQuestion == null || _questionTypes.isEmpty) {
      return 'Unknown question type';
    }
    
    // Find matching question type
    final matchingType = _questionTypes.firstWhere(
      (type) => type.typeId == currentQuestion!.questionTypeId,
      orElse: () => QuestionType(typeId: 'unknown', typeName: 'Unknown Question Type'),
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
  // Add the following method to your AssessmentProvider class or modify the existing one
//Modified loadAssessment method for AssessmentProvider class
Future<void> loadAssessment(dynamic assessmentId) async {
  try {
    print('[AssessmentProvider] Loading assessment with ID: $assessmentId (${assessmentId.runtimeType})');
    
    // Clear existing data
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _score = 0;
    
    // Get database service
    final dbService = DatabaseService();
    
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    
    // Debug available assessments
    await _debugAvailableAssessments();
    
    if (dbService.isConnected) {
      // Get the main_assessment collection
      final mainAssessmentCollection = dbService.getCollection('main_assessment');
      
      // Try different query approaches to find the assessment
      // 1. Try direct equality with assessmentId field
      var assessment = await mainAssessmentCollection.findOne(where.eq('assessmentId', assessmentId));
      
      // 2. If not found, try case-insensitive search
      if (assessment == null && assessmentId is String) {
        // Using regex for case-insensitive search
        final regex = RegExp('^${assessmentId}\$', caseSensitive: false);
        assessment = await mainAssessmentCollection.findOne(
          where.match('assessmentId', regex.pattern)
        );
      }
      
      // 3. If still not found, try direct ObjectId query if assessmentId might be an ObjectId
      if (assessment == null && assessmentId is String) {
        try {
          final objectId = ObjectId.fromHexString(assessmentId);
          assessment = await mainAssessmentCollection.findOne(where.eq('_id', objectId));
        } catch (e) {
          // Not a valid ObjectId, ignore
        }
      }
      
      if (assessment != null) {
        print('[AssessmentProvider] Assessment found: ${assessment['title']}');
        
        // Convert MongoDB document to Assessment model using fromMap method
        _assessment = Assessment.fromMap(assessment);
        
        // Get the questions from the assessment
        _questions = _assessment!.questions;
        
        notifyListeners();
        return;
      }
      
      print('[AssessmentProvider] Assessment with ID $assessmentId not found in database');
      throw Exception('Assessment not found in database');
    } else {
      print('[AssessmentProvider] Database not connected');
      throw Exception('Database not connected');
    }
  } catch (e) {
    print('[AssessmentProvider] Error: Failed to load assessment: $e');
    throw Exception('Failed to load assessment: $e');
  }
}
  // Record reading activity - call this when content is displayed to the student
  void recordContentViewed(int contentSize) {
    _readingMetrics['totalContentViewed'] = (_readingMetrics['totalContentViewed'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  // Record available content - call this when loading new content
  void recordAvailableContent(int contentSize) {
    _readingMetrics['totalContentAvailable'] = (_readingMetrics['totalContentAvailable'] ?? 0) + contentSize;
    _updateReadingPercentage();
  }

  // Record time spent reading - call this periodically during assessment
  void recordReadingTime(int seconds) {
    _readingMetrics['timeSpentReading'] = (_readingMetrics['timeSpentReading'] ?? 0) + seconds;
  }

  // Update reading percentage based on metrics
  void _updateReadingPercentage() {
  final contentViewed = _readingMetrics['totalContentViewed'] ?? 0;
  final contentAvailable = _readingMetrics['totalContentAvailable'] ?? 0;
  
  // Add detailed logging
  print('[AssessmentProvider] Calculating reading percentage:');
  print('[AssessmentProvider] - Content viewed: $contentViewed');
  print('[AssessmentProvider] - Content available: $contentAvailable');
  
  if (contentAvailable > 0) {
    _readingPercentage = (contentViewed / contentAvailable) * 100;
    print('[AssessmentProvider] - Calculated percentage: $_readingPercentage%');
  } else {
    // If no content available, set a default percentage based on score
    // This ensures there's always a non-zero reading percentage
    final scorePercent = _assessment != null && totalQuestions > 0 
        ? (_score / totalQuestions) * 100 
        : 0.0;
    _readingPercentage = scorePercent;
    print('[AssessmentProvider] - No content available, using score percentage: $_readingPercentage%');
  }
}

  // Answer the current question and move to the next
  void answerCurrentQuestion(String answerId) {
    if (_assessment == null || currentQuestion == null || _isAssessmentComplete) return;
    
    print('[AssessmentProvider] Answering question: ${currentQuestion!.questionId} with option: $answerId');
    
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
      print('[AssessmentProvider] Moving to question index: $_currentQuestionIndex');
    } else {
      // Assessment is complete
      _isAssessmentComplete = true;
      
      // Determine reading level based on score and reading percentage
      _determineReadingLevel();
      
      print('[AssessmentProvider] Assessment completed with final score: $_score/${_assessment!.questions.length}');
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
    final scorePercentage = totalQuestions > 0 ? (_score / totalQuestions) * 100 : 0;
    
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
        final userId = 'current_user_id'; // This will be replaced in the updateUserReadingLevel method
        
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
  // Corrected method that uses the right repository variable name
  Future<void> updateUserReadingLevel(AuthProvider authProvider, String readingLevel, {double? readingPercentage}) async {
  final userId = authProvider.currentUser?.idNumber;
  if (userId == null) return;

  try {
    // Use the percentage that was passed in or the current calculated one
    final percentage = readingPercentage ?? _readingPercentage;
    
    print('[AssessmentProvider] Updating reading level to $readingLevel with percentage $percentage%');
    
    // First update the AuthProvider (memory)
    authProvider.updateUserReadingLevel(readingLevel);
    // Also update reading percentage in memory
    authProvider.updateReadingPercentage(percentage);
    // Set preAssessmentCompleted flag in memory
    authProvider.setPreAssessmentCompleted(true);
    
    // Then update the database
    await _repository.updateUserReadingLevel(
      userId: userId,
      readingLevel: readingLevel,
      readingPercentage: percentage,
      preAssessmentCompleted: true,
    );
    
    print('[AssessmentProvider] Successfully updated user reading level to $readingLevel with percentage $percentage%');
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
    double getEffectiveReadingPercentage() {
    // Return the calculated reading percentage if it's non-zero
    if (_readingPercentage > 0) {
      return _readingPercentage;
    }
    
    // Otherwise, calculate percentage based on score
    if (_assessment != null && totalQuestions > 0) {
      return (_score / totalQuestions) * 100;
    }
    
    // Default fallback
    return 50.0;
  }
  // Add this debugging method to the AssessmentProvider class
Future<void> _debugAvailableAssessments() async {
  try {
    final dbService = DatabaseService();
    
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    
    if (dbService.isConnected) {
      final mainAssessmentCollection = dbService.getCollection('main_assessment');
      
      // Find all assessments
      final assessments = await mainAssessmentCollection.find().toList();
      
      print('=============== AVAILABLE ASSESSMENTS ===============');
      print('Total assessments in database: ${assessments.length}');
      
      for (final assessment in assessments) {
        print('ID: ${assessment['_id']} | AssessmentId: ${assessment['assessmentId']} | Title: ${assessment['title']}');
      }
      
      print('====================================================');
    } else {
      print('Database not connected, cannot debug assessments');
    }
  } catch (e) {
    print('Error debugging assessments: $e');
  }
}
  // Add this helper method to the AssessmentProvider class
List<AssessmentOption> _createOptionsFromJson(dynamic optionsJson) {
  if (optionsJson == null) return [];
  
  final List<AssessmentOption> result = [];
  
  try {
    final optionsList = optionsJson as List<dynamic>;
    
    for (final opt in optionsList) {
      final option = AssessmentOption(
        optionId: opt['optionId'] ?? '',
        optionText: opt['optionText'] ?? '',
        isCorrect: opt['isCorrect'] ?? false,
        explanation: opt['explanation'],
      );
      
      result.add(option);
    }
  } catch (e) {
    print('Error parsing options: $e');
  }
  
  return result;
}
}