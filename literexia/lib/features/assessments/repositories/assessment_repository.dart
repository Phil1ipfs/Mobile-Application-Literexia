// lib/features/assessments/repositories/assessment_repository.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';
import '../../../services/database_service.dart';
import '../../../utils/reading_level_utils.dart';

class AssessmentRepository {
  /// Collection names - distinguish between pre-assessment, main assessment, and intervention assessment
  static const String _collMainAssessment =
      'main_assessment'; // For lessons AFTER pre-assessment
  static const String _collPreAssessment =
      'pre-assessment'; // For initial assessment
  static const String _collInterventionAssessment =
      'intervention_assessment'; // For intervention assessments
  static const String _collUsers = 'users';
  static const String _collStudentResponses = 'student_responses';
  static const String _collCategoryResults = 'category_results';
  static const String _collFailedCategoryResult = 'failed_category_result';

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
        // Enforce real data source only
        throw Exception('Database not connected for pre-assessment');
      }

      // Try to get from Pre_Assessment database first
      try {
        final preAssessmentDb = await _dbService.getPreAssessmentDatabase();
        final preAssessmentCollection =
            preAssessmentDb.collection(_collPreAssessment);

        print(
            '[AssessmentRepository] Searching for pre-assessment document in collection: $_collPreAssessment');

        // Look for pre-assessment document - try multiple query approaches
        var doc = await preAssessmentCollection
            .findOne(where.eq('type', 'pre_assessment'));
        print(
            '[AssessmentRepository] Query 1 (type=pre_assessment): ${doc != null ? 'FOUND' : 'NOT FOUND'}');

        // If not found by type, try by assessmentId
        if (doc == null) {
          doc = await preAssessmentCollection
              .findOne(where.eq('assessmentId', '1'));
          print(
              '[AssessmentRepository] Query 2 (assessmentId=1): ${doc != null ? 'FOUND' : 'NOT FOUND'}');
        }

        // If still not found, try getting any document
        if (doc == null) {
          doc = await preAssessmentCollection.findOne();
          print(
              '[AssessmentRepository] Query 3 (any document): ${doc != null ? 'FOUND' : 'NOT FOUND'}');
        }

        // Let's also try to count all documents in the collection
        final count = await preAssessmentCollection.count();
        print('[AssessmentRepository] Total documents in collection: $count');

        if (doc != null) {
          print(
              '[AssessmentRepository] SUCCESS: Found pre-assessment in Pre_Assessment database');
          print('[AssessmentRepository] Document ID: ${doc['_id']}');
          print('[AssessmentRepository] Assessment ID: ${doc['assessmentId']}');
          print('[AssessmentRepository] Type: ${doc['type']}');
          print(
              '[AssessmentRepository] Questions count: ${doc['questions']?.length ?? 0}');

          // Debug the questions structure for pre-assessment
          if (doc['questions'] != null) {
            final questions = doc['questions'] as List;
            print(
                '[AssessmentRepository] Pre-assessment questions type: ${questions.runtimeType}');
            print(
                '[AssessmentRepository] Pre-assessment questions length: ${questions.length}');
            if (questions.isNotEmpty) {
              print(
                  '[AssessmentRepository] Pre-assessment first question type: ${questions.first.runtimeType}');
              print(
                  '[AssessmentRepository] Pre-assessment first question content: ${questions.first}');
              if (questions.first is Map) {
                print(
                    '[AssessmentRepository] Pre-assessment first question keys: ${(questions.first as Map).keys.toList()}');
              } else {
                print(
                    '[AssessmentRepository] Pre-assessment first question is not a Map!');
              }
            }
          }

          return _convertPreAssessmentToModel(doc);
        } else {
          print(
              '[AssessmentRepository] ERROR: No pre-assessment document found in any query');
        }
      } catch (e) {
        print('[AssessmentRepository] Pre_Assessment database error: $e');
      }

      // No fallback: require real Mongo data
      throw Exception('Pre-assessment document not found');
    } catch (e) {
      print('[AssessmentRepository] Error loading pre-assessment: $e');
      return null;
    }
  }

  /// Get scoring rules from pre_assessment table
  Future<Map<String, dynamic>?> getScoringRulesFromPreAssessment() async {
    try {
      print(
          '[AssessmentRepository] Fetching scoring rules from pre_assessment table');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[AssessmentRepository] Database not connected, cannot fetch scoring rules');
        return null;
      }

      // Try to get from Pre_Assessment database
      try {
        final preAssessmentDb = await _dbService.getPreAssessmentDatabase();
        final preAssessmentCollection =
            preAssessmentDb.collection(_collPreAssessment);

        print(
            '[AssessmentRepository] Searching for scoring rules in pre-assessment document');

        // Look for pre-assessment document with scoring rules
        var doc = await preAssessmentCollection
            .findOne(where.eq('assessmentId', '1'));

        if (doc == null) {
          // Try by type
          doc = await preAssessmentCollection
              .findOne(where.eq('type', 'pre_assessment'));
        }

        if (doc == null) {
          // Try getting any document
          doc = await preAssessmentCollection.findOne();
        }

        if (doc != null && doc['scoringRules'] != null) {
          final scoringRules = Map<String, dynamic>.from(doc['scoringRules']);
          print(
              '[AssessmentRepository] Successfully fetched scoring rules from database');
          print('[AssessmentRepository] Scoring rules: $scoringRules');
          return scoringRules;
        } else {
          print(
              '[AssessmentRepository] No scoring rules found in pre_assessment document');
          return null;
        }
      } catch (e) {
        print(
            '[AssessmentRepository] Error accessing pre_assessment database: $e');
        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] Error fetching scoring rules: $e');
      return null;
    }
  }

  /// Get INTERVENTION ASSESSMENT for users who failed specific categories
  Future<Assessment?> getInterventionAssessment(String categoryName,
      {String? readingLevel, String? userId}) async {
    try {
      print(
          '[AssessmentRepository] Loading INTERVENTION ASSESSMENT for category: $categoryName');
      print('[AssessmentRepository] Required reading level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        throw Exception('Database not connected for intervention assessment');
      }

      // Use main database connection for intervention assessments
      final interventionCollection =
          _dbService.getCollection(_collInterventionAssessment);
      Map<String, dynamic>? doc;

      // Strategy 1: Search by category name, reading level, and student ID
      if (readingLevel != null && categoryName.isNotEmpty && userId != null) {
        final normalizedLevel =
            ReadingLevelUtils.normalizeReadingLevel(readingLevel);

        // Convert userId to int since database stores studentId as number
        dynamic studentIdValue;
        try {
          studentIdValue = int.parse(userId);
        } catch (e) {
          studentIdValue = userId; // fallback to string if parsing fails
        }

        print(
            '[AssessmentRepository] Searching for Intervention: StudentId=$studentIdValue, Level=$normalizedLevel, Category=$categoryName');

        final query = where
            .eq('studentId', studentIdValue)
            .and(where.eq('readingLevel', normalizedLevel))
            .and(where.eq('category', categoryName))
            .and(where.eq('status', 'active'));

        final assessments =
            await interventionCollection.find(query).take(1).toList();

        if (assessments.isNotEmpty) {
          doc = assessments.first;
          print(
              '[AssessmentRepository] Found intervention assessment by level and category: ${doc['_id']}');
        }
      }

      // Strategy 2: Search by category name and student ID (any reading level)
      if (doc == null && categoryName.isNotEmpty && userId != null) {
        // Convert userId to int since database stores studentId as number
        dynamic studentIdValue;
        try {
          studentIdValue = int.parse(userId);
        } catch (e) {
          studentIdValue = userId; // fallback to string if parsing fails
        }

        print(
            '[AssessmentRepository] Fallback: Searching by StudentId=$studentIdValue and Category=$categoryName');

        final query = where
            .eq('studentId', studentIdValue)
            .and(where.eq('category', categoryName))
            .and(where.eq('status', 'active'));

        final assessments =
            await interventionCollection.find(query).take(1).toList();

        if (assessments.isNotEmpty) {
          doc = assessments.first;
          print(
              '[AssessmentRepository] Found intervention assessment by category only: ${doc['_id']}');
        }
      }

      // Strategy 3: Try to find any active intervention assessment as last resort
      if (doc == null) {
        print(
            '[AssessmentRepository] Last resort: Searching for any active intervention assessment');

        final query = where.eq('isActive', true);
        final assessments =
            await interventionCollection.find(query).take(1).toList();

        if (assessments.isNotEmpty) {
          doc = assessments.first;
          print(
              '[AssessmentRepository] Found any active intervention assessment: ${doc['_id']}');
        }
      }

      if (doc != null) {
        final assessment = _convertInterventionAssessmentToModel(doc);
        _assessment = assessment;

        print('[AssessmentRepository] LOADED INTERVENTION ASSESSMENT:');
        print('[AssessmentRepository]   - Category: ${doc['category']}');
        print(
            '[AssessmentRepository]   - Reading Level: ${doc['readingLevel']}');
        print(
            '[AssessmentRepository]   - Questions: ${assessment.questions.length}');

        return assessment;
      } else {
        print(
            '[AssessmentRepository] ERROR: No intervention assessment found for category: $categoryName');
        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] Error loading intervention assessment: $e');
      return null;
    }
  }

  /// NEW: Enhanced intervention assessment loader with comprehensive fallback strategies
  Future<Assessment?> loadInterventionAssessmentDirect(String categoryName,
      {String? readingLevel, String? userId}) async {
    try {
      print(
          '[AssessmentRepository] DIRECT INTERVENTION LOADER for category: $categoryName');
      print('[AssessmentRepository] Student ID: $userId');
      print('[AssessmentRepository] Reading Level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      // Ensure database connection is active before proceeding
      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, attempting to reconnect...');
        final reconnected = await _dbService.ensureConnection();
        if (!reconnected) {
          throw Exception('Database not connected for intervention assessment');
        }
      }

      // Add additional connection validation before accessing collection
      print('[AssessmentRepository] DIRECT: Validating database connection...');
      print('[AssessmentRepository] DIRECT: Database initialized: ${_dbService.isInitialized}');
      print('[AssessmentRepository] DIRECT: Database connected: ${_dbService.isConnected}');
      
      if (!_dbService.isConnected) {
        print('[AssessmentRepository] DIRECT: Connection lost, attempting to reconnect...');
        final reconnected = await _dbService.ensureConnection();
        if (!reconnected) {
          throw Exception('Failed to establish database connection for intervention assessment');
        }
      }
      
      final interventionCollection =
          _dbService.getCollection(_collInterventionAssessment);

      // CRITICAL: Verify we're accessing the correct collection
      print(
          '[AssessmentRepository] Accessing collection: $_collInterventionAssessment');
      print(
          '[AssessmentRepository] Expected collection name: intervention_assessment');

      if (_collInterventionAssessment != 'intervention_assessment') {
        print(
            '[AssessmentRepository] ERROR: Wrong collection name! Expected: intervention_assessment, Got: $_collInterventionAssessment');
      }

      // Enhanced strategy: Search with multiple approaches
      Map<String, dynamic>? doc;

      // Convert userId to int for database query
      dynamic studentIdValue;
      if (userId != null) {
        try {
          studentIdValue = int.parse(userId);
        } catch (e) {
          studentIdValue = userId;
        }
      }

      // Strategy 1: Exact match with all parameters
      if (userId != null && readingLevel != null && categoryName.isNotEmpty) {
        final normalizedLevel =
            ReadingLevelUtils.normalizeReadingLevel(readingLevel);

        print('[AssessmentRepository] Strategy 1: Exact match search');
        print('[AssessmentRepository] - StudentId: $studentIdValue');
        print('[AssessmentRepository] - Category: $categoryName');
        print('[AssessmentRepository] - Reading Level: $normalizedLevel');

        final exactQuery = where
            .eq('studentId', studentIdValue)
            .and(where.eq('category', categoryName))
            .and(where.eq('readingLevel', normalizedLevel))
            .and(where.eq('status', 'active'));

        final exactResults =
            await interventionCollection.find(exactQuery).toList();

        if (exactResults.isNotEmpty) {
          doc = exactResults.first;
          print(
              '[AssessmentRepository] SUCCESS: Found exact match intervention assessment');
        }
      }

      // Strategy 2: Student and category match (any reading level)
      if (doc == null && userId != null && categoryName.isNotEmpty) {
        print('[AssessmentRepository] Strategy 2: Student + category match');

        final studentCategoryQuery = where
            .eq('studentId', studentIdValue)
            .and(where.eq('category', categoryName))
            .and(where.eq('status', 'active'));

        final studentCategoryResults =
            await interventionCollection.find(studentCategoryQuery).toList();

        if (studentCategoryResults.isNotEmpty) {
          doc = studentCategoryResults.first;
          print(
              '[AssessmentRepository] SUCCESS: Found student + category match');
        }
      }

      // No fallback strategies - only return intervention assessment if it belongs to the specific student
      if (doc == null) {
        print('[AssessmentRepository] No intervention assessment found for student $studentIdValue in category $categoryName');
        return null;
      }

      // Convert and return the intervention assessment
      if (doc != null) {
        print(
            '[AssessmentRepository] Converting intervention assessment document');
        print('[AssessmentRepository] Document ID: ${doc['_id']}');
        print('[AssessmentRepository] Category: ${doc['category']}');
        print('[AssessmentRepository] Reading Level: ${doc['readingLevel']}');
        print(
            '[AssessmentRepository] Total Questions: ${doc['totalQuestions']}');
        print('[AssessmentRepository] Status: ${doc['status']}');

        // CRITICAL: Verify this is actually intervention assessment data
        if (doc['questions'] != null && doc['questions'] is List) {
          final firstQuestion = (doc['questions'] as List).first;
          print(
              '[AssessmentRepository] VERIFICATION: First question structure:');
          print(
              '[AssessmentRepository] - Has choiceOptions: ${firstQuestion['choiceOptions'] != null}');
          print(
              '[AssessmentRepository] - Has sentenceQuestions: ${firstQuestion['sentenceQuestions'] != null}');
          print(
              '[AssessmentRepository] - Question type: ${firstQuestion['questionType']}');
          print(
              '[AssessmentRepository] - Has storyTitle: ${firstQuestion['storyTitle'] != null}');

          // Check if this looks like main assessment data (should NOT be present)
          if (firstQuestion['storyTitle'] != null ||
              (firstQuestion['sentenceQuestions'] != null &&
                  firstQuestion['choiceOptions'] == null)) {
            print(
                '[AssessmentRepository] ERROR: This appears to be MAIN ASSESSMENT data, not intervention data!');
            print(
                '[AssessmentRepository] Rejecting this document as it has main assessment structure');
            return null;
          }

          // Check if this looks like intervention assessment data (should be present)
          if (firstQuestion['choiceOptions'] != null ||
              firstQuestion['questionType'] == 'patinig' ||
              firstQuestion['questionType'] == 'katinig' ||
              firstQuestion['questionType'] == 'fill_blank' ||
              firstQuestion['displayWord'] != null ||
              firstQuestion['blankOptions'] != null) {
            print(
                '[AssessmentRepository] CONFIRMED: This is genuine INTERVENTION assessment data');
          } else {
            print(
                '[AssessmentRepository] WARNING: This may not be intervention assessment data');
          }
        }

        final assessment = _convertInterventionAssessmentToModel(doc);

        print(
            '[AssessmentRepository] SUCCESSFULLY LOADED INTERVENTION ASSESSMENT');
        print(
            '[AssessmentRepository] Questions loaded: ${assessment.questions.length}');

        return assessment;
      } else {
        print(
            '[AssessmentRepository] ERROR: No intervention assessment found with any strategy');

        // Debug: List all available intervention assessments
        final allDocs = await interventionCollection.find().toList();
        print(
            '[AssessmentRepository] Available intervention assessments in database:');
        for (final availableDoc in allDocs) {
          print('[AssessmentRepository] - ID: ${availableDoc['_id']}');
          print(
              '[AssessmentRepository] - StudentId: ${availableDoc['studentId']}');
          print(
              '[AssessmentRepository] - Category: ${availableDoc['category']}');
          print(
              '[AssessmentRepository] - Reading Level: ${availableDoc['readingLevel']}');
          print('[AssessmentRepository] - Status: ${availableDoc['status']}');
        }

        return null;
      }
    } catch (e) {
      print(
          '[AssessmentRepository] ERROR in loadInterventionAssessmentDirect: $e');
      return null;
    }
  }

  /// FORCE: Explicit intervention assessment loader that ensures correct collection and data structure
  Future<Assessment?> forceLoadInterventionAssessment(String categoryName,
      {String? readingLevel, String? userId}) async {
    try {
      print(
          '[AssessmentRepository] ===== FORCE LOADING INTERVENTION ASSESSMENT =====');
      print('[AssessmentRepository] Category: $categoryName');
      print('[AssessmentRepository] Student ID: $userId');
      print('[AssessmentRepository] Reading Level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      // Ensure database connection is active before proceeding
      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, attempting to reconnect...');
        final reconnected = await _dbService.ensureConnection();
        if (!reconnected) {
          throw Exception('Database not connected for intervention assessment');
        }
      }

      // FORCE: Explicitly use intervention_assessment collection
      // Add additional connection validation before accessing collection
      print('[AssessmentRepository] FORCE: Validating database connection...');
      print('[AssessmentRepository] FORCE: Database initialized: ${_dbService.isInitialized}');
      print('[AssessmentRepository] FORCE: Database connected: ${_dbService.isConnected}');
      
      if (!_dbService.isConnected) {
        print('[AssessmentRepository] FORCE: Connection lost, attempting to reconnect...');
        final reconnected = await _dbService.ensureConnection();
        if (!reconnected) {
          throw Exception('Failed to establish database connection for intervention assessment');
        }
      }
      
      final interventionCollection =
          _dbService.getCollection('intervention_assessment');

      print(
          '[AssessmentRepository] FORCE: Using collection intervention_assessment directly');

      // Convert userId to int for database query
      dynamic studentIdValue;
      if (userId != null) {
        try {
          studentIdValue = int.parse(userId);
        } catch (e) {
          studentIdValue = userId;
        }
      }

      // Strategy 1: Find by student, category, and reading level
      Map<String, dynamic>? doc;
      if (userId != null && readingLevel != null && categoryName.isNotEmpty) {
        final normalizedLevel =
            ReadingLevelUtils.normalizeReadingLevel(readingLevel);

        print('[AssessmentRepository] FORCE: Searching with exact parameters');
        print('[AssessmentRepository] - StudentId: $studentIdValue');
        print('[AssessmentRepository] - Category: $categoryName');
        print('[AssessmentRepository] - Reading Level: $normalizedLevel');

        final exactQuery = where
            .eq('studentId', studentIdValue)
            .and(where.eq('category', categoryName))
            .and(where.eq('readingLevel', normalizedLevel))
            .and(where.eq('status', 'active'));

        final exactResults =
            await interventionCollection.find(exactQuery).toList();

        if (exactResults.isNotEmpty) {
          doc = exactResults.first;
          print('[AssessmentRepository] FORCE: Found exact match');
        }
      }

      // Strategy 2: Find by student and category only
      if (doc == null && userId != null && categoryName.isNotEmpty) {
        print('[AssessmentRepository] FORCE: Searching by student + category');

        final studentCategoryQuery = where
            .eq('studentId', studentIdValue)
            .and(where.eq('category', categoryName))
            .and(where.eq('status', 'active'));

        final studentCategoryResults =
            await interventionCollection.find(studentCategoryQuery).toList();

        if (studentCategoryResults.isNotEmpty) {
          doc = studentCategoryResults.first;
          print('[AssessmentRepository] FORCE: Found student + category match');
        }
      }

      // Strategy 3: Find by category only
      if (doc == null && categoryName.isNotEmpty) {
        print('[AssessmentRepository] FORCE: Searching by category only');

        final categoryQuery = where
            .eq('category', categoryName)
            .and(where.eq('status', 'active'));

        final categoryResults =
            await interventionCollection.find(categoryQuery).toList();

        if (categoryResults.isNotEmpty) {
          doc = categoryResults.first;
          print('[AssessmentRepository] FORCE: Found category match');
        }
      }

      // Validate and return
      if (doc != null) {
        print('[AssessmentRepository] FORCE: Validating document structure');

        // Validate this is intervention assessment data
        if (doc['questions'] != null && doc['questions'] is List) {
          final questions = doc['questions'] as List;
          if (questions.isNotEmpty) {
            final firstQuestion = questions.first;

            // Check for intervention-specific structure
            final hasChoiceOptions = firstQuestion['choiceOptions'] != null;
            final hasInterventionTypes =
                firstQuestion['questionType'] == 'patinig' ||
                    firstQuestion['questionType'] == 'katinig' ||
                    firstQuestion['questionType'] == 'fill_blank' ||
                    firstQuestion['questionType'] == 'fill_missing_letter' ||
                    firstQuestion['questionType'] ==
                        'complete_word_identification' ||
                    firstQuestion['questionType'] == 'malapantig';
            final hasInterventionFields =
                firstQuestion['displayWord'] != null ||
                    firstQuestion['blankOptions'] != null ||
                    firstQuestion['questionSet'] != null;

            // Check for main assessment structure (should NOT be present)
            final hasMainAssessmentFields =
                firstQuestion['storyTitle'] != null ||
                    firstQuestion['acceptableAnswers'] != null;

            print('[AssessmentRepository] FORCE: Structure validation:');
            print(
                '[AssessmentRepository] - Has choiceOptions: $hasChoiceOptions');
            print(
                '[AssessmentRepository] - Has intervention types: $hasInterventionTypes');
            print(
                '[AssessmentRepository] - Has intervention fields: $hasInterventionFields');
            print(
                '[AssessmentRepository] - Has main assessment fields: $hasMainAssessmentFields');

            if (hasMainAssessmentFields) {
              print(
                  '[AssessmentRepository] FORCE: ERROR - This is main assessment data!');
              return null;
            }

            if (hasChoiceOptions ||
                hasInterventionTypes ||
                hasInterventionFields) {
              print(
                  '[AssessmentRepository] FORCE: CONFIRMED - This is intervention assessment data');

              final assessment = _convertInterventionAssessmentToModel(doc);
              print(
                  '[AssessmentRepository] FORCE: Successfully converted intervention assessment');
              print(
                  '[AssessmentRepository] FORCE: Assessment type: ${assessment.type}');
              print(
                  '[AssessmentRepository] FORCE: Questions: ${assessment.questions.length}');

              return assessment;
            } else {
              print(
                  '[AssessmentRepository] FORCE: ERROR - Unknown data structure');
              return null;
            }
          }
        }

        print(
            '[AssessmentRepository] FORCE: ERROR - No questions found in document');
        return null;
      } else {
        print('[AssessmentRepository] FORCE: No document found');

        // Debug: List all documents in intervention_assessment collection
        final allDocs = await interventionCollection.find().toList();
        print(
            '[AssessmentRepository] FORCE: Total documents in intervention_assessment: ${allDocs.length}');

        for (final availableDoc in allDocs) {
          print(
              '[AssessmentRepository] FORCE: Available - ID: ${availableDoc['_id']}');
          print(
              '[AssessmentRepository] FORCE: Available - StudentId: ${availableDoc['studentId']}');
          print(
              '[AssessmentRepository] FORCE: Available - Category: ${availableDoc['category']}');
          print(
              '[AssessmentRepository] FORCE: Available - Reading Level: ${availableDoc['readingLevel']}');
          print(
              '[AssessmentRepository] FORCE: Available - Status: ${availableDoc['status']}');
        }

        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] FORCE: ERROR - $e');
      return null;
    }
  }

  /// Get MAIN ASSESSMENT with fallback mechanism for null reading level
  Future<Assessment?> getMainAssessment(dynamic id,
      {String? readingLevel, String? category}) async {
    try {
      print('[AssessmentRepository] Loading MAIN ASSESSMENT with ID: $id');
      print('[AssessmentRepository] Required reading level: $readingLevel');
      print('[AssessmentRepository] Required category: $category');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }

      // CRITICAL: Use main database connection (test database) for main assessments
      final assessmentCollection =
          _dbService.getCollection(_collMainAssessment);
      Map<String, dynamic>? doc;

      // CRITICAL FIX: Only load ONE specific assessment document
      if (id != null && id is String && id.length == 24) {
        try {
          final objectId = ObjectId.fromHexString(id);
          doc = await assessmentCollection.findOne(where.eq('_id', objectId));

          if (doc != null) {
            print('[AssessmentRepository] Found specific assessment:');
            print('[AssessmentRepository]   - ID: ${doc['_id']}');
            print(
                '[AssessmentRepository]   - Reading Level: ${doc['readingLevel']}');
            print('[AssessmentRepository]   - Category: ${doc['category']}');
            print(
                '[AssessmentRepository]   - Questions: ${(doc['questions'] as List?)?.length ?? 0}');

            // Store the category from this specific assessment
            _currentAssessmentCategory = doc['category']?.toString();
          }
        } catch (e) {
          print('[AssessmentRepository] Error finding by ObjectId: $e');
        }
      }

      // ENHANCED FALLBACK: Try multiple strategies if exact ID failed
      if (doc == null) {
        print(
            '[AssessmentRepository] Exact ID search failed, trying fallback strategies');

        // Strategy 1: If we have both reading level and category - THIS IS THE MAIN APPROACH
        if (readingLevel != null && category != null) {
          final normalizedLevel =
              ReadingLevelUtils.normalizeReadingLevel(readingLevel);

          print(
              '[AssessmentRepository] Fallback 1: Searching for Level=$normalizedLevel, Category=$category');

          final query = where
              .eq('readingLevel', normalizedLevel)
              .and(where.eq('category', category))
              .and(where.eq('isActive', true));

          final assessments =
              await assessmentCollection.find(query).take(1).toList();

          if (assessments.isNotEmpty) {
            doc = assessments.first;
            _currentAssessmentCategory = doc['category']?.toString();
            print(
                '[AssessmentRepository] Found fallback assessment: ${doc['_id']}');
            print(
                '[AssessmentRepository] Assessment reading level: ${doc['readingLevel']}');
            print(
                '[AssessmentRepository] Assessment category: ${doc['category']}');
          }
        }

        // Strategy 2: If we only have category (no reading level)
        if (doc == null && category != null) {
          print(
              '[AssessmentRepository] Fallback 2: Searching by category only: $category');

          final query =
              where.eq('category', category).and(where.eq('isActive', true));

          final assessments =
              await assessmentCollection.find(query).take(1).toList();

          if (assessments.isNotEmpty) {
            doc = assessments.first;
            _currentAssessmentCategory = doc['category']?.toString();
            print(
                '[AssessmentRepository] Found category-only fallback assessment: ${doc['_id']}');
          }
        }

        // Strategy 3: Try to find any active assessment as last resort
        if (doc == null) {
          print(
              '[AssessmentRepository] Fallback 3: Searching for any active assessment');

          final query = where.eq('isActive', true);
          final assessments =
              await assessmentCollection.find(query).take(1).toList();

          if (assessments.isNotEmpty) {
            doc = assessments.first;
            _currentAssessmentCategory = doc['category']?.toString();
            print(
                '[AssessmentRepository] Found last-resort fallback assessment: ${doc['_id']}');
          }
        }
      }

      if (doc != null) {
        final assessment = _convertMainAssessmentToModel(doc);
        _assessment = assessment;

        print('[AssessmentRepository] LOADED SINGLE ASSESSMENT:');
        print(
            '[AssessmentRepository]   - Category: $_currentAssessmentCategory');
        print(
            '[AssessmentRepository]   - Questions: ${assessment.questions.length}');

        return assessment;
      } else {
        print('[AssessmentRepository] ERROR: No assessment found with ID: $id');
        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] Error: $e');
      return null;
    }
  }

  /// Create hardcoded pre-assessment for new users
  Assessment _createHardcodedPreAssessment() {
    print(
        '[AssessmentRepository] Creating hardcoded pre-assessment with reading comprehension');

    final questions = [
      // Add this enhanced reading comprehension question with proper passages and sentenceQuestions
      Question(
        questionId: 'PRE_RC_004',
        questionNumber: 4,
        questionTypeId: 'reading_comprehension',
        questionText: 'Basahin ang kwento at sagutin ang tanong.',
        passages: [
          {
            'pageNumber': 1,
            'pageText':
                'Si Maria ay kumain ng mansanas. Siya ay nakaupo sa ilalim ng puno ng mansanas. Masarap ang mansanas.',
            'pageImage': null
          }
        ],
        sentenceQuestions: [
          {
            'questionText': 'Ano ang kinain ni Maria?',
            'correctAnswer': 'Mansanas',
            'incorrectAnswer': 'Mangga'
          }
        ],
        options: [
          AssessmentOption(
              optionId: '1', optionText: 'Mansanas', isCorrect: true),
          AssessmentOption(
              optionId: '2', optionText: 'Mangga', isCorrect: false),
        ],
      ),

      // Keep other existing questions...
      Question(
        questionId: 'PRE_AK_001',
        questionNumber: 1,
        questionTypeId: 'alphabet_knowledge',
        questionText: 'Anong ang katumbas na maliit na letra?',
        displayedText: 'A',
        hasImage: true,
        imageUrl: 'assets/images/letters/A_big.png',
        options: [
          AssessmentOption(optionId: '1', optionText: 'a', isCorrect: true),
          AssessmentOption(optionId: '2', optionText: 'e', isCorrect: false),
        ],
      ),
      Question(
        questionId: 'PRE_PA_002',
        questionNumber: 2,
        questionTypeId: 'phonological_awareness',
        questionText: 'Bigkasin ang tunog ng salitang nakikita',
        displayedText: 'ASO',
        options: [
          AssessmentOption(
              optionId: '1', optionText: '/ah/ /es/ /oh/', isCorrect: true),
          AssessmentOption(
              optionId: '2', optionText: '/oh/ /es/ /ah/', isCorrect: false),
        ],
      ),
      Question(
        questionId: 'PRE_WR_003',
        questionNumber: 3,
        questionTypeId: 'word_recognition',
        questionText: 'Pagsamahin ang pantig',
        displayedText: 'BO + LA',
        hasImage: true,
        imageUrl: 'assets/images/ball.png',
        options: [
          AssessmentOption(optionId: '1', optionText: 'BOLA', isCorrect: true),
          AssessmentOption(optionId: '2', optionText: 'LABO', isCorrect: false),
        ],
      ),
      Question(
        questionId: 'PRE_DC_005',
        questionNumber: 5,
        questionTypeId: 'decoding',
        questionText: 'Ano ang nasa larawan?',
        hasImage: true,
        imageUrl: 'assets/images/dog.png',
        options: [
          AssessmentOption(optionId: '1', optionText: 'ASO', isCorrect: true),
          AssessmentOption(optionId: '2', optionText: 'OSO', isCorrect: false),
        ],
      ),
    ];

    return Assessment(
      assessmentId: 'PRE_ASSESSMENT_001',
      title: 'Panimulang Pagtatasa sa Pagbasa',
      description: 'Initial assessment to determine reading level',
      totalQuestions: questions.length,
      continueButtonText: 'MAG PATULOY',
      language: 'FL',
      type: 'pre_assessment',
      status: 'active',
      questions: questions,
      categoryCounts: {
        'alphabet_knowledge': 1,
        'phonological_awareness': 1,
        'word_recognition': 1,
        'reading_comprehension': 1,
        'decoding': 1,
      },
    );
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
        final questionType =
            q['questionType'] ?? q['questionTypeId'] ?? 'alphabet_knowledge';
        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? q['displayedText'] ?? '';
        final questionImage = q['questionImage'] ?? q['imageUrl'];

        print('[AssessmentRepository] Question $questionId details:');
        print('[AssessmentRepository]   - questionType: ${q['questionType']}');
        print(
            '[AssessmentRepository]   - questionTypeId: ${q['questionTypeId']}');
        print('[AssessmentRepository]   - category: ${q['category']}');
        print(
            '[AssessmentRepository]   - questionImage: ${q['questionImage']}');
        print('[AssessmentRepository]   - imageUrl: ${q['imageUrl']}');
        print('[AssessmentRepository]   - Final image URL: $questionImage');
        print(
            '[AssessmentRepository]   - Is AWS S3 URL: ${questionImage?.toString().contains('s3.ap-southeast-2.amazonaws.com') == true}');

        // ENHANCED: Process passages and sentenceQuestions for pre-assessment
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

        // Handle questionSet data for phonological awareness
        Map<String, dynamic>? questionSet;
        if (q['questionSet'] != null) {
          questionSet = Map<String, dynamic>.from(q['questionSet']);
          print(
              '[AssessmentRepository] Found questionSet for question $questionId: $questionSet');
        }

        // Parse decoding-specific fields when present
        List<String>? displaySequence;
        if (q['displaySequence'] != null && q['displaySequence'] is List) {
          displaySequence = (q['displaySequence'] as List).cast<String>();
        }
        List<String>? dragElements;
        if (q['dragElements'] != null && q['dragElements'] is List) {
          dragElements = (q['dragElements'] as List).cast<String>();
        }
        List<String>? correctSequence;
        if (q['correctSequence'] != null && q['correctSequence'] is List) {
          correctSequence = (q['correctSequence'] as List).cast<String>();
        }

        // Parse word recognition fields
        List<String>? wordChoices;
        if (q['wordChoices'] != null && q['wordChoices'] is List) {
          wordChoices = (q['wordChoices'] as List).cast<String>();
        } else if (q['blankOptions'] != null && q['blankOptions'] is List) {
          wordChoices = (q['blankOptions'] as List).cast<String>();
        }

        String? sentenceWithBlank;
        if (q['sentenceWithBlank'] != null) {
          sentenceWithBlank = q['sentenceWithBlank'].toString();
        } else if (q['displayWord'] != null) {
          sentenceWithBlank = q['displayWord'].toString();
        }

        String? correctAnswer;
        if (q['correctAnswer'] != null) {
          if (q['correctAnswer'] is List &&
              (q['correctAnswer'] as List).isNotEmpty) {
            correctAnswer = (q['correctAnswer'] as List).first.toString();
          } else {
            correctAnswer = q['correctAnswer'].toString();
          }
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
          questionSet: questionSet,
          displaySequence: displaySequence,
          dragElements: dragElements,
          correctSequence: correctSequence,
          wordChoices: wordChoices,
          sentenceWithBlank: sentenceWithBlank,
          correctAnswer: correctAnswer,
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
    print(
        '[AssessmentRepository] Category: ${doc['category']}'); // IMPORTANT: Log the document category

    if (doc['questions'] != null && doc['questions'] is List) {
      final questionsList = doc['questions'] as List;
      print(
          '[AssessmentRepository] Processing ${questionsList.length} questions');

      // Get the assessment category from the document
      final assessmentCategory = doc['category']?.toString() ?? 'Unknown';

      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];

        // FIXED: Create category-specific question IDs
        final questionType = q['questionType']?.toString().toLowerCase() ?? '';
        final categoryPrefix =
            _getCategoryPrefix(assessmentCategory, questionType);
        final questionId =
            '${categoryPrefix}_${i + 1}'; // e.g., "AK_1", "PA_2", etc.

        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? '';
        final questionImage = q['questionImage'];

        print(
            '[AssessmentRepository] Creating question $questionId for category: $assessmentCategory, type: $questionType');

        // Enhanced passages parsing with detailed logging
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
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
            print(
                '[AssessmentRepository] Processed single passage map for question $questionId');
          }
        }

        // Enhanced sentence questions parsing
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
              }
            }
            print(
                '[AssessmentRepository] Processed ${sentenceQuestions.length} sentenceQuestions for question $questionId');
          } else if (q['sentenceQuestions'] is Map) {
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
              optionId: (optIndex + 1).toString(),
              optionText: choice['optionText'] ?? '',
              isCorrect: choice['isCorrect'] ?? false,
            ));
          }
          print(
              '[AssessmentRepository] Processed ${options.length} options for question $questionId');
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

        // FIXED: Use proper question type ID that matches the assessment category
        final standardizedQuestionTypeId =
            _getStandardizedQuestionTypeId(assessmentCategory, questionType);

        // Handle questionSet data for phonological awareness
        Map<String, dynamic>? questionSet;
        if (q['questionSet'] != null) {
          questionSet = Map<String, dynamic>.from(q['questionSet']);
          print(
              '[AssessmentRepository] Found questionSet for main assessment question $questionId: $questionSet');
        }

        questions.add(Question(
          questionId: questionId, // Now category-specific
          questionNumber: i + 1,
          questionTypeId:
              standardizedQuestionTypeId, // Standardized category mapping
          questionText: questionText,
          displayedText: questionValue,
          hasImage: questionImage != null,
          imageUrl: questionImage,
          options: options,
          questionType: questionType,
          order: q['order'] ?? i + 1,
          passages: passages,
          sentenceQuestions: sentenceQuestions,
          questionSet: questionSet,
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
    );
  }

  /// Convert intervention_assessment document to Assessment model
  Assessment _convertInterventionAssessmentToModel(Map<String, dynamic> doc) {
    List<Question> questions = [];

    print(
        '[AssessmentRepository] Converting intervention assessment document to model');
    print('[AssessmentRepository] Document ID: ${doc['_id']}');
    print('[AssessmentRepository] Reading Level: ${doc['readingLevel']}');
    print('[AssessmentRepository] Category: ${doc['category']}');
    print('[AssessmentRepository] Total Questions: ${doc['totalQuestions']}');

    if (doc['questions'] != null && doc['questions'] is List) {
      final questionsList = doc['questions'] as List;
      print(
          '[AssessmentRepository] Processing ${questionsList.length} intervention questions');

      // Get the assessment category from the document
      final assessmentCategory = doc['category']?.toString() ?? 'Unknown';

      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];

        // Create category-specific question IDs for intervention
        final questionType = q['questionType']?.toString().toLowerCase() ?? '';
        final categoryPrefix =
            _getCategoryPrefix(assessmentCategory, questionType);
        final questionId = q['questionId'] ??
            'INT_${categoryPrefix}_${i + 1}'; // Use existing ID or create one

        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? '';
        final questionImage = q['questionImage'];

        print(
            '[AssessmentRepository] Creating intervention question $questionId for category: $assessmentCategory, type: $questionType');

        // Parse passages for reading comprehension
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null) {
          if (q['passages'] is List) {
            passages = [];
            for (final passage in q['passages']) {
              if (passage is Map) {
                final passageMap = Map<String, dynamic>.from(passage);
                passages.add(passageMap);
              }
            }
          } else if (q['passages'] is Map) {
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
          }
        }

        // Parse sentence questions for reading comprehension
        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null) {
          if (q['sentenceQuestions'] is List) {
            sentenceQuestions = [];
            for (final sq in q['sentenceQuestions']) {
              if (sq is Map) {
                sentenceQuestions.add(Map<String, dynamic>.from(sq));
              }
            }
          } else if (q['sentenceQuestions'] is Map) {
            sentenceQuestions = [
              Map<String, dynamic>.from(q['sentenceQuestions'] as Map)
            ];
          }
        }

        // Parse options - Handle choiceOptions (intervention assessment specific)
        List<AssessmentOption> options = [];
        if (q['choiceOptions'] != null && q['choiceOptions'] is List) {
          final choiceOptions = q['choiceOptions'] as List;
          for (int optIndex = 0; optIndex < choiceOptions.length; optIndex++) {
            final choice = choiceOptions[optIndex];
            options.add(AssessmentOption(
              optionId:
                  choice['optionId']?.toString() ?? (optIndex + 1).toString(),
              optionText: choice['optionText'] ?? '',
              isCorrect: choice['isCorrect'] ?? false,
            ));
          }
          print(
              '[AssessmentRepository] Processed ${options.length} choiceOptions for $questionId');
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
          }
        }

        // Use standardized question type ID
        final standardizedQuestionTypeId =
            _getStandardizedQuestionTypeId(assessmentCategory, questionType);

        // Handle questionSet data for phonological awareness (malapantig type)
        Map<String, dynamic>? questionSet;
        if (q['questionSet'] != null) {
          questionSet = Map<String, dynamic>.from(q['questionSet']);
          print(
              '[AssessmentRepository] Found questionSet for intervention question $questionId: $questionSet');
        }

        // Handle intervention-specific fields for decoding questions
        List<String>? displaySequence;
        if (q['displaySequence'] != null && q['displaySequence'] is List) {
          displaySequence = (q['displaySequence'] as List).cast<String>();
          print(
              '[AssessmentRepository] Found displaySequence for $questionId: $displaySequence');
        }

        List<String>? dragElements;
        if (q['dragElements'] != null && q['dragElements'] is List) {
          dragElements = (q['dragElements'] as List).cast<String>();
          print(
              '[AssessmentRepository] Found dragElements for $questionId: $dragElements');
        }

        List<String>? correctSequence;
        if (q['correctSequence'] != null && q['correctSequence'] is List) {
          correctSequence = (q['correctSequence'] as List).cast<String>();
          print(
              '[AssessmentRepository] Found correctSequence for $questionId: $correctSequence');
        }

        // Handle intervention-specific fields for word recognition questions
        String? displayWord;
        if (q['displayWord'] != null) {
          displayWord = q['displayWord'].toString();
          print(
              '[AssessmentRepository] Found displayWord for $questionId: $displayWord');
        }

        List<String>? blankOptions;
        if (q['blankOptions'] != null && q['blankOptions'] is List) {
          blankOptions = (q['blankOptions'] as List).cast<String>();
          print(
              '[AssessmentRepository] Found blankOptions for $questionId: $blankOptions');
        }

        // Handle correctAnswer field
        String? correctAnswer;
        if (q['correctAnswer'] != null) {
          if (q['correctAnswer'] is List &&
              (q['correctAnswer'] as List).isNotEmpty) {
            correctAnswer = (q['correctAnswer'] as List).first.toString();
          } else {
            correctAnswer = q['correctAnswer'].toString();
          }
          print(
              '[AssessmentRepository] Found correctAnswer for $questionId: $correctAnswer');
        }

        // Handle blankPosition for fill_missing_letter questions
        int? blankPosition;
        if (q['blankPosition'] != null) {
          blankPosition = q['blankPosition'] as int?;
          print(
              '[AssessmentRepository] Found blankPosition for $questionId: $blankPosition');
        }

        questions.add(Question(
          questionId: questionId, // Use intervention question ID
          questionNumber: i + 1,
          questionTypeId: standardizedQuestionTypeId,
          questionText: questionText,
          displayedText: questionValue,
          hasImage: questionImage != null,
          imageUrl: questionImage,
          options: options,
          questionType: questionType,
          order: q['order'] ?? i + 1,
          passages: passages,
          sentenceQuestions: sentenceQuestions,
          questionSet: questionSet,
          // Add intervention-specific fields
          displaySequence: displaySequence,
          dragElements: dragElements,
          correctSequence: correctSequence,
          sentenceWithBlank:
              displayWord, // Use displayWord for sentence with blank
          wordChoices: blankOptions, // Use blankOptions for word choices
          correctAnswer: correctAnswer,
          blankPosition: blankPosition,
        ));
      }
    }

    return Assessment(
      assessmentId: doc['_id'].toString(),
      title: 'Intervention: ${doc['category'] ?? 'Unknown Category'}',
      description:
          'Intervention assessment for ${doc['readingLevel'] ?? 'Unknown Level'} reading level',
      totalQuestions: doc['totalQuestions'] ??
          questions.length, // Use dynamic count from teacher
      continueButtonText: 'MAG PATULOY',
      language: 'FL',
      type: 'intervention_assessment',
      status: doc['status'] == 'active'
          ? 'active'
          : 'inactive', // Check status field correctly
      questions: questions,
      categoryCounts: {doc['category'] ?? 'unknown': questions.length},
    );
  }

  /// Helper method to get category prefix for question IDs
  String _getCategoryPrefix(String assessmentCategory, String questionType) {
    // First try to map based on assessment category
    switch (assessmentCategory.toLowerCase()) {
      case 'alphabet knowledge':
        return 'AK';
      case 'phonological awareness':
        return 'PA';
      case 'decoding':
        return 'DC';
      case 'word recognition':
        return 'WR';
      case 'reading comprehension':
        return 'RC';
      default:
        // Fallback to question type mapping
        return _getQuestionTypePrefix(questionType);
    }
  }

  /// Helper method to get prefix based on question type
  String _getQuestionTypePrefix(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'patinig':
      case 'katinig':
      case 'malapantig':
        return 'PA'; // Phonological Awareness
      case 'word':
        return 'WR'; // Word Recognition
      case 'sentence':
        return 'RC'; // Reading Comprehension
      default:
        return 'AK'; // Default to Alphabet Knowledge
    }
  }

  /// Updated method to standardize question type IDs based on assessment category
  String _getStandardizedQuestionTypeId(
      String assessmentCategory, String questionType) {
    // Use the assessment category as the primary source of truth
    switch (assessmentCategory.toLowerCase()) {
      case 'alphabet knowledge':
        return 'alphabet_knowledge';
      case 'phonological awareness':
        return 'phonological_awareness';
      case 'decoding':
        return 'decoding';
      case 'word recognition':
        return 'word_recognition';
      case 'reading comprehension':
        return 'reading_comprehension';
      default:
        // Fallback to original mapping if category is not recognized
        return _mapQuestionTypeToId(questionType);
    }
  }

  /// Helper function for min
  int min(int a, int b) {
    return a < b ? a : b;
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

  // In assessment_repository.dart - Update saveUserResponses method
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

      // CRITICAL FIX: Convert userId to integer
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
        print(
            '[AssessmentRepository] Converted userId to integer: $studentIdValue');
      } catch (e) {
        print(
            '[AssessmentRepository] WARNING: Could not convert userId to integer: $e');
        studentIdValue = userId;
      }

      // Use integer from additionalData if available
      if (additionalData != null &&
          additionalData['studentIdInteger'] != null) {
        studentIdValue = additionalData['studentIdInteger'];
        print(
            '[AssessmentRepository] Using studentIdInteger from additionalData: $studentIdValue');
      }

      print(
          '[AssessmentRepository] Final studentId: $studentIdValue (${studentIdValue.runtimeType})');
      print('[AssessmentRepository] Assessment ID: $assessmentId');
      print('[AssessmentRepository] Total answers: ${answers.length}');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      // Extract category information
      Map<String, String>? questionCategories;
      if (additionalData != null &&
          additionalData['questionCategories'] != null) {
        questionCategories =
            Map<String, String>.from(additionalData['questionCategories']);
      }

      if (additionalData != null && additionalData['category'] != null) {
        _currentAssessmentCategory = additionalData['category'] as String?;
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, saving locally');
        return await _dbService.saveAssessmentResultsLocally(
          userId: studentIdValue, // Use integer value
          assessmentId: assessmentId,
          score: score,
          readingLevel: readingLevel,
        );
      }

      int questionOrder = 1;
      String categoryResultId = '';

      // Process each answer
      for (final entry in answers.entries) {
        final questionId = entry.key;
        final selectedOption = entry.value;

        final isCorrect =
            _isAnswerCorrect(questionId, selectedOption, additionalData);

        // Determine category
        String category;
        if (questionCategories != null &&
            questionCategories.containsKey(questionId)) {
          category = questionCategories[questionId]!;
        } else if (_currentAssessmentCategory != null &&
            _currentAssessmentCategory!.isNotEmpty) {
          category = _currentAssessmentCategory!;
        } else {
          category = _getCategoryFromQuestionId(questionId,
              defaultCategory: 'Unknown Category');
        }

        category = _normalizeCategory(category);

        print(
            '[AssessmentRepository] Saving response for question $questionId:');
        print('[AssessmentRepository]   - Category: $category');
        print(
            '[AssessmentRepository]   - Student ID: $studentIdValue (${studentIdValue.runtimeType})');

        await _dbService.saveStudentResponse({
          'studentId': studentIdValue, // Use integer value
          'categoryResultId': categoryResultId,
          'categoryId': assessmentId,
          'questionOrder': questionOrder,
          'questionId': questionId,
          'category': category,
          'sentenceQuestionIndex': questionOrder,
          'selectedOption': selectedOption,
          'isCorrect': isCorrect,
          'responseTime': 0,
          'answeredAt': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'assessmentType': additionalData?['assessmentType'] ?? 'unknown',
          'readingLevel': readingLevel,
        });

        questionOrder++;
      }

      print(
          '[AssessmentRepository] Successfully saved ${answers.length} student responses with integer studentId');
      return true;
    } catch (e) {
      print('[AssessmentRepository] Error saving user responses: $e');
      return false;
    }
  }

  /// Helper method to normalize category names
  String _normalizeCategory(String category) {
    final normalizedCategory = category.trim();

    // Map common variations to standard names
    switch (normalizedCategory.toLowerCase()) {
      case 'alphabet knowledge':
      case 'alphabet_knowledge':
      case 'ak':
        return 'Alphabet Knowledge';
      case 'phonological awareness':
      case 'phonological_awareness':
      case 'pa':
        return 'Phonological Awareness';
      case 'decoding':
      case 'dc':
        return 'Decoding';
      case 'word recognition':
      case 'word_recognition':
      case 'wr':
        return 'Word Recognition';
      case 'reading comprehension':
      case 'reading_comprehension':
      case 'rc':
        return 'Reading Comprehension';
      default:
        return normalizedCategory; // Return as-is if no mapping found
    }
  }

  /// ENHANCED: Updated _isAnswerCorrect method with better logging
  bool _isAnswerCorrect(String questionId, String selectedOption,
      Map<String, dynamic>? additionalData) {
    if (additionalData != null && additionalData['correctAnswers'] != null) {
      final correctAnswers =
          additionalData['correctAnswers'] as Map<String, dynamic>;
      final correctOption = correctAnswers[questionId];
      final isCorrect = correctOption == selectedOption;

      print('[AssessmentRepository] Answer check for $questionId:');
      print('[AssessmentRepository]   - Selected: $selectedOption');
      print('[AssessmentRepository]   - Correct: $correctOption');
      print('[AssessmentRepository]   - Is Correct: $isCorrect');

      return isCorrect;
    }

    print(
        '[AssessmentRepository] No correct answers data available for $questionId');
    return false;
  }

  /// ENHANCED: Updated method with better category tracking
  String _getCategoryFromQuestionId(String questionId,
      {String defaultCategory = 'Unknown Category'}) {
    try {
      print(
          '[AssessmentRepository] Determining category for question ID: $questionId');

      // Enhanced pattern-based detection
      if (questionId.startsWith('AK_') ||
          questionId.startsWith('PRE_AK') ||
          questionId.contains('alphabet')) {
        return 'Alphabet Knowledge';
      }
      if (questionId.startsWith('PA_') ||
          questionId.startsWith('PRE_PA') ||
          questionId.contains('phono')) {
        return 'Phonological Awareness';
      }
      if (questionId.startsWith('DC_') ||
          questionId.startsWith('PRE_DC') ||
          questionId.contains('decod')) {
        return 'Decoding';
      }
      if (questionId.startsWith('WR_') ||
          questionId.startsWith('PRE_WR') ||
          questionId.contains('word')) {
        return 'Word Recognition';
      }
      if (questionId.startsWith('RC_') ||
          questionId.startsWith('PRE_RC') ||
          questionId.contains('reading') ||
          questionId.contains('comprehension')) {
        return 'Reading Comprehension';
      }

      // Use current assessment category if available and question ID doesn't have clear category info
      if (_currentAssessmentCategory != null &&
          _currentAssessmentCategory!.isNotEmpty) {
        print(
            '[AssessmentRepository] Using current assessment category: $_currentAssessmentCategory');
        return _currentAssessmentCategory!;
      }

      // Fallback for generic question IDs
      if (questionId.contains('main_q_')) {
        print(
            '[AssessmentRepository] WARNING: Generic question ID detected: $questionId, using default category: $defaultCategory');
        return defaultCategory;
      }

      // Final fallback
      print(
          '[AssessmentRepository] No category pattern matched for $questionId, using default: $defaultCategory');
      return defaultCategory;
    } catch (e) {
      print(
          '[AssessmentRepository] Error determining category from question ID: $e');
      return defaultCategory;
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
      );

      return result.isSuccess;
    } catch (e) {
      print('[AssessmentRepository] Error updating user reading level: $e');
      return false;
    }
  }

  // Add these fields to the AssessmentRepository class
  Assessment? _assessment;
  String? _currentAssessmentCategory;

  /// Updated _convertAssessmentsToLessons to include reading level validation
  List<Map<String, dynamic>> _convertAssessmentsToLessons(
      List<Map<String, dynamic>> assessments, String targetReadingLevel) {
    final List<Map<String, dynamic>> lessons = [];

    for (int i = 0; i < assessments.length; i++) {
      final assessment = assessments[i];

      // Verify the assessment is for the correct reading level
      final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
      if (ReadingLevelUtils.normalizeReadingLevel(assessmentLevel) !=
          targetReadingLevel) {
        print(
            '[AssessmentRepository] Skipping assessment with incorrect reading level: $assessmentLevel');
        continue;
      }

      final questionCount = assessment['questions'] is List
          ? (assessment['questions'] as List).length
          : 5;

      final category = assessment['category'] ?? 'Filipino Lesson';

      lessons.add({
        'index': i + 1,
        'title': 'ARALIN ${i + 1}: $category',
        'description': _getDescriptionForLevel(targetReadingLevel, category),
        'questionCount': questionCount,
        'isAvailable': i == 0, // First lesson always available
        'isCompleted': false, // This will be updated by home screen logic
        'assessmentId': assessment['_id'].toString(),
        'readingLevel': targetReadingLevel,
        'category': category,
      });
    }

    print(
        '[AssessmentRepository] Converted ${lessons.length} assessments to lessons for level: $targetReadingLevel');
    return lessons;
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

  /// Check for failed categories and save to failed_category_result collection
  Future<bool> checkAndSaveFailedCategories({
    required String userId,
    required String categoryName,
    required double score,
    required int totalQuestions,
    required int correctAnswers,
    required String assessmentId,
    required String readingLevel,
    double passingThreshold = 75.0,
  }) async {
    try {
      print(
          '[AssessmentRepository] Checking if category failed: $categoryName (Score: $score%)');

      if (score >= passingThreshold) {
        print(
            '[AssessmentRepository] Category passed, no need to save to failed_category_result');
        return true; // Not failed, but operation successful
      }

      // Category failed, save to failed_category_result collection
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[AssessmentRepository] Database not connected, cannot save failed category');
        return false;
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final failedCategoryCollection =
          _dbService.getCollection(_collFailedCategoryResult);

      final failedCategoryDoc = {
        'studentId': studentIdValue,
        'categoryName': categoryName,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'attemptDate': DateTime.now().toIso8601String(),
        'assessmentId': assessmentId,
        'readingLevel': readingLevel,
        'isPassed': false,
        'passingThreshold': passingThreshold,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      print(
          '[AssessmentRepository] Saving failed category to failed_category_result:');
      print('[AssessmentRepository] - Student ID: $studentIdValue');
      print('[AssessmentRepository] - Category: $categoryName');
      print('[AssessmentRepository] - Score: $score%');

      final result =
          await failedCategoryCollection.insertOne(failedCategoryDoc);

      if (result.isSuccess) {
        print(
            '[AssessmentRepository] Successfully saved failed category record');
        return true;
      } else {
        print('[AssessmentRepository] Failed to save failed category record');
        return false;
      }
    } catch (e) {
      print('[AssessmentRepository] Error checking/saving failed category: $e');
      return false;
    }
  }

  /// Get failed categories for a user from failed_category_result collection
  Future<List<Map<String, dynamic>>> getFailedCategories(String userId, {String? readingLevel}) async {
    try {
      print(
          '[AssessmentRepository] Getting failed categories for user: $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[AssessmentRepository] Database not connected, cannot get failed categories');
        return [];
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final failedCategoryCollection =
          _dbService.getCollection(_collFailedCategoryResult);

      var query = where.eq('studentId', studentIdValue);
      if (readingLevel != null && readingLevel.isNotEmpty) {
        query = query.eq('readingLevel', readingLevel);
      }
      query = query.sortBy('attemptDate', descending: true);

      final results = await failedCategoryCollection.find(query).toList();

      print(
          '[AssessmentRepository] Found ${results.length} failed category records');

      return results;
    } catch (e) {
      print('[AssessmentRepository] Error getting failed categories: $e');
      return [];
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

  /// Debug assessment queries for troubleshooting assessment loading issues
  Future<bool> debugAssessmentQueries(String assessmentId) async {
    try {
      print('\n======= DEBUG ASSESSMENT QUERY =======');
      print('Debugging assessment ID: $assessmentId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('ERROR: Database not connected');
        return false;
      }

      // Use the main_assessment collection from test database
      final assessmentCollection =
          _dbService.getCollection(_collMainAssessment);

      // STEP 1: Try to find by exact ObjectId
      try {
        if (assessmentId.length == 24) {
          final objectId = ObjectId.fromHexString(assessmentId);
          final doc =
              await assessmentCollection.findOne(where.eq('_id', objectId));

          if (doc != null) {
            print('SUCCESS: Found assessment by ObjectId');
            print('  - ID: ${doc['_id']}');
            print('  - Category: ${doc['category']}');
            print('  - Reading Level: ${doc['readingLevel']}');
            print('  - Questions: ${(doc['questions'] as List?)?.length ?? 0}');
            return true;
          } else {
            print('FAILED: No assessment found with ObjectId: $assessmentId');
          }
        }
      } catch (e) {
        print('ERROR searching by ObjectId: $e');
      }

      // STEP 2: Try alternate searches
      print('\nPerforming secondary searches...');

      // Try to find by partial ID match
      final partialQuery =
          where.match('_id', assessmentId).and(where.eq('isActive', true));
      final partialMatches =
          await assessmentCollection.find(partialQuery).toList();

      if (partialMatches.isNotEmpty) {
        print(
            'Found ${partialMatches.length} assessments with partial ID match:');
        for (final doc in partialMatches) {
          print('  - ID: ${doc['_id']}');
          print('  - Category: ${doc['category']}');
          print('  - Reading Level: ${doc['readingLevel']}');
        }
      } else {
        print('No partial ID matches found');
      }

      // STEP 3: Check available assessments
      print('\nListing all available assessments:');
      final allAssessments =
          await assessmentCollection.find(where.eq('isActive', true)).toList();

      print('Found ${allAssessments.length} active assessments:');
      for (final doc in allAssessments) {
        print('  - ID: ${doc['_id']}');
        print('  - Category: ${doc['category']}');
        print('  - Reading Level: ${doc['readingLevel']}');
      }

      print('\n======= END DEBUG =======\n');
      return false;
    } catch (e) {
      print('Error in debugAssessmentQueries: $e');
      return false;
    }
  }

  /// Save intervention assessment response to intervention_responses collection
  Future<bool> saveInterventionResponse({
    required String studentId,
    required String interventionAssessmentId,
    required String questionId,
    required String category,
    required dynamic response,
    required bool isCorrect,
    required double responseTime,
    required String readingLevel,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('[AssessmentRepository] Saving intervention response for questionId: $questionId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, cannot save intervention response');
        return false;
      }

      // Convert studentId to int
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(studentId);
      } catch (e) {
        studentIdValue = studentId;
      }

      final interventionResponsesCollection = _dbService.getCollection('intervention_responses');

      // ✅ REMOVED: Old attemptNumber logic - now getting revisionNumber from intervention_assessment

      // ✅ FIXED: Get revisionNumber from intervention_assessment, not attemptNumber
      int revisionNumber = 1; // Default fallback
      ObjectId assessmentObjectId; // Declare here to be accessible outside try-catch
      
      try {
        final interventionCollection = _dbService.getCollection('intervention_assessment');
        
        // Handle interventionAssessmentId - it's always a String in this method
        // Check if it's a string representation of ObjectId
        if (interventionAssessmentId.startsWith('ObjectId("') && interventionAssessmentId.endsWith('")')) {
          // Extract the hex string from "ObjectId("hex")"
          final hexString = interventionAssessmentId.substring(10, interventionAssessmentId.length - 2);
          assessmentObjectId = ObjectId.parse(hexString);
        } else {
          // Regular hex string - try to parse directly
          assessmentObjectId = ObjectId.parse(interventionAssessmentId);
        }
        
        final interventionDoc = await interventionCollection.findOne(
          where.eq('_id', assessmentObjectId)
        );
        
        if (interventionDoc != null) {
          revisionNumber = interventionDoc['revisionNumber'] ?? 1;
          print('[AssessmentRepository] Found revisionNumber from intervention_assessment: $revisionNumber');
        }
      } catch (e) {
        print('[AssessmentRepository] Error getting revisionNumber from intervention_assessment: $e');
        // Set default assessmentObjectId if parsing failed
        try {
          assessmentObjectId = ObjectId.parse(interventionAssessmentId);
        } catch (e) {
          print('[AssessmentRepository] Failed to parse interventionAssessmentId as ObjectId: $e');
          return false;
        }
      }

      final responseDoc = {
        'studentId': studentIdValue,
        'interventionAssessmentId': assessmentObjectId, // ✅ FIXED: Use the already processed ObjectId
        'revisionNumber': revisionNumber, // ✅ FIXED: From intervention_assessment
        'questionId': questionId,
        'category': category,
        'response': response, // ✅ Should be optionId (string)
        'isCorrect': isCorrect,
        'responseTime': responseTime,
        'answeredAt': DateTime.now().toIso8601String(),
        'readingLevel': readingLevel,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Add any additional data (like correctMatches, totalMatches for phonological)
      if (additionalData != null) {
        responseDoc.addAll(additionalData);
      }

      print('[AssessmentRepository] Intervention response document: $responseDoc');

      final result = await interventionResponsesCollection.insertOne(responseDoc);

      if (result.isSuccess) {
        print('[AssessmentRepository] Successfully saved intervention response');
        return true;
      } else {
        print('[AssessmentRepository] Failed to save intervention response');
        return false;
      }
    } catch (e) {
      print('[AssessmentRepository] Error saving intervention response: $e');
      return false;
    }
  }

  // ===== CATEGORY RESULTS MANAGEMENT =====

  /// Check if a user has existing category_results record
  Future<bool> hasExistingCategoryResults(String userId) async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, cannot check category_results');
        return false;
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final categoryResultsCollection = _dbService.getCollection(_collCategoryResults);
      
      final existingRecord = await categoryResultsCollection.findOne(
        where.eq('studentId', studentIdValue)
      );

      final hasRecord = existingRecord != null;
      print('[AssessmentRepository] User $userId has existing category_results: $hasRecord');
      
      return hasRecord;
    } catch (e) {
      print('[AssessmentRepository] Error checking existing category_results: $e');
      return false;
    }
  }

  /// Create new category_results record for new user after first main assessment
  Future<bool> createCategoryResultsRecord({
    required String userId,
    required String categoryName,
    required int totalQuestions,
    required int correctAnswers,
    required double score,
    required bool isPassed,
    required String readingLevel,
    required String assessmentId,
    int? totalPossibleMatches,
  }) async {
    try {
      print('[AssessmentRepository] ===== CREATING NEW CATEGORY RESULTS RECORD =====');
      print('[AssessmentRepository] User ID: $userId');
      print('[AssessmentRepository] Category: $categoryName');
      print('[AssessmentRepository] Score: $score%');
      print('[AssessmentRepository] Reading Level: $readingLevel');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, cannot create category_results');
        return false;
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final categoryResultsCollection = _dbService.getCollection(_collCategoryResults);

      // Get assessment ObjectIds for each category
      final assessmentObjectIds = await _getAssessmentObjectIds();

      // Create categories array with all 5 main assessment categories
      final categories = [
        _createCategoryObject(
          categoryName: 'Alphabet Knowledge',
          assessmentObjectId: assessmentObjectIds['Alphabet Knowledge'],
          isCompleted: categoryName == 'Alphabet Knowledge',
          totalQuestions: categoryName == 'Alphabet Knowledge' ? totalQuestions : 15,
          correctAnswers: categoryName == 'Alphabet Knowledge' ? correctAnswers : 0,
          score: categoryName == 'Alphabet Knowledge' ? score : 0,
          isPassed: categoryName == 'Alphabet Knowledge' ? isPassed : false,
        ),
        _createCategoryObject(
          categoryName: 'Phonological Awareness',
          assessmentObjectId: assessmentObjectIds['Phonological Awareness'],
          isCompleted: categoryName == 'Phonological Awareness',
          totalQuestions: categoryName == 'Phonological Awareness' ? totalQuestions : 6,
          correctAnswers: categoryName == 'Phonological Awareness' ? correctAnswers : 0,
          score: categoryName == 'Phonological Awareness' ? score : 0,
          isPassed: categoryName == 'Phonological Awareness' ? isPassed : false,
          totalPossibleMatches: categoryName == 'Phonological Awareness' ? totalPossibleMatches : 15,
        ),
        _createCategoryObject(
          categoryName: 'Decoding',
          assessmentObjectId: assessmentObjectIds['Decoding'],
          isCompleted: categoryName == 'Decoding',
          totalQuestions: categoryName == 'Decoding' ? totalQuestions : 15,
          correctAnswers: categoryName == 'Decoding' ? correctAnswers : 0,
          score: categoryName == 'Decoding' ? score : 0,
          isPassed: categoryName == 'Decoding' ? isPassed : false,
        ),
        _createCategoryObject(
          categoryName: 'Word Recognition',
          assessmentObjectId: assessmentObjectIds['Word Recognition'],
          isCompleted: categoryName == 'Word Recognition',
          totalQuestions: categoryName == 'Word Recognition' ? totalQuestions : 15,
          correctAnswers: categoryName == 'Word Recognition' ? correctAnswers : 0,
          score: categoryName == 'Word Recognition' ? score : 0,
          isPassed: categoryName == 'Word Recognition' ? isPassed : false,
        ),
        _createCategoryObject(
          categoryName: 'Reading Comprehension',
          assessmentObjectId: assessmentObjectIds['Reading Comprehension'],
          isCompleted: categoryName == 'Reading Comprehension',
          totalQuestions: categoryName == 'Reading Comprehension' ? totalQuestions : 10,
          correctAnswers: categoryName == 'Reading Comprehension' ? correctAnswers : 0,
          score: categoryName == 'Reading Comprehension' ? score : 0,
          isPassed: categoryName == 'Reading Comprehension' ? isPassed : false,
        ),
      ];

      // Calculate overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      final totalCategories = 5; // Always 5 standard CRLA categories
      // Calculate average score of completed categories only
      final completedScores = categories.where((cat) => cat['isCompleted'] == true).map((cat) => cat['score'] as double).toList();
      final overallScore = completedScores.isNotEmpty ? 
        (completedScores.reduce((sum, score) => sum + score) / completedScores.length).round() : 0;
      final allCategoriesPassed = categories.length >= 5 &&
          categories.every((cat) => cat['isPassed'] == true);

      // Create the main category_results document
      final categoryResultsDoc = {
        'studentId': studentIdValue,
        'assessmentDate': DateTime.now().toIso8601String(),
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'totalCategories': totalCategories,
        'allCategoriesPassed': allCategoriesPassed,
        'readingLevel': readingLevel,
        'readingLevelUpdated': false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        '__v': 1,
      };

      print('[AssessmentRepository] Creating category_results document:');
      print('[AssessmentRepository] - Student ID: $studentIdValue');
      print('[AssessmentRepository] - Overall Score: $overallScore');
      print('[AssessmentRepository] - Completed Categories: $completedCategories/$totalCategories');
      print('[AssessmentRepository] - All Categories Passed: $allCategoriesPassed');
      print('[AssessmentRepository] - Reading Level: $readingLevel');

      final result = await categoryResultsCollection.insertOne(categoryResultsDoc);

      if (result.isSuccess) {
        print('[AssessmentRepository] Successfully created category_results record');
        print('[AssessmentRepository] ===== END CREATING CATEGORY RESULTS RECORD =====');
        return true;
      } else {
        print('[AssessmentRepository] Failed to create category_results record');
        return false;
      }
    } catch (e) {
      print('[AssessmentRepository] Error creating category_results record: $e');
      return false;
    }
  }

  /// Update existing category_results record with new assessment results
  Future<bool> updateCategoryResultsRecord({
    required String userId,
    required String categoryName,
    required int totalQuestions,
    required int correctAnswers,
    required double score,
    required bool isPassed,
    String? newReadingLevel,
    int? totalPossibleMatches,
  }) async {
    try {
      print('[AssessmentRepository] ===== UPDATING CATEGORY RESULTS RECORD =====');
      print('[AssessmentRepository] User ID: $userId');
      print('[AssessmentRepository] Category: $categoryName');
      print('[AssessmentRepository] Score: $score%');
      print('[AssessmentRepository] Total Questions: $totalQuestions');
      print('[AssessmentRepository] Correct Answers: $correctAnswers');
      print('[AssessmentRepository] Is Passed: $isPassed');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected, cannot update category_results');
        return false;
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final categoryResultsCollection = _dbService.getCollection(_collCategoryResults);

      // Find existing record — key on BOTH studentId AND readingLevel to
      // avoid hitting a stale doc from a different level.
      // We read the user's current readingLevel from the users collection.
      final usersCollection = _dbService.getCollection('users');
      final userDoc = await usersCollection.findOne(
        where.eq('idNumber', studentIdValue)
      );
      final readingLevel = userDoc?['readingLevel'] as String? ?? '';

      final existingRecord = await categoryResultsCollection.findOne(
        where.eq('studentId', studentIdValue).eq('readingLevel', readingLevel)
      );

      if (existingRecord == null) {
        print('[AssessmentRepository] No existing category_results record found for user $userId');
        return false;
      }

      // Update the specific category in the categories array
      final categories = List<Map<String, dynamic>>.from(existingRecord['categories'] ?? []);
      
      // Find and update the specific category
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          categories[i]['totalQuestions'] = totalQuestions;
          categories[i]['correctAnswers'] = correctAnswers;
          categories[i]['score'] = score;
          categories[i]['isPassed'] = isPassed;
          categories[i]['isCompleted'] = true;
          categories[i]['lastQuestionAnswered'] = ''; // Could be populated with actual question ID
          if (totalPossibleMatches != null) {
            categories[i]['totalPossibleMatches'] = totalPossibleMatches;
          }
          categoryFound = true;
          break;
        }
      }

      // If category not found, add it to the categories array
      if (!categoryFound) {
        print('[AssessmentRepository] Category $categoryName not found, adding it to categories array');
        
        // Get assessment ObjectIds for the new category
        final assessmentObjectIds = await _getAssessmentObjectIds();
        
        // Create the new category object
        final newCategory = _createCategoryObject(
          categoryName: categoryName,
          assessmentObjectId: assessmentObjectIds[categoryName],
          isCompleted: true,
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          score: score,
          isPassed: isPassed,
          totalPossibleMatches: totalPossibleMatches,
        );
        
        categories.add(newCategory);
        print('[AssessmentRepository] Added $categoryName to categories array');
      }

      // Recalculate overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      final totalCategories = 5; // Always 5 standard CRLA categories
      // Calculate average score of completed categories only
      final completedScores = categories.where((cat) => cat['isCompleted'] == true).map((cat) => cat['score'] as double).toList();
      
      print('[AssessmentRepository] DEBUG: Overall score calculation:');
      print('[AssessmentRepository] - Completed categories: $completedCategories');
      print('[AssessmentRepository] - Total categories: $totalCategories');
      print('[AssessmentRepository] - Completed scores: $completedScores');
      
      final overallScore = completedScores.isNotEmpty ? 
        (completedScores.reduce((sum, score) => sum + score) / completedScores.length).round() : 0;
      final allCategoriesPassed = categories.length >= 5 &&
          categories.every((cat) => cat['isPassed'] == true);
      
      print('[AssessmentRepository] - Calculated overall score: $overallScore');

      // Update the document
      final updateDoc = {
        'assessmentDate': DateTime.now().toIso8601String(),
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'totalCategories': totalCategories,
        'allCategoriesPassed': allCategoriesPassed,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update reading level if provided
      print('[AssessmentRepository] newReadingLevel parameter: $newReadingLevel');
      print('[AssessmentRepository] newReadingLevel is null: ${newReadingLevel == null}');
      print('[AssessmentRepository] newReadingLevel is empty: ${newReadingLevel?.isEmpty ?? true}');
      
      if (newReadingLevel != null && newReadingLevel.isNotEmpty) {
        updateDoc['readingLevel'] = newReadingLevel;
        updateDoc['readingLevelUpdated'] = true;
        print('[AssessmentRepository] Updating reading level to: $newReadingLevel');
      } else {
        print('[AssessmentRepository] NOT updating reading level - newReadingLevel is null or empty');
      }

      print('[AssessmentRepository] Updating category_results - Score: $overallScore, Categories: $completedCategories/$totalCategories');

      final result = await categoryResultsCollection.updateOne(
        where.eq('studentId', studentIdValue).eq('readingLevel', readingLevel),
        updateDoc,
      );

      if (result.isSuccess) {
        print('[AssessmentRepository] Successfully updated category_results record');
        print('[AssessmentRepository] ===== END UPDATING CATEGORY RESULTS RECORD =====');
        return true;
      } else {
        print('[AssessmentRepository] Failed to update category_results record');
        return false;
      }
    } catch (e) {
      print('[AssessmentRepository] Error updating category_results record: $e');
      return false;
    }
  }

  /// Helper method to create a category object for the categories array
  Map<String, dynamic> _createCategoryObject({
    required String categoryName,
    required String? assessmentObjectId,
    required bool isCompleted,
    required int totalQuestions,
    required int correctAnswers,
    required double score,
    required bool isPassed,
    int? totalPossibleMatches,
  }) {
    return {
      'categoryName': categoryName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'totalPossibleMatches': totalPossibleMatches ?? 0,
      'correctMatches': 0,
      'score': score,
      'isPassed': isPassed,
      'passingThreshold': 75,
      'isCompleted': isCompleted,
      'lastQuestionAnswered': '',
      'interventionRequired': !isPassed,
      'interventionAttempts': 0,
      'interventionCompleted': false,
      'currentInterventionId': null,
      'interventionHistory': [],
      '_id': assessmentObjectId ?? ObjectId().toString(),
    };
  }

  /// Helper method to get assessment ObjectIds for each category
  Future<Map<String, String?>> _getAssessmentObjectIds() async {
    try {
      final mainAssessmentCollection = _dbService.getCollection(_collMainAssessment);
      
      final assessments = await mainAssessmentCollection.find({}).toList();
      final Map<String, String?> objectIds = {};
      
      for (final assessment in assessments) {
        final title = assessment['title'] as String? ?? '';
        final objectId = assessment['_id']?.toString();
        
        // Map assessment titles to category names
        if (title.contains('Alphabet Knowledge') || title.contains('Alphabet')) {
          objectIds['Alphabet Knowledge'] = objectId;
        } else if (title.contains('Phonological Awareness') || title.contains('Phonological')) {
          objectIds['Phonological Awareness'] = objectId;
        } else if (title.contains('Decoding')) {
          objectIds['Decoding'] = objectId;
        } else if (title.contains('Word Recognition') || title.contains('Word')) {
          objectIds['Word Recognition'] = objectId;
        } else if (title.contains('Reading Comprehension') || title.contains('Reading')) {
          objectIds['Reading Comprehension'] = objectId;
        }
      }
      
      print('[AssessmentRepository] Retrieved assessment ObjectIds: $objectIds');
      return objectIds;
    } catch (e) {
      print('[AssessmentRepository] Error getting assessment ObjectIds: $e');
      return {};
    }
  }
}
