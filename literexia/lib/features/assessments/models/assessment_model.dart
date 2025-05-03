// lib/features/assessments/models/assessment_model.dart
class AssessmentOption {
  final String optionId;
  final String optionText;
  final bool isCorrect;

  AssessmentOption({
    required this.optionId,
    required this.optionText,
    required this.isCorrect,
  });

   factory AssessmentOption.fromMap(Map<String, dynamic> map) {
  try {
    return AssessmentOption(
      optionId   : map['optionId']?.toString() ?? map['optionText']?.toString() ?? '',
      optionText : map['optionText']?.toString() ?? map['optionId']?.toString() ?? '',
      isCorrect  : map['isCorrect'] as bool? ?? false,
    );
  } catch (e) {
    print('Error in AssessmentOption.fromMap: $e');
    rethrow;
  }
}
}

class Question {
  final String  questionId;
  final int?    questionNumber;     // nullable
  final String  questionTypeId;
  final String  questionText;
  final bool?   hasImage;           // nullable
  final String? imageUrl;
  final String? imageAlt;
  final bool?   hasAudio;           // nullable
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
      // Corrected to handle both typeId and questionTypeId field names
      final typeId = map['typeId']?.toString() ?? 
                    map['questionTypeId']?.toString() ?? 'unknown';
      
      print('Question.fromMap: questionId=${map['questionId']}, typeId=$typeId');
      
      return Question(
        questionId      : map['questionId'].toString(),
        questionNumber  : (map['questionNumber'] as int?) ?? 0,
        questionTypeId  : typeId,
        questionText    : map['questionText']?.toString() ?? '',
        hasImage        : map['hasImage'] as bool? ?? false,
        imageUrl        : map['imageUrl']?.toString(),
        imageAlt        : map['imageAlt']?.toString(),
        hasAudio        : map['hasAudio'] as bool? ?? false,
        audioUrl        : map['audioUrl']?.toString(),
        audioText       : map['audioText']?.toString(),
        displayedText   : map['displayedText']?.toString(),
        options: List<AssessmentOption>.from(
          (map['options'] as List<dynamic>).map((opt) {
            if (opt is Map) {
              // full object  ➜ parse normally
              return AssessmentOption.fromMap(Map<String, dynamic>.from(opt));
            } else {
              // simple string  ➜ wrap in a default map
              final text = opt.toString();
              // true if there's a top‑level `correctOption` that matches this choice
              final isCorrect = map['correctOption']?.toString() == text;
              return AssessmentOption(
                optionId   : text,
                optionText : text,
                isCorrect  : isCorrect,
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
  });

  factory Assessment.fromMap(Map<String, dynamic> map) {
    try {
      return Assessment(
        assessmentId: map['assessmentId'], // Accept any type without casting
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
              // Convert to String-keyed map first
              Map<String, dynamic> questionMap = {};
              (x as Map).forEach((key, value) {
                questionMap[key.toString()] = value;
              });
              return Question.fromMap(questionMap);
            },
          ),
        ),
      );
    } catch (e) {
      print('Error in Assessment.fromMap: $e');
      rethrow;
    }
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