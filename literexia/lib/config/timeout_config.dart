// lib/config/timeout_config.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized timeout configuration for all network operations
///
/// This class provides consistent timeout values and utilities for
/// handling network timeouts across the entire application.
class TimeoutConfig {
  // =========================
  // TIMEOUT CONSTANTS
  // =========================

  /// Quick operations (ping, health checks)
  static const Duration quick = Duration(seconds: 5);

  /// Standard operations (login, API calls)
  static const Duration standard = Duration(seconds: 15);

  /// Long operations (file uploads, assessment saves)
  static const Duration long = Duration(seconds: 30);

  /// Critical operations (data sync, backup)
  static const Duration critical = Duration(seconds: 45);

  /// Connection timeout for HTTP clients
  static const Duration connection = Duration(seconds: 8);

  /// TTS API calls
  static const Duration tts = Duration(seconds: 20);

  /// Database operations
  static const Duration database = Duration(seconds: 25);

  /// Assessment data operations
  static const Duration assessment = Duration(seconds: 30);

  // =========================
  // RETRY CONFIGURATION
  // =========================

  /// Number of retry attempts for failed operations
  static const int maxRetries = 3;

  /// Delay between retry attempts
  static const Duration retryDelay = Duration(seconds: 2);

  /// Exponential backoff multiplier
  static const double backoffMultiplier = 1.5;

  // =========================
  // TIMEOUT UTILITIES
  // =========================

  /// Wrap any Future with a consistent timeout and error handling
  static Future<T> withTimeout<T>(
    Future<T> future, {
    Duration? timeout,
    String? operationName,
    VoidCallback? onTimeout,
  }) async {
    final effectiveTimeout = timeout ?? standard;
    final operation = operationName ?? 'Operation';

    try {
      return await future.timeout(
        effectiveTimeout,
        onTimeout: () {
          print('[$operation] Timeout after ${effectiveTimeout.inSeconds}s');
          if (onTimeout != null) onTimeout();
          throw TimeoutException(
            '$operation timed out after ${effectiveTimeout.inSeconds} seconds',
            effectiveTimeout,
          );
        },
      );
    } catch (e) {
      if (e is TimeoutException) {
        print('[$operation] TimeoutException: ${e.message}');
        rethrow;
      } else {
        print('[$operation] Unexpected error: $e');
        rethrow;
      }
    }
  }

  /// Wrap Future with retry logic and timeout
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    int? maxAttempts,
    Duration? retryInterval,
    String? operationName,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    final effectiveTimeout = timeout ?? standard;
    final attempts = maxAttempts ?? maxRetries;
    final interval = retryInterval ?? retryDelay;
    final name = operationName ?? 'Operation';

    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        print('[$name] Attempt $attempt/$attempts');

        return await withTimeout(
          operation(),
          timeout: effectiveTimeout,
          operationName: '$name (attempt $attempt)',
        );
      } catch (e) {
        print('[$name] Attempt $attempt failed: $e');

        // Don't retry on the last attempt
        if (attempt == attempts) {
          print('[$name] All $attempts attempts failed');
          rethrow;
        }

        // Check if we should retry this specific error
        if (shouldRetry != null && !shouldRetry(e)) {
          print('[$name] Error not retryable, aborting');
          rethrow;
        }

        // Wait before next attempt with exponential backoff
        final delay = Duration(
          milliseconds:
              (interval.inMilliseconds * (backoffMultiplier * (attempt - 1)))
                  .round(),
        );

        print('[$name] Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
      }
    }

    // This should never be reached
    throw StateError('Retry logic error');
  }

  /// Configure HTTP client with consistent timeout settings
  static void configureHttpClient(HttpClient client, {Duration? timeout}) {
    final effectiveTimeout = timeout ?? connection;
    client.connectionTimeout = effectiveTimeout;
    client.idleTimeout = Duration(seconds: effectiveTimeout.inSeconds + 5);
  }

  /// Check if an error is network-related and retryable
  static bool isRetryableError(dynamic error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is HttpException) return true;

    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable') ||
        errorString.contains('dns');
  }

  /// Get appropriate timeout for operation type
  static Duration getTimeoutForOperation(String operationType) {
    switch (operationType.toLowerCase()) {
      case 'ping':
      case 'health':
      case 'check':
        return quick;
      case 'login':
      case 'auth':
      case 'api':
        return standard;
      case 'upload':
      case 'download':
      case 'save':
        return long;
      case 'sync':
      case 'backup':
      case 'critical':
        return critical;
      case 'tts':
      case 'speech':
        return tts;
      case 'database':
      case 'db':
        return database;
      case 'assessment':
        return assessment;
      default:
        return standard;
    }
  }

  /// Create a timeout handler with user-friendly messages
  static TimeoutHandler createHandler({
    required String operationName,
    String? userMessage,
    VoidCallback? onTimeout,
    VoidCallback? onRetry,
  }) {
    return TimeoutHandler._(
      operationName: operationName,
      userMessage: userMessage,
      onTimeout: onTimeout,
      onRetry: onRetry,
    );
  }
}

/// Helper class for handling timeout scenarios with user feedback
class TimeoutHandler {
  final String operationName;
  final String? userMessage;
  final VoidCallback? onTimeout;
  final VoidCallback? onRetry;

  const TimeoutHandler._({
    required this.operationName,
    this.userMessage,
    this.onTimeout,
    this.onRetry,
  });

  /// Get user-friendly timeout message
  String getUserMessage() {
    return userMessage ?? _getDefaultMessage();
  }

  String _getDefaultMessage() {
    switch (operationName.toLowerCase()) {
      case 'login':
        return 'Login is taking longer than expected. Please check your internet connection and try again.';
      case 'assessment':
        return 'Saving your assessment is taking longer than expected. Please wait or try again.';
      case 'tts':
        return 'Audio is taking longer to load. Please check your connection.';
      case 'database':
        return 'Database operation timed out. Please try again.';
      default:
        return 'Operation timed out. Please check your internet connection and try again.';
    }
  }

  /// Handle timeout occurrence
  void handleTimeout() {
    print('Timeout occurred for: $operationName');
    if (onTimeout != null) {
      onTimeout!();
    }
  }

  /// Handle retry attempt
  void handleRetry() {
    print('Retrying: $operationName');
    if (onRetry != null) {
      onRetry!();
    }
  }
}

/// Exception class for timeout-related errors with context
class LiterexiaTimeoutException implements Exception {
  final String operation;
  final Duration timeout;
  final String userMessage;
  final bool isRetryable;

  const LiterexiaTimeoutException({
    required this.operation,
    required this.timeout,
    required this.userMessage,
    this.isRetryable = true,
  });

  @override
  String toString() {
    return 'LiterexiaTimeoutException: $operation timed out after ${timeout.inSeconds}s - $userMessage';
  }
}
