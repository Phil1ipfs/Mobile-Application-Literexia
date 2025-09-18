// lib/features/assessments/repositories/assessment_repository.dart
import 'package:literexia/features/intervention/repository/intervention_repository.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/assessment_model.dart';
import '../../../services/database_service.dart';
import 'package:literexia/features/intervention/logic/intervention_provider.dart';
import '../../../utils/reading_level_utils.dart';

class AssessmentRepository {
  /// Collection names - distinguish between pre-assessment and main assessment
  static const String _collMainAssessment = 'main_assessment'; // For lessons AFTER pre-assessment
  static const String _collPreAssessment = 'pre-assessment'; // For initial assessment
  static const String _collUsers = 'users';
  static const String _collStudentResponses = 'student_responses';
  static const String _collCategoryResults = 'category_results';
  final InterventionRepository _repository = InterventionRepository();

  /// Get database service instance
  DatabaseService get _dbService => DatabaseService();

  /// Get the main assessment collection from the "test" database
  Future<DbCollection> _getMainAssessmentCollection() async {
    try {
      // Get the MongoDB URI and modify it to point to "test" database
      final uri = dotenv.env['MONGO_URI'];
      if (uri == null || uri.isEmpty) {
        throw Exception('MONGO_URI not found in .env');
      }
      
      // Modify URI to point to "test" database
      final testUri = uri.replaceFirstMapped(
        RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
        (m) => 'mongodb${m[1] ?? ''}://${m[2]}/test',
      );
      
      print('[AssessmentRepository] Connecting to test database: ${_maskUri(testUri)}');
      final testDb = await Db.create(testUri);
      await testDb.open();
      
      print('[AssessmentRepository] Connected to test database: ${testDb.databaseName}');
      print('[AssessmentRepository] Available collections: ${await testDb.getCollectionNames()}');
      
      return testDb.collection(_collMainAssessment);
    } catch (e) {
      print('[AssessmentRepository] Error getting main assessment collection: $e');
      // Fallback to default collection access
      return _dbService.getCollection(_collMainAssessment);
    }
  }

  String _maskUri(String uri) {
    try {
      final parts = uri.split('@');
      if (parts.length > 1) {
        final creds = parts[0].split('://')[1];
        return uri.replaceFirst(creds, '***:***');
      }
      return uri.replaceAll(RegExp(r':[^@:]+@'), ':***@');
    } catch (_) {
      return '[unable to mask uri]';
    }
  }

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
        final preAssessmentCollection = preAssessmentDb.collection(_collPreAssessment);
        
        print('[AssessmentRepository] Searching for pre-assessment document in collection: $_collPreAssessment');
        
        // Look for pre-assessment document - try multiple query approaches
        var doc = await preAssessmentCollection.findOne(where.eq('type', 'pre_assessment'));
        print('[AssessmentRepository] Query 1 (type=pre_assessment): ${doc != null ? 'FOUND' : 'NOT FOUND'}');
        
        // If not found by type, try by assessmentId
        if (doc == null) {
          doc = await preAssessmentCollection.findOne(where.eq('assessmentId', '1'));
          print('[AssessmentRepository] Query 2 (assessmentId=1): ${doc != null ? 'FOUND' : 'NOT FOUND'}');
        }
        
        // If still not found, try getting any document
        if (doc == null) {
          doc = await preAssessmentCollection.findOne();
          print('[AssessmentRepository] Query 3 (any document): ${doc != null ? 'FOUND' : 'NOT FOUND'}');
        }
        
        // Let's also try to count all documents in the collection
        final count = await preAssessmentCollection.count();
        print('[AssessmentRepository] Total documents in collection: $count');
        
