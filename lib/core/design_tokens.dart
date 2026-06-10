// Design System Tokens - Single source of truth for LosCheck.
// Use these tokens instead of magic numbers/colors to maintain
// visual consistency and make future theme changes effortless.
import 'package:flutter/material.dart';

/// Comprehensive Design Tokens for LosCheck
/// Organized by category for easy navigation
class DesignTokens {
  DesignTokens._(); // Prevent instantiation

  /// ═══════════════════════════════════════════════════════════════════════════
  /// SPACING (8px grid system)
  /// ═══════════════════════════════════════════════════════════════════════════
  static const double spacingXs = 4.0; // xs: 4px (rarely used)
  static const double spacingXs2 = 8.0; // s: 8px (gaps, dividers)
  static const double spacingS = 12.0; // s: 12px
  static const double spacingM = 16.0; // m: 16px (standard padding)
  static const double spacingL = 24.0; // l: 24px (section spacing)
  static const double spacingXl = 32.0; // xl: 32px (large sections)
  static const double spacingXxl = 48.0; // xxl: 48px (hero sections)

  /// Edge insets for common patterns
  static const EdgeInsets paddingXs = EdgeInsets.all(spacingXs);
  static const EdgeInsets paddingXs2 = EdgeInsets.all(spacingXs2);
  static const EdgeInsets paddingS = EdgeInsets.all(spacingS);
  static const EdgeInsets paddingM = EdgeInsets.all(spacingM);
  static const EdgeInsets paddingL = EdgeInsets.all(spacingL);
  static const EdgeInsets paddingXl = EdgeInsets.all(spacingXl);

  /// Horizontal padding (common for screens)
  static const EdgeInsets paddingHorizontalM = EdgeInsets.symmetric(
    horizontal: spacingM,
  );
  static const EdgeInsets paddingHorizontalL = EdgeInsets.symmetric(
    horizontal: spacingL,
  );

  /// ═══════════════════════════════════════════════════════════════════════════
  /// BORDER RADIUS
  /// ═══════════════════════════════════════════════════════════════════════════
  static const double radiusSm = 8.0; // Small (input fields)
  static const double radiusMd = 12.0; // Medium (cards, buttons)
  static const double radiusLg = 16.0; // Large (containers, dialogs)
  static const double radiusXl = 20.0; // Extra large (prominent cards)
  static const double radiusCircle = 999.0; // Circle (avatars, badges)

  /// BorderRadius objects (ready to use)
  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ELEVATION / SHADOWS
  /// ═══════════════════════════════════════════════════════════════════════════
  static const double elevationXs = 2.0; // Subtle
  static const double elevationSm = 4.0; // Light
  static const double elevationMd = 8.0; // Medium
  static const double elevationLg = 12.0; // Strong
  static const double elevationXl = 16.0; // Very strong

