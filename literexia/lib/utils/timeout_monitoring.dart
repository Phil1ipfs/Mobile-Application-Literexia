// lib/utils/timeout_monitoring.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../config/timeout_config.dart';

/// Monitoring service for tracking timeout performance and issues
///
/// This service collects metrics about timeout occurrences and
/// provides insights for optimization.
class TimeoutMonitoringService extends ChangeNotifier {
  static final TimeoutMonitoringService _instance = TimeoutMonitoringService._internal();
  factory TimeoutMonitoringService() => _instance;
  TimeoutMonitoringService._internal();

  // Metrics storage
  final Queue<TimeoutEvent> _recentEvents = Queue<TimeoutEvent>();
  final Map<String, OperationMetrics> _operationMetrics = {};
  final Map<String, int> _errorCounts = {};

  // Configuration
  static const int maxRecentEvents = 100;
  static const Duration metricsRetentionPeriod = Duration(hours: 24);

  // Getters
  List<TimeoutEvent> get recentEvents => _recentEvents.toList();
  Map<String, OperationMetrics> get operationMetrics => Map.unmodifiable(_operationMetrics);
  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);

  /// Record a timeout event
  void recordTimeoutEvent({
    required String operationName,
    required Duration timeout,
    required Duration actualDuration,
    required TimeoutEventType eventType,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) {
    final event = TimeoutEvent(
      operationName: operationName,
      timeout: timeout,
      actualDuration: actualDuration,
      eventType: eventType,
      timestamp: DateTime.now(),
      errorMessage: errorMessage,
      additionalData: additionalData,
    );

    // Add to recent events
    _recentEvents.addLast(event);
    if (_recentEvents.length > maxRecentEvents) {
      _recentEvents.removeFirst();
    }

    // Update operation metrics
    _updateOperationMetrics(event);

    // Update error counts
    if (eventType == TimeoutEventType.timeout || eventType == TimeoutEventType.error) {
      final key = errorMessage ?? 'Unknown Error';
      _errorCounts[key] = (_errorCounts[key] ?? 0) + 1;
    }

    // Clean old metrics
    _cleanOldMetrics();

    notifyListeners();

    // Log significant events
    if (eventType == TimeoutEventType.timeout) {
      debugPrint('[TimeoutMonitoring] TIMEOUT: $operationName after ${actualDuration.inSeconds}s (limit: ${timeout.inSeconds}s)');
    } else if (eventType == TimeoutEventType.slowOperation) {
      debugPrint('[TimeoutMonitoring] SLOW: $operationName took ${actualDuration.inSeconds}s');
    }
  }

  void _updateOperationMetrics(TimeoutEvent event) {
    final metrics = _operationMetrics[event.operationName] ??= OperationMetrics(
      operationName: event.operationName,
    );

    metrics.totalCalls++;
    metrics.totalDuration += event.actualDuration;

    switch (event.eventType) {
      case TimeoutEventType.success:
        metrics.successCount++;
        break;
      case TimeoutEventType.timeout:
        metrics.timeoutCount++;
        break;
      case TimeoutEventType.error:
        metrics.errorCount++;
        break;
      case TimeoutEventType.retry:
        metrics.retryCount++;
        break;
      case TimeoutEventType.slowOperation:
        metrics.slowOperationCount++;
        break;
    }

    // Update min/max durations
    if (metrics.minDuration == null || event.actualDuration < metrics.minDuration!) {
      metrics.minDuration = event.actualDuration;
    }
    if (metrics.maxDuration == null || event.actualDuration > metrics.maxDuration!) {
      metrics.maxDuration = event.actualDuration;
    }

    metrics.lastUpdated = DateTime.now();
  }

  void _cleanOldMetrics() {
    final cutoff = DateTime.now().subtract(metricsRetentionPeriod);

    // Remove old events
    _recentEvents.removeWhere((event) => event.timestamp.isBefore(cutoff));

    // Clean old operation metrics
    _operationMetrics.removeWhere((key, metrics) =>
        metrics.lastUpdated.isBefore(cutoff));
  }

  /// Get performance summary for an operation
  PerformanceSummary getPerformanceSummary(String operationName) {
    final metrics = _operationMetrics[operationName];
    if (metrics == null) {
      return PerformanceSummary(
        operationName: operationName,
        isHealthy: true,
        message: 'No data available',
      );
    }

    final successRate = metrics.totalCalls > 0
        ? (metrics.successCount / metrics.totalCalls) * 100
        : 0.0;

    final avgDuration = metrics.totalCalls > 0
        ? Duration(milliseconds: metrics.totalDuration.inMilliseconds ~/ metrics.totalCalls)
        : Duration.zero;

    final timeoutRate = metrics.totalCalls > 0
        ? (metrics.timeoutCount / metrics.totalCalls) * 100
        : 0.0;

    // Determine health status
    bool isHealthy = true;
    String message = 'Operating normally';

    if (timeoutRate > 10) {
      isHealthy = false;
      message = 'High timeout rate: ${timeoutRate.toStringAsFixed(1)}%';
    } else if (successRate < 90) {
      isHealthy = false;
      message = 'Low success rate: ${successRate.toStringAsFixed(1)}%';
    } else if (avgDuration > TimeoutConfig.getTimeoutForOperation(operationName) * 0.8) {
      isHealthy = false;
      message = 'Slow performance: avg ${avgDuration.inSeconds}s';
    }

    return PerformanceSummary(
      operationName: operationName,
      successRate: successRate,
      averageDuration: avgDuration,
      timeoutRate: timeoutRate,
      totalCalls: metrics.totalCalls,
      isHealthy: isHealthy,
      message: message,
    );
  }

  /// Get overall system health
  SystemHealth getSystemHealth() {
    if (_operationMetrics.isEmpty) {
      return SystemHealth(
        overallHealth: HealthStatus.healthy,
        message: 'No operations recorded yet',
        criticalOperations: [],
        recommendations: [],
      );
    }

    final summaries = _operationMetrics.keys
        .map((op) => getPerformanceSummary(op))
        .toList();

    final unhealthyOps = summaries.where((s) => !s.isHealthy).toList();
    final criticalOps = summaries.where((s) => s.timeoutRate > 20 || s.successRate < 80).toList();

    HealthStatus overallHealth;
    String message;
    List<String> recommendations = [];

    if (criticalOps.isNotEmpty) {
      overallHealth = HealthStatus.critical;
      message = '${criticalOps.length} operations are critically degraded';
      recommendations.addAll([
        'Check network connectivity',
        'Review timeout configurations',
        'Monitor server performance',
      ]);
    } else if (unhealthyOps.isNotEmpty) {
      overallHealth = HealthStatus.degraded;
      message = '${unhealthyOps.length} operations are experiencing issues';
      recommendations.addAll([
        'Monitor affected operations',
        'Consider increasing timeout values',
      ]);
    } else {
      overallHealth = HealthStatus.healthy;
      message = 'All operations are performing normally';
    }

    // Add specific recommendations based on error patterns
    final commonErrors = _getCommonErrors();
    if (commonErrors.contains('Network')) {
      recommendations.add('Enable network recovery mechanisms');
    }
    if (commonErrors.contains('Database')) {
      recommendations.add('Optimize database queries');
    }

    return SystemHealth(
      overallHealth: overallHealth,
      message: message,
      criticalOperations: criticalOps.map((s) => s.operationName).toList(),
      recommendations: recommendations,
    );
  }

  List<String> _getCommonErrors() {
    return _errorCounts.entries
        .where((e) => e.value > 5)
        .map((e) => e.key)
        .toList();
  }

  /// Generate monitoring report
  MonitoringReport generateReport() {
    final systemHealth = getSystemHealth();
    final recentTimeouts = _recentEvents
        .where((e) => e.eventType == TimeoutEventType.timeout)
        .length;

    final topSlowOperations = _operationMetrics.entries
        .map((e) => getPerformanceSummary(e.key))
        .where((s) => s.averageDuration != null)
        .toList()
      ..sort((a, b) => b.averageDuration!.compareTo(a.averageDuration!));

    return MonitoringReport(
      generatedAt: DateTime.now(),
      systemHealth: systemHealth,
      totalOperations: _operationMetrics.length,
      recentTimeouts: recentTimeouts,
      topSlowOperations: topSlowOperations.take(5).toList(),
      errorBreakdown: Map.from(_errorCounts),
    );
  }

  /// Reset all metrics (for testing or maintenance)
  void resetMetrics() {
    _recentEvents.clear();
    _operationMetrics.clear();
    _errorCounts.clear();
    notifyListeners();
  }

  /// Export metrics for external analysis
  Map<String, dynamic> exportMetrics() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'recentEvents': _recentEvents.map((e) => e.toJson()).toList(),
      'operationMetrics': _operationMetrics.map((k, v) => MapEntry(k, v.toJson())),
      'errorCounts': _errorCounts,
      'systemHealth': getSystemHealth().toJson(),
    };
  }
}

