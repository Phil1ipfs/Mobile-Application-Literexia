// lib/features/interventions/ui/intervention_result_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/intervention/model/intervention_model.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

class InterventionResultScreen extends StatefulWidget {
  final double score;
  final bool isPassed;
  final InterventionAssessment intervention;

  const InterventionResultScreen({
    Key? key,
    required this.score,
    required this.isPassed,
    required this.intervention,
  }) : super(key: key);

  @override
  State<InterventionResultScreen> createState() => _InterventionResultScreenState();
}

class _InterventionResultScreenState extends State<InterventionResultScreen> {
  // Confetti controller for celebration animation
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    
    // Start confetti animation if passed
    if (widget.isPassed) {
      Future.delayed(Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    
    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Score display
                    _buildScoreCircle(theme, themeProvider),
                    
                    const SizedBox(height: 30),
                    
                    // Pass/Fail message
                    _buildResultMessage(theme, themeProvider),
                    
                    const SizedBox(height: 20),
                    
                    // Intervention details
                    _buildInterventionDetails(theme, themeProvider),
                    
                    const SizedBox(height: 40),
                    
                    // Action buttons
                    _buildActionButtons(theme, themeProvider),
                  ],
                ),
              ),
            ),
          ),
          
          // Confetti effect for passing
          if (widget.isPassed)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.1,
                numberOfParticles: 20,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.2,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.purple,
                  Colors.orange,
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildScoreCircle(AppThemeData theme, ThemeProvider themeProvider) {
    final scoreColor = widget.isPassed ? Colors.green : Colors.red;
    final scoreSize = MediaQuery.of(context).size.width * 0.4; // 40% of screen width
    
    return Container(
      width: scoreSize,
      height: scoreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scoreColor.withOpacity(0.1),
        border: Border.all(
          color: scoreColor,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${widget.score.toStringAsFixed(0)}%',
            style: TextStyle(
              color: scoreColor,
              fontSize: themeProvider.getRealFontSize(40),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
          ),
          Text(
            widget.isPassed ? 'PASSED' : 'FAILED',
            style: TextStyle(
              color: scoreColor,
              fontSize: themeProvider.getRealFontSize(16),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultMessage(AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isPassed 
            ? Colors.green.withOpacity(0.1) 
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPassed ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.isPassed 
                ? 'Napagtagumpayan mo ang intervention!' 
                : 'Hindi mo pa napagtagumpayan ang intervention.',
            style: TextStyle(
              color: widget.isPassed ? Colors.green : Colors.red,
              fontSize: themeProvider.getRealFontSize(20),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.isPassed
                ? 'Mahusay! Nagpakita ka ng mahusay na pag-unawa sa kategoryang ${widget.intervention.category}.'
                : 'Kailangan mo ng karagdagang pagsasanay sa kategoryang ${widget.intervention.category}. Subukan muli!',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.8),
              fontSize: themeProvider.getRealFontSize(16),
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInterventionDetails(AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.headerColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intervention Details',
            style: TextStyle(
              color: theme.textColor,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Name:',
            widget.intervention.name,
            theme,
            themeProvider,
          ),
          _buildDetailRow(
            'Category:',
            widget.intervention.category,
            theme,
            themeProvider,
          ),
          _buildDetailRow(
            'Reading Level:',
            widget.intervention.readingLevel,
            theme,
            themeProvider,
          ),
          _buildDetailRow(
            'Passing Threshold:',
            '${widget.intervention.passThreshold.toStringAsFixed(0)}%',
            theme,
            themeProvider,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(
      String label, String value, AppThemeData theme, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textColor.withOpacity(0.7),
              fontSize: themeProvider.getRealFontSize(14),
              fontFamily: themeProvider.fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(14),
                fontFamily: themeProvider.fontFamily,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(AppThemeData theme, ThemeProvider themeProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: () {
              // Return to home screen (pop to root)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.buttonTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: Icon(Icons.home),
            label: Text(
              'BUMALIK SA HOME',
              style: TextStyle(
                fontSize: themeProvider.getRealFontSize(16),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Only show retry button if failed
        if (!widget.isPassed)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton.icon(
              onPressed: () {
                // Go back to intervention screen
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.accentColor,
                side: BorderSide(color: theme.accentColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: Icon(Icons.refresh),
              label: Text(
                'SUBUKAN MULI',
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}