// lib/models/user_model.dart
class User {
  final String idNumber; // Keep as String for your app's internal use
  final String name;
  final List<int>? completedLessons;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  User({
    required this.idNumber,
    required this.name,
    this.completedLessons,
    this.createdAt,
    this.lastLogin,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    // Handle the ID number which could be either int or String in MongoDB
    String idNumber;
    if (map['idNumber'] is int) {
      // Convert integer to string if it comes from MongoDB as int
      idNumber = (map['idNumber'] as int).toString();
    } else {
      // Use as is if it's already a string
      idNumber = map['idNumber'] as String;
    }

    return User(
      idNumber: idNumber,
      name: map['name'] as String,
      completedLessons: List<int>.from(map['completedLessons'] ?? []),
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'].toString())
              : null,
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
      'idNumber':
          numericId ??
          idNumber, // Store as int if possible, otherwise as string
      'name': name,
      'completedLessons': completedLessons,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  User copyWith({
    String? idNumber,
    String? name,
    List<int>? completedLessons,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      completedLessons: completedLessons ?? this.completedLessons,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
