// lib/features/assessments/repositories/assessment_repository.dart
import 'package:literexia/services/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';

class AssessmentRepository {
  /// Collection names
  static const String _collAssessments = 'assessments';
  static const String _collQuestionTypes = 'question_types';
  static const String _collResponses = 'user_responses';
  static const String _collUsers = 'users';

  /// Open database connection
  Future<Db> _openPreAssessmentDb() async {
    final baseUri = dotenv.env['MONGO_URI'];
    if (baseUri == null || baseUri.isEmpty) {
      throw Exception('MONGO_URI missing in .env');
    }

    final uriWithDb = baseUri.replaceFirstMapped(
      RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
      (m) => 'mongodb${m[1] ?? ''}://${m[2]}/Pre_Assessment',
    );

    final db = await Db.create(uriWithDb);
    await db.open();
    return db;
  }

  /// Create initial assessment in database
  Future<void> createAssessment() async {
    final db = await _openPreAssessmentDb();

    // Ensure collections exist
    final existing = (await db.getCollectionNames()).whereType<String>();

    for (final coll in [_collAssessments, _collQuestionTypes, _collResponses]) {
      if (!existing.contains(coll)) {
        await db.collection(coll).insertOne({'_init': true});
        await db.collection(coll).deleteMany({'_init': true});
      }
    }

    // Skip if already inserted
    final assessColl = db.collection(_collAssessments);
    if (await assessColl.findOne(where.eq('assessmentId', 1)) != null) {
      await db.close();
      return;
    }

    // Seed question types first
    await _createQuestionTypes(db);

    // Insert assessment document with updated scoring rules matching Reading Profile Stages
    await assessColl.insertOne({
      'assessmentId': 1,
      'title': 'Alphabet Knowledge Pre-Assessment',
      'description': 'Evaluates basic alphabet knowledge in Filipino',
      'totalQuestions': 5,
      'continueButtonText': 'MAG PATULOY',
      'language': 'FL',
      'type': 'pre_assessment',
      'status': 'active',
      'questions': [
        {
          'questionId': '1',
          'questionNumber': 1,
          'questionTypeId': 'phonological_awareness',
          'questionText': 'Bigkasin ang tunog ng salitang nakikita',
          'displayedText': 'ASO',
          'hasAudio': false,
          'options': [
            {
              'optionId': '1',
              'optionText': '/ah/ /es/ /oh/',
              'isCorrect': true,
            },
            {
              'optionId': '2',
              'optionText': '/oh/ /es/ /ah/',
              'isCorrect': false,
            },
          ],
        },
        {
          'questionId': '2',
          'questionNumber': 2,
          'questionTypeId': 'word_formation',
          'questionText': 'Tukuyin ang angkop na salita sa larawan',
          'displayedText': 'BO + LA',
          'hasImage': true,
          'imageUrl': 'assets/images/circle.png',
          'imageAlt': 'Circle shape',
          'options': [
            {'optionId': '1', 'optionText': 'BOLA', 'isCorrect': true},
            {'optionId': '2', 'optionText': 'LABO', 'isCorrect': false},
          ],
        },
        {
          'questionId': '3',
          'questionNumber': 3,
          'questionTypeId': 'reading_comprehension',
          'questionText': 'Tukuying ang angkop na sagot',
          'displayedText': 'Ano ang ginagawa ni Ana?',
          'options': [
            {'optionId': '1', 'optionText': 'naglalakad', 'isCorrect': true},
            {'optionId': '2', 'optionText': 'nagluluto', 'isCorrect': false},
          ],
        },
        {
          'questionId': '4',
          'questionNumber': 4,
          'questionTypeId': 'phoneme_identification',
          'questionText': 'Anong tunog ang unang letra ng salitang ito?',
          'hasAudio': true,
          'audioUrl': 'assets/audio/sample_word.mp3',
          'options': [
            {'optionId': '1', 'optionText': '/ah/', 'isCorrect': true},
            {'optionId': '2', 'optionText': '/eh/', 'isCorrect': false},
          ],
        },
        {
          'questionId': '5',
          'questionNumber': 5,
          'questionTypeId': 'letter_identification',
          'questionText': 'Anong tunog ng letra?',
          'displayedText': 'Aa',
          'options': [
            {'optionId': '1', 'optionText': '/ey/', 'isCorrect': true},
            {'optionId': '2', 'optionText': '/ey/', 'isCorrect': false},
          ],
        },
      ],
      'scoringRules': {
        'Low Emerging': {
          'minScore': 0,
          'maxScore': 0,
          'readingPercentage': [0, 16],
        },
        'High Emerging': {
          'minScore': 0,
          'maxScore': 0,
          'readingPercentage': [17, 30],
        },
        'Developing': {
          'minScore': 1,
          'maxScore': 1,
          'readingPercentage': [26, 50],
        },
        'Transitioning': {
          'minScore': 2,
          'maxScore': 3,
          'readingPercentage': [51, 75],
        },
        'At Grade Level': {
          'minScore': 4,
          'maxScore': 5,
          'readingPercentage': [76, 100],
        },
      },
    });

    await db.close();
  }

