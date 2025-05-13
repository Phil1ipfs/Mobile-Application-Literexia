// lib/features/assessments/models/assessment_model.dart
class AssessmentOption {
  final String optionId;
  final String optionText;
  final bool isCorrect;
  final String? audioUrl;
  final String? explanation; // Add this field

  AssessmentOption({
    required this.optionId,
    required this.optionText,
    required this.isCorrect,
    this.audioUrl,
    this.explanation, // Add this parameter
  });

  factory AssessmentOption.fromMap(Map<String, dynamic> map) {
    try {
      return AssessmentOption(
        optionId: map['optionId']?.toString() ?? '',
        optionText: map['optionText']?.toString() ?? '',
        isCorrect: map['isCorrect'] as bool? ?? false,
        audioUrl: map['audioUrl']?.toString(),
        explanation: map['explanation']?.toString(), // Add this
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
    
    if (explanation != null) {
      map['explanation'] = explanation as String;
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
      
      // Safe conversion for questionNumber
      int? questionNumber;
      if (map['questionNumber'] != null) {
        if (map['questionNumber'] is int) {
          questionNumber = map['questionNumber'] as int;
        } else if (map['questionNumber'] is String) {
          questionNumber = int.tryParse(map['questionNumber'] as String);
        }
      }
      
      return Question(
        questionId: map['questionId'].toString(),
        questionNumber: questionNumber,
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
  
  // Add fromJson factory method
  factory Question.fromJson(Map<String, dynamic> json) => Question.fromMap(json);

  Map<String, dynamic> toMap() {
    final map = {
      'questionId': questionId,
      'questionTypeId': questionTypeId,
      'questionText': questionText,
      'options': options.map((o) => o.toMap()).toList(),
    };
    
    if (questionNumber != null) map['questionNumber'] = questionNumber as int;
    if (hasImage != null) map['hasImage'] = hasImage as bool;  // Fixed: was int
    if (imageUrl != null) map['imageUrl'] = imageUrl as String;  // Fixed: was int
    if (imageAlt != null) map['imageAlt'] = imageAlt as String;  // Fixed: was int
    if (hasAudio != null) map['hasAudio'] = hasAudio as bool;  // Fixed: was int
    if (audioUrl != null) map['audioUrl'] = audioUrl as String;  // Fixed: was int
    if (audioText != null) map['audioText'] = audioText as String;  // Fixed: was int
    if (displayedText != null) map['displayedText'] = displayedText as String;  // Fixed: was int
    
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
  
  // Add fromJson factory method
  factory ScoringRule.fromJson(Map<String, dynamic> json) => ScoringRule.fromMap(json);
  
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
  final int? categoryID;
  final String? categoryName;
  final String? targetReadingLevel;
  final int totalQuestions;
  final int? passingThreshold;
  final String status;
  final bool? isPublished;
  final List<Question> questions;
  final String? instructions;
  final String continueButtonText;
  final String? language;
  final String? type;
  final Map<String, dynamic>? scoringRules;

  Assessment({
    required this.assessmentId,
    required this.title,
    required this.description,
    this.categoryID,
    this.categoryName,
    this.targetReadingLevel,
    required this.totalQuestions,
    this.passingThreshold,
    required this.status,
    this.isPublished,
    required this.questions,
    this.instructions,
    required this.continueButtonText,
    this.language = 'en',
    this.type = 'assessment',
    this.scoringRules,
  });

  Assessment copyWith({
    dynamic assessmentId,
    String? title,
    String? description,
    int? categoryID,
    String? categoryName,
    String? targetReadingLevel,
    int? totalQuestions,
    int? passingThreshold,
    String? status,
    bool? isPublished,
    List<Question>? questions,
    String? instructions,
    String? continueButtonText,
    String? language,
    String? type,
    Map<String, dynamic>? scoringRules,
  }) {
    return Assessment(
      assessmentId: assessmentId ?? this.assessmentId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryID: categoryID ?? this.categoryID,
      categoryName: categoryName ?? this.categoryName,
      targetReadingLevel: targetReadingLevel ?? this.targetReadingLevel,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      passingThreshold: passingThreshold ?? this.passingThreshold,
      status: status ?? this.status,
      isPublished: isPublished ?? this.isPublished,
      questions: questions ?? this.questions,
      instructions: instructions ?? this.instructions,
      continueButtonText: continueButtonText ?? this.continueButtonText,
      language: language ?? this.language,
      type: type ?? this.type,
      scoringRules: scoringRules ?? this.scoringRules,
    );
  }

  factory Assessment.fromMap(Map<String, dynamic> map) {
    try {
      // Check if the document has a "parts" structure and extract the first part
      Map<String, dynamic> partData = {};
      List<Question> questions = [];
      
      if (map.containsKey('parts') && map['parts'] is List && (map['parts'] as List).isNotEmpty) {
        // Extract data from the first part
        final firstPart = (map['parts'] as List).first as Map;
        
        // Add keys from the part to our data map
        firstPart.forEach((key, value) {
          partData[key.toString()] = value;
        });
        
        // Check if the part has questions directly
        if (firstPart.containsKey('questions') && firstPart['questions'] is List) {
          questions = List<Question>.from(
            (firstPart['questions'] as List).map((q) => Question.fromMap(Map<String, dynamic>.from(q)))
          );
        }
      } else if (map.containsKey('questions') && map['questions'] is List) {
        // Direct questions array
        questions = List<Question>.from(
          (map['questions'] as List).map((q) => Question.fromMap(Map<String, dynamic>.from(q)))
        );
      }
      
      // Safe getters for strings and integers with defaults
      String getString(String key, {String defaultValue = ''}) {
        if (partData.containsKey(key) && partData[key] != null) {
          return partData[key].toString();
        }
        if (map.containsKey(key) && map[key] != null) {
          return map[key].toString();
        }
        return defaultValue;
      }
      
      int getInt(String key, {int defaultValue = 0}) {
        var value;
        if (partData.containsKey(key) && partData[key] != null) {
          value = partData[key];
        } else if (map.containsKey(key) && map[key] != null) {
          value = map[key];
        } else {
          return defaultValue;
        }
        
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? defaultValue;
        return defaultValue;
      }
      
      bool getBool(String key, {bool defaultValue = false}) {
        var value;
        if (partData.containsKey(key) && partData[key] != null) {
          value = partData[key];
        } else if (map.containsKey(key) && map[key] != null) {
          value = map[key];
        } else {
          return defaultValue;
        }
        
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        if (value is int) return value == 1;
        return defaultValue;
      }
      
      // Process any scoring rules
      Map<String, dynamic>? rules;
      if (map.containsKey('scoringRules') && map['scoringRules'] != null) {
        rules = Map<String, dynamic>.from(map['scoringRules'] as Map<String, dynamic>);
      } else if (partData.containsKey('scoringRules') && partData['scoringRules'] != null) {
        rules = Map<String, dynamic>.from(partData['scoringRules'] as Map<String, dynamic>);
      }
      
      // If no questions have been found yet, look in the categories or other possible places
      if (questions.isEmpty && partData.containsKey('categories') && partData['categories'] is List) {
        // Try to find questions in categories if they exist
        final allCategoryQuestions = <Question>[];
        
        for (final category in partData['categories'] as List) {
          if (category is Map && category.containsKey('questions') && category['questions'] is List) {
            final categoryQuestions = (category['questions'] as List).map((q) {
              final qMap = Map<String, dynamic>.from(q as Map);
              // Add the category ID to the question for reference
              if (category.containsKey('categoryID')) {
                qMap['questionTypeId'] = category['categoryID'].toString();
              }
              return Question.fromMap(qMap);
            }).toList();
            
            allCategoryQuestions.addAll(categoryQuestions);
          }
        }
        
        if (allCategoryQuestions.isNotEmpty) {
          questions = allCategoryQuestions;
        }
      }
      
      // Get categoryID
      int? categoryID;
      if (map.containsKey('categoryID')) {
        if (map['categoryID'] is int) {
          categoryID = map['categoryID'];
        } else {
          categoryID = int.tryParse(map['categoryID'].toString());
        }
      }
      
      return Assessment(
        assessmentId: map['assessmentId'],
        title: getString('title', defaultValue: 'Untitled Assessment'),
        description: getString('description', defaultValue: 'No description'),
        categoryID: categoryID,
        categoryName: getString('categoryName'),
        targetReadingLevel: getString('targetReadingLevel'),
        totalQuestions: getInt('totalQuestions', defaultValue: questions.length),
        passingThreshold: map.containsKey('passingThreshold') ? getInt('passingThreshold') : null,
        status: getString('status', defaultValue: 'active'),
        isPublished: getBool('isPublished'),
        questions: questions,
        instructions: getString('instructions'),
        continueButtonText: getString('continueButtonText', defaultValue: 'Continue'),
        language: getString('language', defaultValue: 'en'),
        type: getString('type', defaultValue: 'assessment'),
        scoringRules: rules,
      );
    } catch (e) {
      print('Error in Assessment.fromMap: $e');
      rethrow;
    }
  }
  
  // Add fromJson factory method
  factory Assessment.fromJson(Map<String, dynamic> json) => Assessment.fromMap(json);

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
    
    if (categoryID != null) map['categoryID'] = categoryID;
    if (categoryName != null) map['categoryName'] = categoryName;
    if (targetReadingLevel != null) map['targetReadingLevel'] = targetReadingLevel;
    if (passingThreshold != null) map['passingThreshold'] = passingThreshold;
    if (isPublished != null) map['isPublished'] = isPublished;
    if (instructions != null) map['instructions'] = instructions;
    
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
  
  // Add fromJson factory method
  factory QuestionType.fromJson(Map<String, dynamic> json) => QuestionType.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'typeId': typeId,
      'typeName': typeName,
    };
  }
}