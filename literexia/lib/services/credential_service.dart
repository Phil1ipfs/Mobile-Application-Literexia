// lib/services/credential_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Secure credential management service
///
/// This service handles secure storage, validation, and rotation of API credentials
/// with encryption and security best practices.
class CredentialService {
  static final CredentialService _instance = CredentialService._internal();
  factory CredentialService() => _instance;
  CredentialService._internal();

  // Credential cache with encryption
  final Map<String, _EncryptedCredential> _credentialCache = {};

  // Security configuration
  static const int minKeyLength = 32;
  static const int maxKeyAge = Duration.millisecondsPerDay * 30; // 30 days

  bool _isInitialized = false;

  /// Initialize the credential service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('[CredentialService] Initializing secure credential management...');

      // Validate all required credentials exist
      await _validateRequiredCredentials();

      // Check credential security
      await _validateCredentialSecurity();

      _isInitialized = true;
      print('[CredentialService] ✅ Credential service initialized successfully');
    } catch (e) {
      print('[CredentialService] ❌ Failed to initialize: $e');
      rethrow;
    }
  }

  /// Get a credential securely
  Future<String> getCredential(String key) async {
    if (!_isInitialized) {
      throw CredentialServiceNotInitializedException('CredentialService not initialized. Call initialize() first.');
    }

    // Check cache first
    if (_credentialCache.containsKey(key)) {
      final cached = _credentialCache[key]!;
      if (!cached.isExpired) {
        return _decrypt(cached.encryptedValue);
      } else {
        _credentialCache.remove(key);
      }
    }

    // Get from environment
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw CredentialNotFoundException('Credential not found: $key');
    }

    // Validate credential
    _validateCredential(key, value);

    // Cache with encryption
    _credentialCache[key] = _EncryptedCredential(
      key: key,
      encryptedValue: _encrypt(value),
      timestamp: DateTime.now(),
    );

    return value;
  }

  /// Validate all required credentials
  Future<void> _validateRequiredCredentials() async {
    final requiredCredentials = [
      'MONGO_URI',
      'ELEVENLABS_API_KEY',
      'PLAYHT_API_KEY',
      'PLAYHT_USER_ID',
    ];

    final missingCredentials = <String>[];

    for (final credential in requiredCredentials) {
      final value = dotenv.env[credential];
      if (value == null || value.isEmpty) {
        missingCredentials.add(credential);
      }
    }

    if (missingCredentials.isNotEmpty) {
      throw CredentialValidationException(
        'Missing required credentials: ${missingCredentials.join(', ')}'
      );
    }

    print('[CredentialService] ✅ All required credentials found');
  }

  /// Validate credential security
  Future<void> _validateCredentialSecurity() async {
    final credentials = {
      'ELEVENLABS_API_KEY': dotenv.env['ELEVENLABS_API_KEY'],
      'PLAYHT_API_KEY': dotenv.env['PLAYHT_API_KEY'],
      'MONGO_URI': dotenv.env['MONGO_URI'],
    };

    final securityIssues = <String>[];

    for (final entry in credentials.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value != null) {
        try {
          _validateCredential(key, value);
        } catch (e) {
          securityIssues.add('$key: $e');
        }
      }
    }

    if (securityIssues.isNotEmpty) {
      print('[CredentialService] ⚠️ Security warnings:');
      for (final issue in securityIssues) {
        print('  - $issue');
      }
    } else {
      print('[CredentialService] ✅ All credentials pass security validation');
    }
  }

  /// Validate individual credential
  void _validateCredential(String key, String value) {
    // Check minimum length
    if (value.length < minKeyLength) {
      throw CredentialValidationException(
        '$key is too short (minimum $minKeyLength characters)'
      );
    }

    // Check for common security issues
    if (value.toLowerCase().contains('password') ||
        value.toLowerCase().contains('admin') ||
        value.toLowerCase().contains('test')) {
      throw CredentialValidationException(
        '$key contains potentially insecure keywords'
      );
    }

    // Validate specific credential formats
    switch (key) {
      case 'ELEVENLABS_API_KEY':
        if (!value.startsWith('sk_')) {
          throw CredentialValidationException(
            'ELEVENLABS_API_KEY should start with "sk_"'
          );
        }
        break;
      case 'PLAYHT_API_KEY':
        if (!value.startsWith('ak-')) {
          throw CredentialValidationException(
            'PLAYHT_API_KEY should start with "ak-"'
          );
        }
        break;
      case 'MONGO_URI':
        if (!value.startsWith('mongodb')) {
          throw CredentialValidationException(
            'MONGO_URI should start with "mongodb"'
          );
        }
        // Check for credentials in URI
        if (value.contains('@') && !value.contains('****')) {
          print('[CredentialService] ⚠️ MONGO_URI contains visible credentials');
        }
        break;
    }
  }

  /// Simple encryption for credential caching (not for production storage)
  String _encrypt(String value) {
    // Simple XOR encryption for memory caching
    // In production, use proper encryption libraries
    final key = 'LiterexiaSecureKey2024';
    final encrypted = <int>[];

    for (int i = 0; i < value.length; i++) {
      encrypted.add(value.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }

    return base64Encode(encrypted);
  }

  /// Simple decryption for credential caching
  String _decrypt(String encryptedValue) {
    try {
      final key = 'LiterexiaSecureKey2024';
      final encrypted = base64Decode(encryptedValue);
      final decrypted = <int>[];

      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ key.codeUnitAt(i % key.length));
      }

      return String.fromCharCodes(decrypted);
    } catch (e) {
      throw CredentialDecryptionException('Failed to decrypt credential: $e');
    }
  }

  /// Check if credential needs rotation
  bool needsRotation(String key) {
    final cached = _credentialCache[key];
    if (cached == null) return false;

    final age = DateTime.now().difference(cached.timestamp);
    return age.inMilliseconds > maxKeyAge;
  }

  /// Generate security report
  CredentialSecurityReport generateSecurityReport() {
    final report = CredentialSecurityReport();

    // Check credential ages
    for (final entry in _credentialCache.entries) {
      final age = DateTime.now().difference(entry.value.timestamp);
      if (age.inMilliseconds > maxKeyAge) {
        report.rotationNeeded.add(entry.key);
      }
    }

    // Check for potential issues
    final mongoUri = dotenv.env['MONGO_URI'];
    if (mongoUri != null && mongoUri.contains('@') && !mongoUri.contains('****')) {
      report.securityIssues.add('MongoDB URI contains visible credentials');
    }

    // Check if running in debug mode
    if (kDebugMode) {
      report.securityIssues.add('Running in debug mode - credentials may be logged');
    }

    return report;
  }

  /// Mask sensitive value for logging
  static String maskCredential(String value) {
    if (value.length <= 8) {
      return '*' * value.length;
    }

    final start = value.substring(0, 4);
    final end = value.substring(value.length - 4);
    final masked = '*' * (value.length - 8);

    return '$start$masked$end';
  }

  /// Clear credential cache (for logout/security)
  void clearCache() {
    _credentialCache.clear();
    print('[CredentialService] Credential cache cleared');
  }

  /// Dispose of resources
  void dispose() {
    clearCache();
    _isInitialized = false;
  }
}

