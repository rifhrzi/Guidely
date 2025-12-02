import 'package:flutter/material.dart';

/// Accessibility-focused theme optimized for visually impaired users.
/// 
/// Key principles:
/// - High contrast colors (WCAG AAA compliant)
/// - Large touch targets (minimum 72dp for primary actions)
/// - Clear, readable typography
/// - Strong focus indicators
class AppTheme {
  // High contrast primary - deep blue
  static const Color _primaryLight = Color(0xFF0D47A1);
  static const Color _primaryDark = Color(0xFF64B5F6);
  
  // High contrast accent - bright orange for visibility
  static const Color _accentLight = Color(0xFFE65100);
  static const Color _accentDark = Color(0xFFFFB74D);

  /// Minimum touch target size for accessibility (72dp for primary, 56dp for secondary)
  static const double minTouchTargetPrimary = 72.0;
  static const double minTouchTargetSecondary = 56.0;

  /// Standard border radius for accessibility (not too rounded, easier to perceive)
  static const double borderRadius = 16.0;

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: _primaryLight,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFBBDEFB),
      onPrimaryContainer: const Color(0xFF0D47A1),
      secondary: _accentLight,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFE0B2),
      onSecondaryContainer: const Color(0xFFE65100),
      surface: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      onSurfaceVariant: const Color(0xFF424242),
      error: const Color(0xFFB71C1C),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFCDD2),
      onErrorContainer: const Color(0xFFB71C1C),
    );

    return _buildTheme(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: const Color(0xFF0D47A1),
      primaryContainer: const Color(0xFF1565C0),
      onPrimaryContainer: const Color(0xFFE3F2FD),
      secondary: _accentDark,
      onSecondary: const Color(0xFF4E342E),
      secondaryContainer: const Color(0xFFE65100),
      onSecondaryContainer: const Color(0xFFFFE0B2),
      surface: const Color(0xFF121212),
      onSurface: const Color(0xFFFAFAFA),
      onSurfaceVariant: const Color(0xFFBDBDBD),
      error: const Color(0xFFEF5350),
      onError: Colors.black,
      errorContainer: const Color(0xFFB71C1C),
      onErrorContainer: const Color(0xFFFFCDD2),
    );

    return _buildTheme(scheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    // Large, readable text styles
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: scheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight 
          ? const Color(0xFFF5F5F5) 
          : const Color(0xFF0A0A0A),
      textTheme: textTheme,
      
      // AppBar - clear, high contrast
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(
          size: 28,
          color: scheme.onSurface,
        ),
      ),

      // Primary button - LARGE touch target (72dp)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(minTouchTargetPrimary),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          ),
          shape: WidgetStatePropertyAll(rounded),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          iconSize: const WidgetStatePropertyAll(28),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.surfaceContainerHighest;
            }
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.8);
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            scheme.onPrimary.withValues(alpha: 0.12),
          ),
        ),
      ),

      // Filled button - LARGE touch target
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(minTouchTargetPrimary),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          ),
          shape: WidgetStatePropertyAll(rounded),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          iconSize: const WidgetStatePropertyAll(28),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(minTouchTargetSecondary),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(rounded),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.primary, width: 2),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          iconSize: const WidgetStatePropertyAll(24),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      // Icon button - accessible size
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
          iconSize: const WidgetStatePropertyAll(28),
        ),
      ),

      // Card - clear boundaries
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: isLight ? 2 : 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ListTile - large touch targets
      listTileTheme: ListTileThemeData(
        shape: rounded,
        tileColor: scheme.surface,
        selectedColor: scheme.primary,
        minVerticalPadding: 16,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        leadingAndTrailingTextStyle: textTheme.bodyLarge,
        iconColor: scheme.primary,
        minLeadingWidth: 32,
      ),

      // Input - clear, large
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: scheme.primary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyLarge,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // Switch - large
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.5);
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return scheme.outline;
        }),
      ),

      // Slider - large thumb
      sliderTheme: SliderThemeData(
        thumbColor: scheme.primary,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
        trackHeight: 8,
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),

      // FAB - extra large for accessibility
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        highlightElevation: 12,
        shape: const CircleBorder(),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: 80,
          height: 80,
        ),
        extendedSizeConstraints: const BoxConstraints.tightFor(
          height: 64,
        ),
        iconSize: 32,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shape: rounded,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),

      // Bottom sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleSize: const Size(48, 6),
        dragHandleColor: scheme.outline,
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 8,
      ),
    );
  }
}
