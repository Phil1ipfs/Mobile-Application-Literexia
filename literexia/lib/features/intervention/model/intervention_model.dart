// lib/features/interventions/models/intervention_model.dart

class InterventionAssessment {
  final String id;
  final String name;
  final String description;
  final String category;
  final String readingLevel;
  final double passThreshold;
  final List<InterventionQuestion> questions;
  final String studentId;
  final String studentNumber;
  final String categoryResultId;
  final String prescriptiveAnalysisId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  InterventionAssessment({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.readingLevel,
    required this.passThreshold,
    required this.questions,
    required this.studentId,
    required this.studentNumber,
    required this.categoryResultId,
    required this.prescriptiveAnalysisId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterventionAssessment.fromMap(Map<String, dynamic> map) {
    List<InterventionQuestion> questionsList = [];
    if (map['questions'] != null && map['questions'] is List) {
      questionsList = (map['questions'] as List)
          .map((q) => InterventionQuestion.fromMap(q))
          .toList();
    }

    return InterventionAssessment(
      id: map['_id']?.toString() ?? '',
      name: map['name'] ?? 'Intervention Assessment',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      readingLevel: map['readingLevel'] ?? '',
      passThreshold: (map['passThreshold'] is num)
          ? (map['passThreshold'] as num).toDouble()
          : 75.0,
      questions: questionsList,
      studentId: map['studentId']?.toString() ?? '',
      studentNumber: map['studentNumber']?.toString() ?? '',
      categoryResultId: map['categoryResultId']?.toString() ?? '',
      prescriptiveAnalysisId: map['prescriptiveAnalysisId']?.toString() ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'category': category,
      'readingLevel': readingLevel,
      'passThreshold': passThreshold,
      'questions': questions.map((q) => q.toMap()).toList(),
      'studentId': studentId,
      'studentNumber': studentNumber,
      'categoryResultId': categoryResultId,
      'prescriptiveAnalysisId': prescriptiveAnalysisId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class InterventionQuestion {
  final String questionId;
  final String source;
  final String sourceQuestionId;
  final int questionIndex;
  final String questionType;
  final String questionText;
  final String? questionImage;
  final String? questionValue;
  final List<String> choiceIds;
  final String correctChoiceId;
  final List<InterventionChoice> choices;

  InterventionQuestion({
    required this.questionId,
    required this.source,
    required this.sourceQuestionId,
    required this.questionIndex,
    required this.questionType,
    required this.questionText,
    this.questionImage,
    this.questionValue,
    required this.choiceIds,
    required this.correctChoiceId,
    required this.choices,
  });

  factory InterventionQuestion.fromMap(Map<String, dynamic> map) {
    List<InterventionChoice> choicesList = [];
    if (map['choices'] != null && map['choices'] is List) {
      choicesList = (map['choices'] as List)
          .map((c) => InterventionChoice.fromMap(c))
          .toList();
    }

    List<String> choiceIdsList = [];
    if (map['choiceIds'] != null && map['choiceIds'] is List) {
      choiceIdsList = (map['choiceIds'] as List).map((c) => c.toString()).toList();
    }

    return InterventionQuestion(
      questionId: map['questionId']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      sourceQuestionId: map['sourceQuestionId']?.toString() ?? '',
      questionIndex: map['questionIndex'] is int ? map['questionIndex'] : 0,
      questionType: map['questionType']?.toString() ?? '',
      questionText: map['questionText']?.toString() ?? '',
      questionImage: map['questionImage']?.toString(),
      questionValue: map['questionValue']?.toString(),
      choiceIds: choiceIdsList,
      correctChoiceId: map['correctChoiceId']?.toString() ?? '',
      choices: choicesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'source': source,
      'sourceQuestionId': sourceQuestionId,
      'questionIndex': questionIndex,
      'questionType': questionType,
      'questionText': questionText,
      'questionImage': questionImage,
      'questionValue': questionValue,
      'choiceIds': choiceIds,
      'correctChoiceId': correctChoiceId,
      'choices': choices.map((c) => c.toMap()).toList(),
    };
  }
}

class InterventionChoice {
  final String optionText;
  final bool isCorrect;
  final String description;
  final String? id;

  InterventionChoice({
    required this.optionText,
    required this.isCorrect,
    required this.description,
    this.id,
  });

  factory InterventionChoice.fromMap(Map<String, dynamic> map) {
    return InterventionChoice(
      optionText: map['optionText']?.toString() ?? '',
      isCorrect: map['isCorrect'] is bool ? map['isCorrect'] : false,
      description: map['description']?.toString() ?? '',
      id: map['_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'optionText': optionText,
      'isCorrect': isCorrect,
      'description': description,
      if (id != null) '_id': id,
    };
  }
}

class InterventionResult {
  final String id;
  final String userId;
  final String studentNumber;
  final String interventionAssessmentId;
  final double score;
  final Map<String, String> answers;
  final bool isPassed;
  final DateTime completedAt;
  final DateTime createdAt;

  InterventionResult({
    required this.id,
    required this.userId,
    required this.studentNumber,
    required this.interventionAssessmentId,
    required this.score,
    required this.answers,
    required this.isPassed,
    required this.completedAt,
    required this.createdAt,
  });

  factory InterventionResult.fromMap(Map<String, dynamic> map) {
    // Convert answers map
    Map<String, String> answersMap = {};
    if (map['answers'] is Map) {
      (map['answers'] as Map).forEach((key, value) {
        answersMap[key.toString()] = value.toString();
      });
    }

    return InterventionResult(
      id: map['_id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      studentNumber: map['studentNumber']?.toString() ?? '',
      interventionAssessmentId: map['interventionAssessmentId']?.toString() ?? '',
      score: (map['score'] is num) ? (map['score'] as num).toDouble() : 0.0,
      answers: answersMap,
      isPassed: map['isPassed'] is bool ? map['isPassed'] : false,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'].toString())
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'userId': userId,
      'studentNumber': studentNumber,
      'interventionAssessmentId': interventionAssessmentId,
      'score': score,
      'answers': answers,
      'isPassed': isPassed,
      'completedAt': completedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}