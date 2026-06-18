// lib/features/interventions/repositories/intervention_repository.dart
import 'package:mongo_dart/mongo_dart.dart';
import '../model/intervention_model.dart';
import '../../../services/database_service.dart';

class InterventionRepository {
  /// Collection names for intervention data
  static const String _collInterventionAssessment = 'intervention_assessment';
  static const String _collInterventionResults = 'intervention_results';
  static const String _collInterventionResponses = 'intervention_responses';
  static const String _collCategoryResults = 'category_results';
  static const String _collFailedCategoryResult = 'failed_category_result';

  /// Get database service instance
  DatabaseService get _dbService => DatabaseService();

  /// Helper method to normalize category names for comparison
  String _normalizeCategoryName(String categoryName) {
    return categoryName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '') // Remove non-letters
        .trim();
  }

  /// FIXED: Enhanced method to get detailed intervention status
  Future<Map<String, dynamic>> getDetailedInterventionStatus(
      String userId) async {
    try {
      print(
          '[InterventionRepository] Getting FIXED intervention status for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot get detailed status');
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
        };
      }

      // Get the most recent category results for this user
      final categoryResultCollection =
          _dbService.getCollection('category_results');

      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }

      final query = where
          .eq('studentId', userIdValue)
          .sortBy('createdAt', descending: true)
          .limit(1);

      final results = await categoryResultCollection.find(query).toList();
      if (results.isEmpty) {
        print(
            '[InterventionRepository] No category results found for user $userId');

        // ENHANCED: Check if this is because they completed lessons but not categories
        // For now, return empty but indicate no results found
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
          'noCategoryResults':
              true, // Flag to indicate missing category results
        };
      }

      final latestResult = results.first;
      final categories = latestResult['categories'] as List?;

      if (categories == null || categories.isEmpty) {
        print(
            '[InterventionRepository] No categories found in the latest result');
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
        };
      }

      print(
          '[InterventionRepository] Processing ${categories.length} categories');

      // ENHANCED: More flexible completion detection
      bool hasCompletedAllCategories = false;

      // Method 1: Check explicit completion flags
      if (latestResult['allCategoriesCompleted'] == true ||
          latestResult['isCompleted'] == true ||
          latestResult['status'] == 'completed') {
        hasCompletedAllCategories = true;
        print(
            '[InterventionRepository] Categories marked as completed via status flags');
      }

      // Method 2: Check if all categories have valid scores (not null/zero)
      if (!hasCompletedAllCategories && categories.isNotEmpty) {
        bool allHaveValidScores = true;
        int categoriesWithScores = 0;

        for (final category in categories) {
          if (category is Map) {
            final score = category['score'];
            if (score != null && score is num && score > 0) {
              categoriesWithScores++;
            } else {
              allHaveValidScores = false;
            }
          }
        }

        // Consider completed if we have scores for most categories
        hasCompletedAllCategories = allHaveValidScores ||
            categoriesWithScores >= (categories.length * 0.8).ceil();
        print(
            '[InterventionRepository] Categories with valid scores: $categoriesWithScores/${categories.length}');
      }

      // Method 3: ENHANCED - Check against standard reading categories
      if (!hasCompletedAllCategories) {
        const standardCategories = [
          'Alphabet Knowledge',
          'Phonological Awareness',
          'Decoding',
          'Word Recognition',
          'Reading Comprehension'
        ];

        Set<String> foundCategories = {};
        for (final category in categories) {
          if (category is Map) {
            final categoryName = category['categoryName']?.toString() ?? '';
            final score = category['score'];
            if (categoryName.isNotEmpty && score != null) {
              // Normalize category name for comparison
              final normalizedName = _normalizeCategoryName(categoryName);
              foundCategories.add(normalizedName);
            }
          }
        }

        // Check if we have all standard categories
        int matchedStandardCategories = 0;
        for (final standardCategory in standardCategories) {
          final normalizedStandard = _normalizeCategoryName(standardCategory);
          if (foundCategories.contains(normalizedStandard)) {
            matchedStandardCategories++;
          }
        }

        // Consider completed if we have most of the standard categories
        hasCompletedAllCategories =
            matchedStandardCategories >= 4; // At least 4 out of 5
        print(
            '[InterventionRepository] Matched standard categories: $matchedStandardCategories/5');
        print(
            '[InterventionRepository] Found category names: ${foundCategories.toList()}');
      }

      print(
          '[InterventionRepository] Final completion status: $hasCompletedAllCategories');

      // Process categories and calculate statistics
      List<String> failedCategories = [];
      List<Map<String, dynamic>> categoryDetails = [];
      double totalScore = 0;
      int totalCategories = categories.length;
      const double passingThreshold = 75.0;

      for (final category in categories) {
        if (category is Map) {
          final categoryName =
              category['categoryName']?.toString() ?? 'Unknown';
          final score = (category['score'] is num)
              ? (category['score'] as num).toDouble()
              : 0.0;
          final isPassed =
              category['isPassed'] == true || score >= passingThreshold;

          // Get intervention-related fields
          final interventionAttempts = category['interventionAttempts'] ?? 0;
          final interventionCompleted = category['interventionCompleted'] ?? false;
          final currentInterventionId = category['currentInterventionId'];
          final interventionHistory = category['interventionHistory'] ?? [];

          // Add to category details with intervention information
          categoryDetails.add({
            'name': categoryName,
            'score': score,
            'isPassed': isPassed,
            'interventionAttempts': interventionAttempts,
            'interventionCompleted': interventionCompleted,
            'currentInterventionId': currentInterventionId,
            'interventionHistory': interventionHistory,
          });

          print('[InterventionRepository] Category $categoryName details:');
          print('[InterventionRepository] - interventionAttempts: $interventionAttempts');
          print('[InterventionRepository] - interventionCompleted: $interventionCompleted');
          print('[InterventionRepository] - currentInterventionId: $currentInterventionId');
          print('[InterventionRepository] - interventionHistory entries: ${interventionHistory.length}');

          totalScore += score;

          // ENHANCED: Add to failed categories if student has sufficient completion AND the category is failed
          if (hasCompletedAllCategories &&
              (!isPassed || score < passingThreshold)) {
            failedCategories.add(categoryName);
            print(
                '[InterventionRepository] Found failed category: $categoryName (Score: $score%)');
          }
        }
      }

      // Calculate overall average
      double overallAverage =
          totalCategories > 0 ? totalScore / totalCategories : 0;

      print('[InterventionRepository] Final detailed status:');
      print(
          '[InterventionRepository] - Has completed all categories: $hasCompletedAllCategories');
      print('[InterventionRepository] - Failed categories: $failedCategories');
      print(
          '[InterventionRepository] - Overall average: ${overallAverage.toStringAsFixed(1)}%');
      print('[InterventionRepository] - Total categories: $totalCategories');

      return {
        'failedCategories': failedCategories,
        'overallAverage': overallAverage,
        'categoryDetails': categoryDetails,
        'hasCompletedAllCategories': hasCompletedAllCategories,
      };
    } catch (e) {
      print(
          '[InterventionRepository] Error getting detailed intervention status: $e');
      return {
        'failedCategories': [],
        'overallAverage': 0.0,
        'categoryDetails': [],
        'hasCompletedAllCategories': false,
      };
    }
  }

  /// Helper method to check failed_category_result collection for additional failed categories
  Future<void> _checkFailedCategoryResults(
      dynamic userIdValue,
      List<String> failedCategories,
      List<Map<String, dynamic>> categoryDetails) async {
    try {
      print(
          '[InterventionRepository] Checking failed_category_result collection for user $userIdValue');

      final failedCategoryCollection =
          _dbService.getCollection('failed_category_result');

      // Get all failed category records for this user
      final failedCategoryResults = await failedCategoryCollection
          .find(where.eq('studentId', userIdValue))
          .toList();

      print(
          '[InterventionRepository] Found ${failedCategoryResults.length} failed category records');

      for (final failedResult in failedCategoryResults) {
        final categoryName = failedResult['categoryName']?.toString();
        final score = (failedResult['score'] is num)
            ? (failedResult['score'] as num).toDouble()
            : 0.0;
        final createdAt = failedResult['createdAt'];

        if (categoryName != null && categoryName.isNotEmpty) {
          print(
              '[InterventionRepository] Failed category found: $categoryName (Score: $score%) at $createdAt');

          // Add to failed categories if not already present
          if (!failedCategories.contains(categoryName)) {
            failedCategories.add(categoryName);
            print(
                '[InterventionRepository] Added $categoryName to failed categories list');
          }

          // Check if this category is already in categoryDetails, if not add it
          bool categoryExists =
              categoryDetails.any((detail) => detail['name'] == categoryName);
          if (!categoryExists) {
            categoryDetails.add({
              'name': categoryName,
              'score': score,
              'isPassed':
                  false, // It's in failed_category_result, so it's failed
            });
            print(
                '[InterventionRepository] Added $categoryName to category details');
          } else {
            // Update existing category detail to mark as failed if this is more recent
            final existingIndex = categoryDetails
                .indexWhere((detail) => detail['name'] == categoryName);
            if (existingIndex != -1) {
              final existingScore =
                  categoryDetails[existingIndex]['score'] as double;
              // If the failed result has a lower score, update it
              if (score < existingScore) {
                categoryDetails[existingIndex]['score'] = score;
                categoryDetails[existingIndex]['isPassed'] = false;
                print(
                    '[InterventionRepository] Updated $categoryName with lower score from failed results');
              }
            }
          }
        }
      }

      print('[InterventionRepository] After checking failed_category_result:');
      print(
          '[InterventionRepository] - Total failed categories: ${failedCategories.length}');
      print('[InterventionRepository] - Failed categories: $failedCategories');
    } catch (e) {
      print(
          '[InterventionRepository] Error checking failed_category_result collection: $e');
    }
  }

  /// FIXED: Enhanced method to check if all lessons are completed
  Future<bool> checkAllLessonsCompleted(String userId) async {
    try {
      print(
          '[InterventionRepository] FIXED check: Are all lessons completed for user $userId?');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot check lesson completion');
        return false;
      }

      // Get user document to check completed lessons
      final usersCollection = _dbService.getCollection('users');

      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }

      final userDoc =
          await usersCollection.findOne(where.eq('idNumber', userIdValue));

      if (userDoc == null) {
        print('[InterventionRepository] User not found');
        return false;
      }

      final readingLevel = userDoc['readingLevel']?.toString() ?? '';
      final completedLessons = userDoc['completedLessons'] as List? ?? [];

      print('[InterventionRepository] User reading level: $readingLevel');
      print(
          '[InterventionRepository] User completed lessons: $completedLessons');

      // ENHANCED LOGIC: Multiple ways to determine if lessons are completed

      // Method 1: Check if user has completed 5+ lessons (standard number)
      if (completedLessons.length >= 5) {
        print(
            '[InterventionRepository] User has completed ${completedLessons.length} lessons - sufficient for intervention check');
        return true;
      }

      // Method 2: Check against assigned lessons for reading level (if any exist)
      try {
        final lessonsCollection = _dbService.getCollection('lessons');
        final assignedLessons = await lessonsCollection
            .find(where
                .eq('readingLevel', readingLevel)
                .and(where.eq('status', 'active')))
            .toList();

        if (assignedLessons.isNotEmpty) {
          print(
              '[InterventionRepository] Found ${assignedLessons.length} lessons for reading level: $readingLevel');

          int totalAssignedLessons = assignedLessons.length;
          int completedCount = 0;

          for (final lesson in assignedLessons) {
            final lessonIndex = lesson['index'];
            if (lessonIndex != null) {
              bool isCompleted = completedLessons.contains(lessonIndex) ||
                  completedLessons.contains(lessonIndex.toString());
              if (isCompleted) {
                completedCount++;
              }
            }
          }

          bool allLessonsCompleted = completedCount == totalAssignedLessons;

          print('[InterventionRepository] Lesson completion against assigned:');
          print(
              '[InterventionRepository] - Total assigned: $totalAssignedLessons');
          print('[InterventionRepository] - Completed: $completedCount');
          print(
              '[InterventionRepository] - All completed: $allLessonsCompleted');

          return allLessonsCompleted;
        }
      } catch (e) {
        print('[InterventionRepository] Error checking assigned lessons: $e');
      }

      // Method 3: Alternative check - if user has any completed lessons and category results, assume lessons done
      if (completedLessons.isNotEmpty) {
        // Check if user has category results (indicating they've progressed past lessons)
        try {
          final categoryResultCollection =
              _dbService.getCollection('category_results');
          final categoryCount = await categoryResultCollection
              .count(where.eq('studentId', userIdValue));

          if (categoryCount > 0) {
            print(
                '[InterventionRepository] User has category results - assuming lessons completed');
            return true;
          }
        } catch (e) {
          print('[InterventionRepository] Error checking category results: $e');
        }
      }

      // Method 4: FALLBACK - Based on your screenshots showing completed lessons
      // If we can't determine from database, but we see evidence of completion, assume true
      print(
          '[InterventionRepository] Could not determine lesson completion definitively');
      print(
          '[InterventionRepository] Completed lessons count: ${completedLessons.length}');

      // If user has completed some lessons (1+), give benefit of doubt for intervention check
      return completedLessons.isNotEmpty;
    } catch (e) {
      print('[InterventionRepository] Error checking lesson completion: $e');
      return false;
    }
  }

  /// Check if student can access intervention assessment based on attemptNumber matching
  /// Returns intervention assessment only if attemptNumber matches revisionNumber
  Future<InterventionAssessment?> getMatchingInterventionAssessment(
      String userId, String categoryName) async {
    try {
      print(
          '[InterventionRepository] Checking matching intervention for user $userId, category: $categoryName');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot get matching intervention');
        return null;
      }

      // Get the student's interventionAttempts for this category
      final categoryResultsCollection =
          _dbService.getCollection(_collCategoryResults);

      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      final categoryResult = await categoryResultsCollection
          .findOne(where.eq('studentId', studentIdValue));
      if (categoryResult == null) {
        print(
            '[InterventionRepository] No category results found for user $userId');
        return null;
      }

      final categories = categoryResult['categories'] as List?;
      if (categories == null) {
        print(
            '[InterventionRepository] No categories found in category results');
        return null;
      }

      int userInterventionAttempts = 1;
      bool categoryFailed = false;

      // Find the specific category and get its interventionAttempts
      for (final category in categories) {
        if (category is Map && category['categoryName'] == categoryName) {
          userInterventionAttempts = category['interventionAttempts'] ?? 1; // Use current interventionAttempts
          categoryFailed = category['isPassed'] != true;
          print(
              '[InterventionRepository] Found category $categoryName - interventionAttempts: $userInterventionAttempts, failed: $categoryFailed');
          break;
        }
      }

      if (!categoryFailed) {
        print(
            '[InterventionRepository] Category $categoryName has not failed, no intervention needed');
        return null;
      }

      // Query for intervention assessment that matches this category and revision
      final interventionCollection =
          _dbService.getCollection(_collInterventionAssessment);

      final query = where
          .eq('studentId', studentIdValue)
          .and(where.eq('category', categoryName))
          .and(where.eq('revisionNumber', userInterventionAttempts))
          .and(where.eq('status', 'active'));

      final results = await interventionCollection.find(query).toList();

      if (results.isEmpty) {
        print('[InterventionRepository] No matching intervention found for:');
        print('[InterventionRepository] - Student: $studentIdValue');
        print('[InterventionRepository] - Category: $categoryName');
        print(
            '[InterventionRepository] - Required revisionNumber: $userInterventionAttempts (matching interventionAttempts)');
        return null;
      }

      if (results.length > 1) {
        print(
            '[InterventionRepository] Warning: Multiple matching interventions found, using first one');
      }

      final interventionDoc = results.first;
      final intervention = InterventionAssessment.fromMap(interventionDoc);

      print('[InterventionRepository] Found matching intervention:');
      print('[InterventionRepository] - ID: ${intervention.id}');
      print('[InterventionRepository] - Name: ${intervention.name}');
      print('[InterventionRepository] - Category: ${intervention.category}');
      print(
          '[InterventionRepository] - RevisionNumber: ${interventionDoc['revisionNumber']}');

      return intervention;
    } catch (e) {
      print('[InterventionRepository] Error getting matching intervention: $e');
      return null;
    }
  }

  /// Check if student has an intervention assessment assigned
  Future<List<InterventionAssessment>> getInterventionAssessments(
      String userId) async {
    try {
      print(
          '[InterventionRepository] Getting intervention assessments for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot get intervention assessments');
        return [];
      }

      // Query for active intervention assessments for this student
      final interventionCollection =
          _dbService.getCollection(_collInterventionAssessment);

      // Convert userId to int since database stores studentId as number
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId; // fallback to string if parsing fails
      }

      final query = where
          .eq('studentId', studentIdValue)
          .and(where.eq('status', 'active'));

      final results = await interventionCollection.find(query).toList();
      if (results.isEmpty) {
        print(
            '[InterventionRepository] No intervention assessments found for user $userId');
        return [];
      }

      // Convert to model objects
      List<InterventionAssessment> interventions = [];
      for (final doc in results) {
        try {
          final intervention = InterventionAssessment.fromMap(doc);
          interventions.add(intervention);
          print(
              '[InterventionRepository] Found intervention: ${intervention.name}');
        } catch (e) {
          print('[InterventionRepository] Error parsing intervention: $e');
        }
      }

      return interventions;
    } catch (e) {
      print(
          '[InterventionRepository] Error getting intervention assessments: $e');
      return [];
    }
  }

  /// Get intervention history for a student
  Future<List<InterventionResult>> getInterventionHistory(String userId) async {
    try {
      print(
          '[InterventionRepository] Getting intervention history for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot get intervention history');
        return [];
      }

      // Query for intervention results for this student
      final resultsCollection =
          _dbService.getCollection(_collInterventionResults);
      final query =
          where.eq('userId', userId).sortBy('completedAt', descending: true);

      final results = await resultsCollection.find(query).toList();

      // Convert to model objects
      List<InterventionResult> history = [];
      for (final doc in results) {
        try {
          final result = InterventionResult.fromMap(doc);
          history.add(result);
        } catch (e) {
          print(
              '[InterventionRepository] Error parsing intervention result: $e');
        }
      }

      print(
          '[InterventionRepository] Found ${history.length} intervention history records');
      return history;
    } catch (e) {
      print('[InterventionRepository] Error getting intervention history: $e');
      return [];
    }
  }

  /// Save individual intervention response (NEW: per question response)
  Future<bool> saveInterventionResponse(InterventionResponse response) async {
    try {
      print(
          '[InterventionRepository] Saving intervention response for question ${response.questionId}');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot save intervention response');
        return false;
      }

      // Save to intervention_responses collection
      final responsesCollection =
          _dbService.getCollection(_collInterventionResponses);

      final responseDoc = response.toMap();

      // Save to database
      final result = await responsesCollection.insertOne(responseDoc);

      if (result.isSuccess) {
        final insertedId = result.document?['_id']?.toString() ?? 'unknown';
        print(
            '[InterventionRepository] Successfully saved intervention response with ID: $insertedId');
        return true;
      } else {
        print('[InterventionRepository] Failed to save intervention response');
        return false;
      }
    } catch (e) {
      print('[InterventionRepository] Error saving intervention response: $e');
      return false;
    }
  }

  /// Save intervention result
  Future<bool> saveInterventionResult({
    required String userId,
    required String studentNumber,
    required String interventionId,
    required double score,
    required Map<String, String> answers,
    required bool isPassed,
  }) async {
    try {
      print(
          '[InterventionRepository] Saving intervention result for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print(
            '[InterventionRepository] Database not connected, cannot save intervention result');
        return false;
      }

      // Create result document
      final resultsCollection =
          _dbService.getCollection(_collInterventionResults);

      final resultDoc = {
        'userId': userId,
        'studentNumber': studentNumber,
        'interventionAssessmentId': interventionId,
        'score': score,
        'answers': answers,
        'isPassed': isPassed,
        'completedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Log intervention result save attempt
      print(
          '[InterventionRepository] Saving intervention result for user $userId: ${score.toStringAsFixed(1)}% (${answers.length} answers)');

      // Save to database
      final result = await resultsCollection.insertOne(resultDoc);

      if (result.isSuccess) {
        final insertedId = result.document?['_id']?.toString() ?? 'unknown';
        print(
            '[InterventionRepository] Successfully saved intervention result with ID: $insertedId');

        // If passed, update category result status for this category
        if (isPassed) {
          await _updateCategoryStatus(userId, interventionId);
        }

        return true;
      } else {
        print('[InterventionRepository] Failed to save intervention result');
        return false;
      }
    } catch (e) {
      print('[InterventionRepository] Error saving intervention result: $e');
      return false;
    }
  }

  /// Update category status after successful intervention
  Future<bool> _updateCategoryStatus(
      String userId, String interventionId) async {
    try {
      print(
          '[InterventionRepository] Updating category status for user $userId');

      // First, get the intervention to determine which category to update
      final interventionCollection =
          _dbService.getCollection(_collInterventionAssessment);
      final interventionDoc = await interventionCollection
          .findOne(where.eq('_id', ObjectId.parse(interventionId)));

      if (interventionDoc == null) {
        print(
            '[InterventionRepository] Cannot find intervention with ID: $interventionId');
        return false;
      }

      final category = interventionDoc['category'];
      if (category == null || category.toString().isEmpty) {
        print('[InterventionRepository] Intervention has no category defined');
        return false;
      }

      // Now update the category result
      final categoryResultCollection =
          _dbService.getCollection(_collCategoryResults);

      // Get the latest category result for this user
      final latestResultQuery = where
          .eq('studentId', userId)
          .sortBy('createdAt', descending: true)
          .limit(1);
      final latestResults =
          await categoryResultCollection.find(latestResultQuery).toList();

      if (latestResults.isEmpty) {
        print('[InterventionRepository] No category results found to update');
        return false;
      }

      final latestResult = latestResults.first;
      final categories = latestResult['categories'] as List?;

      if (categories == null || categories.isEmpty) {
        print(
            '[InterventionRepository] No categories found in the latest result');
        return false;
      }

      // Find and update the specific category
      bool foundCategory = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i] is Map && categories[i]['categoryName'] == category) {
          // CRITICAL FIX: Only update intervention-specific fields
          // DO NOT modify main assessment results (score, correctAnswers, totalQuestions, isPassed)
          categories[i]['interventionCompleted'] = true;
          categories[i]['interventionRequired'] = false;
          
          // Increment intervention attempts counter
          final currentAttempts = categories[i]['interventionAttempts'] ?? 0;
          categories[i]['interventionAttempts'] = currentAttempts + 1;
          
          foundCategory = true;
          print('[InterventionRepository] Updated intervention status for: $category (INTERVENTION ONLY)');
          print('[InterventionRepository] - interventionCompleted: true');
          print('[InterventionRepository] - interventionRequired: false');
          print('[InterventionRepository] - interventionAttempts: ${currentAttempts + 1}');
          print('[InterventionRepository] - PRESERVED main assessment: score=${categories[i]['score']}, isPassed=${categories[i]['isPassed']}');
          break;
        }
      }

      if (!foundCategory) {
        print(
            '[InterventionRepository] Category not found in results: $category');
        return false;
      }

      // Check if all categories are now passed
      // A category is considered "passed" if either:
      // 1. Main assessment was passed (isPassed == true) OR
      // 2. Intervention was completed successfully (interventionCompleted == true)
      // Must have all 5 standard categories before declaring all passed
      bool allPassed = categories.length >= 5;
      if (allPassed) {
        for (final cat in categories) {
          if (cat is Map) {
            final mainAssessmentPassed = cat['isPassed'] == true;
            final interventionCompleted = cat['interventionCompleted'] == true;
            
            if (!mainAssessmentPassed && !interventionCompleted) {
              allPassed = false;
              break;
            }
          }
        }
      }

      // Update the category result
      final updateResult = await categoryResultCollection.updateOne(
          where.eq('_id', latestResult['_id']),
          modify
              .set('categories', categories)
              .set('allCategoriesPassed', allPassed)
              .set('updatedAt', DateTime.now().toIso8601String()));

      if (updateResult.isSuccess) {
        print('[InterventionRepository] Successfully updated category status');
        return true;
      } else {
        print('[InterventionRepository] Failed to update category status');
        return false;
      }
    } catch (e) {
      print('[InterventionRepository] Error updating category status: $e');
      return false;
    }
  }
}
