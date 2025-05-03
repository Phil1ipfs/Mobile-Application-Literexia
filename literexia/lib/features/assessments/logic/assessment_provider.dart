// lib/features/assessments/logic/assessment_provider.dart
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';
import '../repositories/assessment_repository.dart';

class AssessmentProvider extends ChangeNotifier {
  final AssessmentRepository _repository = AssessmentRepository();
  
  Assessment? _assessment;
  List<QuestionType> _questionTypes = [];
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {};
  bool _isAssessmentComplete = false;
  int _score = 0;
  String? _errorMessage;

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

  // Load assessment data from MongoDB - Fixed to handle string IDs
  Future<void> loadAssessment(dynamic assessmentId) async {
    try {
      _errorMessage = null;
      print('[AssessmentProvider] Loading assessment with ID: $assessmentId');

      // 1️⃣ Guarantee the document exists
      await _repository.createAssessment();

      // 2️⃣ Now fetch it - support both string "Q1" and int 1 formats
      final assessmentData = await _repository.getAssessment(assessmentId);
      if (assessmentData == null) {
        throw Exception('Assessment not found in database');
      }

      print('[AssessmentProvider] Assessment loaded: ${assessmentData.title}');

      _assessment = assessmentData;
      _questionTypes = await _repository.getQuestionTypes();
      
      print('[AssessmentProvider] Question types loaded: ${_questionTypes.length}');
      for (var type in _questionTypes) {
        print('[AssessmentProvider] > Type: ${type.typeId} - ${type.typeName}');
      }
      
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _isAssessmentComplete = false;
      _score = 0;
      
      // Debug current question type
      if (currentQuestion != null) {
        print('[AssessmentProvider] Current question type: ${currentQuestion!.questionTypeId}');
        print('[AssessmentProvider] Current question type name: $currentQuestionTypeName');
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load assessment: $e';
      print('[AssessmentProvider] Error: $_errorMessage');
      notifyListeners();
      rethrow;
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
      
      // Debug new current question type
      if (currentQuestion != null) {
        print('[AssessmentProvider] New current question type: ${currentQuestion!.questionTypeId}');
        print('[AssessmentProvider] New current question type name: $currentQuestionTypeName');
      }
    } else {
      // Assessment is complete
      _isAssessmentComplete = true;
      print('[AssessmentProvider] Assessment completed with final score: $_score/${_assessment!.questions.length}');
      
      // Save results to database
      _saveResults();
    }
    
    notifyListeners();
  }

  // Save assessment results to database
  Future<void> _saveResults() async {
    try {
      // Implement saving to database
      print('[AssessmentProvider] Saving assessment results');
      
      if (_assessment != null) {
        await _repository.saveUserResponses(
          assessmentId: _assessment!.assessmentId,
          userId: 'current_user_id', // Replace with actual user ID
          answers: _userAnswers,
          score: _score,
        );
      }
    } catch (e) {
      print('[AssessmentProvider] Error saving results: $e');
    }
  }

  // Reset the assessment to start over
  void resetAssessment() {
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _isAssessmentComplete = false;
    _score = 0;
    notifyListeners();
  }
}