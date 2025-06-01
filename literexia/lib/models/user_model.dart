// lib/models/user_model.dart
import 'package:mongo_dart/mongo_dart.dart';

class User {
  final ObjectId? id;
  final String idNumber;
  final String? name;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final List<int>? completedLessons;
  final String? readingLevel; // This field is causing the issue

  // Add any other fields your User model has
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final int? age;
  final String? parentId;
  final String? lastAssessmentDate;
  final double? readingPercentage;
  final bool? preAssessmentCompleted;
  final String? profileImageUrl;
  final String? gradeLevel;
  final String? gender;
  final String? address;
  final String? section;

  User({
    this.id,
    required this.idNumber,
    this.name,
    this.createdAt,
    this.lastLogin,
    this.completedLessons,
    this.readingLevel,
    this.firstName,
    this.lastName,
    this.middleName,
    this.age,
    this.parentId,
    this.lastAssessmentDate,
    this.readingPercentage,
    this.preAssessmentCompleted,
    this.profileImageUrl,
    this.gradeLevel,
    this.gender,
    this.address,
    this.section,
  });

  // Create a copy with modified fields
  User copyWith({
    String? idNumber,
    String? name,
    String? firstName,
    String? lastName,
    String? middleName,
    int? age,
    String? readingLevel,
    double? readingPercentage,
    bool? preAssessmentCompleted,
    List<int>? completedLessons,
  }) {
    return User(
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      age: age ?? this.age,
      readingLevel: readingLevel ?? this.readingLevel,
      readingPercentage: readingPercentage ?? this.readingPercentage,
      preAssessmentCompleted:
          preAssessmentCompleted ?? this.preAssessmentCompleted,
      completedLessons: completedLessons ?? this.completedLessons,
    );
  }

  // Factory method to create a User from a Map
  factory User.fromMap(Map<String, dynamic> map) {
    // Helper function to safely convert values
    T? _safeValue<T>(dynamic value) {
      if (value == null) return null;
      if (value is T) return value;

      // Handle specific type conversions
      if (T == String && value is bool) {
        return value.toString() as T; // Convert bool to String
      }

      // Log warning about unexpected type
      print(
          'Type mismatch: expected $T but got ${value.runtimeType} for value: $value');
      return null; // Return null for incompatible types
    }

    // Parse date values safely
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Failed to parse date: $value, error: $e');
          return null;
        }
      }
      return null;
    }

    // Parse completed lessons safely
    List<int>? _parseCompletedLessons(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value
            .whereType<int>()
            .toList(); // This filters to only int values
      }
      return null;
    }

    try {
      return User(
        id: map['_id'] is ObjectId ? map['_id'] : null,
        // Ensure idNumber is always a string
        idNumber: map['idNumber'] is int
            ? map['idNumber'].toString()
            : (map['idNumber'] ?? '').toString(),
        name: _safeValue<String>(map['name']),
        createdAt: _parseDate(map['createdAt']),
        lastLogin: _parseDate(map['lastLogin']),
        completedLessons: _parseCompletedLessons(map['completedLessons']),
        // Handle the readingLevel field that might be boolean or string
        readingLevel: _safeValue<String>(map['readingLevel']),

        // Handle other fields with safe conversions
        firstName: _safeValue<String>(map['firstName']),
        lastName: _safeValue<String>(map['lastName']),
        middleName: _safeValue<String>(map['middleName']),
        age: _safeValue<int>(map['age']),
        parentId: _safeValue<String>(map['parentId']),
        lastAssessmentDate: _safeValue<String>(map['lastAssessmentDate']),
        readingPercentage: map['readingPercentage'] is num
            ? (map['readingPercentage'] as num).toDouble()
            : null,
        preAssessmentCompleted: _safeValue<bool>(map['preAssessmentCompleted']),
        profileImageUrl: _safeValue<String>(map['profileImageUrl']),
        gradeLevel: _safeValue<String>(map['gradeLevel']),
        gender: _safeValue<String>(map['gender']),
        address: _safeValue<String>(map['address']),
        section: _safeValue<String>(map['section']),
      );
    } catch (e) {
      print('Error creating User from map: $e');
      print('Problem data: $map');
      rethrow; // Rethrow to allow caller to handle
    }
  }
}