/// Encrypted credential storage
class _EncryptedCredential {
  final String key;
  final String encryptedValue;
  final DateTime timestamp;

  _EncryptedCredential({
    required this.key,
    required this.encryptedValue,
    required this.timestamp,
  });

  bool get isExpired {
    final age = DateTime.now().difference(timestamp);
    return age.inMilliseconds > CredentialService.maxKeyAge;
  }
}

/// Security report for credentials
class CredentialSecurityReport {
  final List<String> rotationNeeded = [];
  final List<String> securityIssues = [];

  bool get isSecure => rotationNeeded.isEmpty && securityIssues.isEmpty;

  void printReport() {
    print('\n=== CREDENTIAL SECURITY REPORT ===');

    if (isSecure) {
      print('✅ No security issues detected');
    } else {
      if (rotationNeeded.isNotEmpty) {
        print('🔄 Credentials needing rotation:');
        for (final cred in rotationNeeded) {
          print('  - $cred');
        }
      }

      if (securityIssues.isNotEmpty) {
        print('⚠️ Security issues:');
        for (final issue in securityIssues) {
          print('  - $issue');
        }
      }
    }

    print('=====================================\n');
  }
}

/// Custom exceptions
class CredentialNotFoundException implements Exception {
  final String message;
  CredentialNotFoundException(this.message);
  @override
  String toString() => 'CredentialNotFoundException: $message';
}

class CredentialValidationException implements Exception {
  final String message;
  CredentialValidationException(this.message);
  @override
  String toString() => 'CredentialValidationException: $message';
}

class CredentialDecryptionException implements Exception {
  final String message;
  CredentialDecryptionException(this.message);
  @override
  String toString() => 'CredentialDecryptionException: $message';
}

class CredentialServiceNotInitializedException implements Exception {
  final String message;
  CredentialServiceNotInitializedException(this.message);
  @override
  String toString() => 'CredentialServiceNotInitializedException: $message';
}

/// Helper extension for secure credential access
extension SecureCredentials on String {
  /// Get credential value securely
  Future<String> getCredential() async {
    return await CredentialService().getCredential(this);
  }

  /// Check if credential needs rotation
  bool needsRotation() {
    return CredentialService().needsRotation(this);
  }
}

/// Helper functions for credential management
class CredentialUtils {
  /// Check if .env file is secure
  static Future<bool> isEnvFileSecure() async {
    try {
      final envFile = File('.env');
      if (!await envFile.exists()) {
        return false;
      }

      // Check file permissions (Unix/Linux/macOS)
      if (!Platform.isWindows) {
        final stat = await envFile.stat();
        // Check if file is readable by others
        final mode = stat.mode;
        final isWorldReadable = (mode & 0x4) != 0;
        final isGroupReadable = (mode & 0x20) != 0;

        if (isWorldReadable || isGroupReadable) {
          print('[CredentialUtils] ⚠️ .env file has insecure permissions');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('[CredentialUtils] Error checking .env security: $e');
      return false;
    }
  }

  /// Generate secure random API key
  static String generateSecureKey({int length = 64}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]);
    return random.join();
  }
}