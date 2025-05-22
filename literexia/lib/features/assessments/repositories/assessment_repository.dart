// lib/features/assessments/repositories/assessment_repository.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';

class AssessmentRepository {
  /// Collection names - corrected to match the actual collection names in MongoDB
  static const String _collAssessments = 'pre-assessment'; // Matches the collection name shown in Image 1
  static const String _collQuestionTypes = 'question.types'; // Matches dot notation in Image 2
  static const String _collResponses = 'user_responses'; // Matches collection name in Image 3

  /// Open database connection to Pre_Assessment database
  Future<Db> _openPreAssessmentDb() async {
    final baseUri = dotenv.env['MONGO_URI'];
    if (baseUri == null || baseUri.isEmpty) {
      throw Exception('MONGO_URI missing in .env');
    }

    final uriWithDb = baseUri.replaceFirstMapped(
      RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
      (m) => 'mongodb${m[1] ?? ''}://${m[2]}/Pre_Assessment',
    );

    print('[AssessmentRepository] Connecting to Pre_Assessment database');
    final db = await Db.create(uriWithDb);
    await db.open();
    return db;
  }

  /// Open test database connection (for users collection)
  Future<Db> _openTestDb() async {
    final baseUri = dotenv.env['MONGO_URI'];
    if (baseUri == null || baseUri.isEmpty) {
      throw Exception('MONGO_URI missing in .env');
    }

    final uriWithDb = baseUri.replaceFirstMapped(
      RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
      (m) => 'mongodb${m[1] ?? ''}://${m[2]}/test',
    );

    print('[AssessmentRepository] Connecting to test database');
    final db = await Db.create(uriWithDb);
    await db.open();
    return db;
  }
  
  /// Create initial assessment in database
  Future<void> createAssessment() async {
    final db = await _openPreAssessmentDb();

    // Ensure collections exist with the correct paths
    final existing = (await db.getCollectionNames()).whereType<String>();

    for (final coll in [_collAssessments, _collQuestionTypes, _collResponses]) {
      if (!existing.contains(coll)) {
        await db.collection(coll).insertOne({'_init': true});
        await db.collection(coll).deleteMany({'_init': true});
      }
    }

    // Skip if already inserted
    final assessColl = db.collection(_collAssessments);
    if (await assessColl.findOne(where.eq('assessmentId', 'FL-G1-001')) != null) {
      await db.close();
      return;
    }

    // Seed question types first
    await _createQuestionTypes(db);

    // Insert assessment document with updated scoring rules matching Reading Profile Stages
    await assessColl.insertOne({
      'assessmentId': 'FL-G1-001',
      'title': 'Filipino Reading Pre-Assessment - Grade 1',
      'description': 'Comprehensive assessment of Filipino reading skills based on DEPED CRLA standards',
      'instructions': 'This assessment evaluates reading skills in Filipino. Please answer all questions carefully.',
      'totalQuestions': 5,
      'continueButtonText': 'MAG PATULOY',
      'language': 'FL',
      'type': 'pre_assessment',
      'status': 'active',
      'questions': [
        {
          'questionId': 'AK_001',
          'questionNumber': 1,
          'questionTypeId': 'alphabet_knowledge',
          'questionText': 'Anong ang katumbas na maliit na letra?',
          'questionValue': 'A',
          'hasImage': true,
          'questionImage': 'assets/images/letters/A_big.png',
          'options': [
            {
              'optionId': '1',
              'optionText': 'a',
              'isCorrect': true
            },
            {
              'optionId': '2',
              'optionText': 'e',
              'isCorrect': false
            }
          ]
        },
        {
          'questionId': 'PA_002',
          'questionNumber': 2,
          'questionTypeId': 'phonological_awareness',
          'questionText': 'Bigkasin ang tunog ng salitang nakikita',
          'questionValue': 'ASO',
          'options': [
            {
              'optionId': '1',
              'optionText': '/ah/ /es/ /oh/',
              'isCorrect': true
            },
            {
              'optionId': '2',
              'optionText': '/oh/ /es/ /ah/',
              'isCorrect': false
            }
          ]
        },
        {
          'questionId': 'WR_002',
          'questionNumber': 3,
          'questionTypeId': 'word_recognition',
          'questionText': 'Pagsamahin ang pantig',
          'questionValue': 'BO + LA',
          'hasImage': true,
          'questionImage': 'assets/images/ball.png',
          'options': [
            {
              'optionId': '1',
              'optionText': 'BOLA',
              'isCorrect': true
            },
            {
              'optionId': '2',
              'optionText': 'LABO',
              'isCorrect': false
            }
          ]
        },
        {
          'questionId': 'RC_001',
          'questionNumber': 4,
          'questionTypeId': 'reading_comprehension',
          'questionText': 'Basahin ang kwento at sagutin ang tanong: Si Maria ay kumain ng mansanas. Ano ang kinain ni Maria?',
          'options': [
            {
              'optionId': '1',
              'optionText': 'Mansanas',
              'isCorrect': true
            },
            {
              'optionId': '2',
              'optionText': 'Mangga',
              'isCorrect': false
            }
          ]
        },
        {
          'questionId': 'DC_001',
          'questionNumber': 5,
          'questionTypeId': 'decoding',
          'questionText': 'Ano ang nasa larawan?',
          'hasImage': true,
          'questionImage': 'assets/images/dog.png',
          'options': [
            {
              'optionId': '1',
              'optionText': 'ASO',
              'isCorrect': true
            },
            {
              'optionId': '2',
              'optionText': 'OSO',
              'isCorrect': false
            }
          ]
        }
      ],
      'scoringRules': {
        'Low Emerging': {
          'minScore': 0,
          'maxScore': 0,
          'readingPercentage': [0, 16]
        },
        'High Emerging': {
          'minScore': 0,
          'maxScore': 0,
          'readingPercentage': [17, 30]
        },
        'Developing': {
          'minScore': 1,
          'maxScore': 1,
          'readingPercentage': [26, 50]
        },
        'Transitioning': {
          'minScore': 2,
          'maxScore': 3,
          'readingPercentage': [51, 75]
        },
        'At Grade Level': {
          'minScore': 4,
          'maxScore': 5,
          'readingPercentage': [76, 100]
        }
      }
    });

    await db.close();
  }