        if (doc != null) {
          print('[AssessmentRepository] SUCCESS: Found pre-assessment in Pre_Assessment database');
          print('[AssessmentRepository] Document ID: ${doc['_id']}');
          print('[AssessmentRepository] Assessment ID: ${doc['assessmentId']}');
          print('[AssessmentRepository] Type: ${doc['type']}');
          print('[AssessmentRepository] Questions count: ${doc['questions']?.length ?? 0}');
          return _convertPreAssessmentToModel(doc);
        } else {
          print('[AssessmentRepository] ERROR: No pre-assessment document found in any query');
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

  
/// Get MAIN ASSESSMENT with fallback mechanism for null reading level
Future<Assessment?> getMainAssessment(dynamic id, {String? readingLevel, String? category}) async {
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
    
    // Get the main assessment collection from the "test" database
    final assessmentCollection = await _getMainAssessmentCollection();
    Map<String, dynamic>? doc;
    
    // Debug: Check collection access
    print('[AssessmentRepository] Collection name: $_collMainAssessment');
    print('[AssessmentRepository] Collection reference: $assessmentCollection');
    
    // Debug: Count total documents in collection
    try {
      final totalCount = await assessmentCollection.count();
      print('[AssessmentRepository] Total documents in main_assessment collection: $totalCount');
      
      // Debug: List all categories in the collection
      final allDocs = await assessmentCollection.find().toList();
      final categories = allDocs.map((d) => d['category']?.toString()).toSet();
      print('[AssessmentRepository] Available categories in collection: $categories');
    } catch (e) {
      print('[AssessmentRepository] Error checking collection: $e');
    }
    
    // CRITICAL FIX: Only load ONE specific assessment document
    if (id != null && id is String && id.length == 24) {
      try {
        final objectId = ObjectId.fromHexString(id);
        doc = await assessmentCollection.findOne(where.eq('_id', objectId));
        
        if (doc != null) {
          print('[AssessmentRepository] Found specific assessment:');
          print('[AssessmentRepository]   - ID: ${doc['_id']}');
          print('[AssessmentRepository]   - Reading Level: ${doc['readingLevel']}');
          print('[AssessmentRepository]   - Category: ${doc['category']}');
          print('[AssessmentRepository]   - Questions: ${(doc['questions'] as List?)?.length ?? 0}');
          
          // Store the category from this specific assessment
          _currentAssessmentCategory = doc['category']?.toString();
        }
      } catch (e) {
        print('[AssessmentRepository] Error finding by ObjectId: $e');
      }
    }
    
    // FALLBACK: Search by category if specific ID failed
    if (doc == null && category != null) {
      print('[AssessmentRepository] Searching by category: $category');
      
      // Build query based on available criteria
      var query = where.eq('category', category);
      
      // Add reading level filter if provided
      if (readingLevel != null) {
        final normalizedLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
        query = query.and(where.eq('readingLevel', normalizedLevel));
        print('[AssessmentRepository] Also filtering by reading level: $normalizedLevel');
      }
      
      // Add active filter
      query = query.and(where.eq('isActive', true));
      
      print('[AssessmentRepository] Final query: category=$category, readingLevel=$readingLevel, isActive=true');
      
      final assessments = await assessmentCollection.find(query).take(1).toList();
      
      if (assessments.isNotEmpty) {
        doc = assessments.first;
        _currentAssessmentCategory = doc['category']?.toString();
        print('[AssessmentRepository] Found assessment by category: ${doc['_id']}');
        print('[AssessmentRepository] Document category: ${doc['category']}');
        print('[AssessmentRepository] Document reading level: ${doc['readingLevel']}');
      } else {
        print('[AssessmentRepository] No assessment found with category: $category');
        
        // Try without reading level filter if it was provided
        if (readingLevel != null) {
          print('[AssessmentRepository] Trying without reading level filter...');
          final simpleQuery = where
            .eq('category', category)
            .and(where.eq('isActive', true));
          
          final simpleAssessments = await assessmentCollection.find(simpleQuery).take(1).toList();
          
          if (simpleAssessments.isNotEmpty) {
            doc = simpleAssessments.first;
            _currentAssessmentCategory = doc['category']?.toString();
            print('[AssessmentRepository] Found assessment without reading level filter: ${doc['_id']}');
          }
        }
        
        // Final fallback: try without isActive filter
        if (doc == null) {
          print('[AssessmentRepository] Trying without isActive filter...');
          final fallbackQuery = where.eq('category', category);
          
          final fallbackAssessments = await assessmentCollection.find(fallbackQuery).take(1).toList();
          
          if (fallbackAssessments.isNotEmpty) {
            doc = fallbackAssessments.first;
            _currentAssessmentCategory = doc['category']?.toString();
            print('[AssessmentRepository] Found assessment without isActive filter: ${doc['_id']}');
          }
        }
      }
    }
    
    if (doc != null) {
      final assessment = _convertMainAssessmentToModel(doc);
      _assessment = assessment;
      
      print('[AssessmentRepository] LOADED SINGLE ASSESSMENT:');
      print('[AssessmentRepository]   - Category: $_currentAssessmentCategory');
      print('[AssessmentRepository]   - Questions: ${assessment.questions.length}');
      
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
    print('[AssessmentRepository] Creating hardcoded pre-assessment with reading comprehension');
    
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
            'pageText': 'Si Maria ay kumain ng mansanas. Siya ay nakaupo sa ilalim ng puno ng mansanas. Masarap ang mansanas.',
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
          AssessmentOption(optionId: '1', optionText: 'Mansanas', isCorrect: true),
          AssessmentOption(optionId: '2', optionText: 'Mangga', isCorrect: false),
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
          AssessmentOption(optionId: '1', optionText: '/ah/ /es/ /oh/', isCorrect: true),
          AssessmentOption(optionId: '2', optionText: '/oh/ /es/ /ah/', isCorrect: false),
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
      print('[AssessmentRepository] Processing ${questionsList.length} pre-assessment questions');
      
      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];
        
        final questionId = q['questionId'] ?? 'pre_q_${i + 1}';
        final questionType = q['questionType'] ?? q['questionTypeId'] ?? 'alphabet_knowledge';
        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? q['displayedText'] ?? '';
        final questionImage = q['questionImage'] ?? q['imageUrl'];
        
        print('[AssessmentRepository] Question $questionId details:');
        print('[AssessmentRepository]   - questionType: ${q['questionType']}');
        print('[AssessmentRepository]   - questionTypeId: ${q['questionTypeId']}');
        print('[AssessmentRepository]   - category: ${q['category']}');
        print('[AssessmentRepository]   - questionImage: ${q['questionImage']}');
        print('[AssessmentRepository]   - imageUrl: ${q['imageUrl']}');
        print('[AssessmentRepository]   - Final image URL: $questionImage');
        print('[AssessmentRepository]   - Is AWS S3 URL: ${questionImage?.toString().contains('s3.ap-southeast-2.amazonaws.com') == true}');
        
        // ENHANCED: Process passages and sentenceQuestions for pre-assessment
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null) {
          print('[AssessmentRepository] Pre-assessment question $questionId has passages data');
          
          if (q['passages'] is List) {
            passages = [];
            for (final passage in q['passages']) {
              if (passage is Map) {
                final passageMap = Map<String, dynamic>.from(passage);
                passages.add(passageMap);
              }
            }
            print('[AssessmentRepository] Processed ${passages.length} passages for pre-assessment question $questionId');
          } else if (q['passages'] is Map) {
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
            print('[AssessmentRepository] Processed single passage map for pre-assessment question $questionId');
          }
        }
        
        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null) {
          print('[AssessmentRepository] Pre-assessment question $questionId has sentenceQuestions data');
          
          if (q['sentenceQuestions'] is List) {
            sentenceQuestions = [];
            for (final sq in q['sentenceQuestions']) {
              if (sq is Map) {
                sentenceQuestions.add(Map<String, dynamic>.from(sq));
              }
            }
            print('[AssessmentRepository] Processed ${sentenceQuestions.length} sentenceQuestions for pre-assessment question $questionId');
          } else if (q['sentenceQuestions'] is Map) {
            sentenceQuestions = [Map<String, dynamic>.from(q['sentenceQuestions'] as Map)];
            print('[AssessmentRepository] Processed single sentenceQuestion map for pre-assessment question $questionId');
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
          print('[AssessmentRepository] Processed ${options.length} options for pre-assessment question $questionId');
        }
        
        // Handle questionSet data for phonological awareness
        Map<String, dynamic>? questionSet;
        if (q['questionSet'] != null) {
          questionSet = Map<String, dynamic>.from(q['questionSet']);
          print('[AssessmentRepository] Found questionSet for question $questionId: $questionSet');
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
          if (q['correctAnswer'] is List && (q['correctAnswer'] as List).isNotEmpty) {
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
    
    print('[AssessmentRepository] Converting main assessment document to model');
    print('[AssessmentRepository] Document ID: ${doc['_id']}');
    print('[AssessmentRepository] Reading Level: ${doc['readingLevel']}');
    print('[AssessmentRepository] Category: ${doc['category']}'); // IMPORTANT: Log the document category
    
    if (doc['questions'] != null && doc['questions'] is List) {
      final questionsList = doc['questions'] as List;
      print('[AssessmentRepository] Processing ${questionsList.length} questions');
      
      // Get the assessment category from the document
      final assessmentCategory = doc['category']?.toString() ?? 'Unknown';
      
      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];
        
        // FIXED: Create category-specific question IDs with proper formatting
        final questionType = q['questionType']?.toString().toLowerCase() ?? '';
        final categoryPrefix = _getCategoryPrefix(assessmentCategory, questionType);
        final questionId = '${categoryPrefix}_${(i + 1).toString().padLeft(3, '0')}'; // e.g., "AK_001", "PA_002", etc.
        
        final questionText = q['questionText'] ?? '';
        final questionValue = q['questionValue'] ?? '';
        final questionImage = q['questionImage'];
        
        print('[AssessmentRepository] Creating question $questionId for category: $assessmentCategory, type: $questionType');
        
        // Enhanced passages parsing with detailed logging
        List<Map<String, dynamic>>? passages;
        if (q['passages'] != null) {
          print('[AssessmentRepository] Question $questionId has passages data: ${q['passages'].runtimeType}');
          
          if (q['passages'] is List) {
            passages = [];
            for (final passage in q['passages']) {
              if (passage is Map) {
                final passageMap = Map<String, dynamic>.from(passage);
                passages.add(passageMap);
                print('[AssessmentRepository] Added passage with length: ${passageMap['pageText']?.toString().length ?? 0}');
              }
            }
            print('[AssessmentRepository] Processed ${passages.length} passages for question $questionId');
          } else if (q['passages'] is Map) {
            passages = [Map<String, dynamic>.from(q['passages'] as Map)];
            print('[AssessmentRepository] Processed single passage map for question $questionId');
          }
        }
        
        // Enhanced sentence questions parsing
        List<Map<String, dynamic>>? sentenceQuestions;
        if (q['sentenceQuestions'] != null) {
          print('[AssessmentRepository] Question $questionId has sentenceQuestions data: ${q['sentenceQuestions'].runtimeType}');
          
          if (q['sentenceQuestions'] is List) {
            sentenceQuestions = [];
            for (final sq in q['sentenceQuestions']) {
              if (sq is Map) {
                final sqMap = Map<String, dynamic>.from(sq);
                sentenceQuestions.add(sqMap);
                print('[AssessmentRepository] Added sentenceQuestion: ${sqMap['questionText'] ?? 'No question text'}');
              }
            }
            print('[AssessmentRepository] Processed ${sentenceQuestions.length} sentenceQuestions for question $questionId');
          } else if (q['sentenceQuestions'] is Map) {
            sentenceQuestions = [Map<String, dynamic>.from(q['sentenceQuestions'] as Map)];
            print('[AssessmentRepository] Processed single sentenceQuestion map for question $questionId');
          }
        }
        
        // Handle questionSet for Phonological Awareness questions
        Map<String, dynamic>? questionSet;
        if (assessmentCategory == 'Phonological Awareness' && q['questionSet'] != null) {
          print('[AssessmentRepository] Question $questionId has questionSet data: ${q['questionSet'].runtimeType}');
          
          if (q['questionSet'] is List && (q['questionSet'] as List).isNotEmpty) {
            final questionSetList = q['questionSet'] as List;
            if (questionSetList.first is Map) {
              questionSet = Map<String, dynamic>.from(questionSetList.first as Map);
              print('[AssessmentRepository] Processed questionSet for question $questionId: $questionSet');
            }
          } else if (q['questionSet'] is Map) {
            questionSet = Map<String, dynamic>.from(q['questionSet'] as Map);
            print('[AssessmentRepository] Processed single questionSet map for question $questionId');
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
          print('[AssessmentRepository] Processed ${options.length} options for question $questionId');
        }
        
        // Create reading comprehension options if needed
        if (options.isEmpty && sentenceQuestions != null && sentenceQuestions.isNotEmpty) {
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
            print('[AssessmentRepository] Created options from sentenceQuestion for question $questionId');
          }
        }
        
        // FIXED: Use proper question type ID that matches the assessment category
        final standardizedQuestionTypeId = _getStandardizedQuestionTypeId(assessmentCategory, questionType);
        

        // Parse decoding-specific fields when present (same as pre-assessment)
        List<String>? displaySequence;
        if (q['displaySequence'] != null && q['displaySequence'] is List) {
          displaySequence = (q['displaySequence'] as List).cast<String>();
          print('[AssessmentRepository] Found displaySequence for main assessment question $questionId: $displaySequence');
        }
        List<String>? dragElements;
        if (q['dragElements'] != null && q['dragElements'] is List) {
          dragElements = (q['dragElements'] as List).cast<String>();
          print('[AssessmentRepository] Found dragElements for main assessment question $questionId: $dragElements');
        }
        List<String>? correctSequence;
        if (q['correctSequence'] != null && q['correctSequence'] is List) {
          correctSequence = (q['correctSequence'] as List).cast<String>();
          print('[AssessmentRepository] Found correctSequence for main assessment question $questionId: $correctSequence');
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
          if (q['correctAnswer'] is List && (q['correctAnswer'] as List).isNotEmpty) {
            correctAnswer = (q['correctAnswer'] as List).first.toString();
          } else {
            correctAnswer = q['correctAnswer'].toString();
          }
        }

        questions.add(Question(
          questionId: questionId, // Now category-specific
          questionNumber: i + 1,
          questionTypeId: standardizedQuestionTypeId, // Standardized category mapping
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
      assessmentId: doc['_id'].toString(),
      title: 'Assessment: ${doc['category'] ?? 'Unknown Category'}',
      description: 'Assessment for ${doc['readingLevel'] ?? 'Unknown Level'} reading level',
      totalQuestions: questions.length,
      continueButtonText: 'MAG PATULOY',
      language: 'FL',
      type: 'main_assessment',
      status: doc['isActive'] == true ? 'active' : 'inactive',
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
  String _getStandardizedQuestionTypeId(String assessmentCategory, String questionType) {
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
    print('[AssessmentRepository] Saving user responses to student_responses collection');
    
    // CRITICAL FIX: Convert userId to integer
    dynamic studentIdValue;
    try {
      studentIdValue = int.parse(userId);
      print('[AssessmentRepository] Converted userId to integer: $studentIdValue');
    } catch (e) {
      print('[AssessmentRepository] WARNING: Could not convert userId to integer: $e');
      studentIdValue = userId;
    }
    
    // Use integer from additionalData if available
    if (additionalData != null && additionalData['studentIdInteger'] != null) {
      studentIdValue = additionalData['studentIdInteger'];
      print('[AssessmentRepository] Using studentIdInteger from additionalData: $studentIdValue');
    }
    
    print('[AssessmentRepository] Final studentId: $studentIdValue (${studentIdValue.runtimeType})');
    print('[AssessmentRepository] Assessment ID: $assessmentId');
    print('[AssessmentRepository] Total answers: ${answers.length}');
    
    if (!_dbService.isInitialized) {
      await _dbService.initialize();
    }

    // Extract category information
    Map<String, String>? questionCategories;
    if (additionalData != null && additionalData['questionCategories'] != null) {
      questionCategories = Map<String, String>.from(additionalData['questionCategories']);
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

      final isCorrect = _isAnswerCorrect(questionId, selectedOption, additionalData);

      // Determine category
      String category;
      if (questionCategories != null && questionCategories.containsKey(questionId)) {
        category = questionCategories[questionId]!;
      } else if (_currentAssessmentCategory != null && _currentAssessmentCategory!.isNotEmpty) {
        category = _currentAssessmentCategory!;
      } else {
        category = _getCategoryFromQuestionId(questionId, defaultCategory: 'Unknown Category');
      }

      category = _normalizeCategory(category);

      print('[AssessmentRepository] Saving response for question $questionId:');
      print('[AssessmentRepository]   - Category: $category');
      print('[AssessmentRepository]   - Student ID: $studentIdValue (${studentIdValue.runtimeType})');

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

    print('[AssessmentRepository] Successfully saved ${answers.length} student responses with integer studentId');
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
  bool _isAnswerCorrect(String questionId, String selectedOption, Map<String, dynamic>? additionalData) {
    if (additionalData != null && additionalData['correctAnswers'] != null) {
      final correctAnswers = additionalData['correctAnswers'] as Map<String, dynamic>;
      final correctOption = correctAnswers[questionId];
      final isCorrect = correctOption == selectedOption;
      
      print('[AssessmentRepository] Answer check for $questionId:');
      print('[AssessmentRepository]   - Selected: $selectedOption');
      print('[AssessmentRepository]   - Correct: $correctOption');
      print('[AssessmentRepository]   - Is Correct: $isCorrect');
      
      return isCorrect;
    }
    
    print('[AssessmentRepository] No correct answers data available for $questionId');
    return false;
  }

  /// ENHANCED: Updated method with better category tracking
  String _getCategoryFromQuestionId(String questionId, {String defaultCategory = 'Unknown Category'}) {
    try {
      print('[AssessmentRepository] Determining category for question ID: $questionId');
      
      // Enhanced pattern-based detection
      if (questionId.startsWith('AK_') || questionId.startsWith('PRE_AK') || questionId.contains('alphabet')) {
        return 'Alphabet Knowledge';
      }
      if (questionId.startsWith('PA_') || questionId.startsWith('PRE_PA') || questionId.contains('phono')) {
        return 'Phonological Awareness';
      }
      if (questionId.startsWith('DC_') || questionId.startsWith('PRE_DC') || questionId.contains('decod')) {
        return 'Decoding';
      }
      if (questionId.startsWith('WR_') || questionId.startsWith('PRE_WR') || questionId.contains('word')) {
        return 'Word Recognition';
      }
      if (questionId.startsWith('RC_') || questionId.startsWith('PRE_RC') || questionId.contains('reading') || questionId.contains('comprehension')) {
        return 'Reading Comprehension';
      }

      // Use current assessment category if available and question ID doesn't have clear category info
      if (_currentAssessmentCategory != null && _currentAssessmentCategory!.isNotEmpty) {
        print('[AssessmentRepository] Using current assessment category: $_currentAssessmentCategory');
        return _currentAssessmentCategory!;
      }

      // Fallback for generic question IDs
      if (questionId.contains('main_q_')) {
        print('[AssessmentRepository] WARNING: Generic question ID detected: $questionId, using default category: $defaultCategory');
        return defaultCategory;
      }

      // Final fallback
      print('[AssessmentRepository] No category pattern matched for $questionId, using default: $defaultCategory');
      return defaultCategory;
    } catch (e) {
      print('[AssessmentRepository] Error determining category from question ID: $e');
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
          .set('updatedAt', DateTime.now().toIso8601String())
      );
      
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
    List<Map<String, dynamic>> assessments, 
    String targetReadingLevel
  ) {
    final List<Map<String, dynamic>> lessons = [];
    
    for (int i = 0; i < assessments.length; i++) {
      final assessment = assessments[i];
      
      // Verify the assessment is for the correct reading level
      final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
      if (ReadingLevelUtils.normalizeReadingLevel(assessmentLevel) != targetReadingLevel) {
        print('[AssessmentRepository] Skipping assessment with incorrect reading level: $assessmentLevel');
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
    
    print('[AssessmentRepository] Converted ${lessons.length} assessments to lessons for level: $targetReadingLevel');
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

  /// Fetch the latest pre-assessment result for a user from Pre_Assessment.user_responses
  Future<Map<String, dynamic>?> fetchLatestPreAssessmentResult(String userId) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }
      final preAssessmentDb = await dbService.getPreAssessmentDatabase();
      final userResponsesCollection = preAssessmentDb.collection('user_responses');
      // Find the latest by completedAt (descending)
      final result = await userResponsesCollection.find(where.eq('userId', userId).sortBy('completedAt', descending: true)).toList();
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('[AssessmentRepository] Error fetching pre-assessment result: $e');
      return null;
    }
  }

  /// Load Reading Comprehension assessment from main_assessment collection
  Future<Assessment?> getReadingComprehensionAssessment({String? readingLevel}) async {
    try {
      print('[AssessmentRepository] ===== LOADING READING COMPREHENSION FROM MAIN_ASSESSMENT =====');
      print('[AssessmentRepository] Target reading level: $readingLevel');
      
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }
      
      // Get the main assessment collection from the "test" database
      final assessmentCollection = await _getMainAssessmentCollection();
      
      // Build query for Reading Comprehension assessments
      var query = where.eq('category', 'Reading Comprehension');
      
      // Add reading level filter if provided
      if (readingLevel != null) {
        final normalizedLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
        query = query.and(where.eq('readingLevel', normalizedLevel));
        print('[AssessmentRepository] Filtering by reading level: $normalizedLevel');
      }
      
      // Add active filter
      query = query.and(where.eq('isActive', true));
      
      print('[AssessmentRepository] Querying main_assessment collection for Reading Comprehension');
      final assessments = await assessmentCollection.find(query).toList();
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Reading Comprehension assessments found');
        
        // Try without reading level filter as fallback
        if (readingLevel != null) {
          print('[AssessmentRepository] Trying without reading level filter...');
          final fallbackQuery = where
            .eq('category', 'Reading Comprehension')
            .and(where.eq('isActive', true));
          
          final fallbackAssessments = await assessmentCollection.find(fallbackQuery).toList();
          
          if (fallbackAssessments.isNotEmpty) {
            print('[AssessmentRepository] Found ${fallbackAssessments.length} Reading Comprehension assessments without reading level filter');
            final assessment = _convertMainAssessmentToModel(fallbackAssessments.first);
            return assessment;
          }
        }
        
        return null;
      }
      
      // Use the first matching assessment
      final doc = assessments.first;
      print('[AssessmentRepository] Found Reading Comprehension assessment:');
      print('[AssessmentRepository]   - ID: ${doc['_id']}');
      print('[AssessmentRepository]   - Reading Level: ${doc['readingLevel']}');
      print('[AssessmentRepository]   - Questions: ${(doc['questions'] as List?)?.length ?? 0}');
      print('[AssessmentRepository]   - Passages: ${(doc['passages'] as List?)?.length ?? 0}');
      
      final assessment = _convertMainAssessmentToModel(doc);
      
      print('[AssessmentRepository] Successfully loaded Reading Comprehension assessment with ${assessment.questions.length} questions');
      return assessment;
      
    } catch (e) {
      print('[AssessmentRepository] Error loading Reading Comprehension assessment: $e');
      return null;
    }
  }

  /// Load specific Reading Comprehension question by ID from main_assessment collection
  Future<Question?> getReadingComprehensionQuestion(String questionId, {String? readingLevel}) async {
    try {
      print('[AssessmentRepository] ===== LOADING RC QUESTION $questionId =====');
      
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }
      
      // Get the main assessment collection from the "test" database
      final assessmentCollection = await _getMainAssessmentCollection();
      
      // Build query for Reading Comprehension assessments
      var query = where.eq('category', 'Reading Comprehension');
      
      // Add reading level filter if provided
      if (readingLevel != null) {
        final normalizedLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
        query = query.and(where.eq('readingLevel', normalizedLevel));
      }
      
      // Add active filter
      query = query.and(where.eq('isActive', true));
      
      final assessments = await assessmentCollection.find(query).toList();
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Reading Comprehension assessments found');
        return null;
      }
      
      // Search through all assessments for the specific question
      for (final doc in assessments) {
        if (doc['questions'] != null && doc['questions'] is List) {
          final questionsList = doc['questions'] as List;
          
          for (final q in questionsList) {
            if (q['questionId'] == questionId) {
              print('[AssessmentRepository] Found question $questionId in assessment ${doc['_id']}');
              
              // Convert the question data to Question model
              final question = _convertQuestionFromMainAssessment(q, doc['category']?.toString() ?? 'Reading Comprehension');
              return question;
            }
          }
        }
      }
      
      print('[AssessmentRepository] Question $questionId not found in any Reading Comprehension assessment');
      return null;
      
    } catch (e) {
      print('[AssessmentRepository] Error loading Reading Comprehension question: $e');
      return null;
    }
  }

  /// Get Phonological Awareness Assessment from main_assessment collection
  Future<Assessment?> getPhonologicalAwarenessAssessment({String? readingLevel}) async {
    try {
      print('[AssessmentRepository] ===== LOADING PHONOLOGICAL AWARENESS FROM MAIN_ASSESSMENT =====');
      print('[AssessmentRepository] Target reading level: $readingLevel');
      
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }
      
      // Get the main assessment collection from the "test" database
      final collection = await _getMainAssessmentCollection();
      
      // Build query for Phonological Awareness assessments
      var query = where.eq('category', 'Phonological Awareness');
      
      // Add reading level filter if provided
      if (readingLevel != null) {
        final normalizedLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
        query = query.and(where.eq('readingLevel', normalizedLevel));
        print('[AssessmentRepository] Filtering by reading level: $normalizedLevel');
      }
      
      // Add active filter
      query = query.and(where.eq('isActive', true));
      
      print('[AssessmentRepository] Querying main_assessment collection for Phonological Awareness');
      
      // Find assessments matching the criteria
      final assessments = await collection.find(query).toList();
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Phonological Awareness assessment found, trying without reading level filter');
        // Try without reading level filter
        query = where.eq('category', 'Phonological Awareness').and(where.eq('isActive', true));
        final fallbackAssessments = await collection.find(query).toList();
        if (fallbackAssessments.isNotEmpty) {
          assessments.addAll(fallbackAssessments);
        }
      }
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Phonological Awareness assessment found in main_assessment collection');
        return null;
      }
      
      // Use the first matching assessment
      final doc = assessments.first;
      print('[AssessmentRepository] Found Phonological Awareness assessment:');
      print('[AssessmentRepository]   - ID: ${doc['_id']}');
      print('[AssessmentRepository]   - Reading Level: ${doc['readingLevel']}');
      print('[AssessmentRepository]   - Questions: ${(doc['questions'] as List?)?.length ?? 0}');
      
      final assessment = _convertMainAssessmentToModel(doc);
      
      print('[AssessmentRepository] Successfully loaded Phonological Awareness assessment with ${assessment.questions.length} questions');
      return assessment;
      
    } catch (e) {
      print('[AssessmentRepository] Error loading Phonological Awareness assessment: $e');
      return null;
    }
  }

