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
  int? _expandedPanelIndex =
      0; // First panel is expanded by default as shown in the image

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final aralinProvider = Provider.of<AralinProvider>(context);
    final userName = authProvider.currentUser?.name ?? 'RAINIER';

    // List of all lesson data
    final lessonData = [
      {
        'index': 0,
        'title': 'ARALIN 1 : Mga Huni o Tunog ng mga Hayop',
        'isAvailable': true,
      },
      {
        'index': 1,
        'title': 'ARALIN 2 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 2,
        'title': 'ARALIN 3 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 3,
        'title': 'ARALIN 4 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 4,
        'title': 'ARALIN 5 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 5,
        'title': 'ARALIN 6 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 6,
        'title': 'ARALIN 7 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
      {
        'index': 7,
        'title': 'ARALIN 8 : Mga Uri ng Pangungusap',
        'isAvailable': false,
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.primaryLightBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(userName),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'PANIMULANG KASAYANAYAN',
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

  Widget _buildHeader(String userName) {
    return Container(
      width: double.infinity,
      height: 65,
      color: AppTheme.primaryDarkBlue,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // Navigator.pushNamed(context, AppRouter.profile);
            },
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: 'Setting',
            isSelected: false,
            onTap: () {
              // Navigator.pushNamed(context, AppRouter.settingss);
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
