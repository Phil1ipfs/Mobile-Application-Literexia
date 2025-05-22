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
  
  // Assessment start time for tracking duration
  DateTime? _assessmentStartTime;

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

  // Constructor
  AssessmentProvider() {
    // Initialize assessment start time
    _assessmentStartTime = DateTime.now();
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
    _assessmentStartTime = DateTime.now();
    notifyListeners();
  }

  // Load assessment data with enhanced error handling and fallback
  Future<void> loadAssessment(dynamic assessmentId) async {
  try {
    print('[AssessmentProvider] Loading assessment with ID: $assessmentId (${assessmentId.runtimeType})');
    
    // Clear existing data
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _score = 0;
    _assessmentStartTime = DateTime.now();
    
    // Get database service
    final dbService = DatabaseService();
    
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    
    // Debug database state to see available collections
    await dbService.debugDatabaseState();
    
    if (dbService.isConnected) {
      // Try to access the Pre_Assessment database explicitly
      final preAssessmentDb = await dbService.getPreAssessmentDatabase();
      final preAssessmentCollection = preAssessmentDb.collection('pre-assessment');
      
      // Log what we're doing
      print('[AssessmentProvider] Connected to Pre_Assessment database, querying pre-assessment collection');
      
      // Try different query approaches to find the assessment
      Map<String, dynamic>? assessment;
      
      // 1. Try the specific assessment ID from the JSON example "FL-G1-001"
      assessment = await preAssessmentCollection.findOne(where.eq('assessmentId', "FL-G1-001"));
      print('[AssessmentProvider] Tried specific ID "FL-G1-001": ${assessment != null ? 'Found' : 'Not found'}');
      
      // 2. If not found with specific ID, try with the passed assessmentId
      if (assessment == null && assessmentId != null) {
        // Try with assessmentId as is
        assessment = await preAssessmentCollection.findOne(where.eq('assessmentId', assessmentId));
        print('[AssessmentProvider] Tried with passed assessmentId: ${assessment != null ? 'Found' : 'Not found'}');
        
        // If numeric, try with formatted string (e.g., 1 -> "FL-G1-001")
        if (assessment == null && assessmentId is int) {
          final formattedId = "FL-G1-00$assessmentId";
          assessment = await preAssessmentCollection.findOne(where.eq('assessmentId', formattedId));
          print('[AssessmentProvider] Tried with formatted ID $formattedId: ${assessment != null ? 'Found' : 'Not found'}');
        }
      }
      
      // 3. If still not found, try to get any document from the collection
      if (assessment == null) {
        print('[AssessmentProvider] Trying to find any assessment document...');
        
        // Fixed this line - use take(1) instead of limit(1)
        final documents = await preAssessmentCollection.find().take(1).toList();
        
        if (documents.isNotEmpty) {
          assessment = documents.first;
          print('[AssessmentProvider] Found an assessment document with ID: ${assessment['_id']}');
        } else {
          print('[AssessmentProvider] No documents found in pre-assessment collection');
        }
      }
      
      // 4. If still null, check if we have the paste.txt document in our collection
      if (assessment == null) {
        // Look for a document with title containing "Filipino Reading Pre-Assessment"
        final documents = await preAssessmentCollection.find(
          where.match('title', 'Filipino Reading Pre-Assessment', caseInsensitive: true)
        ).toList();
        
        if (documents.isNotEmpty) {
          assessment = documents.first;
          print('[AssessmentProvider] Found document matching title "Filipino Reading Pre-Assessment"');
        } else {
          print('[AssessmentProvider] No documents found matching title');
        }
      }
      
      // 5. If still null, try to create a sample assessment from the document content we have
      if (assessment == null) {
        print('[AssessmentProvider] Creating a sample assessment from the paste.txt document');
        _assessment = _createSampleAssessment();
        _questions = _assessment!.questions;
        notifyListeners();
        return;
      }
      
      if (assessment != null) {
        print('[AssessmentProvider] Assessment found: ${assessment['title'] ?? 'Unnamed Assessment'}');
        
        // Convert to the expected Assessment model format
        _assessment = _convertToAssessmentModel(assessment);
        
        // Get the questions
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

  // Create a sample assessment from the paste.txt document
  Assessment _createSampleAssessment() {
    // Create questions based on the paste.txt document
    final questions = [
      Question(
        questionId: 'AK_001',
        questionNumber: 1,
        questionTypeId: 'alphabet_knowledge',
        questionText: 'Anong ang katumbas na maliit na letra?',
        displayedText: 'A',
        hasImage: true,
        imageUrl: 'assets/images/letters/A_big.png',
        options: [
          AssessmentOption(
            optionId: '1',
            optionText: 'a',
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: 'e',
            isCorrect: false,
          ),
        ],
      ),
      Question(
        questionId: 'PA_002',
        questionNumber: 2,
        questionTypeId: 'phonological_awareness',
        questionText: 'Bigkasin ang tunog ng salitang nakikita',
        displayedText: 'ASO',
        options: [
          AssessmentOption(
            optionId: '1',
            optionText: '/ah/ /es/ /oh/',
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: '/oh/ /es/ /ah/',
            isCorrect: false,
          ),
        ],
      ),
      Question(
        questionId: 'WR_002',
        questionNumber: 3,
        questionTypeId: 'word_recognition',
        questionText: 'Pagsamahin ang pantig',
        displayedText: 'BO + LA',
        hasImage: true,
        imageUrl: 'assets/images/ball.png',
        options: [
          AssessmentOption(
            optionId: '1',
            optionText: 'BOLA',
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: 'LABO',
            isCorrect: false,
          ),
        ],
      ),
      Question(
        questionId: 'RC_001',
        questionNumber: 4,
        questionTypeId: 'reading_comprehension',
        questionText: 'Basahin ang kwento at sagutin ang tanong: Si Maria ay kumain ng mansanas. Ano ang kinain ni Maria?',
        displayedText: '',
        options: [
          AssessmentOption(
            optionId: '1',
            optionText: 'Mansanas',
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: 'Mangga',
            isCorrect: false,
          ),
        ],
      ),
      Question(
        questionId: 'DC_001',
        questionNumber: 5,
        questionTypeId: 'decoding',
        questionText: 'Ano ang nasa larawan?',
        displayedText: '',
        hasImage: true,
        imageUrl: 'assets/images/dog.png',
        options: [
          AssessmentOption(
            optionId: '1',
            optionText: 'ASO',
            isCorrect: true,
          ),
          AssessmentOption(
            optionId: '2',
            optionText: 'OSO',
            isCorrect: false,
          ),
        ],
      ),
    ];

    return Assessment(
      assessmentId: 'FL-G1-001',
      title: 'Filipino Reading Pre-Assessment - Grade 1',
      description: 'Comprehensive assessment of Filipino reading skills based on DEPED CRLA standards',
      totalQuestions: questions.length,
      continueButtonText: 'MAG PATULOY',
      language: 'FL',
      type: 'pre_assessment',
      status: 'active',
      questions: questions,
      categoryCounts: {
        'alphabet_knowledge': 1,
        'phonological_awareness': 1,
        'decoding': 1,
        'word_recognition': 1,
        'reading_comprehension': 1,
      },
      difficultyLevels: {
        'low_emerging': {
          'description': 'Basic recognition tasks',
          'targetReadingLevel': 'Low Emerging',
          'weight': 1
        },
        'high_emerging': {
          'description': 'Simple identification and matching',
          'targetReadingLevel': 'High Emerging',
          'weight': 2
        },
        'developing': {
          'description': 'Word formation and basic comprehension',
          'targetReadingLevel': 'Developing',
          'weight': 3
        },
        'transitioning': {
          'description': 'Sentence-level tasks and short texts',
          'targetReadingLevel': 'Transitioning',
          'weight': 4
        },
        'at_grade_level': {
          'description': 'Paragraph-level comprehension',
          'targetReadingLevel': 'At Grade Level',
          'weight': 5
        }
      },
      scoringRules: {
        'Low Emerging': {
          'part1ScoreRange': [0, 16],
          'readingPercentageRange': [0, 16],
          'correctAnswersRange': [0, 0]
        },
        'High Emerging': {
          'part1ScoreRange': [17, 30],
          'readingPercentageRange': [1, 25],
          'correctAnswersRange': [0, 0]
        },
        'Developing': {
          'part1ScoreRange': [17, 30],
          'readingPercentageRange': [26, 50],
          'correctAnswersRange': [1, 1]
        },
        'Transitioning': {
          'part1ScoreRange': [17, 30],
          'readingPercentageRange': [51, 75],
          'correctAnswersRange': [2, 3]
        },
        'At Grade Level': {
          'part1ScoreRange': [17, 30],
          'readingPercentageRange': [76, 100],
          'correctAnswersRange': [4, 5]
        }
      },
    );
  }

  // Add this helper method to convert from database format to Assessment model
  Assessment _convertToAssessmentModel(Map<String, dynamic> dbAssessment) {
    // Extract ID - use string representation of ObjectId
    final assessmentId = dbAssessment['assessmentId'] ?? dbAssessment['_id'].toString();
    
    // Extract title from category or default
    final title = dbAssessment['title'] ?? dbAssessment['category'] ?? 'Filipino Assessment';
    
    // Extract description or use default
    final description = dbAssessment['description'] ?? 'Interactive Filipino reading assessment';
    
    // Extract category counts if available
    Map<String, int>? categoryCounts;
    if (dbAssessment['categoryCounts'] != null) {
      categoryCounts = {};
      final countMap = dbAssessment['categoryCounts'] as Map<String, dynamic>;
      countMap.forEach((key, value) {
        if (value is int) {
          categoryCounts![key] = value;
        } else if (value is num) {
          categoryCounts![key] = value.toInt();
        }
      });
    }
    
    // Convert questions from database format to Question model format
    List<Question> questions = [];
    
    if (dbAssessment['questions'] != null && dbAssessment['questions'] is List) {
      final questionsList = dbAssessment['questions'] as List;
      
      int questionNumber = 1;
      for (final q in questionsList) {
        // Store the original question data for later use (especially for reading comprehension with passages)
        final questionId = q['questionId'] ?? 'q${questionNumber}';
        _rawQuestionData[questionId] = q;
        
        // Map database question to our Question model
        // Get question type
        final questionTypeId = q['questionTypeId'] ?? 'default_type';
        
        // Get question text
        final questionText = q['questionText'] ?? 'Answer the question';
        
        // Get displayed text if available
        final displayedText = q['questionValue'] ?? '';
        
        // Extract options into our model format
        List<AssessmentOption> options = [];
        
        // For reading comprehension questions with sentenceQuestions
        if (questionTypeId == 'reading_comprehension' && q['sentenceQuestions'] != null && q['sentenceQuestions'] is List) {
          final sentenceQuestions = q['sentenceQuestions'] as List;
          if (sentenceQuestions.isNotEmpty) {
            final sentenceQuestion = sentenceQuestions[0];
            // Create options from correctAnswer and incorrectAnswer
            options.add(AssessmentOption(
              optionId: '1',
              optionText: sentenceQuestion['correctAnswer'] ?? '',
              isCorrect: true,
            ));
            options.add(AssessmentOption(
              optionId: '2',
              optionText: sentenceQuestion['incorrectAnswer'] ?? '',
              isCorrect: false,
            ));
          }
        }
        // For standard questions with options array
        else if (q['options'] != null && q['options'] is List) {
          final optionsList = q['options'] as List;
          int optionNumber = 1;
          
          for (final opt in optionsList) {
            options.add(AssessmentOption(
              optionId: opt['optionId'] ?? 'opt${optionNumber}',
              optionText: opt['optionText'] ?? '',
              isCorrect: opt['isCorrect'] ?? false,
            ));
            optionNumber++;
          }
        }
        // For questions with choiceOptions array
        else if (q['choiceOptions'] != null && q['choiceOptions'] is List) {
          final optionsList = q['choiceOptions'] as List;
          int optionNumber = 1;
          
          for (final opt in optionsList) {
            options.add(AssessmentOption(
              optionId: opt['optionId'] ?? 'opt${optionNumber}',
              optionText: opt['optionText'] ?? '',
              isCorrect: opt['isCorrect'] ?? false,
            ));
            optionNumber++;
          }
        }
        
        // Parse passages if available
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null && q['passages'] is List && (q['passages'] as List).isNotEmpty) {
          passages = [];
          for (final passage in q['passages']) {
            if (passage is Map) {
              passages.add(Map<String, dynamic>.from(passage));
            }
          }
        }
        
        // Parse sentence questions if available
        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null && q['sentenceQuestions'] is List && 
            (q['sentenceQuestions'] as List).isNotEmpty) {
          sentenceQuestions = [];
          for (final sq in q['sentenceQuestions']) {
            if (sq is Map) {
              sentenceQuestions.add(Map<String, dynamic>.from(sq));
            }
          }
        }
        
        // Create and add the question
        questions.add(Question(
          questionId: questionId,
          questionNumber: questionNumber,
          questionTypeId: questionTypeId,
          questionText: questionText,
          displayedText: displayedText,
          hasImage: q['questionImage'] != null || q['hasImage'] == true,
          imageUrl: q['questionImage'] ?? q['imageUrl'],
          hasAudio: q['audioUrl'] != null || q['hasAudio'] == true,
          audioUrl: q['audioUrl'],
          options: options,
          questionType: q['questionType'],
          difficultyLevel: q['difficultyLevel'],
          passages: passages,
          sentenceQuestions: sentenceQuestions,
          order: q['order'],
        ));
        
        questionNumber++;
      }
    }
    
    // Create and return the Assessment model
    return Assessment(
      assessmentId: assessmentId,
      title: title,
      description: description,
      totalQuestions: questions.length,
      continueButtonText: dbAssessment['continueButtonText'] ?? 'MAG PATULOY',
      language: dbAssessment['language'] ?? 'FL',
      type: dbAssessment['type'] ?? 'assessment',
      status: dbAssessment['status'] == true || dbAssessment['status'] == 'active' ? 'active' : 'inactive',
      questions: questions,
      categoryCounts: categoryCounts,
      difficultyLevels: dbAssessment['difficultyLevels'],
      scoringRules: dbAssessment['scoringRules'],
      instructions: dbAssessment['instructions'],
    );
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

  // Updated _determineReadingLevel to use scoringRules from the assessment
  void _determineReadingLevel() {
    if (_assessment == null) return;
    
    // Calculate Part 1 score (first 20 questions scaled to 0-30)
    int correctInPart1 = 0;
    int part1Questions = 0;
    int correctInReadingComp = 0;
    int readingCompQuestions = 0;
    
    for (int i = 0; i < _userAnswers.length; i++) {
      final questionId = _assessment!.questions[i].questionId;
      final userAnswer = _userAnswers[questionId];
      
      if (userAnswer == null) continue;
      
      final isCorrect = _assessment!.questions[i].options
          .firstWhere((o) => o.optionId == userAnswer, orElse: () => 
              AssessmentOption(optionId: '', optionText: '', isCorrect: false))
          .isCorrect;
      
      if (_assessment!.questions[i].questionTypeId == 'reading_comprehension') {
        readingCompQuestions++;
        if (isCorrect) correctInReadingComp++;
      } else {
        part1Questions++;
        if (isCorrect) correctInPart1++;
      }
    }
    
    // Calculate Part 1 score (scale to 0-30)
    final double part1Score = part1Questions > 0 
        ? (correctInPart1 / part1Questions) * 30 
        : 0;
    final int roundedPart1Score = part1Score.round();
    
    print('[AssessmentProvider] Part 1 Score: $roundedPart1Score (from $correctInPart1/$part1Questions)');
    print('[AssessmentProvider] Reading Comp Score: $correctInReadingComp/$readingCompQuestions');
    
    // First try to use the scoringRules from the assessment
    if (_assessment!.scoringRules != null) {
      print('[AssessmentProvider] Using assessment scoringRules to determine reading level');
      
      // Get the scoring rules
      final rules = _assessment!.scoringRules!;
      
      // Check each level's criteria
      if (_checkScoringRuleCriteria(rules['Low Emerging'], roundedPart1Score, correctInReadingComp)) {
        _readingLevel = "Low Emerging";
      } else if (_checkScoringRuleCriteria(rules['High Emerging'], roundedPart1Score, correctInReadingComp)) {
        _readingLevel = "High Emerging";
      } else if (_checkScoringRuleCriteria(rules['Developing'], roundedPart1Score, correctInReadingComp)) {
        _readingLevel = "Developing";
      } else if (_checkScoringRuleCriteria(rules['Transitioning'], roundedPart1Score, correctInReadingComp)) {
        _readingLevel = "Transitioning";
      } else if (_checkScoringRuleCriteria(rules['At Grade Level'], roundedPart1Score, correctInReadingComp)) {
        _readingLevel = "At Grade Level";
      } else {
        // Default fallback based on part1 score
        if (roundedPart1Score <= 16) {
          _readingLevel = "Low Emerging";
        } else {
          _readingLevel = "High Emerging";
        }
      }
    } else {
      // Fallback to hard-coded logic if scoringRules not available
      print('[AssessmentProvider] Using fallback logic to determine reading level');
      
      if (roundedPart1Score <= 16) {
        _readingLevel = "Low Emerging";
      } else if (roundedPart1Score >= 17 && _readingPercentage <= 25 && correctInReadingComp == 0) {
        _readingLevel = "High Emerging";
      } else if (roundedPart1Score >= 17 && _readingPercentage >= 26 && _readingPercentage <= 50 && correctInReadingComp == 1) {
        _readingLevel = "Developing";
      } else if (roundedPart1Score >= 17 && _readingPercentage >= 51 && _readingPercentage <= 75 && correctInReadingComp >= 2 && correctInReadingComp <= 3) {
        _readingLevel = "Transitioning";
      } else if (roundedPart1Score >= 17 && _readingPercentage >= 76 && correctInReadingComp >= 4) {
        _readingLevel = "At Grade Level";
      } else {
        // Default fallback - determine based on available criteria
        if (correctInReadingComp >= 4) {
          _readingLevel = "At Grade Level";
        } else if (correctInReadingComp >= 2) {
          _readingLevel = "Transitioning";
        } else if (correctInReadingComp >= 1) {
          _readingLevel = "Developing";
        } else if (roundedPart1Score >= 17) {
          _readingLevel = "High Emerging";
        } else {
          _readingLevel = "Low Emerging";
        }
      }
    }
    
    print('[AssessmentProvider] Determined reading level: $_readingLevel');
  }

  // Helper to check if a score meets scoring rule criteria
  bool _checkScoringRuleCriteria(Map<String, dynamic>? rule, int part1Score, int readingCompCorrect) {
    if (rule == null) return false;
    
    // Get the criteria ranges
    final part1Range = rule['part1ScoreRange'] ?? [0, 0];
    final readingPercentageRange = rule['readingPercentageRange'] ?? [0, 0];
    final correctAnswersRange = rule['correctAnswersRange'] ?? [0, 0];
    
    // Convert to proper int values if they're dynamic
    final int part1Min = part1Range[0] is int ? part1Range[0] : (part1Range[0] as num).toInt();
    final int part1Max = part1Range[1] is int ? part1Range[1] : (part1Range[1] as num).toInt();
    final int readingPercentMin = readingPercentageRange[0] is int ? readingPercentageRange[0] : (readingPercentageRange[0] as num).toInt();
    final int readingPercentMax = readingPercentageRange[1] is int ? readingPercentageRange[1] : (readingPercentageRange[1] as num).toInt();
    final int correctMin = correctAnswersRange[0] is int ? correctAnswersRange[0] : (correctAnswersRange[0] as num).toInt();
    final int correctMax = correctAnswersRange[1] is int ? correctAnswersRange[1] : (correctAnswersRange[1] as num).toInt();
    
    // Check if the scores fall within the ranges
    bool meetsScoreCriteria = (part1Score >= part1Min && part1Score <= part1Max);
    bool meetsReadingCriteria = (_readingPercentage >= readingPercentMin && _readingPercentage <= readingPercentMax);
    bool meetsCorrectCriteria = (readingCompCorrect >= correctMin && readingCompCorrect <= correctMax);
    
    print('[AssessmentProvider] Checking rule: ${rule.keys.first}');
    print('[AssessmentProvider] - Part1 score: $part1Score in range [$part1Min-$part1Max]: $meetsScoreCriteria');
    print('[AssessmentProvider] - Reading %: $_readingPercentage in range [$readingPercentMin-$readingPercentMax]: $meetsReadingCriteria');
    print('[AssessmentProvider] - Reading Comp correct: $readingCompCorrect in range [$correctMin-$correctMax]: $meetsCorrectCriteria');
    
    // All criteria must be met
    return meetsScoreCriteria && meetsReadingCriteria && meetsCorrectCriteria;
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

  // Updated save results method that gets the user ID from AuthProvider
  Future<void> _saveResults() async {
    try {
      print('[AssessmentProvider] Saving assessment results');
      
      if (_assessment == null) {
        print('[AssessmentProvider] Error: No assessment to save results for');
        return;
      }
      
      // We can't directly use AuthProvider here since we don't have context,
      // so we'll wait for saveResults to be called from outside
      // with the proper user ID (or use another method like saveDetailedResults)
    } catch (e) {
      print('[AssessmentProvider] Error saving results: $e');
    }
  }

  // Enhanced saveResults for comprehensive data saving
  Future<void> saveResults(String userId) async {
    try {
      print('[AssessmentProvider] Saving comprehensive assessment results for user: $userId');
      
      if (_assessment == null) {
        print('[AssessmentProvider] Error: No assessment available to save results');
        return;
      }
      
      // Calculate Part 1 score (first 20 questions scaled to 0-30)
      int correctInPart1 = 0;
      int part1Questions = 0;
      int correctInReadingComp = 0;
      int readingCompQuestions = 0;
      
      // Track scores by category
      Map<String, dynamic> categoryScores = {};
      Map<String, dynamic> difficultyBreakdown = {};
      final categories = _assessment!.categoryCounts ?? {};
      
      // Initialize category scores
      categories.forEach((category, count) {
        categoryScores[category] = {
          'total': count,
          'correct': 0,
          'score': 0.0
        };
      });
      
      // Initialize difficulty breakdown
      final difficultyLevels = _assessment!.difficultyLevels ?? {};
      difficultyLevels.forEach((level, _) {
        difficultyBreakdown[level] = {
          'questions': 0,
          'correct': 0,
          'score': 0.0
        };
      });
      
      // Analyze answers by category and difficulty
      for (int i = 0; i < _assessment!.questions.length; i++) {
        final question = _assessment!.questions[i];
        final questionId = question.questionId;
        final userAnswer = _userAnswers[questionId];
        
        if (userAnswer == null) continue;
        
        // Determine if answer is correct
        final isCorrect = question.options
            .firstWhere((o) => o.optionId == userAnswer, orElse: () => 
                AssessmentOption(optionId: '', optionText: '', isCorrect: false))
            .isCorrect;
        
        // Track by question type
        final category = question.questionTypeId;
        if (categoryScores.containsKey(category)) {
          if (isCorrect) {
            categoryScores[category]['correct'] = (categoryScores[category]['correct'] ?? 0) + 1;
          }
        }
        
        // Track by difficulty level
        final difficulty = _getQuestionDifficultyLevel(question);
        if (difficultyBreakdown.containsKey(difficulty)) {
          difficultyBreakdown[difficulty]['questions'] = (difficultyBreakdown[difficulty]['questions'] ?? 0) + 1;
          if (isCorrect) {
            difficultyBreakdown[difficulty]['correct'] = (difficultyBreakdown[difficulty]['correct'] ?? 0) + 1;
          }
        }
        
        // Track Part 1 vs Reading Comprehension scores
        if (category == 'reading_comprehension') {
          readingCompQuestions++;
          if (isCorrect) correctInReadingComp++;
        } else {
          part1Questions++;
          if (isCorrect) correctInPart1++;
        }
      }
      
      // Calculate Part 1 score (scale to 0-30)
      final double part1Score = part1Questions > 0 
          ? (correctInPart1 / part1Questions) * 30 
          : 0;
      final int roundedPart1Score = part1Score.round();
      
      // Calculate category scores percentages
      categoryScores.forEach((category, data) {
        if (data['total'] > 0) {
          data['score'] = (data['correct'] / data['total']) * 100;
        }
      });
      
      // Calculate difficulty breakdown percentages
      difficultyBreakdown.forEach((level, data) {
        if (data['questions'] > 0) {
          data['score'] = (data['correct'] / data['questions']) * 100;
        }
      });
      
      // Determine if all categories passed (> 75%)
      bool allCategoriesPassed = true;
      categoryScores.forEach((_, data) {
        if (data['score'] < 75) allCategoriesPassed = false;
      });
      
      // Create a comprehensive response object
      final response = {
        'assessmentId': _assessment!.assessmentId,
        'userId': userId,
        'answers': _userAnswers,
        'score': _score,
        'totalQuestions': _assessment!.totalQuestions,
        'part1Score': roundedPart1Score,
        'readingPercentage': _readingPercentage,
        'readingLevel': _readingLevel,
        'categoryScores': categoryScores,
        'difficultyBreakdown': difficultyBreakdown,
        'allCategoriesPassed': allCategoriesPassed,
        'correctInReadingComp': correctInReadingComp,
        'readingCompQuestions': readingCompQuestions,
        'timeTaken': _calculateTimeTaken(),
        'completedAt': DateTime.now().toIso8601String(),
      };
      
      // Now save the comprehensive data
      await _repository.saveUserResponses(
        assessmentId: _assessment!.assessmentId,
        userId: userId,
        answers: _userAnswers,
        score: _score,
        readingLevel: _readingLevel ?? 'Undefined',
        readingPercentage: _readingPercentage,
        additionalData: response, // Pass the entire response object with all details
      );
      
      print('[AssessmentProvider] Successfully saved comprehensive assessment results');
    } catch (e) {
      print('[AssessmentProvider] Error saving comprehensive results: $e');
    }
  }

  // New method that takes both AuthProvider and readingLevel parameter
  // Corrected method that uses the right repository variable name
  Future<void> updateUserReadingLevel(AuthProvider authProvider, String readingLevel, {double? readingPercentage}) async {
    final userId = authProvider.currentUser?.idNumber;
    if (userId == null) {
      print('[AssessmentProvider] Error: Cannot update reading level - No user ID available');
      return;
    }

    try {
      // Use the percentage that was passed in or the current calculated one
      final percentage = readingPercentage ?? _readingPercentage;
      
      print('[AssessmentProvider] Updating user profile for $userId with reading level $readingLevel and percentage $percentage%');
      
      // First update the AuthProvider (memory)
      authProvider.updateUserReadingLevel(readingLevel);
      authProvider.updateReadingPercentage(percentage);
      authProvider.setPreAssessmentCompleted(true);
      
      // Then update the database - pass all three fields explicitly
      final result = await _repository.updateUserReadingLevel(
        userId: userId,
        readingLevel: readingLevel,
        readingPercentage: percentage,
        preAssessmentCompleted: true,
      );
      
      if (result) {
        print('[AssessmentProvider] Successfully updated user profile in database');
      } else {
        print('[AssessmentProvider] Failed to update user profile in database');
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
    _assessmentStartTime = DateTime.now();
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

  // Enhanced saveDetailedResults method
  Future<void> saveDetailedResults(String userId, String assessmentId) async {
    if (_assessment == null) return;
    
    try {
      print('[AssessmentProvider] Saving detailed results for user: $userId, assessment: $assessmentId');
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }
      
      // Calculate total time taken in seconds since assessment started
      final timeTaken = _calculateTimeTaken();
      
      // Calculate Part 1 score (scale to 0-30)
      int correctInPart1 = 0;
      int part1Questions = 0;
      int correctInReadingComp = 0;
      
      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final userAnswer = _userAnswers[question.questionId];
        
        if (userAnswer != null) {
          final selectedOption = question.options.firstWhere(
            (opt) => opt.optionId == userAnswer,
            orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
          );
          
          // Save individual response to student_response collection
          await dbService.saveStudentResponse({
            'studentId': userId,
            'categoryResultId': '', // Will be updated after saving category result
            'categoryId': assessmentId,
            'questionOrder': i + 1,
            'category': question.questionTypeId,
            'questionType': question.questionType ?? '',
            'difficultyLevel': _getQuestionDifficultyLevel(question),
            'sentenceQuestionIndex': i + 1,
            'selectedOption': selectedOption.optionText,
            'isCorrect': selectedOption.isCorrect,
            'responseTime': 0.0, // Could track this if needed
            'answeredAt': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          
          // Track part1 and reading comp scores
          if (question.questionTypeId == 'reading_comprehension') {
            if (selectedOption.isCorrect) correctInReadingComp++;
          } else {
            part1Questions++;
            if (selectedOption.isCorrect) correctInPart1++;
          }
        }
      }
      
      // Calculate Part 1 score (scale to 0-30)
      final double part1Score = part1Questions > 0 
          ? (correctInPart1 / part1Questions) * 30 
          : 0;
      final int roundedPart1Score = part1Score.round();
      
      // Create category breakdown
      final Map<String, dynamic> categoryBreakdown = {};
      final categoryTypes = _assessment?.categoryCounts ?? {};
      
      categoryTypes.forEach((category, _) {
        int total = 0;
        int correct = 0;
        
        for (final question in _questions) {
          if (question.questionTypeId == category) {
            total++;
            final userAnswer = _userAnswers[question.questionId];
            if (userAnswer != null) {
              final selectedOption = question.options.firstWhere(
                (opt) => opt.optionId == userAnswer,
                orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
              );
              if (selectedOption.isCorrect) correct++;
            }
          }
        }
        
        categoryBreakdown[category] = {
          'categoryName': category, 
          'totalQuestions': total,
          'correctAnswers': correct,
          'score': total > 0 ? (correct / total * 100).round() : 0,
          'isPassed': total > 0 ? (correct / total >= 0.75) : false,
          'passingThreshold': 75,
        };
      });
      
      // Calculate difficulty breakdown
      final Map<String, dynamic> difficultyBreakdown = {};
      final difficulties = _assessment?.difficultyLevels ?? {};
      
      difficulties.forEach((difficulty, _) {
        int total = 0;
        int correct = 0;
        
        for (final question in _questions) {
          final questionDifficulty = _getQuestionDifficultyLevel(question);
          if (questionDifficulty == difficulty) {
            total++;
            final userAnswer = _userAnswers[question.questionId];
            if (userAnswer != null) {
              final selectedOption = question.options.firstWhere(
                (opt) => opt.optionId == userAnswer,
                orElse: () => AssessmentOption(optionId: '', optionText: '', isCorrect: false),
              );
              if (selectedOption.isCorrect) correct++;
            }
          }
        }
        
        difficultyBreakdown[difficulty] = {
          'totalQuestions': total,
          'correctAnswers': correct,
          'score': total > 0 ? (correct / total * 100).round() : 0,
        };
      });
      
      // Save comprehensive category result
      final categoryResultId = await dbService.saveCategoryResult({
        'studentId': userId,
        'assessmentId': assessmentId,
        'assessmentType': _assessment!.type,
        'assessmentTitle': _assessment!.title,
        'assessmentDate': DateTime.now().toIso8601String(),
        'allCategoriesPassed': _score >= (_assessment!.totalQuestions * 0.75).round(),
        'categories': categoryBreakdown.values.toList(),
        'difficultyBreakdown': difficultyBreakdown,
        'overallScore': (_score / _assessment!.totalQuestions * 100).round(),
        'part1Score': roundedPart1Score,
        'readingPercentage': _readingPercentage,
        'readingLevel': _readingLevel ?? "Undefined",
        'readingLevelUpdated': true,
        'timeTaken': timeTaken,
        'scoringRules': _assessment!.scoringRules,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      // Update student responses with category result ID
      if (categoryResultId.isNotEmpty) {
        await dbService.updateStudentResponsesCategoryId(userId, categoryResultId);
      }
      
      // Mark assessment as completed for user
      await dbService.markAssessmentAsCompleted(userId, assessmentId);
      
      print('[AssessmentProvider] Assessment detailed results saved successfully');
    } catch (e) {
      print('[AssessmentProvider] Error saving detailed assessment results: $e');
      throw e;
    }
  }

  // Helper method to calculate time taken for the assessment
  int _calculateTimeTaken() {
    if (_assessmentStartTime == null) return 0;
    
    // If we have tracked time, use it
    final trackedTime = _readingMetrics['timeSpentReading'] ?? 0;
    if (trackedTime > 0) return trackedTime;
    
    // Otherwise, calculate from start time
    final now = DateTime.now();
    final difference = now.difference(_assessmentStartTime!);
    return difference.inSeconds;
  }

  // Helper method to get question difficulty level
  String _getQuestionDifficultyLevel(Question question) {
    // First try to access the difficulty level directly from the question
    if (question.difficultyLevel != null && question.difficultyLevel!.isNotEmpty) {
      return question.difficultyLevel!;
    }
    
    // If not available directly, try to get from the original question data
    final questionData = getOriginalQuestionData(question.questionId);
    if (questionData != null && questionData['difficultyLevel'] != null) {
      return questionData['difficultyLevel'].toString();
    }
    
    // Default fallback based on question type
    switch (question.questionTypeId) {
      case 'alphabet_knowledge':
        return 'low_emerging';
      case 'phonological_awareness':
        return 'high_emerging';
      case 'decoding':
        return 'developing';
      case 'word_recognition':
        return 'transitioning';
      case 'reading_comprehension':
        return 'at_grade_level';
      default:
        return 'developing';
    }
  }

  // Add this helper method to create options from JSON
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

  // Storage for original question data
  Map<String, dynamic> _rawQuestionData = {};

  // Add this getter method to access the original question data
  dynamic getOriginalQuestionData(String questionId) {
    if (_rawQuestionData.containsKey(questionId)) {
      return _rawQuestionData[questionId];
    }
    return null;
  }
}