  /// Get specific Phonological Awareness question from main_assessment collection
  Future<Question?> getPhonologicalAwarenessQuestion(String questionId, {String? readingLevel}) async {
    try {
      print('[AssessmentRepository] ===== LOADING PA QUESTION $questionId =====');
      print('[AssessmentRepository] Target reading level: $readingLevel');
      
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        throw Exception('Database not connected');
      }
      
      // Get the main assessment collection from the "test" database
      final collection = await _getMainAssessmentCollection();
      
      // Build query for Phonological Awareness assessments
      var query = where.eq('category', 'Phonological Awareness');
      
      // Add reading level filter if provided
      if (readingLevel != null) {
        final normalizedLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
        query = query.and(where.eq('readingLevel', normalizedLevel));
        print('[AssessmentRepository] Filtering by reading level: $normalizedLevel');
      }
      
      // Add active filter
      query = query.and(where.eq('isActive', true));
      
      print('[AssessmentRepository] Querying main_assessment collection for Phonological Awareness question: $questionId');
      
      // Find assessments matching the criteria
      final assessments = await collection.find(query).toList();
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Phonological Awareness assessment found, trying without reading level filter');
        // Try without reading level filter
        query = where.eq('category', 'Phonological Awareness').and(where.eq('isActive', true));
        final fallbackAssessments = await collection.find(query).toList();
        if (fallbackAssessments.isNotEmpty) {
          assessments.addAll(fallbackAssessments);
        }
      }
      