  /// Reusable shadow definitions
  static List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 12,
      offset: const Offset(0, 8),
    ),
  ];

  /// ═══════════════════════════════════════════════════════════════════════════
  /// TYPOGRAPHY
  /// ═══════════════════════════════════════════════════════════════════════════
  static const double lineHeightTight = 1.2; // Headings
  static const double lineHeightNormal = 1.5; // Body text
  static const double lineHeightLoose = 1.75; // Comfortable reading

  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
  static const double letterSpacingLoose = 1.0;

  /// Font weights
  static const FontWeight fontWeightThin = FontWeight.w100;
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;
  static const FontWeight fontWeightExtraBold = FontWeight.w800;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// DURATIONS (Animations)
  /// ═══════════════════════════════════════════════════════════════════════════
  static const Duration durationFast = Duration(
    milliseconds: 150,
  ); // Quick interactions
  static const Duration durationNormal = Duration(
    milliseconds: 300,
  ); // Standard
  static const Duration durationSlow = Duration(
    milliseconds: 500,
  ); // Deliberate
  static const Duration durationVerySlow = Duration(
    milliseconds: 750,
  ); // Entrance animations

  /// ═══════════════════════════════════════════════════════════════════════════
  /// CURVES (Animation easing)
  /// ═══════════════════════════════════════════════════════════════════════════
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveEaseInOut = Curves.easeInOut;
  static const Curve curveLinear = Curves.linear;
  static const Curve curveElastic = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// COLOR PALETTE
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Primary Color (Teal)
  static const Color primaryLight = Color(0xFFB2DFDB); // Teal 100
  static const Color primaryMain = Color(0xFF00897B); // Teal 700
  static const Color primaryDark = Color(0xFF004D40); // Teal 900

  /// Secondary Color (Amber)
  static const Color secondaryLight = Color(0xFFFFF8E1); // Amber 50
  static const Color secondaryMain = Color(0xFFFBC02D); // Amber 700
  static const Color secondaryDark = Color(0xFFF57F17); // Amber 900

  /// Success (Green)
  static const Color successLight = Color(0xFFC8E6C9);
  static const Color successMain = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF2E7D32);

  /// Error (Red)
  static const Color errorLight = Color(0xFFFFCDD2);
  static const Color errorMain = Color(0xFFF44336);
  static const Color errorDark = Color(0xFFC62828);

  /// Warning (Orange)
  static const Color warningLight = Color(0xFFFFE0B2);
  static const Color warningMain = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFE65100);

  /// Info (Blue)
  static const Color infoLight = Color(0xFFBBDEFB);
  static const Color infoMain = Color(0xFF2196F3);
  static const Color infoDark = Color(0xFF1565C0);

  /// Neutral (Gray)
  static const Color neutralLight = Color(0xFFFAFAFA); // Gray 50
  static const Color neutralBorder = Color(0xFFEEEEEE); // Gray 200
  static const Color neutralSecondary = Color(0xFF757575); // Gray 600
  static const Color neutralDark = Color(0xFF212121); // Gray 900

  /// ═══════════════════════════════════════════════════════════════════════════
  /// UTILITY / COMMON SIZES
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Minimum touch target size (48x48 per Material guidelines)
  static const double touchTargetSize = 48.0;

  /// Icon sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  /// Avatar sizes
  static const double avatarSizeXs = 32.0;
  static const double avatarSizeSm = 40.0;
  static const double avatarSizeMd = 56.0;
  static const double avatarSizeLg = 72.0;

  /// Common container widths
  static const double containerMaxWidth = 800.0;
  static const double containerMaxWidthMobile = double.infinity;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// USAGE EXAMPLES
/// ═══════════════════════════════════════════════════════════════════════════

/*
// ❌ OLD (Magic numbers everywhere)
Container(
  padding: const EdgeInsets.all(20),
  margin: const EdgeInsets.only(bottom: 24),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 12,
      ),
    ],
  ),
  child: Text(
    'Title',
    style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
)

// ✅ NEW (Using design tokens)
Container(
  padding: DesignTokens.paddingM,
  margin: EdgeInsets.only(bottom: DesignTokens.spacingL),
  decoration: BoxDecoration(
    borderRadius: DesignTokens.borderRadiusMd,
    boxShadow: DesignTokens.shadowLg,
  ),
  child: Text(
    'Title',
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontWeight: DesignTokens.fontWeightBold,
      letterSpacing: DesignTokens.letterSpacingTight,
    ),
  ),
)

// ✅ Animated button (using tokens)
GestureDetector(
  onTap: () => _controller.forward(),
  child: ScaleTransition(
    scale: _controller.drive(Tween(begin: 1.0, end: 0.98)),
    child: Container(
      decoration: BoxDecoration(
        color: DesignTokens.primaryMain,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowMd,
      ),
      padding: DesignTokens.paddingM,
      child: Text(
        'Tap me',
        style: TextStyle(color: Colors.white),
      ),
    ),
  ),
)
*/
