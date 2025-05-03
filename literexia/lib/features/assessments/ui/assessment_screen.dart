// lib/features/assessments/ui/assessment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/assessment_provider.dart';
import 'assessment_question_screen.dart';

class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDarkBlue,
        elevation: 0,
        title: const Text(
          'Panimulang Kasanayan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro text
              const Text(
                'Sagutin ang mga tanong para malaman kung nasaan ka na sa iyong pag-aaral.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              // Assessment card
              _buildAssessmentCard(
                context,
                title: 'Alphabet Knowledge Pre-Assessment',
                description: 'Assessment for evaluating basic alphabet knowledge in Filipino',
                assessmentId: 1,
              ),

              const Spacer(),

              // Instructions
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mga Panuto:',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Sagutan ang lahat ng mga tanong sa paimulang pagtatasa.',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      '2. Kung hindi mo alam ang sagot, pumili ng pinakamalapit na sagot.',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      '3. Hindi mo maaaring i-skip ang anumang tanong.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context, {
    required String title,
    required String description,
    required int assessmentId,
  }) {
    return Card(
      elevation: 4,
      color: AppTheme.lessonPanelBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz,
                  color: AppTheme.accentAmber,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '5 Questions • Filipino',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startAssessment(context, assessmentId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SIMULAN ANG PAGTATASA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startAssessment(BuildContext context, int assessmentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => AssessmentProvider(),
          child: AssessmentQuestionScreen(assessmentId: assessmentId),
        ),
      ),
    );
  }
}