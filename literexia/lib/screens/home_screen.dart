// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:provider/provider.dart';
import '../config/router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/logic/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _expandedPanelIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final aralinProvider = Provider.of<AralinProvider>(context);
    final userName = authProvider.currentUser?.firstName ?? 
                 authProvider.currentUser?.name ?? 
                 'Guest';
    final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';
    
    // Get lessons based on reading level
    final lessonData = _getLessonsForLevel(readingLevel);

    return Scaffold(
      backgroundColor: AppTheme.primaryLightBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(userName, readingLevel),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'PANIMULANG KASAYANAYAN - $readingLevel Level',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Build all lesson panels dynamically
                  ...lessonData.map((lesson) {
                    return _buildLessonItem(
                      index: lesson['index'] as int,
                      title: lesson['title'] as String,
                      isAvailable: lesson['isAvailable'] as bool,
                    );
                  }).toList(),
                ],
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  // New method to get lessons based on reading level
  List<Map<String, dynamic>> _getLessonsForLevel(String readingLevel) {
    // Base lessons that are always available
    final List<Map<String, dynamic>> baseLessons = [
      {
        'index': 0,
        'title': 'ARALIN 1: Panimulang Pagbasa',
        'isAvailable': true,
      },
    ];
    
    // Add more lessons based on reading level
    switch (readingLevel.toLowerCase()) {
      case 'emergent':
        // Emergent readers get basic lessons
        baseLessons.addAll([
          {
            'index': 1,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'isAvailable': true,
          },
          {
            'index': 2,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'isAvailable': false,
          },
        ]);
        break;
        
      case 'early':
        // Early readers get intermediate lessons
        baseLessons.addAll([
          {
            'index': 1,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'isAvailable': true,
          },
          {
            'index': 2,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'isAvailable': true,
          },
          {
            'index': 4,
            'title': 'ARALIN 5: Mga Salitang may Katunog',
            'isAvailable': true,
          },
          {
            'index': 5,
            'title': 'ARALIN 6: Mga Uri ng Pangungusap',
            'isAvailable': false,
          },
        ]);
        break;
        
      case 'fluent':
        // Fluent readers get advanced lessons
        baseLessons.addAll([
          {
            'index': 1,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'isAvailable': true,
          },
          {
            'index': 2,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'isAvailable': true,
          },
          {
            'index': 4,
            'title': 'ARALIN 5: Mga Salitang may Katunog',
            'isAvailable': true,
          },
          {
            'index': 5,
            'title': 'ARALIN 6: Mga Uri ng Pangungusap',
            'isAvailable': true,
          },
          {
            'index': 6,
            'title': 'ARALIN 7: Pag-unawa sa Binasa',
            'isAvailable': true,
          },
          {
            'index': 7,
            'title': 'ARALIN 8: Pagsulat ng Maikling Kwento',
            'isAvailable': true,
          },
        ]);
        break;
        
      default:
        // Default lessons for undefined or other levels
        baseLessons.addAll([
          {
            'index': 1,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'isAvailable': false,
          },
          {
            'index': 2,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'isAvailable': false,
          },
        ]);
    }
    
    return baseLessons;
  }

  // Modified header to display reading level
  Widget _buildHeader(String userName, String readingLevel) {
    return Container(
      width: double.infinity,
      height: 65,
      color: AppTheme.primaryDarkBlue,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'H I !   $userName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reading Level: $readingLevel',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3D4B71),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/penguin.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonItem({
    required int index,
    required String title,
    required bool isAvailable,
  }) {
    final isExpanded = _expandedPanelIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.7,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.lessonPanelBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  isAvailable
                      ? () {
                        setState(() {
                          _expandedPanelIndex = isExpanded ? null : index;
                        });
                      }
                      : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/books.png',
                      width: 20,
                      height: 20,
                      color: AppTheme.accentAmber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isAvailable)
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: Colors.white,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 60,
      color: AppTheme.primaryDarkBlue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            isSelected: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            isSelected: false,
            onTap: () {
              // Navigate to profile
            },
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: 'Setting',
            isSelected: false,
            onTap: () {
              // Navigate to settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.accentAmber : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.accentAmber : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}