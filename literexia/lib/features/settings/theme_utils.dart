// lib/features/settings/utils/theme_utils.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';

/// Utility class for getting themed widgets and styles
class ThemeUtils {
  /// Returns a themed AppBar
  static AppBar getThemedAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    bool useBackButton = true,
    VoidCallback? onBackPressed,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return AppBar(
      backgroundColor: theme.primaryColor,
      elevation: 0,
      leading:
          useBackButton
              ? IconButton(
                icon: Icon(Icons.arrow_back, color: theme.textColor),
                onPressed:
                    onBackPressed ??
                    () {
                      Navigator.of(context).pop();
                    },
              )
              : null,
      title: Text(
        title,
        style: TextStyle(
          color: theme.textColor,
          fontSize: themeProvider.getRealFontSize(24),
          fontWeight: FontWeight.bold,
          fontFamily: themeProvider.fontFamily,
          letterSpacing: themeProvider.getRealLetterSpacing(),
        ),
      ),
      centerTitle: true,
      actions: actions,
    );
  }

  /// Returns a themed button
  static Widget getThemedButton(
    BuildContext context, {
    required String text,
    required VoidCallback onPressed,
    bool isFullWidth = true,
    bool isPrimary = true,
    IconData? icon,
    double height = 50,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    final buttonChild = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: isPrimary ? theme.buttonTextColor : theme.textColor,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: themeProvider.getRealFontSize(16),
            fontWeight: FontWeight.bold,
            color: isPrimary ? theme.buttonTextColor : theme.textColor,
            fontFamily: themeProvider.fontFamily,
            letterSpacing: themeProvider.getRealLetterSpacing(),
          ),
        ),
      ],
    );

    if (isPrimary) {
      return SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: height,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accentColor,
            foregroundColor: theme.buttonTextColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: buttonChild,
        ),
      );
    } else {
      return SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.textColor,
            side: BorderSide(color: theme.accentColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: buttonChild,
        ),
      );
    }
  }

  /// Returns a themed text field
  static Widget getThemedTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    bool enabled = true,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.accentColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          color: Colors.black,
          fontSize: themeProvider.getRealFontSize(16),
          fontFamily: themeProvider.fontFamily,
          letterSpacing: themeProvider.getRealLetterSpacing(),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey,
            fontFamily: themeProvider.fontFamily,
            letterSpacing: themeProvider.getRealLetterSpacing(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  /// Returns themed text style
  static TextStyle getThemedTextStyle(
    BuildContext context, {
    bool isBold = false,
    bool isTitle = false,
    double fontSize = 16,
    Color? color,
    double opacityFactor = 1.0,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return TextStyle(
      color: (color ?? theme.textColor).withOpacity(opacityFactor),
      fontSize: themeProvider.getRealFontSize(isTitle ? 24 : fontSize),
      fontWeight: isBold || isTitle ? FontWeight.bold : FontWeight.normal,
      fontFamily: themeProvider.fontFamily,
      letterSpacing: themeProvider.getRealLetterSpacing(),
    );
  }

  /// Returns a themed card
  static Widget getThemedCard(
    BuildContext context, {
    required Widget child,
    double elevation = 4,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Card(
      elevation: elevation,
      color: theme.primaryColor.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.accentColor, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  /// Applies theme to a page with a progress indicator
  static Widget buildThemedProgressIndicator(
    BuildContext context, {
    String? progressMessage,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.accentColor),
          if (progressMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              progressMessage,
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
                letterSpacing: themeProvider.getRealLetterSpacing(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
