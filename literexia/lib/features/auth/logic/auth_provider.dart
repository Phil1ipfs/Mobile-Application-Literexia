// lib/features/auth/logic/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/database_service.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  User? _currentUser;
  final UserRepository _userRepository = UserRepository();
  final DatabaseService _databaseService = DatabaseService();

  // Getters
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Initialize auth state
  Future<void> initialize() async {
    try {
      print('Initializing auth provider...');
      // Initialize database connection
      final dbInitialized = await _databaseService.initialize();
      print('Database initialized: $dbInitialized');

      if (!dbInitialized) {
        _status = AuthStatus.error;
        _errorMessage = 'Database connection failed';
        notifyListeners();
        return;
      }

      // For demo purposes, we'll set status to unauthenticated
      // In a real app, you would check local storage for saved credentials
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      print('Error initializing auth provider: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Failed to initialize authentication: $e';
      notifyListeners();
    }
  }

  // Login with ID number - Updated to support the new database structure
  Future<bool> login(String idNumber) async {
    try {
      print('Attempting login with ID: $idNumber');
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      // Validate ID number format
      int? numericId;
      try {
        numericId = int.parse(idNumber);
        print('Parsed ID number to integer: $numericId');
      } catch (e) {
        print('ID number is not a valid integer: $idNumber');
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'ID number must be a valid number.';
        notifyListeners();
        return false;
      }

      // Special case for user 30145 - always direct to pre-assessment
      if (idNumber == '30145') {
        print('Test user 30145 detected - directing to pre-assessment');

        // Create a minimal user for testing WITHOUT a reading level
        _currentUser = User(
          idNumber: '30145',
          name: 'Maria L. Santos',
          readingLevel: null, // Always null to force pre-assessment
          firstName: 'Maria',
          lastName: 'Santos',
          middleName: 'L.',
          age: 8,
          preAssessmentCompleted: false, // Mark as not completed
        );

        // Save this user to local database with null reading level
        try {
          await _databaseService.saveUserDataLocally(
            idNumber: '30145',
            name: 'Maria L. Santos',
            readingLevel: null, // Always null to force pre-assessment
          );
        } catch (e) {
          print('Error saving test user to local DB: $e');
        }

        // Set user ID in database service for future queries
        _databaseService.setCurrentUserId('30145');

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      // For all other users, proceed with normal authentication flow
      // First try to verify via repository (MongoDB)
      print('Attempting MongoDB authentication');
      bool isValid = false;

      try {
        isValid = await _userRepository.verifyLogin(idNumber);
        print('MongoDB login verification result: $isValid');
      } catch (e) {
        print('Error during MongoDB verification: $e');
        // Continue to local authentication
      }

      if (isValid) {
        // Get user details from MongoDB
        User? user;
        try {
          user = await _userRepository.getUserByIdNumber(idNumber);
          print('Retrieved user from MongoDB: ${user?.name}');
        } catch (e) {
          print('Error retrieving user from MongoDB: $e');
          // Continue to try local authentication
        }

        if (user != null) {
          _currentUser = user;

          // Set user ID in database service for future queries
          _databaseService.setCurrentUserId(idNumber);

          // Save to local DB for offline login
          try {
            await _databaseService.saveUserDataLocally(
              idNumber: idNumber,
              name: _currentUser?.name,
              readingLevel: _currentUser?.readingLevel,
            );
          } catch (e) {
            print('Error saving to local DB: $e');
            // Not critical, continue
          }

          _status = AuthStatus.authenticated;
          notifyListeners();
          return true;
        }
      }

      // If MongoDB login failed, try local database
      print('MongoDB login failed, trying local database');
      Map<String, dynamic>? localUser;

      try {
        localUser = await _databaseService.getUserFromLocalDb(idNumber);
      } catch (e) {
        print('Error accessing local DB: $e');
        // Continue to hardcoded fallback
      }

      if (localUser != null) {
        print('Found user in local database: $localUser');

        // Create a User object from local data
        try {
          _currentUser = User(
            idNumber: idNumber,
            name: localUser['name'] as String?,
            readingLevel: localUser['readingLevel'] as String?,
          );

          // Set user ID in database service for future queries
          _databaseService.setCurrentUserId(idNumber);

          print('Created user from local data: ${_currentUser?.name}');
          _status = AuthStatus.authenticated;
          notifyListeners();

          // Return success for local authentication
          return true;
        } catch (e) {
          print('Error creating user from local data: $e');
          // Continue to hardcoded fallback
        }
      }

      // If we get here, authentication failed
      _status = AuthStatus.unauthenticated;
      _errorMessage =
          'Invalid ID number. Please check with your administrator.';
      notifyListeners();
      return false;
    } catch (e) {
      print('Login error: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Login error: $e';
      notifyListeners();
      return false;
    }
  }

  // Update completed lessons
  Future<bool> updateCompletedLesson(int lessonNumber) async {
    if (_currentUser == null) return false;

    try {
      final success = await _userRepository.updateCompletedLesson(
        _currentUser!.idNumber,
        lessonNumber,
      );

      if (success) {
        // Update local user object with the new completed lesson
        final updatedLessons = List<int>.from(
          _currentUser!.completedLessons ?? [],
        );
        if (!updatedLessons.contains(lessonNumber)) {
          updatedLessons.add(lessonNumber);
        }

        _currentUser = _currentUser!.copyWith(completedLessons: updatedLessons);
        notifyListeners();
      }

      return success;
    } catch (e) {
      print('Error updating completed lesson: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    // Clear the current user ID in database service
    _databaseService.setCurrentUserId('');
    notifyListeners();
  }

  // Method to update user reading level
  Future<bool> updateUserReadingLevel(String readingLevel) async {
    if (currentUser == null) return false;

    try {
      // Create a new user model with updated reading level
      final updatedUser = currentUser!.copyWith(readingLevel: readingLevel);

      // Update the current user
      _currentUser = updatedUser;

      // Update in database following the guide's structure
      if (_databaseService.isConnected) {
        final usersCollection = _databaseService.getCollection('users');

        // Convert userId to appropriate type
        dynamic userIdValue;
        try {
          userIdValue = int.parse(currentUser!.idNumber);
        } catch (e) {
          userIdValue = currentUser!.idNumber;
        }

        // Update user document with new reading level
        final result = await usersCollection.updateOne(
            where.eq('idNumber', userIdValue),
            modify
                .set('readingLevel', readingLevel)
                .set('lastAssessmentDate', DateTime.now().toIso8601String())
                .set('updatedAt', DateTime.now().toIso8601String()));

        print(
            '[AuthProvider] Updated user reading level in database: $readingLevel (Success: ${result.isSuccess})');
      }

      // Also save locally for offline access
      await _databaseService.saveUserDataLocally(
        idNumber: currentUser!.idNumber,
        readingLevel: readingLevel,
      );

      print(
          '[AuthProvider] Updated user reading level in memory: $readingLevel');
      notifyListeners();
      return true;
    } catch (e) {
      print('[AuthProvider] Error updating reading level: $e');
      return false;
    }
  }

  // Update reading level from assessment results
  Future<bool> updateReadingLevelFromAssessment(String readingLevel) async {
    if (_currentUser == null) return false;

    try {
      // Update using the guide's structure
      if (_databaseService.isConnected) {
        final usersCollection = _databaseService.getCollection('users');

        // Convert ID to appropriate type
        dynamic idValue;
        try {
          idValue = int.parse(_currentUser!.idNumber);
        } catch (e) {
          idValue = _currentUser!.idNumber;
        }

        // Update in MongoDB following the guide's structure
        await usersCollection.updateOne(
          where.eq('idNumber', idValue),
          modify
              .set('readingLevel', readingLevel)
              .set('lastAssessmentDate', DateTime.now().toIso8601String()),
        );
      }

      // Also update in memory
      _currentUser = _currentUser!.copyWith(readingLevel: readingLevel);

      // Save locally for offline access
      await _databaseService.saveUserDataLocally(
        idNumber: _currentUser!.idNumber,
        readingLevel: readingLevel,
      );

      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating reading level: $e');
      return false;
    }
  }

  // Update pre-assessment completion status in memory
  void setPreAssessmentCompleted(bool completed) {
    if (currentUser != null) {
      // Create a new user model with updated pre-assessment completion status
      final updatedUser =
          currentUser!.copyWith(preAssessmentCompleted: completed);

      // Update the current user
      _currentUser = updatedUser;

      print(
          '[AuthProvider] Updated user pre-assessment completion status: $completed');
      notifyListeners();
    }
  }

  // Update reading percentage
  void updateReadingPercentage(double percentage) {
    if (currentUser != null) {
      // Create a new user model with updated reading percentage
      final updatedUser = currentUser!.copyWith(readingPercentage: percentage);

      // Update the current user
      _currentUser = updatedUser;

      print(
          '[AuthProvider] Updated user reading percentage in memory: $percentage%');
      notifyListeners();
    }
  }

  // Update completed lessons list
  Future<void> updateCompletedLessons(dynamic lessonId) async {
    if (currentUser == null) return;

    // Get the current completed lessons
    final List<dynamic> currentCompletedLessons =
        List.from(currentUser?.completedLessons ?? []);

    // Check if lesson is already marked as completed
    if (!currentCompletedLessons.contains(lessonId) &&
        !currentCompletedLessons.contains(lessonId.toString())) {
      // Add the lesson ID to completed lessons
      currentCompletedLessons.add(lessonId);

      // Update in database if possible
      try {
        if (_databaseService.isConnected) {
          // Update in MongoDB
          final usersCollection = _databaseService.getCollection('users');

          // Use the user ID from the current user
          final userId = currentUser!.idNumber;

          // Convert userId to appropriate type
          dynamic userIdValue;
          try {
            userIdValue = int.parse(userId);
          } catch (e) {
            userIdValue = userId;
          }

          // Update the completedLessons field in the database
          await usersCollection.updateOne(
            where.eq('idNumber', userIdValue),
            modify.set('completedLessons', currentCompletedLessons),
          );

          print('Updated completed lessons in MongoDB for user $userId');
        }

        // Update local database
        await _databaseService.saveUserDataLocally(
          idNumber: currentUser!.idNumber,
          name: currentUser!.name ?? '',
          readingLevel: currentUser!.readingLevel ?? '',
        );

        // Update current user in memory
        _currentUser = _currentUser!
            .copyWith(completedLessons: currentCompletedLessons.cast<int>());

        print('Updated completed lessons for user ${currentUser!.idNumber}');
        notifyListeners();
      } catch (e) {
        print('Error updating completed lessons: $e');
      }
    }
  }

  // Update user name
  Future<void> updateUserName(String name) async {
    if (currentUser == null) return;

    try {
      // Update the user's name in the database first
      if (_databaseService.isConnected) {
        final collection = _databaseService.getCollection('users');

        // Convert to appropriate type
        dynamic userIdValue;
        try {
          userIdValue = int.parse(currentUser!.idNumber);
        } catch (e) {
          userIdValue = currentUser!.idNumber;
        }

        // Create query based on ID number
        final query = where.eq('idNumber', userIdValue);

        await collection.updateOne(
          query,
          modify.set('name', name).set('firstName', name),
        );
      }

      // Update in local database
      await _databaseService.saveUserDataLocally(
        idNumber: currentUser!.idNumber,
        name: name,
        readingLevel: currentUser!.readingLevel,
      );

      // Update in memory
      _currentUser = _currentUser!.copyWith(name: name, firstName: name);

      notifyListeners();
    } catch (e) {
      print('Error updating user name: $e');
    }
  }

  // Check if user needs pre-assessment
  bool needsPreAssessment() {
    if (_currentUser == null) return true;

    // User needs pre-assessment if:
    // 1. Reading level is null, empty, or "Undefined"
    // 2. preAssessmentCompleted is false
    final noReadingLevel = _currentUser!.readingLevel == null ||
        _currentUser!.readingLevel!.isEmpty ||
        _currentUser!.readingLevel == 'Undefined';

    final notCompleted = _currentUser!.preAssessmentCompleted != true;

    return noReadingLevel || notCompleted;
  }
}
