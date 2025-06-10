// lib/screens/pre_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import '../config/router.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';

class PreLoginScreen extends StatefulWidget {
  const PreLoginScreen({super.key});

  @override
  State<PreLoginScreen> createState() => _PreLoginScreenState();
}

class _PreLoginScreenState extends State<PreLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _snowflakeController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasSpokenIntro = false;

  // Store references to providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  final String _introText = 
      "Maligayang pagdating sa LITEREXIA! Ang app na ito ay idinisenyo para sa mga estudyanteng upang matuto ng Tagalog reading comprehension.";

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _snowflakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Start fade animation when screen loads
    _fadeController.forward();

    // Speak intro text after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _speakIntroText();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references safely during widget lifecycle
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
  }

  void _speakIntroText() {
    if (_hasSpokenIntro || !mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        _introText,
        speed: 0.4,
        onStart: () {
          if (mounted) {
            setState(() {
              _hasSpokenIntro = true;
            });
          }
        },
        onComplete: () {
          // Optional: Handle completion
        },
        onError: () {
          print('TTS Error occurred while speaking intro');
        },
      );
    }
  }

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
    }
  }

  void _navigateToLogin() {
    _playButtonAudio();
    
    // Stop any ongoing TTS before navigating
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _snowflakeController.dispose();
    _audioPlayer.dispose();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snowflake = Icon(Icons.ac_unit, color: Colors.white, size: 48);
    return Scaffold(
      backgroundColor: const Color(0xFF334970), // Dark blue background
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Stack(
            children: [
              // Snowflakes and Penguin
              Column(
                children: [
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedBuilder(
                          animation: _snowflakeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * _snowflakeController.value),
                              child: child,
                            );
                          },
                          child: snowflake,
                        ),
                        AnimatedBuilder(
                          animation: _snowflakeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -20 * _snowflakeController.value),
                              child: child,
                            );
                          },
                          child: snowflake,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Penguin Lottie Animation
                  Center(
                    child: SizedBox(
                      height: 140,
                      child: Lottie.asset('assets/animations/penguin.json', repeat: true),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Name
                  Text(
                    'LITEREXIA',
                    style: TextStyle(
                      fontFamily: 'Snow Blue',
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 3.0,
                          color: Colors.black.withOpacity(0.9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Maligayang pagdating sa LITEREXIA! Ang app na ito ay idinisenyo para sa mga estudyante upang mahasa at matuto sa pag tatagalog.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  // Login Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48.0),
                    child: SizedBox(
                      width: 260,
                      height: 48,
                      child: Stack(
                        children: [
                          // Drop shadow
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  offset: const Offset(0, 4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Button with inner shadow
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _InnerShadowPainter(
                                color: Colors.black.withOpacity(0.25),
                                offset: const Offset(0, -3),
                                blur: 4,
                                borderRadius: 30,
                              ),
                              child: ElevatedButton(
                                onPressed: _navigateToLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0, // Remove default shadow
                                ),
                                child: const Text(
                                  'Mag Login',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFF9D56E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blur;
  final double borderRadius;

  _InnerShadowPainter({
    required this.color,
    required this.offset,
    required this.blur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    final clipPath = Path()..addRRect(rrect);
    canvas.saveLayer(rect, Paint());
    canvas.clipPath(clipPath);
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}