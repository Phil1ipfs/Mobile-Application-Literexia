import 'package:literexia/services/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show where;

/// Helper class for managing category_results collection
class CategoryResultsHelper {
  /// Update existing category_results record with new category data
  /// This method should be used by subsequent categories (not Alphabet Knowledge)
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - categoryName: Name of the category
  /// - score: For Phonological Awareness = correctMatches, for others = correctAnswers
  /// - total: For Phonological Awareness = totalPossibleMatches, for others = totalQuestions
  /// - scorePercentage: For Phonological Awareness = ignored (calculated), for others = percentage
  /// - totalQuestions: For Phonological Awareness = number of questions, for others = same as total
  /// Durable entry point. Ensures the connection (with retry across a failover
  /// window), runs the write, and on failure queues it to the outbox for
  /// replay-on-reconnect — so a progression-gating result is never silently lost
  /// on an Atlas `No master connection`. The core write is a `$set` keyed by
  /// studentId+readingLevel, so replaying it is idempotent.
  static Future<void> updateCategoryResults(String userId, String categoryName, int score, int total, double scorePercentage, {int? totalQuestions}) async {
    final dbService = DatabaseService();
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    await dbService.ensureConnectionWithRetry();
    try {
      await _updateCategoryResultsCore(userId, categoryName, score, total, scorePercentage, totalQuestions: totalQuestions);
      // Connected — opportunistically drain anything queued during an earlier blip.
      await dbService.flushPendingCategoryWrites();
    } catch (e) {
      print('[CategoryResultsHelper] updateCategoryResults failed ($e) — queuing to durable outbox');
      await dbService.enqueueCategoryWrite('updateCategoryResults', {
        'userId': userId,
        'categoryName': categoryName,
        'score': score,
        'total': total,
        'scorePercentage': scorePercentage,
        'totalQuestions': totalQuestions,
      });
    }
  }