  /// Create question types in database
  Future<void> _createQuestionTypes(Db db) async {
    final coll = db.collection(_collQuestionTypes);
    if (await coll.count() > 0) return;

    await coll.insertMany([
      {'typeId': 'phonological_awareness', 'typeName': 'Phonological Awareness'},
      {'typeId': 'word_formation', 'typeName': 'Word Formation'},
      {'typeId': 'reading_comprehension', 'typeName': 'Reading Comprehension'},
      {'typeId': 'phoneme_identification', 'typeName': 'Phoneme Identification'},
      {'typeId': 'letter_identification', 'typeName': 'Letter Identification'},
      {'typeId': 'alphabet_knowledge', 'typeName': 'Alphabet Knowledge'},
      {'typeId': 'decoding', 'typeName': 'Decoding'},
      {'typeId': 'word_recognition', 'typeName': 'Word Recognition'},
    ]);
  }

  /// Get assessment by ID
  Future<Assessment?> getAssessment(dynamic id) async {
    final db = await _openPreAssessmentDb();
    print('[AssessmentRepository] Getting assessment with ID: $id (type: ${id.runtimeType})');
    
    // Use the correct collection name
    final assessColl = db.collection(_collAssessments);
    
    // Support both string IDs and integer IDs
    Map<String, dynamic>? doc;
    
    // 1. Try exact match on assessmentId
    doc = await assessColl.findOne(where.eq('assessmentId', id));
    
    // 2. If not found and id is int, try with formatted string
    if (doc == null && id is int) {
      final formattedId = 'FL-G1-00$id';
      print('[AssessmentRepository] Retrying with formatted ID: $formattedId');
      doc = await assessColl.findOne(where.eq('assessmentId', formattedId));
    }
    
    // 3. If still not found, try with ObjectId
    if (doc == null && id is String && id.length == 24) {
      try {
        final objectId = ObjectId.fromHexString(id);
        doc = await assessColl.findOne(where.eq('_id', objectId));
      } catch (e) {
        print('[AssessmentRepository] Not a valid ObjectId: $e');
      }
    }
    
    // 4. If still not found, try any active assessment
    if (doc == null) {
      doc = await assessColl.findOne(where.eq('status', 'active'));
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

  /// Save user responses to database with additional data
  Future<bool> saveUserResponses({
    required dynamic assessmentId,
    required String userId,
    required Map<String, String> answers,
    required int score,
    required String readingLevel,
    double? readingPercentage,
    Map<String, dynamic>? additionalData,
  }) async {
    final db = await _openPreAssessmentDb();
    
    try {
      // Prepare the response data
      Map<String, dynamic> responseData = {
        'assessmentId': assessmentId,
        'userId': userId,
        'answers': answers,
        'score': score,
        'readingLevel': readingLevel,
        'readingPercentage': readingPercentage ?? 0.0,
        'completedAt': DateTime.now().toIso8601String(),
      };
      
      // Add all additional data if provided
      if (additionalData != null) {
        responseData.addAll(additionalData);
      }
      
      // Insert into the collection
      final res = await db.collection(_collResponses).insertOne(responseData);
      
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
    bool preAssessmentCompleted = true,
  }) async {
    return _retryOperation(() async {
      print('[AssessmentRepository] Updating user profile for user $userId');
      print('[AssessmentRepository] - Reading level: $readingLevel');
      print('[AssessmentRepository] - Reading percentage: ${readingPercentage ?? 0.0}%');
      print('[AssessmentRepository] - Pre-assessment completed: $preAssessmentCompleted');
      
      Db? testDb;
      Db? preAssessmentDb;
      try {
        // Open the test database (for users collection)
        testDb = await _openTestDb();
        
        // Try with numeric ID first
        dynamic userIdValue;
        try {
          userIdValue = int.parse(userId);
          print('[AssessmentRepository] Using numeric ID: $userIdValue');
        } catch (e) {
          // If not numeric, use as is
          userIdValue = userId;
          print('[AssessmentRepository] Using string ID: $userIdValue');
        }
        
        // Update user in the test.users collection with explicit fields
        final userResult = await testDb.collection('users').updateOne(
          where.eq('idNumber', userIdValue),
          modify
            .set('readingLevel', readingLevel)
            .set('readingPercentage', readingPercentage?.toDouble() ?? 0.0)
            .set('preAssessmentCompleted', preAssessmentCompleted)
            .set('lastAssessmentDate', DateTime.now().toIso8601String())
        );
        
        // Check if the update actually affected any documents
        print('[AssessmentRepository] Update result:');
        print('[AssessmentRepository] - isSuccess: ${userResult.isSuccess}');
        print('[AssessmentRepository] - nMatched: ${userResult.nMatched}');
        print('[AssessmentRepository] - nModified: ${userResult.nModified}');
        
        if (userResult.nMatched == 0) {
          // If no document matched the query, try additional query formats
          print('[AssessmentRepository] No user found with idNumber: $userIdValue, trying additional queries');
          
          // Try with an exact string match
          final stringResult = await testDb.collection('users').updateOne(
            where.eq('idNumber', userId.toString()),
            modify
              .set('readingLevel', readingLevel)
              .set('readingPercentage', readingPercentage?.toDouble() ?? 0.0)
              .set('preAssessmentCompleted', preAssessmentCompleted)
              .set('lastAssessmentDate', DateTime.now().toIso8601String())
          );
          
          print('[AssessmentRepository] String ID attempt result: ${stringResult.isSuccess}, matched: ${stringResult.nMatched}');
          
          // If that still didn't work, try a broader query
          if (stringResult.nMatched == 0) {
            // Create a new document if none exists
            print('[AssessmentRepository] No existing user document found, inserting new one');
            await testDb.collection('users').insertOne({
              'idNumber': userIdValue,
              'readingLevel': readingLevel,
              'readingPercentage': readingPercentage?.toDouble() ?? 0.0,
              'preAssessmentCompleted': preAssessmentCompleted,
              'lastAssessmentDate': DateTime.now().toIso8601String(),
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
        }
        
        // Also save to user_responses collection in Pre_Assessment database
        preAssessmentDb = await _openPreAssessmentDb();
        final responseResult = await preAssessmentDb.collection(_collResponses).insertOne({
          'userId': userId,
          'readingLevel': readingLevel,
          'readingPercentage': readingPercentage?.toDouble() ?? 0.0,
          'preAssessmentCompleted': preAssessmentCompleted,
          'completedAt': DateTime.now().toIso8601String()
        });
        
        // Log the results for debugging
        print('[AssessmentRepository] User update result: ${userResult.isSuccess}');
        print('[AssessmentRepository] Response save result: ${responseResult.isSuccess}');
        
        // Close database connections
        if (testDb != null) await testDb.close();
        if (preAssessmentDb != null) await preAssessmentDb.close();
        
        return userResult.isSuccess || responseResult.isSuccess;
      } catch (e) {
        print('[AssessmentRepository] Database operation error: $e');
        
        if (testDb != null) {
          try { await testDb.close(); } catch (_) {}
        }
        if (preAssessmentDb != null) {
          try { await preAssessmentDb.close(); } catch (_) {}
        }
        
        return false;
      }
    }, maxRetries: 3);
  }
    
  Future<bool> _retryOperation(Future<bool> Function() operation, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        print('[AssessmentRepository] Operation failed, attempt $attempts of $maxRetries: $e');
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