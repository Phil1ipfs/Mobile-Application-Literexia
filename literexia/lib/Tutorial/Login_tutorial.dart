import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../screens/login_screen.dart';
import '../features/assessments/ui/PhonologicalMatching.dart';

class LoginTutorial extends StatefulWidget {
  const LoginTutorial({Key? key}) : super(key: key);

  @override
  State<LoginTutorial> createState() => _LoginTutorialState();
}

class _LoginTutorialState extends State<LoginTutorial>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  // Text variables for first screen
  String _displayText = '';
  final String _fullText =
      'Pag nakita mo ito maaari mo ba pindutin at itype ang iyong LRN NUMBER na nasa iyong ID';

  // Text variables for second screen
  String _displayText2 = '';
  final String _fullText2 =
      'Pagkatapos mong ilagay ang iyong LRN Number. pindutin lamang ang button katulad ng halimbawa na nasa itaas.';

  int _currentIndex = 0;
  int _currentIndex2 = 0;
  Timer? _timer;
  Timer? _timer2;
  bool _showTopButton = false;
  bool _showSecondScreenElements = false;
  bool _isSecondScreen = false;

  // Tablet-specific text scaling utilities
  double get _screenWidth => MediaQuery.of(context).size.width;
  bool get _isTablet => _screenWidth >= 768;
  bool get _isLargeTablet => _screenWidth >= 1024;

  // Tablet text scaling - makes text bigger only for tablets
  double _getTabletTextSize(double baseFontSize) {
    if (_isLargeTablet) {
      return baseFontSize * 1.8; // Much larger for large tablets
    } else if (_isTablet) {
      return baseFontSize * 1.5; // Bigger for regular tablets
    }
    return baseFontSize; // Normal size for phones
  }

  @override
  void initState() {
    super.initState();

    // Setup smooth beating animation
    _heartbeatController = AnimationController(
      duration:
          const Duration(milliseconds: 2000), // Slower for smoother effect
      vsync: this,
    );

    _heartbeatAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(
                begin: 1.0, end: 1.05) // Smaller scale for subtlety
            .chain(CurveTween(curve: Curves.easeInOutSine)), // Smoother curve
        weight: 25.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)), // Smoother curve
        weight: 25.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 50.0, // Longer pause between beats
      ),
    ]).animate(_heartbeatController);

    _heartbeatController.repeat();

    // Start typewriter effect for first screen
    _startTypewriterEffect();
  }

  void _startTypewriterEffect() {
    const duration = Duration(milliseconds: 50);
    _timer = Timer.periodic(duration, (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _displayText = _fullText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
        // Show the top input field when text is fully typed
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _showTopButton = true;
          });
        });
      }
    });
  }

  void _switchToSecondScreen() {
    setState(() {
      _isSecondScreen = true;

      // Reset for second screen's typewriter effect
      _currentIndex2 = 0;
      _displayText2 = '';

      // Cancel first timer if it's still running
      _timer?.cancel();

      // Start the second screen's typewriter effect
      _startSecondTypewriterEffect();
    });
  }

  void _startSecondTypewriterEffect() {
    const duration = Duration(milliseconds: 50);
    _timer2 = Timer.periodic(duration, (timer) {
      if (_currentIndex2 < _fullText2.length) {
        setState(() {
          _displayText2 = _fullText2.substring(0, _currentIndex2 + 1);
          _currentIndex2++;
        });
      } else {
        _timer2?.cancel();
        // Show the elements when text is fully typed
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _showSecondScreenElements = true;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer2?.cancel();
    _heartbeatController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF1C2B4E), // Dark blue background from the image
      body: SafeArea(
        child: _isSecondScreen ? _buildSecondScreen() : _buildFirstScreen(),
      ),
    );
  }

  Widget _buildFirstScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Spacer(),

          // LRN NUMBER input field (top)
          AnimatedOpacity(
            opacity: _showTopButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: AnimatedBuilder(
              animation: _heartbeatAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _heartbeatAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'LRN NUMBER',
                        style: TextStyle(
                          color: Color(0xFFA0A0A0),
                          fontSize: _getTabletTextSize(16),
                          fontWeight: FontWeight.w600,
                          letterSpacing: _isTablet ? 2.0 : 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Typewriter text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTablet ? 60 : 40),
            child: Text(
              _displayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getTabletTextSize(20),
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),

          const Spacer(),

          // Yellow "MAG PATULOY" button (image 1, bottom button)
          if (_showTopButton)
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              margin: EdgeInsets.only(bottom: _isTablet ? 120 : 100),
              child: ElevatedButton(
                onPressed: _switchToSecondScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: _isTablet ? 20 : 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'MAG PATULOY',
                  style: TextStyle(
                    fontSize: _getTabletTextSize(20),
                    fontWeight: FontWeight.bold,
                    letterSpacing: _isTablet ? 1.5 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecondScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Spacer(),

          // Yellow button example - shows after typewriter completes
          AnimatedOpacity(
            opacity: _showSecondScreenElements ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: AnimatedBuilder(
              animation: _heartbeatAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _heartbeatAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: ElevatedButton(
                      onPressed: () {
                        // This is the example button they refer to
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'MAG PATULOY',
                        style: TextStyle(
                          fontSize: _getTabletTextSize(16),
                          fontWeight: FontWeight.bold,
                          letterSpacing: _isTablet ? 1.5 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Second screen typewriter text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTablet ? 60 : 40),
            child: Text(
              _displayText2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getTabletTextSize(20),
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),

          const Spacer(),

          // Bottom "MAG PATULOY" button - shows after typewriter completes
          if (_showSecondScreenElements)
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              margin: EdgeInsets.only(bottom: _isTablet ? 120 : 100),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: _isTablet ? 20 : 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'MAG PATULOY',
                  style: TextStyle(
                    fontSize: _getTabletTextSize(20),
                    fontWeight: FontWeight.bold,
                    letterSpacing: _isTablet ? 1.5 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
