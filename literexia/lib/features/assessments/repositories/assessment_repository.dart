// lib/features/assessments/repositories/assessment_repository.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';
import '../../../services/database_service.dart';

class AssessmentRepository {
  /// Stores raw question data for reference (e.g., for answer checking)
  final Map<String, dynamic> _rawQuestionData = {};

  /// Collection names - distinguish between pre-assessment and main assessment
  static const String _collMainAssessment =
      'main_assessment'; // For lessons AFTER pre-assessment
  static const String _collPreAssessment =
      'pre-assessment'; // For initial assessment
  static const String _collUsers = 'users';
  static const String _collStudentResponses = 'student_responses';
  static const String _collCategoryResults = 'category_results';

  /// Get database service instance
  DatabaseService get _dbService => DatabaseService();

  /// Get PRE-ASSESSMENT (for new users who haven't completed initial assessment)
  Future<Assessment?> getPreAssessment() async {
    try {
      print('[AssessmentRepository] Loading PRE-ASSESSMENT for new user');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected');
        return null;
      }

      // Try to get from Pre_Assessment database first
      try {
        final preAssessmentDb = await _dbService.getPreAssessmentDatabase();
        final preAssessmentCollection =
            preAssessmentDb.collection(_collPreAssessment);

        // Look for pre-assessment document
        final doc = await preAssessmentCollection
            .findOne(where.eq('type', 'pre_assessment'));

        if (doc != null) {
          print(
              '[AssessmentRepository] Found pre-assessment in Pre_Assessment database');
          return _convertPreAssessmentToModel(doc);
        }
      } catch (e) {
        print(
            '[AssessmentRepository] Pre_Assessment database not available: $e');
      }

      // If no pre-assessment found, return null
      print('[AssessmentRepository] No pre-assessment found');
      return null;
    } catch (e) {
      print('[AssessmentRepository] Error loading pre-assessment: $e');
      return null;
    }
  }

  /// Get MAIN ASSESSMENT (for users who completed pre-assessment, used for lessons)
  /// Now with strict reading level filtering
  Future<Assessment?> getMainAssessment(dynamic id,
      {String? readingLevel}) async {
    try {
      print(
          '[AssessmentRepository] Loading MAIN ASSESSMENT with ID: $id for reading level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }

      // Use the main_assessment collection for lessons
      final assessmentCollection =
          _dbService.getCollection(_collMainAssessment);

      Map<String, dynamic>? doc;

      // PRIORITY 1: If readingLevel provided, find EXACT match by readingLevel and isActive
      if (readingLevel != null &&
          readingLevel.isNotEmpty &&
          readingLevel != 'Undefined') {
        // Normalize the reading level to ensure consistent matching
        final normalizedLevel = _normalizeReadingLevel(readingLevel);

        print(
            '[AssessmentRepository] Searching for EXACT reading level match: $normalizedLevel');

        var query = where
            .eq('readingLevel', normalizedLevel)
            .and(where.eq('isActive', true));
        var assessments = await assessmentCollection.find(query).toList();

        if (assessments.isNotEmpty) {
          // If we have an ID, try to find that specific assessment
          if (id != null) {
            doc = assessments.firstWhere(
              (a) =>
                  a['_id'].toString() == id.toString() ||
                  a['assessmentId']?.toString() == id.toString(),
              orElse: () => assessments.first,
            );
          } else {
            doc = assessments.first;
          }
          print('[AssessmentRepository] Found assessment by reading level');
        }
      }

      // PRIORITY 2: If no match by reading level, try by ID
      if (doc == null && id != null && id is String && id.length == 24) {
        try {
          final objectId = ObjectId.fromHexString(id);
          doc = await assessmentCollection.findOne(where.eq('_id', objectId));

          if (doc != null) {
            print('[AssessmentRepository] Found assessment by ObjectId');

            // Verify the reading level matches if one was specified
            if (readingLevel != null && readingLevel.isNotEmpty) {
              final assessmentLevel = doc['readingLevel']?.toString() ?? '';
              final normalizedRequestedLevel =
                  _normalizeReadingLevel(readingLevel);
              final normalizedAssessmentLevel =
                  _normalizeReadingLevel(assessmentLevel);

              if (normalizedAssessmentLevel != normalizedRequestedLevel) {
                print(
                    '[AssessmentRepository] Assessment found but reading level mismatch: $normalizedAssessmentLevel vs $normalizedRequestedLevel');
                return null; // Don't return assessment for wrong reading level
              }
            }
          }
        } catch (e) {
          print('[AssessmentRepository] Not a valid ObjectId: $e');
        }
      }

      if (doc != null) {
        // Final validation: ensure assessment matches requested reading level
        if (readingLevel != null &&
            readingLevel.isNotEmpty &&
            readingLevel != 'Undefined') {
          final assessmentLevel = doc['readingLevel']?.toString() ?? '';
          final normalizedRequestedLevel = _normalizeReadingLevel(readingLevel);
          final normalizedAssessmentLevel =
              _normalizeReadingLevel(assessmentLevel);

          if (normalizedAssessmentLevel != normalizedRequestedLevel) {
            print(
                '[AssessmentRepository] Final check failed: Assessment level $normalizedAssessmentLevel does not match requested level $normalizedRequestedLevel');
            return null;
          }
        }

        print(
            '[AssessmentRepository] Found valid assessment: ${doc['category'] ?? 'Unknown Category'} for level ${doc['readingLevel']}');
        return _convertMainAssessmentToModel(doc);
      } else {
        print(
            '[AssessmentRepository] No suitable assessment found for the specified criteria');
        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] Error getting main assessment: $e');
      return null;
    }
  }

  /// Convert pre-assessment document to Assessment model
  Assessment _convertPreAssessmentToModel(Map<String, dynamic> doc) {
    List<Question> questions = [];

    print('[AssessmentRepository] Converting pre-assessment document to model');

    if (doc['questions'] != null && doc['questions'] is List) {
      final questionsList = doc['questions'] as List;
      print(
          '[AssessmentRepository] Processing ${questionsList.length} pre-assessment questions');

      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];

        final questionId = q['questionId'] ?? 'pre_q_${i + 1}';
        final questionType = q['questionTypeId'] ?? 'alphabet_knowledge';
        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? q['displayedText'] ?? '';
        final questionImage = q['questionImage'] ?? q['imageUrl'];

        // Process passages and sentenceQuestions for pre-assessment
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null) {
          print(
              '[AssessmentRepository] Pre-assessment question $questionId has passages data');

          if (q['passages'] is List) {
            passages = [];
            for (final passage in q['passages']) {
              if (passage is Map) {
                final passageMap = Map<String, dynamic>.from(passage);
                passages.add(passageMap);
              }
            }
            print(
                '[AssessmentRepository] Processed ${passages.length} passages for pre-assessment question $questionId');
          } else if (q['passages'] is Map) {
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
            print(
                '[AssessmentRepository] Processed single passage map for pre-assessment question $questionId');
          }
        }

        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null) {
          print(
              '[AssessmentRepository] Pre-assessment question $questionId has sentenceQuestions data');

          if (q['sentenceQuestions'] is List) {
            sentenceQuestions = [];
            for (final sq in q['sentenceQuestions']) {
              if (sq is Map) {
                sentenceQuestions.add(Map<String, dynamic>.from(sq));
              }
            }
            print(
                '[AssessmentRepository] Processed ${sentenceQuestions.length} sentenceQuestions for pre-assessment question $questionId');
          } else if (q['sentenceQuestions'] is Map) {
            sentenceQuestions = [
              Map<String, dynamic>.from(q['sentenceQuestions'] as Map)
            ];
            print(
                '[AssessmentRepository] Processed single sentenceQuestion map for pre-assessment question $questionId');
          }
        }

        List<AssessmentOption> options = [];
        if (q['options'] != null && q['options'] is List) {
          final optionsList = q['options'] as List;
          for (int optIndex = 0; optIndex < optionsList.length; optIndex++) {
            final opt = optionsList[optIndex];
            options.add(AssessmentOption(
              optionId: opt['optionId'] ?? (optIndex + 1).toString(),
              optionText: opt['optionText'] ?? '',
              isCorrect: opt['isCorrect'] ?? false,
            ));
          }
          print(
              '[AssessmentRepository] Processed ${options.length} options for pre-assessment question $questionId');
        }

        questions.add(Question(
          questionId: questionId,
          questionNumber: i + 1,
          questionTypeId: questionType,
          questionText: questionText,
          displayedText: questionValue,
          hasImage: questionImage != null,
          imageUrl: questionImage,
          options: options,
          passages: passages,
          sentenceQuestions: sentenceQuestions,
        ));
      }
    }

    return Assessment(
      assessmentId: doc['assessmentId'] ?? doc['_id'].toString(),
      title: doc['title'] ?? 'Panimulang Pagtatasa sa Pagbasa',
      description: doc['description'] ?? 'Initial reading assessment',
      totalQuestions: questions.length,
      continueButtonText: doc['continueButtonText'] ?? 'MAG PATULOY',
      language: doc['language'] ?? 'FL',
      type: 'pre_assessment',
      status: doc['status'] ?? 'active',
      questions: questions,
    );
  }

  /// Convert main_assessment document to Assessment model
  Assessment _convertMainAssessmentToModel(Map<String, dynamic> doc) {
    List<Question> questions = [];

    print(
        '[AssessmentRepository] Converting main assessment document to model');
    print('[AssessmentRepository] Document ID: ${doc['_id']}');
    print('[AssessmentRepository] Reading Level: ${doc['readingLevel']}');

    if (doc['questions'] != null && doc['questions'] is List) {
      final questionsList = doc['questions'] as List;
      print(
          '[AssessmentRepository] Processing ${questionsList.length} questions');

      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];

        final questionId = q['questionId'] ?? 'main_q_${i + 1}';
        final questionType = q['questionType'] ?? 'unknown';
        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? '';
        final questionImage = q['questionImage'];

        // Improved passages parsing with detailed logging
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null) {
          print(
              '[AssessmentRepository] Question $questionId has passages data: ${q['passages'].runtimeType}');

          if (q['passages'] is List) {
            passages = [];
            for (final passage in q['passages']) {
              if (passage is Map) {
                final passageMap = Map<String, dynamic>.from(passage);
                passages.add(passageMap);
                print(
                    '[AssessmentRepository] Added passage with length: ${passageMap['pageText']?.toString().length ?? 0}');
              }
            }
            print(
                '[AssessmentRepository] Processed ${passages.length} passages for question $questionId');
          } else if (q['passages'] is Map) {
            // Handle case where passages is a single map instead of a list
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
            print(
                '[AssessmentRepository] Processed single passage map for question $questionId');
          }
        }

        // Improved sentence questions parsing with detailed logging
        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null) {
          print(
              '[AssessmentRepository] Question $questionId has sentenceQuestions data: ${q['sentenceQuestions'].runtimeType}');

          if (q['sentenceQuestions'] is List) {
            sentenceQuestions = [];
            for (final sq in q['sentenceQuestions']) {
              if (sq is Map) {
                final sqMap = Map<String, dynamic>.from(sq);
                sentenceQuestions.add(sqMap);
                print(
                    '[AssessmentRepository] Added sentenceQuestion: ${sqMap['questionText'] ?? 'No question text'}');
                print(
                    '[AssessmentRepository] Question has correctAnswer: ${sqMap['correctAnswer'] != null}');
                print(
                    '[AssessmentRepository] Question has incorrectAnswer: ${sqMap['incorrectAnswer'] != null}');
              }
            }
            print(
                '[AssessmentRepository] Processed ${sentenceQuestions.length} sentenceQuestions for question $questionId');
          } else if (q['sentenceQuestions'] is Map) {
            // Handle case where sentenceQuestions is a single map instead of a list
            sentenceQuestions = [
              Map<String, dynamic>.from(q['sentenceQuestions'] as Map)
            ];
            print(
                '[AssessmentRepository] Processed single sentenceQuestion map for question $questionId');
          }
        }

        // Parse options
        List<AssessmentOption> options = [];
        if (q['choiceOptions'] != null && q['choiceOptions'] is List) {
          final choiceOptions = q['choiceOptions'] as List;
          for (int optIndex = 0; optIndex < choiceOptions.length; optIndex++) {
            final choice = choiceOptions[optIndex];
            options.add(AssessmentOption(
              optionId: choice['optionId'] ?? (optIndex + 1).toString(),
              optionText: choice['optionText'] ?? '',
              isCorrect: choice['isCorrect'] ?? false,
              explanation: choice['description'],
            ));
          }
          print(
              '[AssessmentRepository] Processed ${options.length} options for question $questionId');
        } else {
          print(
              '[AssessmentRepository] No choiceOptions found for question $questionId');
        }

        // Create reading comprehension options if needed
        if (options.isEmpty &&
            sentenceQuestions != null &&
            sentenceQuestions.isNotEmpty) {
          final sq = sentenceQuestions.first;
          if (sq['correctAnswer'] != null && sq['incorrectAnswer'] != null) {
            options = [
              AssessmentOption(
                optionId: '1',
                optionText: sq['correctAnswer'],
                isCorrect: true,
              ),
              AssessmentOption(
                optionId: '2',
                optionText: sq['incorrectAnswer'],
                isCorrect: false,
              ),
            ];
            print(
                '[AssessmentRepository] Created options from sentenceQuestion for question $questionId');
          }
        }

        questions.add(Question(
          questionId: questionId,
          questionNumber: i + 1,
          questionTypeId: _mapQuestionTypeToId(questionType),
          questionText: questionText,
          displayedText: questionValue,
          hasImage: questionImage != null,
          imageUrl: questionImage,
          options: options,
          questionType: questionType,
          order: q['order'] ?? i + 1,
          passages: passages,
          sentenceQuestions: sentenceQuestions,
        ));
      }
    }

    return Assessment(
      assessmentId: doc['_id'].toString(),
      title: 'Assessment: ${doc['category'] ?? 'Unknown Category'}',
      description:
          'Assessment for ${doc['readingLevel'] ?? 'Unknown Level'} reading level',
      totalQuestions: questions.length,
      continueButtonText: 'MAG PATULOY',
      language: 'FL',
      type: 'main_assessment',
      status: doc['isActive'] == true ? 'active' : 'inactive',
      questions: questions,
      categoryCounts: {doc['category'] ?? 'unknown': questions.length},
      readingLevel: doc['readingLevel'],
      category: doc['category'],
    );
  }

  /// Map question types from main_assessment to standard IDs
  String _mapQuestionTypeToId(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'patinig':
        return 'phonological_awareness';
      case 'katinig':
        return 'phonological_awareness';
      case 'malapantig':
        return 'word_recognition';
      case 'word':
        return 'word_recognition';
      case 'sentence':
        return 'reading_comprehension';
      default:
        return 'alphabet_knowledge';
    }
  }

  /// Save user responses following the guide's mobile responsibility
  Future<bool> saveUserResponses({
    required dynamic assessmentId,
    required String userId,
    required Map<String, String> answers,
    required int score,
    required String readingLevel,
    double? readingPercentage,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print(
          '[AssessmentRepository] Saving user responses to student_responses collection');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, saving locally');
        return await _dbService.saveAssessmentResultsLocally(
          userId: userId,
          assessmentId: assessmentId,
          score: score,
          readingLevel: readingLevel,
        );
      }

      // Get/create the category_results document
      String categoryResultId = '';

      // Get existing category_results or create new
      final existingResults =
          await _dbService.getCategoryResultsForStudent(userId);
      if (existingResults != null) {
        categoryResultId = existingResults['_id'].toString();
        print(
            '[AssessmentRepository] Using existing category_results: $categoryResultId');
      } else {
        // For new assessment, first get available categories
        final availableCategories =
            await _dbService.getAvailableCategoriesForLevel(readingLevel);
        if (availableCategories.isEmpty) {
          print(
              '[AssessmentRepository] No categories available for reading level: $readingLevel');
          return false;
        }

        // Create new category_results document
        categoryResultId = await _dbService.createCategoryResults(
          studentId: userId,
          readingLevel: readingLevel,
          availableCategories: availableCategories,
        );

        if (categoryResultId.isEmpty) {
          print('[AssessmentRepository] Failed to create category_results');
          return false;
        }

        print(
            '[AssessmentRepository] Created new category_results: $categoryResultId');
      }

      // Save individual responses to student_responses collection (mobile responsibility)
      int questionOrder = 1;

      for (final entry in answers.entries) {
        final questionId = entry.key;
        final selectedOption = entry.value;

        // Determine if answer is correct (simplified - in real app this would be more robust)
        final isCorrect =
            _isAnswerCorrect(questionId, selectedOption, additionalData);

        // Create student response record
        await _dbService.saveStudentResponse({
          'studentId': int.tryParse(userId) ??
              userId, // Use int if possible, string otherwise
          'categoryResultId': categoryResultId,
          'categoryId': assessmentId,
          'questionOrder': questionOrder,
          'category': _getCategoryFromQuestionId(questionId),
          'sentenceQuestionIndex': questionOrder,
          'selectedOption': selectedOption,
          'isCorrect': isCorrect,
          'responseTime': 0, // Could track this if needed
          'answeredAt': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        questionOrder++;
      }

      print(
          '[AssessmentRepository] Successfully saved ${answers.length} student responses');

      // Update user reading level if needed
      if (additionalData != null && additionalData['isPreAssessment'] == true) {
        await updateUserReadingLevel(
          userId: userId,
          readingLevel: readingLevel,
          readingPercentage: readingPercentage,
          preAssessmentCompleted: true,
        );
      }

      return true;
    } catch (e) {
      print('[AssessmentRepository] Error saving user responses: $e');
      return false;
    }
  }

  /// Update user reading level following the guide's structure
  Future<bool> updateUserReadingLevel({
    required String userId,
    required String readingLevel,
    double? readingPercentage,
    bool preAssessmentCompleted = true,
  }) async {
    try {
      print('[AssessmentRepository] Updating user profile for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, saving locally');
        return await _dbService.saveUserDataLocally(
          idNumber: userId,
          readingLevel: readingLevel,
          preAssessmentCompleted: preAssessmentCompleted,
        );
      }

      // Update users collection following the guide's structure
      final usersCollection = _dbService.getCollection(_collUsers);

      // Convert userId to appropriate type
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }

      // Update user document with new reading level
      final result = await usersCollection.updateOne(
          where.eq('idNumber', userIdValue),
          modify
              .set('readingLevel', readingLevel)
              .set('readingPercentage', readingPercentage?.toDouble() ?? 0.0)
              .set('preAssessmentCompleted', preAssessmentCompleted)
              .set('lastAssessmentDate', DateTime.now().toIso8601String())
              .set('updatedAt', DateTime.now().toIso8601String()));

      print('[AssessmentRepository] User update result: ${result.isSuccess}');

      // Also save locally for offline access
      await _dbService.saveUserDataLocally(
        idNumber: userId,
        readingLevel: readingLevel,
        preAssessmentCompleted: preAssessmentCompleted,
      );

      return result.isSuccess;
    } catch (e) {
      print('[AssessmentRepository] Error updating user reading level: $e');
      return false;
    }
  }

  /// Helper method to determine if an answer is correct
  bool _isAnswerCorrect(String questionId, String selectedOption,
      Map<String, dynamic>? additionalData) {
    // This is a simplified version - in reality, you'd need to check against the actual question data
    if (additionalData != null && additionalData['correctAnswers'] != null) {
      final correctAnswers =
          additionalData['correctAnswers'] as Map<String, dynamic>;
      return correctAnswers[questionId] == selectedOption;
    }
    return false; // Default to false if we can't determine
  }

  /// Helper method to get category from question ID
  String _getCategoryFromQuestionId(String questionId) {
    if (questionId.startsWith('PRE_')) {
      // Pre-assessment questions have category in their ID
      final parts = questionId.split('_');
      if (parts.length > 1) {
        switch (parts[1]) {
          case 'AK':
            return 'alphabet_knowledge';
          case 'PA':
            return 'phonological_awareness';
          case 'WR':
            return 'word_recognition';
          case 'DC':
            return 'decoding';
          case 'RC':
            return 'reading_comprehension';
          default:
            return 'unknown';
        }
      }
    } else if (questionId.startsWith('AK_')) {
      return 'Alphabet Knowledge';
    } else if (questionId.startsWith('PA_')) {
      return 'Phonological Awareness';
    } else if (questionId.startsWith('DC_')) {
      return 'Decoding';
    } else if (questionId.startsWith('WR_')) {
      return 'Word Recognition';
    } else if (questionId.startsWith('RC_')) {
      return 'Reading Comprehension';
    }
    return 'unknown';
  }

  /// Get lessons for a reading level, following the guide's structure
  Future<List<Map<String, dynamic>>> getLessonsForReadingLevel(
    String readingLevel, {
    String? userId,
  }) async {
    try {
      print(
          '[AssessmentRepository] Getting lessons for reading level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }

      // Normalize the reading level
      final normalizedLevel = _normalizeReadingLevel(readingLevel);

      // Query main_assessment collection for the EXACT reading level
      final assessmentCollection =
          _dbService.getCollection(_collMainAssessment);

      // STRICT query - only get assessments that exactly match the reading level
      final query = where
          .eq('readingLevel', normalizedLevel)
          .and(where.eq('isActive', true))
          .and(where.eq('status', 'active'));

      final assessments = await assessmentCollection.find(query).toList();

      print(
          '[AssessmentRepository] Found ${assessments.length} assessments for exact level: $normalizedLevel');

      // Do NOT fallback to other reading levels if none found
      if (assessments.isEmpty) {
        print(
            '[AssessmentRepository] No assessments available for reading level: $normalizedLevel');
        return [];
      }

      // Convert to lessons
      final List<Map<String, dynamic>> lessons = [];

      for (int i = 0; i < assessments.length; i++) {
        final assessment = assessments[i];

        // Verify the assessment is for the correct reading level
        final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
        if (_normalizeReadingLevel(assessmentLevel) != normalizedLevel) {
          print(
              '[AssessmentRepository] Skipping assessment with incorrect reading level: $assessmentLevel');
          continue;
        }

        final questionCount = assessment['questions'] is List
            ? (assessment['questions'] as List).length
            : 5;

        final category = assessment['category'] ?? 'Filipino Lesson';
        final assessmentId = assessment['_id'].toString();

        // Check completion status if userId provided
        bool isCompleted = false;
        if (userId != null) {
          isCompleted =
              await _dbService.hasStudentCompletedCategory(userId, category);
        }

        // Determine availability - first lesson is always available
        bool isAvailable = i == 0;

        // Other lessons are available if previous lesson is completed
        if (i > 0 && userId != null) {
          final prevCategory = assessments[i - 1]['category'];
          isAvailable = await _dbService.hasStudentCompletedCategory(
              userId, prevCategory);
        }

        lessons.add({
          'index': i + 1,
          'title': 'ARALIN ${i + 1}: $category',
          'description': _getDescriptionForLevel(normalizedLevel, category),
          'questionCount': questionCount,
          'isAvailable': isAvailable,
          'isCompleted': isCompleted,
          'assessmentId': assessmentId,
          'readingLevel': normalizedLevel,
          'category': category,
        });
      }

      print(
          '[AssessmentRepository] Converted ${lessons.length} assessments to lessons for level: $normalizedLevel');
      return lessons;
    } catch (e) {
      print('[AssessmentRepository] Error getting lessons: $e');
      return [];
    }
  }

  /// Helper method to generate appropriate descriptions based on reading level
  String _getDescriptionForLevel(String readingLevel, String category) {
    switch (readingLevel) {
      case 'Low Emerging':
        return 'Basic $category activities for beginning readers';
      case 'High Emerging':
        return 'Foundational $category skills for developing readers';
      case 'Developing':
        return 'Progressive $category exercises for growing readers';
      case 'Transitioning':
        return 'Advanced $category practice for maturing readers';
      case 'At Grade Level':
        return 'Grade-appropriate $category mastery activities';
      default:
        return 'Assessment for ${readingLevel.toLowerCase()} reading level';
    }
  }

  /// Helper method to normalize reading level for consistent matching
  String _normalizeReadingLevel(String readingLevel) {
    // Ensure consistent capitalization and formatting
    switch (readingLevel.toLowerCase().trim()) {
      case 'low emerging':
      case 'lowEmerging':
      case 'low_emerging':
        return 'Low Emerging';
      case 'high emerging':
      case 'highEmerging':
      case 'high_emerging':
        return 'High Emerging';
      case 'developing':
        return 'Developing';
      case 'transitioning':
        return 'Transitioning';
      case 'at grade level':
      case 'atGradeLevel':
      case 'at_grade_level':
        return 'At Grade Level';
      case 'emergent':
        return 'Low Emerging'; // Map old format to new
      case 'early':
        return 'High Emerging'; // Map old format to new
      case 'fluent':
        return 'At Grade Level'; // Map old format to new
      default:
        return readingLevel; // Return as-is if not recognized
    }
  }

  /// Fetch the latest pre-assessment result for a user from Pre_Assessment.user_responses
  Future<Map<String, dynamic>?> fetchLatestPreAssessmentResult(
      String userId) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }
      final preAssessmentDb = await dbService.getPreAssessmentDatabase();
      final userResponsesCollection =
          preAssessmentDb.collection('user_responses');
      // Find the latest by completedAt (descending)
      final result = await userResponsesCollection
          .find(where
              .eq('userId', userId)
              .sortBy('completedAt', descending: true))
          .toList();
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('[AssessmentRepository] Error fetching pre-assessment result: $e');
      return null;
    }
  }

  /// Initialize a new main assessment following the guide's flow
  Future<Map<String, dynamic>> initializeMainAssessment(
      String userId, String readingLevel) async {
    try {
      print(
          '[AssessmentRepository] Initializing main assessment for user $userId at level $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      // Phase 1: Available Categories Query
      final availableCategories =
          await _dbService.getAvailableCategoriesForLevel(readingLevel);

      if (availableCategories.isEmpty) {
        throw Exception(
            'No categories available for reading level: $readingLevel');
      }

      // Check if there's an existing incomplete assessment
      final existingResults =
          await _dbService.getCategoryResultsForStudent(userId);
      String categoryResultsId;
      String currentCategory;
      bool isResumingAssessment = false;

      if (existingResults != null &&
          existingResults['allCategoriesCompleted'] != true) {
        // Resume existing assessment
        categoryResultsId = existingResults['_id'].toString();
        isResumingAssessment = true;

        // Find first incomplete category
        final categories = existingResults['categories'] as List;
        final incompleteCategory = categories.firstWhere(
          (category) => category['isCompleted'] != true,
          orElse: () => categories[0],
        );
        currentCategory = incompleteCategory['categoryName'];

        print(
            '[AssessmentRepository] Resuming assessment: $categoryResultsId, category: $currentCategory');
      } else {
        // Create new category_results document
        categoryResultsId = await _dbService.createCategoryResults(
          studentId: userId,
          readingLevel: readingLevel,
          availableCategories: availableCategories,
        );

        // Start with first category
        currentCategory = availableCategories[0];
        isResumingAssessment = false;

        print(
            '[AssessmentRepository] Created new assessment: $categoryResultsId, starting with category: $currentCategory');
      }

      return {
        'categoryResultsId': categoryResultsId,
        'currentCategory': currentCategory,
        'availableCategories': availableCategories,
        'isResumingAssessment': isResumingAssessment,
        'readingLevel': readingLevel,
      };
    } catch (e) {
      print('[AssessmentRepository] Error initializing main assessment: $e');
      rethrow;
    }
  }

  Future<List<Question>> getQuestionsForCurrentCategory({
    required String readingLevel,
    required String category,
  }) async {
    try {
      print(
          '[AssessmentRepository] Getting questions: Level="$readingLevel", Category="$category"');

      // IMPORTANT: Check if database is initialized and connected
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
        print('[AssessmentRepository] Database initialized');
      }

      if (!_dbService.isConnected) {
        print(
            '[AssessmentRepository] Database not connected! Cannot fetch questions');
        return [];
      }

      // Get the collection
      final collection = _dbService.getCollection('main_assessment');
      print('[AssessmentRepository] Got main_assessment collection');

      // Construct the query with exact matching
      final query = where
          .eq('readingLevel', readingLevel)
          .and(where.eq('category', category))
          .and(where.eq('isActive', true));

      print(
          '[AssessmentRepository] Executing query: readingLevel="$readingLevel", category="$category"');

      // Find the document
      final doc = await collection.findOne(query);

      if (doc == null) {
        print('[AssessmentRepository] No matching document found!');

        // Get all documents to debug what's available
        final allDocs = await collection.find({}).toList();
        print('[AssessmentRepository] Available documents in main_assessment:');
        for (final d in allDocs) {
          print(
              '  - Level: "${d['readingLevel']}", Category: "${d['category']}"');
        }

        return [];
      }

      print('[AssessmentRepository] Found document with ID: ${doc['_id']}');

      // Extract questions
      if (doc['questions'] == null || doc['questions'] is! List) {
        print(
            '[AssessmentRepository] Document has no questions array or invalid format');
        print(
            '[AssessmentRepository] Document structure: ${doc.keys.toList()}');
        return [];
      }

      final questionsList = doc['questions'] as List;
      print(
          '[AssessmentRepository] Document contains ${questionsList.length} questions');

      // Map to Question models
      final questions = <Question>[];

      for (final q in questionsList) {
        try {
          if (q is! Map) {
            print('[AssessmentRepository] Invalid question format: $q');
            continue;
          }

          final questionMap = Map<String, dynamic>.from(q);

          // Extract options
          List<AssessmentOption> options = [];
          if (questionMap['choiceOptions'] != null &&
              questionMap['choiceOptions'] is List) {
            final optionsList = questionMap['choiceOptions'] as List;

            for (int i = 0; i < optionsList.length; i++) {
              if (optionsList[i] is Map) {
                final opt = Map<String, dynamic>.from(optionsList[i]);

                options.add(AssessmentOption(
                  optionId: opt['optionId']?.toString() ?? (i + 1).toString(),
                  optionText:
                      opt['optionText']?.toString() ?? 'Option ${i + 1}',
                  isCorrect: opt['isCorrect'] == true,
                  explanation: opt['description']?.toString(),
                ));
              }
            }
          }

          // Create Question object
          final question = Question(
            questionId: questionMap['questionId']?.toString() ??
                'q_${questions.length}',
            questionNumber: questions.length + 1,
            questionTypeId: _mapQuestionTypeToId(
                questionMap['questionType']?.toString() ?? ''),
            questionText:
                questionMap['questionText']?.toString() ?? 'No question text',
            displayedText: questionMap['questionValue']?.toString(),
            hasImage: questionMap['questionImage'] != null,
            imageUrl: questionMap['questionImage']?.toString(),
            options: options,
            questionType: questionMap['questionType']?.toString(),
            order: questionMap['order'] is int
                ? questionMap['order']
                : questions.length,
            category: category,
          );

          // Save raw data for future reference
          _rawQuestionData[question.questionId] = questionMap;

          questions.add(question);
        } catch (e) {
          print('[AssessmentRepository] Error processing question: $e');
        }
      }

      print(
          '[AssessmentRepository] Processed ${questions.length} questions successfully');
      return questions;
    } catch (e) {
      print(
          '[AssessmentRepository] Exception in getQuestionsForCurrentCategory: $e');
      return [];
    }
  }

  /// Get assessment results following the guide's structure
  Future<Map<String, dynamic>> getAssessmentResults(String userId) async {
    try {
      print(
          '[AssessmentRepository] Getting assessment results for user $userId');

      final categoryResults =
          await _dbService.getCategoryResultsForStudent(userId);

      if (categoryResults == null) {
        throw Exception('No assessment results found for user $userId');
      }

      return {
        'overallScore': categoryResults['overallScore'] ?? 0,
        'completedCategories': categoryResults['completedCategories'] ?? 0,
        'totalCategories': categoryResults['totalCategories'] ?? 0,
        'allCategoriesPassed': categoryResults['allCategoriesPassed'] ?? false,
        'allCategoriesCompleted':
            categoryResults['allCategoriesCompleted'] ?? false,
        'readingLevel': categoryResults['readingLevel'] ?? 'Unknown',
        'readingLevelUpdated': categoryResults['readingLevelUpdated'] ?? false,
        'categories': categoryResults['categories'] ?? [],
      };
    } catch (e) {
      print('[AssessmentRepository] Error getting assessment results: $e');
      rethrow;
    }
  }
}