      if (assessments.isEmpty) {
        print('[AssessmentRepository] No Phonological Awareness assessment found');
        return null;
      }
      
      // Search through questions in all matching assessments
      for (final doc in assessments) {
        final questions = doc['questions'] as List?;
        if (questions != null) {
          for (final q in questions) {
            if (q is Map && q['questionId'] == questionId) {
              print('[AssessmentRepository] Found question $questionId in document ${doc['_id']}');
              return _convertPhonologicalAwarenessQuestion(Map<String, dynamic>.from(q), 'Phonological Awareness');
            }
          }
        }
      }
      
      print('[AssessmentRepository] Question $questionId not found in Phonological Awareness assessments');
      return null;
      
    } catch (e) {
      print('[AssessmentRepository] Error loading Phonological Awareness question: $e');
      return null;
    }
  }

  /// Convert Phonological Awareness question data from main_assessment to Question model
  Question _convertPhonologicalAwarenessQuestion(Map<String, dynamic> q, String assessmentCategory) {
    print('[AssessmentRepository] Converting PA question from main_assessment: ${q['questionId']}');
    
    // Extract question ID
    final questionId = q['questionId']?.toString() ?? 'PA_001';
    
    // Extract question text
    final questionText = q['questionText']?.toString() ?? 'Pakinggan ang audio. Itugma ito sa katumbas na letra sa kabilang hanay.';
    
    // Extract questionSet data for Phonological Awareness
    Map<String, dynamic>? questionSet;
    if (q['questionSet'] != null && q['questionSet'] is List && (q['questionSet'] as List).isNotEmpty) {
      final questionSetList = q['questionSet'] as List;
      if (questionSetList.first is Map) {
        questionSet = Map<String, dynamic>.from(questionSetList.first as Map);
        print('[AssessmentRepository] Processed questionSet for question $questionId: $questionSet');
      }
    }
    
    // Create options for phonological awareness (usually not used, but create empty list)
    List<AssessmentOption> options = [];
    
    return Question(
      questionId: questionId,
      questionNumber: 1,
      questionTypeId: 'phonological_awareness',
      questionText: questionText,
      displayedText: questionText,
      hasImage: false,
      hasAudio: false,
      options: options,
      questionType: 'matching',
      category: assessmentCategory,
      questionSet: questionSet,
    );
  }

  /// Convert question data from main_assessment to Question model
  Question _convertQuestionFromMainAssessment(Map<String, dynamic> q, String assessmentCategory) {
    print('[AssessmentRepository] Converting question from main_assessment: ${q['questionId']}');
    
    // Extract question ID
    final questionId = q['questionId']?.toString() ?? 'RC_001';
    
    // Extract question text
    final questionText = q['questionText']?.toString() ?? 'Basahin ang mga pahina at sagutin ang mga tanong.';
    
    // Extract passages
    List<Map<String, dynamic>>? passages;
    if (q['passages'] != null && q['passages'] is List) {
      passages = [];
      for (final passage in q['passages']) {
        if (passage is Map) {
          passages.add(Map<String, dynamic>.from(passage));
        }
      }
      print('[AssessmentRepository] Processed ${passages.length} passages for question $questionId');
    }
    
    // Extract sentence questions
    List<Map<String, dynamic>>? sentenceQuestions;
    if (q['sentenceQuestions'] != null && q['sentenceQuestions'] is List) {
      sentenceQuestions = [];
      for (final sq in q['sentenceQuestions']) {
        if (sq is Map) {
          sentenceQuestions.add(Map<String, dynamic>.from(sq));
        }
      }
      print('[AssessmentRepository] Processed ${sentenceQuestions.length} sentence questions for question $questionId');
    }
    
    // Create options for reading comprehension (usually not used, but create empty list)
    List<AssessmentOption> options = [];
    
    return Question(
      questionId: questionId,
      questionNumber: 1,
      questionTypeId: 'reading_comprehension',
      questionText: questionText,
      displayedText: questionText,
      hasImage: false,
      hasAudio: false,
      options: options,
      questionType: 'sentence',
      category: assessmentCategory,
      passages: passages,
      sentenceQuestions: sentenceQuestions,
    );
  }

  /// Get scoring rules from pre_assessment table
  Future<Map<String, dynamic>?> getScoringRulesFromPreAssessment() async {
    try {
      print('[AssessmentRepository] Fetching scoring rules from pre_assessment table');
      
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        print('[AssessmentRepository] Database not connected for scoring rules');
        return null;
      }
      
      // Get the pre-assessment database
      final preAssessmentDb = await _dbService.getPreAssessmentDatabase();
      final preAssessmentCollection = preAssessmentDb.collection(_collPreAssessment);
      
      // Look for a document that contains scoring rules
      final doc = await preAssessmentCollection.findOne(where.eq('type', 'pre_assessment'));
      
      if (doc != null && doc['scoringRules'] != null) {
        print('[AssessmentRepository] Found scoring rules in pre_assessment document');
        return Map<String, dynamic>.from(doc['scoringRules']);
      } else {
        print('[AssessmentRepository] No scoring rules found in pre_assessment table');
        return null;
      }
    } catch (e) {
      print('[AssessmentRepository] Error fetching scoring rules: $e');
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
      
      // Use the main_assessment collection
      final assessmentCollection = _dbService.getCollection(_collMainAssessment);
      
      // STEP 1: Try to find by exact ObjectId
      try {
        if (assessmentId.length == 24) {
          final objectId = ObjectId.fromHexString(assessmentId);
          final doc = await assessmentCollection.findOne(where.eq('_id', objectId));
          
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
      final partialQuery = where.match('_id', assessmentId).and(where.eq('isActive', true));
      final partialMatches = await assessmentCollection.find(partialQuery).toList();
      
      if (partialMatches.isNotEmpty) {
        print('Found ${partialMatches.length} assessments with partial ID match:');
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
      final allAssessments = await assessmentCollection.find(where.eq('isActive', true)).toList();
      
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
}