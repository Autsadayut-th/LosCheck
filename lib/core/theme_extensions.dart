// Theme Extensions & Helper Functions.
// Makes it easy to use design system tokens throughout the app.
import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TEXT THEME EXTENSIONS
/// ═══════════════════════════════════════════════════════════════════════════

/// Easily access responsive text styles with proper semantic naming
extension TextThemeX on TextTheme {
  /// Hero/Display text (largest, most prominent)
  TextStyle get displayHero => displayLarge ?? const TextStyle();

  /// Main headings (page title, major sections)
  TextStyle get headingPrimary => headlineLarge ?? const TextStyle();

  /// Section headers (subsections)
  TextStyle get headingSecondary => headlineSmall ?? const TextStyle();

  /// Card titles, important labels
  TextStyle get cardTitle => titleLarge ?? const TextStyle();

  /// Standard body text (articles, descriptions)
  TextStyle get bodyStandard => bodyLarge ?? const TextStyle();

  /// Smaller body text (subtitles, secondary info)
  TextStyle get bodySmallText => bodySmall ?? const TextStyle();

  /// Button and control labels
  TextStyle get label => labelLarge ?? const TextStyle();

  /// Tiny captions and hints
  TextStyle get caption => labelSmall ?? const TextStyle();
}

/// ═══════════════════════════════════════════════════════════════════════════
/// COLOR EXTENSIONS
/// ═══════════════════════════════════════════════════════════════════════════

extension ColorSchemeX on ColorScheme {
  /// Success color (green - for positive actions)
  Color get success => const Color(0xFF4CAF50);

  /// Warning color (orange - for alerts)
  Color get warning => const Color(0xFFFF9800);

  /// Info color (blue - for information)
  Color get info => const Color(0xFF2196F3);

  /// Neutral background (light/dark mode agnostic)
  Color get background =>
      brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white;

  /// Subtle border color
  Color get borderColor => brightness == Brightness.dark
      ? const Color(0xFF404040)
      : const Color(0xFFEEEEEE);

  /// Disabled state color
  Color get disabled => brightness == Brightness.dark
      ? const Color(0xFF424242)
      : const Color(0xFFBDBDBD);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// CONTEXT HELPERS
/// ═══════════════════════════════════════════════════════════════════════════

extension BuildContextX on BuildContext {
  /// Get current color scheme
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Get current text theme
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Check if device is mobile (< 768px)
  bool get isMobile => MediaQuery.of(this).size.width < 768;

  /// Check if device is tablet (768-1200px)
  bool get isTablet =>
      MediaQuery.of(this).size.width >= 768 &&
      MediaQuery.of(this).size.width < 1200;

  /// Check if device is desktop (> 1200px)
  bool get isDesktop => MediaQuery.of(this).size.width >= 1200;

  /// Get current screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get current screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Get safe padding (notch, status bar, etc.)
  EdgeInsets get safePadding => MediaQuery.of(this).padding;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SHADOW HELPERS
/// ═══════════════════════════════════════════════════════════════════════════

extension ShadowX on List<BoxShadow> {
  /// Create shadow with custom color
  List<BoxShadow> withColor(Color color) {
    return map((shadow) => shadow.copyWith(color: color)).toList();
  }

  /// Create shadow with custom opacity
  List<BoxShadow> withOpacity(double opacity) {
    return map(
      (shadow) =>
          shadow.copyWith(color: shadow.color.withValues(alpha: opacity)),
    ).toList();
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// QUICK HELPER FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════════

/// Build a divider with consistent styling
Widget divider({
  EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16),
  Color? color,
}) {
  return Padding(
    padding: padding,
    child: Divider(
      color: color ?? DesignTokens.neutralBorder,
      thickness: 1,
      height: 1,
    ),
  );
}

/// Build empty state widget (commonly used across screens)
Widget emptyState(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  Widget? action,
}) {
  return Center(
    child: Padding(
      padding: DesignTokens.paddingL,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: context.colors.primary.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: DesignTokens.spacingL),
          Text(
            title,
            style: context.textStyles.headingSecondary.copyWith(
              color: context.colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: DesignTokens.spacingS),
          Text(
            message,
            style: context.textStyles.bodySmallText.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            SizedBox(height: DesignTokens.spacingL),
            action,
          ],
        ],
      ),
    ),
  );
}

/// Show error snackbar with consistent style
void showErrorSnackbar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: DesignTokens.errorMain,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
      behavior: SnackBarBehavior.floating,
      margin: DesignTokens.paddingM,
    ),
  );
}

/// Show success snackbar with consistent style
void showSuccessSnackbar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: DesignTokens.successMain,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
      behavior: SnackBarBehavior.floating,
      margin: DesignTokens.paddingM,
    ),
  );
}

/// ═══════════════════════════════════════════════════════════════════════════
/// CUSTOM BUTTON STYLES
/// ═══════════════════════════════════════════════════════════════════════════

/// Primary button style (main actions)
ButtonStyle primaryButtonStyle(BuildContext context) {
  return ElevatedButton.styleFrom(
    backgroundColor: context.colors.primary,
    foregroundColor: context.colors.onPrimary,
    padding: EdgeInsets.symmetric(
      vertical: DesignTokens.spacingM,
      horizontal: DesignTokens.spacingL,
    ),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
    elevation: DesignTokens.elevationMd,
  );
}

/// Secondary button style (alternative actions)
ButtonStyle secondaryButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    foregroundColor: context.colors.primary,
    side: BorderSide(color: context.colors.primary, width: 2),
    padding: EdgeInsets.symmetric(
      vertical: DesignTokens.spacingM,
      horizontal: DesignTokens.spacingL,
    ),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
  );
}

/// Danger button style (destructive actions)
ButtonStyle dangerButtonStyle(BuildContext context) {
  return ElevatedButton.styleFrom(
    backgroundColor: DesignTokens.errorMain,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(
      vertical: DesignTokens.spacingM,
      horizontal: DesignTokens.spacingL,
    ),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
  );
}

/// ═══════════════════════════════════════════════════════════════════════════
/// USAGE EXAMPLES
/// ═══════════════════════════════════════════════════════════════════════════

/*
// ❌ OLD
Text(
  'Title',
  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
    fontWeight: FontWeight.bold,
  ),
)

// ✅ NEW (using extensions)
Text(
  'Title',
  style: context.textStyles.headingPrimary?.copyWith(
    fontWeight: DesignTokens.fontWeightBold,
  ),
)

// ❌ OLD
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error occurred')),
)

// ✅ NEW (using helper)
showErrorSnackbar(context, message: 'Error occurred')

// ❌ OLD
if (MediaQuery.of(context).size.width < 768) {
  // mobile
} else {
  // desktop
}

// ✅ NEW (using extensions)
if (context.isMobile) {
  // mobile
} else {
  // desktop
}

// ❌ OLD - Empty state
Center(
  child: Column(children: [...])
)

// ✅ NEW - Using helper
emptyState(
  context,
  icon: Icons.inbox_outlined,
  title: 'No data',
  message: 'Try adding some data',
  action: ElevatedButton(onPressed: () {}, child: Text('Add')),
)
*/