/// Extension to automatically monitor timeout operations
extension TimeoutMonitoring<T> on Future<T> {
  Future<T> withMonitoring(String operationName) async {
    final monitor = TimeoutMonitoringService();
    final stopwatch = Stopwatch()..start();

    try {
      final result = await this;
      stopwatch.stop();

      final duration = stopwatch.elapsed;
      final expectedTimeout = TimeoutConfig.getTimeoutForOperation(operationName);

      // Record success
      monitor.recordTimeoutEvent(
        operationName: operationName,
        timeout: expectedTimeout,
        actualDuration: duration,
        eventType: TimeoutEventType.success,
      );

      // Check if operation was slow
      if (duration > expectedTimeout * 0.8) {
        monitor.recordTimeoutEvent(
          operationName: operationName,
          timeout: expectedTimeout,
          actualDuration: duration,
          eventType: TimeoutEventType.slowOperation,
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      final eventType = e is TimeoutException
          ? TimeoutEventType.timeout
          : TimeoutEventType.error;

      monitor.recordTimeoutEvent(
        operationName: operationName,
        timeout: TimeoutConfig.getTimeoutForOperation(operationName),
        actualDuration: stopwatch.elapsed,
        eventType: eventType,
        errorMessage: e.toString(),
      );

      rethrow;
    }
  }
}

// Data classes

class TimeoutEvent {
  final String operationName;
  final Duration timeout;
  final Duration actualDuration;
  final TimeoutEventType eventType;
  final DateTime timestamp;
  final String? errorMessage;
  final Map<String, dynamic>? additionalData;

  TimeoutEvent({
    required this.operationName,
    required this.timeout,
    required this.actualDuration,
    required this.eventType,
    required this.timestamp,
    this.errorMessage,
    this.additionalData,
  });

  Map<String, dynamic> toJson() => {
    'operationName': operationName,
    'timeout': timeout.inMilliseconds,
    'actualDuration': actualDuration.inMilliseconds,
    'eventType': eventType.toString(),
    'timestamp': timestamp.toIso8601String(),
    'errorMessage': errorMessage,
    'additionalData': additionalData,
  };
}

enum TimeoutEventType {
  success,
  timeout,
  error,
  retry,
  slowOperation,
}

class OperationMetrics {
  final String operationName;
  int totalCalls = 0;
  int successCount = 0;
  int timeoutCount = 0;
  int errorCount = 0;
  int retryCount = 0;
  int slowOperationCount = 0;
  Duration totalDuration = Duration.zero;
  Duration? minDuration;
  Duration? maxDuration;
  DateTime lastUpdated = DateTime.now();

  OperationMetrics({required this.operationName});

  Map<String, dynamic> toJson() => {
    'operationName': operationName,
    'totalCalls': totalCalls,
    'successCount': successCount,
    'timeoutCount': timeoutCount,
    'errorCount': errorCount,
    'retryCount': retryCount,
    'slowOperationCount': slowOperationCount,
    'totalDuration': totalDuration.inMilliseconds,
    'minDuration': minDuration?.inMilliseconds,
    'maxDuration': maxDuration?.inMilliseconds,
    'lastUpdated': lastUpdated.toIso8601String(),
  };
}

class PerformanceSummary {
  final String operationName;
  final double successRate;
  final Duration? averageDuration;
  final double timeoutRate;
  final int totalCalls;
  final bool isHealthy;
  final String message;

  PerformanceSummary({
    required this.operationName,
    this.successRate = 0.0,
    this.averageDuration,
    this.timeoutRate = 0.0,
    this.totalCalls = 0,
    required this.isHealthy,
    required this.message,
  });
}

enum HealthStatus { healthy, degraded, critical }

class SystemHealth {
  final HealthStatus overallHealth;
  final String message;
  final List<String> criticalOperations;
  final List<String> recommendations;

  SystemHealth({
    required this.overallHealth,
    required this.message,
    required this.criticalOperations,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'overallHealth': overallHealth.toString(),
    'message': message,
    'criticalOperations': criticalOperations,
    'recommendations': recommendations,
  };
}

class MonitoringReport {
  final DateTime generatedAt;
  final SystemHealth systemHealth;
  final int totalOperations;
  final int recentTimeouts;
  final List<PerformanceSummary> topSlowOperations;
  final Map<String, int> errorBreakdown;

  MonitoringReport({
    required this.generatedAt,
    required this.systemHealth,
    required this.totalOperations,
    required this.recentTimeouts,
    required this.topSlowOperations,
    required this.errorBreakdown,
  });

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'systemHealth': systemHealth.toJson(),
    'totalOperations': totalOperations,
    'recentTimeouts': recentTimeouts,
    'topSlowOperations': topSlowOperations.map((s) => {
      'operationName': s.operationName,
      'averageDuration': s.averageDuration?.inMilliseconds,
      'successRate': s.successRate,
      'timeoutRate': s.timeoutRate,
    }).toList(),
    'errorBreakdown': errorBreakdown,
  };
}