  static Future<void> _updateCategoryResultsCore(String userId, String categoryName, int score, int total, double scorePercentage, {int? totalQuestions}) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Get user data from test.users collection
      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));
      
      if (userData == null) {
        print('[CategoryResultsHelper] User not found in test.users collection');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';

      print('[CategoryResultsHelper] Updating category_results - StudentId: $studentId, Category: $categoryName, Score: $scorePercentage%');

      // Create category data matching the MongoDB Atlas image structure
      Map<String, dynamic> categoryData;
      
      if (categoryName == 'Phonological Awareness') {
        // Special handling for Phonological Awareness
        // Uses: totalPossibleMatches and correctMatches
        final totalPossibleMatches = total; // total parameter represents totalPossibleMatches
        final correctMatches = score; // score parameter represents correctMatches
        final actualTotalQuestions = totalQuestions ?? total; // Use provided totalQuestions or fallback to total
                final phonologicalScore = totalPossibleMatches > 0 ? (correctMatches / totalPossibleMatches) * 100.0 : 0.0;
        
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': actualTotalQuestions, // Actual number of questions
          'correctAnswers': 0, // Always 0 for Phonological Awareness
          'totalPossibleMatches': totalPossibleMatches,
          'correctMatches': correctMatches,
          'score': phonologicalScore,
          'isPassed': phonologicalScore >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': phonologicalScore < 75.0,
          'interventionAttempts': 0, // Always start at 0, only incremented when teacher creates intervention
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      } else if (categoryName == 'Reading Comprehension') {
        // Special handling for Reading Comprehension
        // TODO: Define the correct structure for Reading Comprehension
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': total,
          'correctAnswers': score,
          'totalPossibleMatches': 0,
          'correctMatches': 0,
          'score': scorePercentage,
          'isPassed': scorePercentage >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': scorePercentage < 75.0,
          'interventionAttempts': 0, // Always start at 0, only incremented when teacher creates intervention
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      } else {
        // Standard handling for Alphabet Knowledge, Decoding, Word Recognition
        // Uses: totalQuestions and correctAnswers
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': total,
          'correctAnswers': score,
          'totalPossibleMatches': 0,
          'correctMatches': 0,
          'score': scorePercentage,
          'isPassed': scorePercentage >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': scorePercentage < 75.0,
          'interventionAttempts': 0, // Always start at 0, only incremented when teacher creates intervention
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      }

      // Update existing category_results record for the CURRENT reading level
      // (records are per-level; keying on studentId alone can hit the wrong one).
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] ERROR: No existing category_results record found for student $studentId');
        print('[CategoryResultsHelper] This method should only be called for subsequent categories after Alphabet Knowledge');
        return;
      }

      // Update existing record - add/update the new category
      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);
      
      print('[CategoryResultsHelper] ===== BEFORE UPDATE =====');
      print('[CategoryResultsHelper] Current categories count: ${categories.length}');
      print('[CategoryResultsHelper] Current readingLevel: ${existingResult['readingLevel']}');
      print('[CategoryResultsHelper] Current completedCategories: ${existingResult['completedCategories']}');
      
      // Check if category already exists
      final existingCategoryIndex = categories.indexWhere(
        (cat) => cat['categoryName'] == categoryName
      );

      if (existingCategoryIndex >= 0) {
        // Update existing category - preserve attemptNumber if category still failed
        print('[CategoryResultsHelper] Updating existing category: $categoryName');
        final existingCategory = categories[existingCategoryIndex];
        final existingAttemptNumber = existingCategory['attemptNumber'] ?? 0;

        // IMPORTANT: Always preserve attemptNumber - it should never reset
        // attemptNumber only increments when intervention fails, never resets
        categoryData['attemptNumber'] = existingAttemptNumber; // Always preserve

        if (categoryData['isPassed'] == true) {
          print('[CategoryResultsHelper] Category $categoryName passed - preserving attemptNumber: $existingAttemptNumber');
        } else {
          print('[CategoryResultsHelper] Category $categoryName still failed - preserving attemptNumber: $existingAttemptNumber');
        }

        categories[existingCategoryIndex] = categoryData;
      } else {
        // Add new category
        print('[CategoryResultsHelper] Adding new category: $categoryName');
        categories.add(categoryData);
      }
      
      print('[CategoryResultsHelper] After update - categories count: ${categories.length}');
      print('[CategoryResultsHelper] ===== END BEFORE UPDATE =====');

      // Calculate updated overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      final allCategoriesPassed = categories.length >= 5 &&
          categories.every((cat) => cat['isPassed'] == true);
      
      // Calculate overall score safely
      double overallScore;
      if (categories.isNotEmpty) {
        print('[CategoryResultsHelper] Calculating overall score from ${categories.length} categories');
        final scores = categories.map((cat) => (cat['score'] as num).toDouble()).toList();
        print('[CategoryResultsHelper] Individual scores: $scores');
        final sum = scores.reduce((a, b) => a + b);
        print('[CategoryResultsHelper] Sum of scores: $sum');
        overallScore = sum / categories.length.toDouble();
        print('[CategoryResultsHelper] Calculated overall score: $overallScore');
      } else {
        overallScore = scorePercentage;
        print('[CategoryResultsHelper] Using scorePercentage as overall score: $overallScore');
      }

      final updatedResult = {
        'assessmentDate': DateTime.now().toIso8601String(),
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'totalCategories': 5,
        'allCategoriesPassed': allCategoriesPassed,
        'readingLevel': readingLevel,
        'readingLevelUpdated': false,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId).eq('readingLevel', readingLevel),
        {'\$set': updatedResult}
      );

      // Display the updated record details
      print('[CategoryResultsHelper] ===== UPDATED CATEGORY_RESULTS RECORD =====');
      print('[CategoryResultsHelper] StudentId: $studentId');
      print('[CategoryResultsHelper] ReadingLevel: $readingLevel');
      print('[CategoryResultsHelper] OverallScore: ${overallScore.toStringAsFixed(1)}%');
      print('[CategoryResultsHelper] CompletedCategories: $completedCategories/5');
      print('[CategoryResultsHelper] AllCategoriesPassed: $allCategoriesPassed');
      print('[CategoryResultsHelper] Updated Category: $categoryName');
      print('[CategoryResultsHelper] Category Details:');
      print('[CategoryResultsHelper]   - totalQuestions: ${categoryData['totalQuestions']}');
      print('[CategoryResultsHelper]   - correctAnswers: ${categoryData['correctAnswers']}');
      print('[CategoryResultsHelper]   - totalPossibleMatches: ${categoryData['totalPossibleMatches']}');
      print('[CategoryResultsHelper]   - correctMatches: ${categoryData['correctMatches']}');
      print('[CategoryResultsHelper]   - score: ${categoryData['score'].toStringAsFixed(1)}%');
      print('[CategoryResultsHelper]   - isPassed: ${categoryData['isPassed']}');
      print('[CategoryResultsHelper]   - interventionRequired: ${categoryData['interventionRequired']}');
      print('[CategoryResultsHelper] ===== END UPDATED RECORD =====');
      
      // Show final record summary
      print('[CategoryResultsHelper] ===== FINAL RECORD SUMMARY =====');
      print('[CategoryResultsHelper] StudentId: $studentId');
      print('[CategoryResultsHelper] ReadingLevel: $readingLevel (updated from test.users)');
      print('[CategoryResultsHelper] Categories Array: ${categories.length} items');
      for (int i = 0; i < categories.length; i++) {
        final cat = categories[i];
        print('[CategoryResultsHelper]   [$i] ${cat['categoryName']} - Score: ${cat['score'].toStringAsFixed(1)}% - Passed: ${cat['isPassed']}');
      }
      print('[CategoryResultsHelper] Overall Score: ${overallScore.toStringAsFixed(1)}%');
      print('[CategoryResultsHelper] Completed Categories: $completedCategories/5');
      print('[CategoryResultsHelper] All Categories Passed: $allCategoriesPassed');
      print('[CategoryResultsHelper] ===== END FINAL SUMMARY =====');
    } catch (e) {
      print('[CategoryResultsHelper] Error updating category_results: $e');
      rethrow;
    }
  }

  /// Handle when teacher creates new intervention - increment interventionAttempts and set currentInterventionId
  /// This is the ONLY place where interventionAttempts should be incremented
  static Future<void> handleNewInterventionCreated(String userId, String categoryName, String newInterventionId) async {
    try {
      print('[CategoryResultsHelper] Teacher created new intervention for $categoryName');
      print('[CategoryResultsHelper] New intervention ID: $newInterventionId');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when handling new intervention creation');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for new intervention creation');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and update the specific category
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          // Increment intervention attempts counter (this is the ONLY place it should be incremented)
          final currentAttempts = categories[i]['interventionAttempts'] ?? 0;
          categories[i]['interventionAttempts'] = currentAttempts + 1;
          
          // Set new currentInterventionId
          categories[i]['currentInterventionId'] = newInterventionId;
          
          // Set interventionCompleted to false (ready for new attempt)
          categories[i]['interventionCompleted'] = false;

          print('[CategoryResultsHelper] Updated category $categoryName (NEW INTERVENTION CREATED):');
          print('[CategoryResultsHelper] - interventionAttempts: $currentAttempts -> ${currentAttempts + 1}');
          print('[CategoryResultsHelper] - currentInterventionId: $newInterventionId');
          print('[CategoryResultsHelper] - interventionCompleted: false (ready for new attempt)');

          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for new intervention creation');
        return;
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId).eq('readingLevel', readingLevel),
        {'\$set': updatedResult}
      );

      print('[CategoryResultsHelper] Successfully handled new intervention creation for $categoryName');
    } catch (e) {
      print('[CategoryResultsHelper] Error handling new intervention creation: $e');
      rethrow;
    }
  }

  /// Increment interventionAttempts for a failed category after intervention failure
  /// This method is called when a student fails an intervention assessment
  static Future<void> incrementInterventionAttempts(String userId, String categoryName) async {
    try {
      print('[CategoryResultsHelper] Incrementing interventionAttempts for $categoryName, user: $userId');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when incrementing attemptNumber');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for interventionAttempts increment');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and increment the specific category's interventionAttempts
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          final currentInterventionAttempts = categories[i]['interventionAttempts'] ?? 0;
          categories[i]['interventionAttempts'] = currentInterventionAttempts + 1;

          print('[CategoryResultsHelper] Incremented interventionAttempts for $categoryName: $currentInterventionAttempts -> ${currentInterventionAttempts + 1}');
          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for interventionAttempts increment');
        return;
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId).eq('readingLevel', readingLevel),
        {'\$set': updatedResult}
      );

      print('[CategoryResultsHelper] Successfully incremented interventionAttempts for $categoryName');
    } catch (e) {
      print('[CategoryResultsHelper] Error incrementing interventionAttempts: $e');
      rethrow;
    }
  }

  /// Handle intervention failure - save currentInterventionId to history and set to null
  /// interventionAttempts is NOT incremented here - only when teacher creates new intervention
  static Future<void> handleInterventionFailure(String userId, String categoryName, [String? currentInterventionId]) async {
    try {
      print('[CategoryResultsHelper] Handling intervention FAILURE for $categoryName');
      print('[CategoryResultsHelper] Current intervention ID: $currentInterventionId');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when handling intervention failure');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for intervention failure');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and update the specific category
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          final resolvedInterventionId = currentInterventionId ?? categories[i]['currentInterventionId']?.toString() ?? 'unknown';
          // Save resolvedInterventionId to interventionHistory with correct format
          final interventionHistory = List<Map<String, dynamic>>.from(categories[i]['interventionHistory'] ?? []);
          interventionHistory.add({
            'interventionId': resolvedInterventionId,
            'isPassed': false,
            'failedAt': DateTime.now().toIso8601String(),
          });
          categories[i]['interventionHistory'] = interventionHistory;

          // Set currentInterventionId to null (until teacher creates new intervention)
          categories[i]['currentInterventionId'] = null;
          categories[i]['interventionCompleted'] = false;

          print('[CategoryResultsHelper] Updated category $categoryName (INTERVENTION FAILURE):');
          print('[CategoryResultsHelper] - currentInterventionId saved to history: $resolvedInterventionId');
          print('[CategoryResultsHelper] - currentInterventionId set to null');
          print('[CategoryResultsHelper] - interventionCompleted: false');
          print('[CategoryResultsHelper] - interventionAttempts NOT incremented (will be incremented when teacher creates new intervention)');

          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for intervention failure');
        return;
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId).eq('readingLevel', readingLevel),
        {'\$set': updatedResult}
      );

      print('[CategoryResultsHelper] Successfully handled intervention failure for $categoryName');
    } catch (e) {
      print('[CategoryResultsHelper] Error handling intervention failure: $e');
      rethrow;
    }
  }

  /// Handle successful intervention completion - sets interventionCompleted: true
  /// This method is called when a student passes an intervention assessment
  /// Durable entry point. Ensures the connection (with retry), runs the write,
  /// and on failure queues it for replay-on-reconnect. The core append into
  /// `interventionHistory` is guarded for idempotency, so a replayed/retried
  /// write can never double-append (no `{interventionId: null, ...}` junk).
  static Future<void> handleInterventionSuccess(String userId, String categoryName, double interventionScore) async {
    final dbService = DatabaseService();
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    await dbService.ensureConnectionWithRetry();
    try {
      await _handleInterventionSuccessCore(userId, categoryName, interventionScore);
      await dbService.flushPendingCategoryWrites();
    } catch (e) {
      print('[CategoryResultsHelper] handleInterventionSuccess failed ($e) — queuing to durable outbox');
      await dbService.enqueueCategoryWrite('handleInterventionSuccess', {
        'userId': userId,
        'categoryName': categoryName,
        'interventionScore': interventionScore,
      });
    }
  }

  static Future<void> _handleInterventionSuccessCore(String userId, String categoryName, double interventionScore) async {
    try {
      print('[CategoryResultsHelper] Handling intervention SUCCESS for $categoryName with score: ${interventionScore.toStringAsFixed(1)}%');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when handling intervention success');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for intervention success');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and update the specific category
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          // CRITICAL FIX: Only update intervention-specific fields
          // DO NOT modify main assessment results (score, correctAnswers, totalQuestions, isPassed)

          // IDEMPOTENCY GUARD (capture PRE-state before mutating): a success for
          // this category is recorded at most once per intervention cycle, so a
          // replayed/retried write can't append a duplicate {interventionId: null}
          // junk entry. Two independent checks (either is sufficient):
          //   key-based   — a passed entry already exists for THIS currentInterventionId
          //                 (covers a normal replay where the id is still present).
          //   state-based — already completed AND already has a passed entry
          //                 (covers the lost-ack case where the committed write
          //                  nulled currentInterventionId before failing).
          // A genuine new cycle (the web sets interventionCompleted=false and a new
          // currentInterventionId) matches neither, so it still appends correctly.
          final bool wasAlreadyCompleted = categories[i]['interventionCompleted'] == true;
          final interventionHistory = List<Map<String, dynamic>>.from(categories[i]['interventionHistory'] ?? []);
          final currentInterventionId = categories[i]['currentInterventionId'];

          final bool keyAlreadyRecorded = currentInterventionId != null &&
              interventionHistory.any((h) =>
                  h['isPassed'] == true &&
                  h['interventionId']?.toString() == currentInterventionId.toString());
          final bool stateAlreadyRecorded = wasAlreadyCompleted &&
              interventionHistory.any((h) => h['isPassed'] == true);
          final bool alreadyRecorded = keyAlreadyRecorded || stateAlreadyRecorded;

          categories[i]['interventionCompleted'] = true;
          categories[i]['interventionRequired'] = false;

          if (!alreadyRecorded) {
            interventionHistory.add({
              'interventionId': currentInterventionId,
              'isPassed': true,
              'score': interventionScore,
              'completedAt': DateTime.now().toIso8601String(),
            });
            categories[i]['interventionHistory'] = interventionHistory;
          } else {
            print('[CategoryResultsHelper] Intervention success already recorded for $categoryName — skipping duplicate history append (idempotent replay)');
          }

          // Set currentInterventionId to null (intervention completed)
          categories[i]['currentInterventionId'] = null;

          print('[CategoryResultsHelper] Updated category $categoryName (INTERVENTION SUCCESS):');
          print('[CategoryResultsHelper] - interventionCompleted: true');
          print('[CategoryResultsHelper] - interventionRequired: false');
          print('[CategoryResultsHelper] - currentInterventionId saved to history: $currentInterventionId');
          print('[CategoryResultsHelper] - currentInterventionId set to null');
          print('[CategoryResultsHelper] - interventionScore: ${interventionScore.toStringAsFixed(1)}% (saved to history)');
          print('[CategoryResultsHelper] - interventionAttempts NOT incremented (only incremented when teacher creates new intervention)');
          print('[CategoryResultsHelper] - PRESERVED main assessment: score=${categories[i]['score']}%, isPassed=${categories[i]['isPassed']}');

          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for intervention success');
        return;
      }

      // Recalculate overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      
      // A category is considered "passed" if either:
      // 1. Main assessment was passed (isPassed == true) OR
      // 2. Intervention was completed successfully (interventionCompleted == true)
      final allCategoriesPassed = categories.length >= 5 &&
          categories.every((cat) => 
            (cat['isPassed'] == true) || (cat['interventionCompleted'] == true)
          );

      // Calculate overall score based ONLY on main assessment scores
      // Intervention scores are tracked separately in interventionHistory
      double overallScore = 0.0;
      if (categories.isNotEmpty) {
        final mainAssessmentScores = categories
            .map((cat) => (cat['score'] as num).toDouble())
            .toList();
        final sum = mainAssessmentScores.reduce((a, b) => a + b);
        overallScore = sum / categories.length.toDouble();
        
        print('[CategoryResultsHelper] Overall score calculation:');
        print('[CategoryResultsHelper] - Based on main assessment scores only');
        print('[CategoryResultsHelper] - Scores: ${mainAssessmentScores.join(', ')}');
        print('[CategoryResultsHelper] - Average: ${overallScore.toStringAsFixed(1)}%');
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'allCategoriesPassed': allCategoriesPassed,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId).eq('readingLevel', readingLevel),
        {'\$set': updatedResult}
      );

      // CRITICAL FIX: Remove the failed record from failed_category_result collection
      // This prevents the old failed record from overriding the intervention success
      try {
        final failedCategoryResultCollection = dbService.getCollection('failed_category_result');
        
        // First, check if there are any failed records to delete
        final existingFailedRecords = await failedCategoryResultCollection.find(
          where.eq('studentId', studentId)
               .eq('readingLevel', readingLevel)
               .and(where.eq('categoryName', categoryName))
        ).toList();
        
        print('[CategoryResultsHelper] Found ${existingFailedRecords.length} failed record(s) to delete for $categoryName');
        
        if (existingFailedRecords.isNotEmpty) {
          final deleteResult = await failedCategoryResultCollection.deleteMany(
            where.eq('studentId', studentId)
                 .eq('readingLevel', readingLevel)
                 .and(where.eq('categoryName', categoryName))
          );
          
          if (deleteResult.writeConcernError == null) {
            print('[CategoryResultsHelper] ✅ Successfully removed failed record(s) from failed_category_result for $categoryName');
            print('[CategoryResultsHelper] This should prevent the red header from showing');
          } else {
            print('[CategoryResultsHelper] ❌ Failed to remove failed record(s) - writeConcernError: ${deleteResult.writeConcernError}');
          }
        } else {
          print('[CategoryResultsHelper] No failed records found to remove for $categoryName');
        }
      } catch (e) {
        print('[CategoryResultsHelper] ❌ Error removing failed record: $e');
        // Don't rethrow - this is not critical for intervention success
      }

      print('[CategoryResultsHelper] Successfully marked intervention as completed for $categoryName');
      print('[CategoryResultsHelper] Category is now PASSED and next category should be unlocked');
    } catch (e) {
      print('[CategoryResultsHelper] Error handling intervention success: $e');
      rethrow;
    }
  }

  /// Get interventionAttempts for a specific category
  /// Returns the current intervention attempts for intervention matching with revisionNumber
  static Future<int> getInterventionAttempts(String userId, String categoryName) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when getting interventionAttempts');
        return 0;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? '';
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(
          where.eq('studentId', studentId).eq('readingLevel', readingLevel));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for interventionAttempts lookup');
        return 0;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find the specific category's interventionAttempts
      for (final category in categories) {
        if (category['categoryName'] == categoryName) {
          final interventionAttempts = category['interventionAttempts'] ?? 0;
          print('[CategoryResultsHelper] Found interventionAttempts for $categoryName: $interventionAttempts');
          return interventionAttempts;
        }
      }

      print('[CategoryResultsHelper] Category $categoryName not found, returning interventionAttempts: 0');
      return 0;
    } catch (e) {
      print('[CategoryResultsHelper] Error getting interventionAttempts: $e');
      return 0;
    }
  }

  /// Replay an outboxed write via the CORE path. The core methods THROW on
  /// failure (instead of re-queuing), so a still-dead connection makes the
  /// outbox preserve the row rather than appending a duplicate. Both cores are
  /// idempotent, so a replay can safely re-run.
  static Future<void> replayQueuedWrite(String opType, Map<String, dynamic> payload) async {
    switch (opType) {
      case 'updateCategoryResults':
        await _updateCategoryResultsCore(
          payload['userId'] as String,
          payload['categoryName'] as String,
          (payload['score'] as num).toInt(),
          (payload['total'] as num).toInt(),
          (payload['scorePercentage'] as num).toDouble(),
          totalQuestions: payload['totalQuestions'] == null
              ? null
              : (payload['totalQuestions'] as num).toInt(),
        );
        break;
      case 'handleInterventionSuccess':
        await _handleInterventionSuccessCore(
          payload['userId'] as String,
          payload['categoryName'] as String,
          (payload['interventionScore'] as num).toDouble(),
        );
        break;
      default:
        print('[CategoryResultsHelper] Unknown outbox opType: $opType (dropping)');
    }
  }
}
