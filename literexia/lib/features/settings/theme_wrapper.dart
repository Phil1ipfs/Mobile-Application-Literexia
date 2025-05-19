// lib/features/settings/ui/theme_wrapper.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';

/// A wrapper widget that applies the current theme to any existing screen
/// Use this to wrap existing screens to make them theme-aware without rewriting them
class ThemeWrapper extends StatelessWidget {
  final Widget child;

  // If true, will also wrap the child in a Scaffold with the themed background
  final bool useScaffold;

  // If useScaffold is true, these parameters can be used to customize the Scaffold
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const ThemeWrapper({
    Key? key,
    required this.child,
    this.useScaffold = false,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;

        // Apply text styles to the child widget via a DefaultTextStyle
        Widget themedChild = DefaultTextStyle(
          style: TextStyle(
            color: theme.textColor,
            fontSize: themeProvider.getRealFontSize(16),
            letterSpacing: themeProvider.getRealLetterSpacing(),
            fontFamily: themeProvider.fontFamily,
          ),
          child: IconTheme(
            data: IconThemeData(color: theme.textColor),
            child: child,
          ),
        );

        // If useScaffold is true, wrap in a Scaffold with the themed background
        if (useScaffold) {
          return Scaffold(
            backgroundColor: theme.primaryColor,
            appBar: appBar,
            body: themedChild,
            bottomNavigationBar:
                bottomNavigationBar != null
                    ? Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(canvasColor: theme.primaryColor),
                      child: bottomNavigationBar!,
                    )
                    : null,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
          );
        }

        return themedChild;
      },
    );
  }
}
