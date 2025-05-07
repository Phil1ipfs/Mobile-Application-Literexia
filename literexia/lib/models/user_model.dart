// lib/models/user_model.dart
class User {
  final String idNumber; // Keep as String for your app's internal use
  final String? name;
  final int? age;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final List<int>? completedLessons;
  final DateTime? createdAt;
  final String? readingLevel; // Added this field
  final DateTime? lastLogin;

  User({
    required this.idNumber,
    this.name,
    this.age,
    this.firstName,
    this.lastName,
    this.middleName,
    this.completedLessons,
    this.createdAt,
    this.readingLevel,
    this.lastLogin,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    // Handle the ID number which could be either int or String in MongoDB
    String idNumber;
    if (map['idNumber'] is int) {
      idNumber = (map['idNumber'] as int).toString();
    } else {
      idNumber = map['idNumber'] as String;
    }

    return User(
      idNumber: idNumber,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      middleName: map['middleName'] as String?,
      age: map['age'] is int ? map['age'] as int : null,
      name: map['name'] as String?, 
      completedLessons: List<int>.from(map['completedLessons'] ?? []),
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'].toString())
              : null,
      readingLevel: map['readingLevel'], 
      lastLogin:
          map['lastLogin'] != null
              ? DateTime.parse(map['lastLogin'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    // Try to parse idNumber as int for MongoDB compatibility
    int? numericId;
    try {
      numericId = int.parse(idNumber);
    } catch (_) {
      // If it can't be parsed as int, leave it as string
    }

    return {
      'idNumber': numericId ?? idNumber, // Store as int if possible, otherwise as string
      'name': name,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'age': age,
      'completedLessons': completedLessons,
      'createdAt': createdAt?.toIso8601String(),
      'readingLevel': readingLevel, // Include in map
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  User copyWith({
    String? idNumber,
    String? name,
    String? firstName,
    String? lastName,
    String? middleName,
    int? age,
    List<int>? completedLessons,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? readingLevel,
  }) {
    return User(
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      age: age ?? this.age,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      completedLessons: completedLessons ?? this.completedLessons,
      readingLevel: readingLevel ?? this.readingLevel,
    );
  }
}