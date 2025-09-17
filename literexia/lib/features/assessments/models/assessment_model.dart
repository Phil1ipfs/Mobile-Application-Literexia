// lib/features/assessments/models/assessment_model.dart
class Assessment {
  final dynamic assessmentId;
  final String title;
  final String description;
  final int totalQuestions;
  final String continueButtonText;
  final String language;
  final String type; // 'pre_assessment' or 'main_assessment'
  final String status;
  final List<Question> questions;
  final String? readingLevel; // Added for main assessments
  final String? category; // Added for main assessments

  // Added fields from JSON structure
  final Map<String, int>? categoryCounts;
  final Map<String, dynamic>? difficultyLevels;
  final Map<String, dynamic>? scoringRules;
  final String? instructions;
  final bool? isActive; // Added for main assessments

  // NEW: Store original question data for complex question types
  final List<Map<String, dynamic>>? originalQuestionsData;

  // Category-specific fields
  final String? primaryCategory;

  Assessment({
    required this.assessmentId,
    required this.title,
    required this.description,
    required this.totalQuestions,
    this.continueButtonText = 'Continue',
    this.language = 'en',
    required this.type,
    this.status = 'active',
    required this.questions,
    this.categoryCounts,
    this.difficultyLevels,
    this.scoringRules,
    this.instructions,
    this.readingLevel,
    this.category,
    this.isActive,
    this.originalQuestionsData,
    this.primaryCategory,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) {
    // Extract questions from map
    final List<Question> parsedQuestions = [];
    if (map['questions'] != null && map['questions'] is List) {
      for (final q in map['questions']) {
        try {
          parsedQuestions.add(Question.fromMap(q));
        } catch (e) {
          print('Error parsing question: $e');
        }
      }
    }

    // Extract category counts
    Map<String, int>? categoryCounts;
    if (map['categoryCounts'] != null) {
      categoryCounts = {};
      final countMap = map['categoryCounts'] as Map<String, dynamic>;
      countMap.forEach((key, value) {
        if (value is int) {
          categoryCounts![key] = value;
        } else if (value is num) {
          categoryCounts![key] = value.toInt();
        }
      });
    }

    // Determine assessment type
    String type = map['type'] ?? 'assessment';
    if (type == 'assessment') {
      // Infer type from other fields
      if (map['isPreAssessment'] == true ||
          map['assessmentId']?.toString().contains('PRE') == true) {
        type = 'pre_assessment';
      } else {
        type = 'main_assessment';
      }
    }

    // Store original questions data
    List<Map<String, dynamic>>? originalData;
    if (map['questions'] != null && map['questions'] is List) {
      originalData = (map['questions'] as List).cast<Map<String, dynamic>>();
    }

    return Assessment(
      assessmentId: map['assessmentId'] ?? map['_id'] ?? '',
      title: map['title'] ?? 'Untitled Assessment',
      description: map['description'] ?? '',
      totalQuestions: map['totalQuestions'] ?? (parsedQuestions.length),
      continueButtonText: map['continueButtonText'] ?? 'Continue',
      language: map['language'] ?? 'en',
      type: type,
      status: map['status'] ?? 'active',
      questions: parsedQuestions,
      categoryCounts: categoryCounts,
      difficultyLevels: map['difficultyLevels'],
      scoringRules: map['scoringRules'],
      instructions: map['instructions'],
      readingLevel: map['readingLevel'],
      category: map['category'],
      isActive: map['isActive'],
      originalQuestionsData: originalData,
      primaryCategory: map['primaryCategory'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assessmentId': assessmentId,
      'title': title,
      'description': description,
      'totalQuestions': totalQuestions,
      'continueButtonText': continueButtonText,
      'language': language,
      'type': type,
      'status': status,
      'questions': questions.map((q) => q.toMap()).toList(),
      if (categoryCounts != null) 'categoryCounts': categoryCounts,
      if (difficultyLevels != null) 'difficultyLevels': difficultyLevels,
      if (scoringRules != null) 'scoringRules': scoringRules,
      if (instructions != null) 'instructions': instructions,
      if (readingLevel != null) 'readingLevel': readingLevel,
      if (category != null) 'category': category,
      if (isActive != null) 'isActive': isActive,
      if (primaryCategory != null) 'primaryCategory': primaryCategory,
    };
  }

  bool get isPreAssessment => type == 'pre_assessment';
  bool get isMainAssessment => type == 'main_assessment';
}

class Question {
  final String questionId;
  final int questionNumber;
  final String questionTypeId;
  final String questionText;
  final String? displayedText;
  final bool hasImage;
  final String? imageUrl;
  final bool hasAudio;
  final String? audioUrl;
  final List<AssessmentOption> options;
  final String? questionType;
  final String? difficultyLevel;
  final List<Map<String, dynamic>>? passages;
  final List<Map<String, dynamic>>? sentenceQuestions;
  final int? order;
  final String? category;

  // NEW: Add questionSet property for phonological questions
  final Map<String, dynamic>? questionSet;

  // Category-specific fields
  final List<String>? displaySequence;
  final List<String>? dragElements;
  final List<String>? correctSequence;
  final List<String>? wordChoices;
  final String? sentenceWithBlank;
  final String? correctAnswer;

  Question({
    required this.questionId,
    required this.questionNumber,
    required this.questionTypeId,
    required this.questionText,
    this.displayedText,
    this.hasImage = false,
    this.imageUrl,
    this.hasAudio = false,
    this.audioUrl,
    required this.options,
    this.questionType,
    this.difficultyLevel,
    this.passages,
    this.sentenceQuestions,
    this.order,
    this.category,
    this.questionSet,
    this.displaySequence,
    this.dragElements,
    this.correctSequence,
    this.wordChoices,
    this.sentenceWithBlank,
    this.correctAnswer,
  });

  // Getters for backward compatibility
  String get id => questionId;
  String get correctOptionId {
    final correctOption = options.firstWhere(
      (opt) => opt.isCorrect,
      orElse: () =>
          AssessmentOption(optionId: '', optionText: '', isCorrect: false),
    );
    return correctOption.optionId;
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    // Extract options from map
    final List<AssessmentOption> parsedOptions = [];

    // Handle both "options" and "choiceOptions" field names, and "blankOptions" for word questions
    final optionsData =
        map['options'] ?? map['choiceOptions'] ?? map['blankOptions'] ?? [];

    if (optionsData is List) {
      for (int i = 0; i < optionsData.length; i++) {
        final option = optionsData[i];
        try {
          if (option is String) {
            // Handle blankOptions (just strings)
            parsedOptions.add(AssessmentOption(
              optionId: (i + 1).toString(),
              optionText: option,
              isCorrect: false, // Will be determined during answer checking
            ));
          } else {
            parsedOptions.add(AssessmentOption.fromMap(option));
          }
        } catch (e) {
          print('Error parsing option: $e');
        }
      }
    }

    // Parse passages if available
    List<Map<String, dynamic>>? passages;
    if (map['passages'] != null &&
        map['passages'] is List &&
        (map['passages'] as List).isNotEmpty) {
      passages = [];
      for (final passage in map['passages']) {
        if (passage is Map) {
          passages.add(Map<String, dynamic>.from(passage));
        }
      }
    }

    // Parse sentence questions if available
    List<Map<String, dynamic>>? sentenceQuestions;
    if (map['sentenceQuestions'] != null &&
        map['sentenceQuestions'] is List &&
        (map['sentenceQuestions'] as List).isNotEmpty) {
      sentenceQuestions = [];
      for (final sq in map['sentenceQuestions']) {
        if (sq is Map) {
          sentenceQuestions.add(Map<String, dynamic>.from(sq));
        }
      }
    }

    // Special handling for sentence questions in reading comprehension
    if (parsedOptions.isEmpty &&
        sentenceQuestions != null &&
        sentenceQuestions.isNotEmpty) {
      final sentenceQuestion = sentenceQuestions.first;

      // Create options based on correct and incorrect answers
      if (sentenceQuestion['correctAnswer'] != null) {
        parsedOptions.add(AssessmentOption(
          optionId: '1',
          optionText: sentenceQuestion['correctAnswer'],
          isCorrect: true,
        ));
      }

      if (sentenceQuestion['incorrectAnswer'] != null) {
        parsedOptions.add(AssessmentOption(
          optionId: '2',
          optionText: sentenceQuestion['incorrectAnswer'],
          isCorrect: false,
        ));
      }
    }

    // Determine image URL from different possible fields
    String? imageUrl = map['imageUrl'];
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = map['questionImage'];
    }

    // Handle questionSet data for phonological awareness
    Map<String, dynamic>? questionSet;
    if (map['questionSet'] != null) {
      questionSet = Map<String, dynamic>.from(map['questionSet']);
    }

    // Parse category-specific fields
    List<String>? displaySequence;
    if (map['displaySequence'] != null && map['displaySequence'] is List) {
      displaySequence = (map['displaySequence'] as List).cast<String>();
    }

    List<String>? dragElements;
    if (map['dragElements'] != null && map['dragElements'] is List) {
      dragElements = (map['dragElements'] as List).cast<String>();
    }

    List<String>? correctSequence;
    if (map['correctSequence'] != null && map['correctSequence'] is List) {
      correctSequence = (map['correctSequence'] as List).cast<String>();
    }

    List<String>? wordChoices;
    if (map['wordChoices'] != null && map['wordChoices'] is List) {
      wordChoices = (map['wordChoices'] as List).cast<String>();
    } else if (map['blankOptions'] != null && map['blankOptions'] is List) {
      wordChoices = (map['blankOptions'] as List).cast<String>();
    }

    return Question(
      questionId: map['questionId'] ?? '',
      questionNumber: map['questionNumber'] ?? 0,
      questionTypeId: map['questionTypeId'] ?? '',
      questionText: map['questionText'] ?? '',
      displayedText: map['questionValue'] ?? map['displayedText'],
      hasImage: map['hasImage'] == true ||
          map['questionImage'] != null ||
          imageUrl != null,
      imageUrl: imageUrl,
      hasAudio: map['hasAudio'] == true || map['audioUrl'] != null,
      audioUrl: map['audioUrl'],
      options: parsedOptions,
      questionType: map['questionType'],
      difficultyLevel: map['difficultyLevel'],
      passages: passages,
      sentenceQuestions: sentenceQuestions,
      order: map['order'],
      category: map['category'],
      questionSet: questionSet,
      displaySequence: map['displaySequence'],
      dragElements: dragElements,
      correctSequence: correctSequence,
      wordChoices: wordChoices,
      sentenceWithBlank: map['sentenceWithBlank'] ?? map['displayWord'],
      correctAnswer: map['correctAnswer'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionNumber': questionNumber,
      'questionTypeId': questionTypeId,
      'questionText': questionText,
      'displayedText': displayedText,
      'hasImage': hasImage,
      'imageUrl': imageUrl,
      'hasAudio': hasAudio,
      'audioUrl': audioUrl,
      'options': options.map((o) => o.toMap()).toList(),
      if (questionType != null) 'questionType': questionType,
      if (difficultyLevel != null) 'difficultyLevel': difficultyLevel,
      if (passages != null) 'passages': passages,
      if (sentenceQuestions != null) 'sentenceQuestions': sentenceQuestions,
      if (order != null) 'order': order,
      if (category != null) 'category': category,
      if (questionSet != null) 'questionSet': questionSet,
      if (displaySequence != null) 'displaySequence': displaySequence,
      if (dragElements != null) 'dragElements': dragElements,
      if (correctSequence != null) 'correctSequence': correctSequence,
      if (wordChoices != null) 'wordChoices': wordChoices,
      if (sentenceWithBlank != null) 'sentenceWithBlank': sentenceWithBlank,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
    };
  }
}

class AssessmentOption {
  final String optionId;
  final String optionText;
  final bool isCorrect;
  final String? explanation;

  AssessmentOption({
    required this.optionId,
    required this.optionText,
    required this.isCorrect,
    this.explanation,
  });

  factory AssessmentOption.fromMap(Map<String, dynamic> map) {
    return AssessmentOption(
      optionId: map['optionId'] ?? '',
      optionText: map['optionText'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
      explanation: map['explanation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'optionId': optionId,
      'optionText': optionText,
      'isCorrect': isCorrect,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class QuestionType {
  final String typeId;
  final String typeName;
  final String? description;

  QuestionType({
    required this.typeId,
    required this.typeName,
    this.description,
  });

  factory QuestionType.fromMap(Map<String, dynamic> map) {
    return QuestionType(
      typeId: map['typeId'] ?? '',
      typeName: map['typeName'] ?? '',
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeId': typeId,
      'typeName': typeName,
      if (description != null) 'description': description,
    };
  }
}
