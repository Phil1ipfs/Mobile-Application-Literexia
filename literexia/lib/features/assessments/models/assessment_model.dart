// lib/features/assessments/models/assessment_model.dart
class AssessmentOption {
  final String optionId;
  final String optionText;
  final bool isCorrect;
  final String? audioUrl;

  AssessmentOption({
    required this.optionId,
    required this.optionText,
    required this.isCorrect,
    this.audioUrl,
  });

  factory AssessmentOption.fromMap(Map<String, dynamic> map) {
    try {
      return AssessmentOption(
        optionId: map['optionId']?.toString() ?? '',
        optionText: map['optionText']?.toString() ?? '',
        isCorrect: map['isCorrect'] as bool? ?? false,
        audioUrl: map['audioUrl']?.toString(),
      );
    } catch (e) {
      print('Error in AssessmentOption.fromMap: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
      'optionId': optionId,
      'optionText': optionText,
      'isCorrect': isCorrect,
    };
    
    if (audioUrl != null) {
      map['audioUrl'] = audioUrl as String;
    }
    
    return map;
  }
}

class Question {
  final String questionId;
  final int? questionNumber;
  final String questionTypeId;
  final String questionText;
  final bool? hasImage;
  final String? imageUrl;
  final String? imageAlt;
  final bool? hasAudio;
  final String? audioUrl;
  final String? audioText;
  final String? displayedText;
  final List<AssessmentOption> options;

  Question({
    required this.questionId,
    this.questionNumber,
    required this.questionTypeId,
    required this.questionText,
    this.hasImage,
    this.imageUrl,
    this.imageAlt,
    this.hasAudio,
    this.audioUrl,
    this.audioText,
    this.displayedText,
    required this.options,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    try {
      // Handle both typeId and questionTypeId field names
      final typeId = map['typeId']?.toString() ?? 
                    map['questionTypeId']?.toString() ?? 'unknown';
      
      // Handle both question prompts (displayed text)
      final displayText = map['displayedText']?.toString() ?? 
                        map['prompt']?.toString();
      
      return Question(
        questionId: map['questionId'].toString(),
        questionNumber: map['questionNumber'] as int?,
        questionTypeId: typeId,
        questionText: map['questionText']?.toString() ?? '',
        hasImage: map['hasImage'] as bool? ?? false,
        imageUrl: map['imageUrl']?.toString(),
        imageAlt: map['imageAlt']?.toString(),
        hasAudio: map['hasAudio'] as bool? ?? false,
        audioUrl: map['audioUrl']?.toString(),
        audioText: map['audioText']?.toString(),
        displayedText: displayText,
        options: List<AssessmentOption>.from(
          (map['options'] as List<dynamic>).map((opt) {
            if (opt is Map) {
              return AssessmentOption.fromMap(Map<String, dynamic>.from(opt));
            } else {
              // Handle simple string options
              final text = opt.toString();
              final isCorrect = map['correctOption']?.toString() == text;
              return AssessmentOption(
                optionId: text,
                optionText: text,
                isCorrect: isCorrect,
              );
            }
          }),
        ),
      );
    } catch (e) {
      print('Error in Question.fromMap: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
      'questionId': questionId,
      'questionTypeId': questionTypeId,
      'questionText': questionText,
      'options': options.map((o) => o.toMap()).toList(),
    };
    
    if (questionNumber != null) map['questionNumber'] = questionNumber as int;
    if (hasImage != null) map['hasImage'] = hasImage as int;
    if (imageUrl != null) map['imageUrl'] = imageUrl as int;
    if (imageAlt != null) map['imageAlt'] = imageAlt as int;
    if (hasAudio != null) map['hasAudio'] = hasAudio as int;
    if (audioUrl != null) map['audioUrl'] = audioUrl as int;
    if (audioText != null) map['audioText'] = audioText as int;
    if (displayedText != null) map['displayedText'] = displayedText as int;
    
    return map;
  }
}

class ScoringRule {
  final int minScore;
  final int maxScore;
  final List<int> readingPercentage;
  
  ScoringRule({
    required this.minScore,
    required this.maxScore,
    required this.readingPercentage,
  });
  
  factory ScoringRule.fromMap(Map<String, dynamic> map) {
    return ScoringRule(
      minScore: map['minScore'] as int,
      maxScore: map['maxScore'] as int,
      readingPercentage: List<int>.from(map['readingPercentage']),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'minScore': minScore,
      'maxScore': maxScore,
      'readingPercentage': readingPercentage,
    };
  }
}

class Assessment {
  final dynamic assessmentId;
  final String title;
  final String description;
  final int totalQuestions;
  final String continueButtonText;
  final String language;
  final String type;
  final String status;
  final List<Question> questions;
  final Map<String, dynamic>? scoringRules;

  Assessment({
    required this.assessmentId,
    required this.title,
    required this.description,
    required this.totalQuestions,
    required this.continueButtonText,
    required this.language,
    required this.type,
    required this.status,
    required this.questions,
    this.scoringRules,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) {
    try {
      // Process scoring rules if available
      Map<String, dynamic>? rules;
      if (map['scoringRules'] != null) {
        rules = Map<String, dynamic>.from(map['scoringRules'] as Map<String, dynamic>);
      }
      
      return Assessment(
        assessmentId: map['assessmentId'],
        title: map['title'] as String,
        description: map['description'] as String,
        totalQuestions: map['totalQuestions'] as int,
        continueButtonText: map['continueButtonText'] as String,
        language: map['language'] as String,
        type: map['type'] as String,
        status: map['status'] as String,
        questions: List<Question>.from(
          (map['questions'] as List<dynamic>).map(
            (x) {
              // Convert to String-keyed map
              Map<String, dynamic> questionMap = {};
              (x as Map).forEach((key, value) {
                questionMap[key.toString()] = value;
              });
              return Question.fromMap(questionMap);
            },
          ),
        ),
        scoringRules: rules,
      );
    } catch (e) {
      print('Error in Assessment.fromMap: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
      'assessmentId': assessmentId,
      'title': title,
      'description': description,
      'totalQuestions': totalQuestions,
      'continueButtonText': continueButtonText,
      'language': language,
      'type': type,
      'status': status,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
    
    if (scoringRules != null) {
      map['scoringRules'] = scoringRules;
    }
    
    return map;
  }
}

class QuestionType {
  final String typeId;
  final String typeName;

  QuestionType({
    required this.typeId,
    required this.typeName,
  });

  factory QuestionType.fromMap(Map<String, dynamic> map) {
    return QuestionType(
      typeId: map['typeId'] as String,
      typeName: map['typeName'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeId': typeId,
      'typeName': typeName,
    };
  }
}