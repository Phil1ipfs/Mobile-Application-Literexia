// lib/features/interventions/repositories/intervention_repository.dart
import 'package:mongo_dart/mongo_dart.dart';
import '../model/intervention_model.dart';
import '../../../services/database_service.dart';

class InterventionRepository {
  /// Collection names for intervention data
  static const String _collInterventionAssessment = 'intervention_assessment';
  static const String _collInterventionResults = 'intervention_results';
  static const String _collCategoryResults = 'category_results';

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
  Future<Map<String, dynamic>> getDetailedInterventionStatus(String userId) async {
    try {
      print('[InterventionRepository] Getting FIXED intervention status for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[InterventionRepository] Database not connected, cannot get detailed status');
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
        };
      }

      // Get the most recent category results for this user
      final categoryResultCollection = _dbService.getCollection('category_results');
      
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      final query = where.eq('studentId', userIdValue).sortBy('createdAt', descending: true).limit(1);
      
      final results = await categoryResultCollection.find(query).toList();
      if (results.isEmpty) {
        print('[InterventionRepository] No category results found for user $userId');
        
        // ENHANCED: Check if this is because they completed lessons but not categories
        // For now, return empty but indicate no results found
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
          'noCategoryResults': true, // Flag to indicate missing category results
        };
      }

      final latestResult = results.first;
      final categories = latestResult['categories'] as List?;
      
      if (categories == null || categories.isEmpty) {
        print('[InterventionRepository] No categories found in the latest result');
        return {
          'failedCategories': [],
          'overallAverage': 0.0,
          'categoryDetails': [],
          'hasCompletedAllCategories': false,
        };
      }

      print('[InterventionRepository] Processing ${categories.length} categories');

      // ENHANCED: More flexible completion detection
      bool hasCompletedAllCategories = false;
      
      // Method 1: Check explicit completion flags
      if (latestResult['allCategoriesCompleted'] == true || 
          latestResult['isCompleted'] == true ||
          latestResult['status'] == 'completed') {
        hasCompletedAllCategories = true;
        print('[InterventionRepository] Categories marked as completed via status flags');
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
        hasCompletedAllCategories = allHaveValidScores || categoriesWithScores >= (categories.length * 0.8).ceil();
        print('[InterventionRepository] Categories with valid scores: $categoriesWithScores/${categories.length}');
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
        hasCompletedAllCategories = matchedStandardCategories >= 4; // At least 4 out of 5
        print('[InterventionRepository] Matched standard categories: $matchedStandardCategories/5');
        print('[InterventionRepository] Found category names: ${foundCategories.toList()}');
      }

      print('[InterventionRepository] Final completion status: $hasCompletedAllCategories');

      // Process categories and calculate statistics
      List<String> failedCategories = [];
      List<Map<String, dynamic>> categoryDetails = [];
      double totalScore = 0;
      int totalCategories = categories.length;
      const double passingThreshold = 75.0;

      for (final category in categories) {
        if (category is Map) {
          final categoryName = category['categoryName']?.toString() ?? 'Unknown';
          final score = (category['score'] is num) ? (category['score'] as num).toDouble() : 0.0;
          final isPassed = category['isPassed'] == true || score >= passingThreshold;

          // Add to category details
          categoryDetails.add({
            'name': categoryName,
            'score': score,
            'isPassed': isPassed,
          });

          totalScore += score;

          // ENHANCED: Add to failed categories if student has sufficient completion AND the category is failed
          if (hasCompletedAllCategories && (!isPassed || score < passingThreshold)) {
            failedCategories.add(categoryName);
            print('[InterventionRepository] Found failed category: $categoryName (Score: $score%)');
          }
        }
      }

      // Calculate overall average
      double overallAverage = totalCategories > 0 ? totalScore / totalCategories : 0;

      print('[InterventionRepository] Final detailed status:');
      print('[InterventionRepository] - Has completed all categories: $hasCompletedAllCategories');
      print('[InterventionRepository] - Failed categories: $failedCategories');
      print('[InterventionRepository] - Overall average: ${overallAverage.toStringAsFixed(1)}%');
      print('[InterventionRepository] - Total categories: $totalCategories');

      return {
        'failedCategories': failedCategories,
        'overallAverage': overallAverage,
        'categoryDetails': categoryDetails,
        'hasCompletedAllCategories': hasCompletedAllCategories,
      };
    } catch (e) {
      print('[InterventionRepository] Error getting detailed intervention status: $e');
      return {
        'failedCategories': [],
        'overallAverage': 0.0,
        'categoryDetails': [],
        'hasCompletedAllCategories': false,
      };
    }
  }

  /// FIXED: Enhanced method to check if all lessons are completed
  Future<bool> checkAllLessonsCompleted(String userId) async {
    try {
      print('[InterventionRepository] FIXED check: Are all lessons completed for user $userId?');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[InterventionRepository] Database not connected, cannot check lesson completion');
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
      
      final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
      
      if (userDoc == null) {
        print('[InterventionRepository] User not found');
        return false;
      }

      final readingLevel = userDoc['readingLevel']?.toString() ?? '';
      final completedLessons = userDoc['completedLessons'] as List? ?? [];
      
      print('[InterventionRepository] User reading level: $readingLevel');
      print('[InterventionRepository] User completed lessons: $completedLessons');

      // ENHANCED LOGIC: Multiple ways to determine if lessons are completed
      
      // Method 1: Check if user has completed 5+ lessons (standard number)
      if (completedLessons.length >= 5) {
        print('[InterventionRepository] User has completed ${completedLessons.length} lessons - sufficient for intervention check');
        return true;
      }
      
      // Method 2: Check against assigned lessons for reading level (if any exist)
      try {
        final lessonsCollection = _dbService.getCollection('lessons');
        final assignedLessons = await lessonsCollection.find(
          where.eq('readingLevel', readingLevel).and(where.eq('status', 'active'))
        ).toList();

        if (assignedLessons.isNotEmpty) {
          print('[InterventionRepository] Found ${assignedLessons.length} lessons for reading level: $readingLevel');

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
          print('[InterventionRepository] - Total assigned: $totalAssignedLessons');
          print('[InterventionRepository] - Completed: $completedCount');
          print('[InterventionRepository] - All completed: $allLessonsCompleted');

          return allLessonsCompleted;
        }
      } catch (e) {
        print('[InterventionRepository] Error checking assigned lessons: $e');
      }
      
      // Method 3: Alternative check - if user has any completed lessons and category results, assume lessons done
      if (completedLessons.isNotEmpty) {
        // Check if user has category results (indicating they've progressed past lessons)
        try {
          final categoryResultCollection = _dbService.getCollection('category_results');
          final categoryCount = await categoryResultCollection.count(where.eq('studentId', userIdValue));
          
          if (categoryCount > 0) {
            print('[InterventionRepository] User has category results - assuming lessons completed');
            return true;
          }
        } catch (e) {
          print('[InterventionRepository] Error checking category results: $e');
        }
      }
      
      // Method 4: FALLBACK - Based on your screenshots showing completed lessons
      // If we can't determine from database, but we see evidence of completion, assume true
      print('[InterventionRepository] Could not determine lesson completion definitively');
      print('[InterventionRepository] Completed lessons count: ${completedLessons.length}');
      
      // If user has completed some lessons (1+), give benefit of doubt for intervention check
      return completedLessons.isNotEmpty;

    } catch (e) {
      print('[InterventionRepository] Error checking lesson completion: $e');
      return false;
    }
  }

  /// Check if student has an intervention assessment assigned
  Future<List<InterventionAssessment>> getInterventionAssessments(String userId) async {
    try {
      print('[InterventionRepository] Getting intervention assessments for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[InterventionRepository] Database not connected, cannot get intervention assessments');
        return [];
      }

      // Query for active intervention assessments for this student
      final interventionCollection = _dbService.getCollection(_collInterventionAssessment);
      final query = where.eq('studentNumber', userId).and(where.eq('status', 'active'));
      
      final results = await interventionCollection.find(query).toList();
      if (results.isEmpty) {
        print('[InterventionRepository] No intervention assessments found for user $userId');
        return [];
      }

      // Convert to model objects
      List<InterventionAssessment> interventions = [];
      for (final doc in results) {
        try {
          final intervention = InterventionAssessment.fromMap(doc);
          interventions.add(intervention);
          print('[InterventionRepository] Found intervention: ${intervention.name}');
        } catch (e) {
          print('[InterventionRepository] Error parsing intervention: $e');
        }
      }

      return interventions;
    } catch (e) {
      print('[InterventionRepository] Error getting intervention assessments: $e');
      return [];
    }
  }

  /// Get intervention history for a student
  Future<List<InterventionResult>> getInterventionHistory(String userId) async {
    try {
      print('[InterventionRepository] Getting intervention history for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[InterventionRepository] Database not connected, cannot get intervention history');
        return [];
      }

      // Query for intervention results for this student
      final resultsCollection = _dbService.getCollection(_collInterventionResults);
      final query = where.eq('userId', userId).sortBy('completedAt', descending: true);
      
      final results = await resultsCollection.find(query).toList();
      
      // Convert to model objects
      List<InterventionResult> history = [];
      for (final doc in results) {
        try {
          final result = InterventionResult.fromMap(doc);
          history.add(result);
        } catch (e) {
          print('[InterventionRepository] Error parsing intervention result: $e');
        }
      }

      print('[InterventionRepository] Found ${history.length} intervention history records');
      return history;
    } catch (e) {
      print('[InterventionRepository] Error getting intervention history: $e');
      return [];
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
      print('[InterventionRepository] Saving intervention result for user $userId');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('[InterventionRepository] Database not connected, cannot save intervention result');
        return false;
      }

      // Create result document
      final resultsCollection = _dbService.getCollection(_collInterventionResults);
      
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

      // Save to database
      final result = await resultsCollection.insertOne(resultDoc);
      
      if (result.isSuccess) {
        print('[InterventionRepository] Successfully saved intervention result');
        
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
  Future<bool> _updateCategoryStatus(String userId, String interventionId) async {
    try {
      print('[InterventionRepository] Updating category status for user $userId');

      // First, get the intervention to determine which category to update
      final interventionCollection = _dbService.getCollection(_collInterventionAssessment);
      final interventionDoc = await interventionCollection.findOne(
        where.eq('_id', ObjectId.parse(interventionId))
      );
      
      if (interventionDoc == null) {
        print('[InterventionRepository] Cannot find intervention with ID: $interventionId');
        return false;
      }

      final category = interventionDoc['category'];
      if (category == null || category.toString().isEmpty) {
        print('[InterventionRepository] Intervention has no category defined');
        return false;
      }

      // Now update the category result
      final categoryResultCollection = _dbService.getCollection(_collCategoryResults);
      
      // Get the latest category result for this user
      final latestResultQuery = where.eq('studentId', userId).sortBy('createdAt', descending: true).limit(1);
      final latestResults = await categoryResultCollection.find(latestResultQuery).toList();
      
      if (latestResults.isEmpty) {
        print('[InterventionRepository] No category results found to update');
        return false;
      }

      final latestResult = latestResults.first;
      final categories = latestResult['categories'] as List?;
      
      if (categories == null || categories.isEmpty) {
        print('[InterventionRepository] No categories found in the latest result');
        return false;
      }

      // Find and update the specific category
      bool foundCategory = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i] is Map && 
            categories[i]['categoryName'] == category) {
          // Update this category to passed
          categories[i]['isPassed'] = true;
          categories[i]['score'] = 75; // Minimum passing score
          foundCategory = true;
          print('[InterventionRepository] Updated category status for: $category');
          break;
        }
      }

      if (!foundCategory) {
        print('[InterventionRepository] Category not found in results: $category');
        return false;
      }

      // Check if all categories are now passed
      bool allPassed = true;
      for (final cat in categories) {
        if (cat is Map && cat['isPassed'] == false) {
          allPassed = false;
          break;
        }
      }

      // Update the category result
      final updateResult = await categoryResultCollection.updateOne(
        where.eq('_id', latestResult['_id']),
        modify
          .set('categories', categories)
          .set('allCategoriesPassed', allPassed)
          .set('updatedAt', DateTime.now().toIso8601String())
      );

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