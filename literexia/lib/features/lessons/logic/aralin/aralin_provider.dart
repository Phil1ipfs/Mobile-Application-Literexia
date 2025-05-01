import 'package:flutter/foundation.dart';
import '/models/lesson_models.dart';

class AralinProvider with ChangeNotifier {
  // Track which lessons are available and completed
  final Map<int, bool> _availableLessons = {};
  final List<int> _completedLessons = [];

  AralinProvider() {
    // Initialize with default values - only first lesson is available initially
    _availableLessons[1] = true;

    // For demo purposes - we can enable more lessons
    for (int i = 1; i <= 8; i++) {
      _availableLessons[i] = i == 1; // Only first lesson starts as available
    }
  }

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
}
