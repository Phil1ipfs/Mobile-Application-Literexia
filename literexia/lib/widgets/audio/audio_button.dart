// lib/widgets/audio/audio_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio/audio_service.dart';
import '../../features/settings/provider/theme_provider.dart';

class AudioButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool enabled;
  final Widget? icon;
  final double? width;
  final double? height;
  final bool playHoverSound;
  final bool playClickSound;

  const AudioButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.fontSize,
    this.fontWeight,
    this.enabled = true,
    this.icon,
    this.width,
    this.height,
    this.playHoverSound = true,
    this.playClickSound = true,
  }) : super(key: key);

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final audioService = Provider.of<AudioService>(context, listen: false);

    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled && widget.playHoverSound) {
          audioService.playButtonHover();
        }
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.95 : _isHovered ? 1.05 : 1.0),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: ElevatedButton(
              onPressed: widget.enabled
                  ? () {
                      if (widget.playClickSound) {
                        audioService.playButtonClick();
                      }
                      widget.onPressed?.call();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.backgroundColor ?? theme.accentColor,
                foregroundColor: widget.foregroundColor ?? theme.buttonTextColor,
                padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(30),
                ),
                elevation: _isPressed ? 2 : _isHovered ? 8 : 4,
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    widget.icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: widget.fontSize ?? themeProvider.getRealFontSize(16),
                      fontWeight: widget.fontWeight ?? FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Specialized audio buttons for different contexts
class AudioIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;
  final bool enabled;
  final bool playHoverSound;
  final bool playClickSound;
  final String? tooltip;

  const AudioIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size,
    this.enabled = true,
    this.playHoverSound = true,
    this.playClickSound = true,
    this.tooltip,
  }) : super(key: key);

  @override
  State<AudioIconButton> createState() => _AudioIconButtonState();
}

class _AudioIconButtonState extends State<AudioIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioService>(context, listen: false);

    Widget button = MouseRegion(
      onEnter: (_) {
        if (widget.enabled && widget.playHoverSound) {
          audioService.playButtonHover();
        }
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.9 : _isHovered ? 1.1 : 1.0),
          child: IconButton(
            onPressed: widget.enabled
                ? () {
                    if (widget.playClickSound) {
                      audioService.playButtonClick();
                    }
                    widget.onPressed?.call();
                  }
                : null,
            icon: Icon(
              widget.icon,
              color: widget.color,
              size: widget.size,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

// Audio toggle button specifically for controlling audio settings
class AudioToggleButton extends StatelessWidget {
  final EdgeInsetsGeometry? padding;

  const AudioToggleButton({Key? key, this.padding}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioService>(
      builder: (context, audioService, child) {
        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: AudioIconButton(
            icon: audioService.isAudioEnabled ? Icons.volume_up : Icons.volume_off,
            onPressed: audioService.toggleAudio,
            color: audioService.isAudioEnabled ? Colors.amber : Colors.grey,
            size: 28,
            tooltip: audioService.isAudioEnabled ? 'Turn off audio' : 'Turn on audio',
            playClickSound: false, // Don't play click sound when toggling audio
          ),
        );
      },
    );
  }
}