  /// Create question types in database
  Future<void> _createQuestionTypes(Db db) async {
    final coll = db.collection(_collQuestionTypes);
    if (await coll.count() > 0) return;

    await coll.insertMany([
      {
        'typeId': 'phonological_awareness',
        'typeName': 'Phonological Awareness',
      },
      {'typeId': 'word_formation', 'typeName': 'Word Formation'},
      {'typeId': 'reading_comprehension', 'typeName': 'Reading Comprehension'},
      {
        'typeId': 'phoneme_identification',
        'typeName': 'Phoneme Identification',
      },
      {'typeId': 'letter_identification', 'typeName': 'Letter Identification'},
    ]);
  }

  /// Get assessment by ID
  Future<Assessment?> getAssessment(dynamic id) async {
    final db = await _openPreAssessmentDb();
    print(
      '[AssessmentRepository] Getting assessment with ID: $id (type: ${id.runtimeType})',
    );

    // Support both string IDs ("Q1") and integer IDs (1)
    final doc = await db
        .collection(_collAssessments)
        .findOne(where.eq('assessmentId', id));

    if (doc == null && id is int) {
      // Try with string version if integer lookup failed
      final stringId = 'Q$id';
      print('[AssessmentRepository] Retrying with string ID: $stringId');
      final stringDoc = await db
          .collection(_collAssessments)
          .findOne(where.eq('assessmentId', stringId));

      await db.close();
      return stringDoc == null
          ? null
          : Assessment.fromMap(Map<String, dynamic>.from(stringDoc));
    }

    await db.close();

    if (doc != null) {
      print('[AssessmentRepository] Found assessment: ${doc['title']}');
    } else {
      print('[AssessmentRepository] Assessment not found');
    }

    return doc == null
        ? null
        : Assessment.fromMap(Map<String, dynamic>.from(doc));
  }

  /// Get all question types
  Future<List<QuestionType>> getQuestionTypes() async {
    final db = await _openPreAssessmentDb();
    final coll = db.collection(_collQuestionTypes);

    if (await coll.count() == 0) await _createQuestionTypes(db);

    final docs = await coll.find().toList();
    await db.close();

    return docs
        .map((e) => QuestionType.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Save user responses to database with reading percentage
  Future<bool> saveUserResponses({
    required dynamic assessmentId,
    required String userId,
    required Map<String, String> answers,
    required int score,
    String? readingLevel,
    double? readingPercentage,
  }) async {
    final db = await _openPreAssessmentDb();

    try {
      final res = await db.collection(_collResponses).insertOne({
        'assessmentId': assessmentId,
        'userId': userId,
        'answers': answers,
        'score': score,
        'readingLevel': readingLevel ?? 'undefined',
        'readingPercentage': readingPercentage ?? 0.0,
        'completedAt': DateTime.now().toIso8601String(),
      });

      await db.close();
      return res.isSuccess;
    } catch (e) {
      print('[AssessmentRepository] Error saving user responses: $e');
      await db.close();
      return false;
    }
  }

  /// Update user reading level in profile with reading percentage
  Future<bool> updateUserReadingLevel({
    required String userId,
    required String readingLevel,
    double? readingPercentage,
  }) async {
    return _retryOperation(() async {
      print(
        '[AssessmentRepository] Updating reading level for user $userId to $readingLevel',
      );

      // Connect to the Pre_Assessment database
      Db? db;
      try {
        // Use the existing _openPreAssessmentDb method
        db = await _openPreAssessmentDb();

        // Try with numeric ID first
        int? numericId;
        try {
          numericId = int.parse(userId);
        } catch (e) {
          // If not numeric, use as is
        }

        // Update user in the users collection
        final userQuery =
            numericId != null
                ? where.eq('idNumber', numericId)
                : where.eq('idNumber', userId);

        final userResult = await db
            .collection(_collUsers)
            .updateOne(
              userQuery,
              modify
                  .set('readingLevel', readingLevel)
                  .set('readingPercentage', readingPercentage ?? 0.0)
                  .set('lastAssessmentDate', DateTime.now().toIso8601String()),
            );

        // Also save to existing user_responses collection
        final responseResult = await db.collection(_collResponses).insertOne({
          'userId': userId,
          'readingLevel': readingLevel,
          'readingPercentage': readingPercentage ?? 0.0,
          'completedAt': DateTime.now().toIso8601String(),
        });

        print(
          '[AssessmentRepository] User update result: ${userResult.isSuccess}',
        );
        print(
          '[AssessmentRepository] Response save result: ${responseResult.isSuccess}',
        );

        await db.close();
        return userResult.isSuccess || responseResult.isSuccess;
      } catch (e) {
        print('[AssessmentRepository] Database operation error: $e');

        if (db != null) {
          try {
            await db.close();
          } catch (_) {}
        }

        return false;
      }
    });
  }

  Future<bool> _retryOperation(
    Future<bool> Function() operation, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        print(
          '[AssessmentRepository] Operation failed, attempt $attempts of $maxRetries: $e',
        );
        if (attempts >= maxRetries) {
          print('[AssessmentRepository] All retry attempts failed');
          return false; // Return false instead of rethrowing
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
    return false;
  }
}
