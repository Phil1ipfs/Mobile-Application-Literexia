// lib/models/lesson_model.dart
import 'package:mongo_dart/mongo_dart.dart';

class Lesson {
  final ObjectId? id;
  final int lessonNumber;
  final String title;
  final String? description;
  final List<String>? content;
  final bool isAvailable;
  final bool isCompleted;

  Lesson({
    this.id,
    required this.lessonNumber,
    required this.title,
    this.description,
    this.content,
    this.isAvailable = false,
    this.isCompleted = false,
  });

  // Convert Lesson object to a Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'lessonNumber': lessonNumber,
      'title': title,
      if (description != null) 'description': description,
      if (content != null) 'content': content,
      'isAvailable': isAvailable,
      'isCompleted': isCompleted,
    };
  }

  // Create Lesson object from a Map
  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['_id'],
      lessonNumber: map['lessonNumber'],
      title: map['title'],
      description: map['description'],
      content:
          map['content'] != null ? List<String>.from(map['content']) : null,
      isAvailable: map['isAvailable'] ?? false,
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  // Create a copy of this Lesson with the given fields replaced
  Lesson copyWith({
    ObjectId? id,
    int? lessonNumber,
    String? title,
    String? description,
    List<String>? content,
    bool? isAvailable,
    bool? isCompleted,
  }) {
    return Lesson(
      id: id ?? this.id,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      isAvailable: isAvailable ?? this.isAvailable,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
