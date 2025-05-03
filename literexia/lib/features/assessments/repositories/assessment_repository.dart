// lib/features/assessments/repositories/assessment_repository.dart
//
// Repository layer dedicated to the Pre‑Assessment database.
// ─ Creates /Pre_Assessment database automatically if it doesn't exist.
// ─ Uses clean collection name: assessments
// ─ Does NOT interfere with the app‑wide DatabaseService connection.
//
// Requires:   mongo_dart       ^0.10.x
//             flutter_dotenv   ^5.0.x   (for MONGO_URI)
//             assessment_model.dart  +  question_type model

import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';

class AssessmentRepository {
  /// Collection names (NO dots).
  static const String _collAssessments   = 'assessments';
  static const String _collQuestionTypes = 'question_types';
  static const String _collResponses     = 'user_responses';

  /// ---------------- INTERNAL DB HANDLING ----------------

  Future<Db> _openPreAssessmentDb() async {
    // 1. Load base URI from .env
    final baseUri = dotenv.env['MONGO_URI'];
    if (baseUri == null || baseUri.isEmpty) {
      throw Exception('MONGO_URI missing in .env');
    }

    // 2. Replace (or add) the path with /Pre_Assessment
    //    Works for both SRV and standard URIs.
    final uriWithDb = baseUri.replaceFirstMapped(
      RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
      (m) => 'mongodb${m[1] ?? ''}://${m[2]}/Pre_Assessment',
    );

    final db = await Db.create(uriWithDb);
    await db.open();
    return db;
  }

  Future<List<String?>> _existingCollections(Db db) async =>
      db.getCollectionNames();

  /// ---------------- PUBLIC CRUD API ----------------

  Future<void> createAssessment() async {
  final db = await _openPreAssessmentDb();

  // Ensure collections exist
  final existing = (await _existingCollections(db)).whereType<String>();

  for (final coll in [
    _collAssessments,
    _collQuestionTypes,
    _collResponses,
  ]) {
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

  // Insert initial assessment doc with CORRECTED STRUCTURE
  await assessColl.insertOne({
    'assessmentId': 1,  // Changed from "Q1" to 1 to match your MongoDB document
    'title': 'Alphabet Knowledge Pre‑Assessment',
    'description': 'Evaluates basic alphabet knowledge in Filipino',
    'totalQuestions': 5,
    'continueButtonText': 'MAG PATULOY',
    'language': 'tl',
    'type': 'pre_assessment',
    'status': 'active',
    'questions': [
      {
        'questionId': 1,
        'questionText': 'Anong titik ang sinusundan ng "A" sa alpabeto?',
        'typeId': 'multiple_choice',  // This MUST match a valid typeId from _createQuestionTypes
        'options': [
          {'optionId': 'A', 'optionText': 'B', 'isCorrect': true},
          {'optionId': 'B', 'optionText': 'C', 'isCorrect': false},
          // Only 2 options as requested
        ],
        "correctOption": "A"
      },
      // Add more questions as needed
    ],
  });

  await db.close();
}

// 2. Make sure question types match exactly
Future<void> _createQuestionTypes(Db db) async {
  final coll = db.collection(_collQuestionTypes);
  if (await coll.count() > 0) return;

  await coll.insertMany([
    {'typeId': 'multiple_choice',      'typeName': 'Multiple Choice'},
    {'typeId': 'text_question',        'typeName': 'Text Question'},
    {'typeId': 'audio_image_question', 'typeName': 'Audio & Image Question'},
  ]);
}

// 3. Add a method to update existing assessment with 2 options
Future<bool> updateAssessmentOptions(int assessmentId) async {
  final db = await _openPreAssessmentDb();
  final assessColl = db.collection(_collAssessments);
  
  final result = await assessColl.updateOne(
    where.eq('assessmentId', assessmentId),
    modify.set('questions.0.options', [
      {'optionId': 'A', 'optionText': 'B', 'isCorrect': true},
      {'optionId': 'B', 'optionText': 'C', 'isCorrect': false},
    ])
  );
  
  await db.close();
  return result.isSuccess;
}

  Future<Assessment?> getAssessment(dynamic id) async {
    final db = await _openPreAssessmentDb();
    print('[AssessmentRepository] Getting assessment with ID: $id (type: ${id.runtimeType})');
    
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

  Future<List<QuestionType>> getQuestionTypes() async {
    final db   = await _openPreAssessmentDb();
    final coll = db.collection(_collQuestionTypes);

    if (await coll.count() == 0) await _createQuestionTypes(db);

    final docs = await coll.find().toList();
    await db.close();

    return docs
        .map((e) => QuestionType.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<bool> saveUserResponses({
    required int assessmentId,
    required String userId,
    required Map<String, String> answers,
    required int score,
  }) async {
    final db   = await _openPreAssessmentDb();
    final res  = await db.collection(_collResponses).insertOne({
      'assessmentId': assessmentId,
      'userId': userId,
      'answers': answers,
      'score': score,
      'completedAt': DateTime.now(),
    });
    await db.close();
    return res.isSuccess;
  }

  /// ---------------- helpers ----------------

  Future<void> _createAssessment(Db db) async {
    final coll = db.collection(_collQuestionTypes);
    if (await coll.count() > 0) return;

    await coll.insertMany([
      {'typeId': 'multiple_choice',     'typeName': 'Multiple Choice'},
      {'typeId': 'text_question',       'typeName': 'Text Question'},
      {'typeId': 'audio_image_question','typeName': 'Audio & Image Question'},
    ]);
  }
}
