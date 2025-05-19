// lib/features/lessons/logic/aralin/aralin_provider.dart

import 'package:flutter/foundation.dart';
import '/models/lesson_models.dart';
import '../../../../services/database_service.dart';

class AralinProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  // Track which lessons are available and completed
  final Map<int, bool> _availableLessons = {};
  final List<int> _completedLessons = [];

  // For MongoDB integration
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = false;
  String? _errorMessage;

  AralinProvider() {
    // Initialize with default values - only first lesson is available initially
    _availableLessons[1] = true;

    // For demo purposes - we can enable more lessons
    for (int i = 1; i <= 8; i++) {
      _availableLessons[i] = i == 1; // Only first lesson starts as available
    }
  }

  // Getters for MongoDB data
  List<Map<String, dynamic>> get lessons => _lessons;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Check if a specific lesson is available
  bool isLessonAvailable(int lessonNumber) {
    return _availableLessons[lessonNumber] ?? false;
  }

  // Mark a lesson as completed
  void completeLesson(int lessonNumber) {
    if (!_completedLessons.contains(lessonNumber)) {
      _completedLessons.add(lessonNumber);

      // Unlock the next lesson
      if (lessonNumber < 8) {
        _availableLessons[lessonNumber + 1] = true;
      }

      notifyListeners();
    }
  }

  // Check if a lesson is completed
  bool isLessonCompleted(int lessonNumber) {
    return _completedLessons.contains(lessonNumber);
  }

  // Get beginner lessons (Aralin 1)
  List<Map<String, dynamic>> getBeginnerLessons() {
    return [
      {
        'lessonNumber': 1,
        'title': 'Mga Huni o Tunog ng mga Hayop',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get advanced lessons (Aralin 2)
  List<Map<String, dynamic>> getAdvancedLessons() {
    return [
      {
        'lessonNumber': 2,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get expert lessons (Aralin 3)
  List<Map<String, dynamic>> getExpertLessons() {
    return [
      {
        'lessonNumber': 3,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get master lessons (Aralin 4)
  List<Map<String, dynamic>> getMasterLessons() {
    return [
      {
        'lessonNumber': 4,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get expert plus lessons (Aralin 5)
  List<Map<String, dynamic>> getExpertPlusLessons() {
    return [
      {
        'lessonNumber': 5,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get master plus lessons (Aralin 6)
  List<Map<String, dynamic>> getMasterPlusLessons() {
    return [
      {
        'lessonNumber': 6,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get master plus plus lessons (Aralin 7)
  List<Map<String, dynamic>> getMasterPlusPlusLessons() {
    return [
      {
        'lessonNumber': 7,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // Get master plus plus plus lessons (Aralin 8)
  List<Map<String, dynamic>> getMasterPlusPlusPlusLessons() {
    return [
      {
        'lessonNumber': 8,
        'title': 'Mga Uri ng Pangungusap',
        'completedLessons': _completedLessons,
      },
    ];
  }

  // MongoDB integration - Load lessons from database based on reading level
  Future<void> fetchLessonsForLevel(String readingLevel) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Query MongoDB for lessons matching the reading level
      final lessonsData = await _databaseService.getLessonsForLevel(
        readingLevel,
      );

      if (lessonsData.isNotEmpty) {
        // Convert the database data to the format expected by the app
        _lessons =
            lessonsData.map((lesson) {
              final lessonNumber =
                  lesson['lessonIndex'] ?? lesson['lessonNumber'] ?? 0;

              // Update availability status from internal tracking
              final isAvailable = isLessonAvailable(lessonNumber);

              return {
                'index': lessonNumber,
                'title': lesson['title'] ?? 'Untitled Lesson',
                'description':
                    lesson['description'] ?? 'No description available',
                'questionCount': lesson['questionCount'] ?? 5,
                'isAvailable': isAvailable,
                'isCompleted': isLessonCompleted(lessonNumber),
              };
            }).toList();

        // Sort lessons by index
        _lessons.sort(
          (a, b) => (a['index'] as int).compareTo(b['index'] as int),
        );
      } else {
        _lessons = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load lessons: $e';
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to load lessons: $e');
    }
  }

  // Add this method to your AralinProvider class
  void setLessons(List<Map<String, dynamic>> newLessons) {
    _lessons = newLessons;
    // Only notify listeners if we're not in the build phase
    // This helps prevent the "setState during build" error
    Future.microtask(() => notifyListeners());
  }
}
