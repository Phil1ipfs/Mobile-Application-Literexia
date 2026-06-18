// lib/widgets/timeout_indicator.dart
import 'package:flutter/material.dart';
import '../config/timeout_config.dart';
import '../services/network_recovery_service.dart';

/// Widget to display timeout status and recovery information
///
/// This widget provides visual feedback to users about operation
/// timeouts and network recovery status.
class TimeoutIndicator extends StatefulWidget {
  final String operationName;
  final bool isVisible;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final Duration? customTimeout;
  final String? customMessage;

  const TimeoutIndicator({
    super.key,
    required this.operationName,
    this.isVisible = false,
    this.onRetry,
    this.onCancel,
    this.customTimeout,
    this.customMessage,
  });

  @override
  State<TimeoutIndicator> createState() => _TimeoutIndicatorState();
}

class _TimeoutIndicatorState extends State<TimeoutIndicator>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  NetworkRecoveryService? _recoveryService;
  bool _showRetryButton = false;
  String _statusMessage = '';
  Color _indicatorColor = Colors.blue;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _progressController = AnimationController(
      duration: widget.customTimeout ?? TimeoutConfig.standard,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Set up animations
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Initialize recovery service
    _recoveryService = NetworkRecoveryService();
    _recoveryService?.addListener(_onRecoveryStatusChanged);

    // Set initial status
    _updateStatus();

    // Start animations if visible
    if (widget.isVisible) {
      _startTimeout();
    }
  }

  @override
  void didUpdateWidget(TimeoutIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _startTimeout();
      } else {
        _stopTimeout();
      }
    }

    if (widget.operationName != oldWidget.operationName) {
      _updateStatus();
    }
  }

  void _startTimeout() {
    _showRetryButton = false;
    _indicatorColor = Colors.blue;
    _updateStatus();

    // Start progress animation
    _progressController.reset();
    _progressController.forward();

    // Start pulse animation
    _pulseController.repeat(reverse: true);

    // Set timeout callback
    _progressController.addStatusListener(_onProgressComplete);
  }

  void _stopTimeout() {
    _progressController.stop();
    _pulseController.stop();
    _progressController.removeStatusListener(_onProgressComplete);
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _showRetryButton = true;
        _indicatorColor = Colors.orange;
        _statusMessage = _getTimeoutMessage();
      });
      _pulseController.stop();
    }
  }

  void _onRecoveryStatusChanged() {
    if (_recoveryService != null && mounted) {
      setState(() {
        _updateStatus();
      });
    }
  }

  void _updateStatus() {
    if (_recoveryService == null) return;

    if (!_recoveryService!.isConnected) {
      _statusMessage = 'Walang internet.';
      _indicatorColor = Colors.red;
      _showRetryButton = true;
    } else if (_recoveryService!.isRecovering) {
      _statusMessage = 'Nagkokonekta ulit...';
      _indicatorColor = Colors.orange;
      _showRetryButton = false;
    } else if (_showRetryButton) {
      _statusMessage = _getTimeoutMessage();
      _indicatorColor = Colors.orange;
    } else {
      _statusMessage = widget.customMessage ?? 'Sandali lang...';
      _indicatorColor = Colors.blue;
    }
  }

  String _getTimeoutMessage() {
    final timeout = widget.customTimeout ?? TimeoutConfig.getTimeoutForOperation(widget.operationName);
    return widget.customMessage ??
           'Matagal ang pag-load. Tingnan ang internet mo.';
  }

  void _handleRetry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    }
    _startTimeout();
  }

  void _handleCancel() {
    _stopTimeout();
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with operation name
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Icon(
                      _getStatusIcon(),
                      color: _indicatorColor,
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.operationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_showRetryButton)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _indicatorColor,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar (only show when not timed out)
          if (!_showRetryButton)
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
                );
              },
            ),

          const SizedBox(height: 12),

          // Status message
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          // Action buttons
          if (_showRetryButton || widget.onCancel != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showRetryButton)
                  ElevatedButton.icon(
                    onPressed: _handleRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Ulitin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indicatorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                if (_showRetryButton && widget.onCancel != null)
                  const SizedBox(width: 12),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: _handleCancel,
                    child: const Text('Huwag Na'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (!_recoveryService!.isConnected) {
      return Icons.wifi_off;
    } else if (_recoveryService!.isRecovering) {
      return Icons.wifi_find;
    } else if (_showRetryButton) {
      return Icons.warning;
    } else {
      return Icons.hourglass_empty;
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _recoveryService?.removeListener(_onRecoveryStatusChanged);
    super.dispose();
  }
}

/// Overlay widget to show timeout indicator on top of current screen
class TimeoutOverlay extends StatelessWidget {
  final Widget child;
  final bool showTimeout;
  final String operationName;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final Duration? timeout;
  final String? message;

  const TimeoutOverlay({
    super.key,
    required this.child,
    required this.showTimeout,
    required this.operationName,
    this.onRetry,
    this.onCancel,
    this.timeout,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showTimeout)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: TimeoutIndicator(
                operationName: operationName,
                isVisible: showTimeout,
                onRetry: onRetry,
                onCancel: onCancel,
                customTimeout: timeout,
                customMessage: message,
              ),
            ),
          ),
      ],
    );
  }
}

/// Mixin to easily add timeout indicators to any widget
mixin TimeoutIndicatorMixin<T extends StatefulWidget> on State<T> {
  bool _showTimeoutIndicator = false;
  String _currentOperation = '';

  bool get showingTimeout => _showTimeoutIndicator;

  void showTimeout(String operationName) {
    if (mounted) {
      setState(() {
        _showTimeoutIndicator = true;
        _currentOperation = operationName;
      });
    }
  }

  void hideTimeout() {
    if (mounted) {
      setState(() {
        _showTimeoutIndicator = false;
        _currentOperation = '';
      });
    }
  }

  Widget buildWithTimeoutOverlay(Widget child, {
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    Duration? timeout,
    String? message,
  }) {
    return TimeoutOverlay(
      showTimeout: _showTimeoutIndicator,
      operationName: _currentOperation,
      onRetry: onRetry ?? hideTimeout,
      onCancel: onCancel ?? hideTimeout,
      timeout: timeout,
      message: message,
      child: child,
    );
  }
}

/// Helper function to wrap any operation with timeout indicator
Future<T> withTimeoutIndicator<T>(
  BuildContext context,
  Future<T> operation, {
  required String operationName,
  Duration? timeout,
  String? message,
}) async {
  bool showIndicator = true;

  // Show timeout indicator after a brief delay
  Future.delayed(const Duration(milliseconds: 500), () {
    if (showIndicator) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: TimeoutIndicator(
            operationName: operationName,
            isVisible: true,
            customTimeout: timeout,
            customMessage: message,
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  });

  try {
    final result = await operation;
    showIndicator = false;

    // Close dialog if it's open
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    return result;
  } catch (e) {
    showIndicator = false;

    // Close dialog if it's open
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    rethrow;
  }
}