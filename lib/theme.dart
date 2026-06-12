import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// ADMIN VISUAL THEMES (Light / Dark / AI)
// =============================================================================

enum AdminThemeMode {
  light,
  dark,
  ai;

  static AdminThemeMode parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'light':
        return AdminThemeMode.light;
      case 'dark':
        return AdminThemeMode.dark;
      case 'ai':
      case 'aI':
      case 'a_i':
        return AdminThemeMode.ai;
      default:
        return AdminThemeMode.light;
    }
  }

  String get label => switch (this) {
    AdminThemeMode.light => 'Light',
    AdminThemeMode.dark => 'Dark',
    AdminThemeMode.ai => 'AI',
  };
}

@immutable
class AdminThemeTokens extends ThemeExtension<AdminThemeTokens> {
  const AdminThemeTokens({
    required this.background,
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderGlow,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.aiAccent,
    required this.cardShadow,
    required this.glowShadow,
  });

  final Color background;
  final Gradient? backgroundGradient;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderGlow;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color aiAccent;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> glowShadow;

  @override
  AdminThemeTokens copyWith({
    Color? background,
    Gradient? backgroundGradient,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderGlow,
    Color? primary,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? aiAccent,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? glowShadow,
  }) {
    return AdminThemeTokens(
      background: background ?? this.background,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderGlow: borderGlow ?? this.borderGlow,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      aiAccent: aiAccent ?? this.aiAccent,
      cardShadow: cardShadow ?? this.cardShadow,
      glowShadow: glowShadow ?? this.glowShadow,
    );
  }

  @override
  ThemeExtension<AdminThemeTokens> lerp(ThemeExtension<AdminThemeTokens>? other, double t) {
    if (other is! AdminThemeTokens) return this;
    return AdminThemeTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundGradient: t < 0.5 ? backgroundGradient : other.backgroundGradient,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      border: Color.lerp(border, other.border, t) ?? border,
      borderGlow: Color.lerp(borderGlow, other.borderGlow, t) ?? borderGlow,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
      aiAccent: Color.lerp(aiAccent, other.aiAccent, t) ?? aiAccent,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      glowShadow: t < 0.5 ? glowShadow : other.glowShadow,
    );
  }
}

extension AdminTokensContext on BuildContext {
  AdminThemeTokens get tokens => Theme.of(this).extension<AdminThemeTokens>() ?? _fallbackTokens(Theme.of(this));
}

AdminThemeTokens _fallbackTokens(ThemeData theme) {
  final cs = theme.colorScheme;
  return AdminThemeTokens(
    background: theme.scaffoldBackgroundColor,
    backgroundGradient: null,
    surface: cs.surface,
    surfaceElevated: cs.surfaceContainerHighest,
    border: cs.outline.withValues(alpha: 0.18),
    borderGlow: cs.primary.withValues(alpha: 0.35),
    primary: cs.primary,
    secondary: cs.tertiary,
    textPrimary: cs.onSurface,
    textSecondary: cs.onSurfaceVariant,
    success: Colors.green,
    warning: Colors.orange,
    danger: cs.error,
    info: Colors.blue,
    aiAccent: cs.tertiary,
    cardShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10))],
    glowShadow: const [],
  );
}

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// Modern, neutral color palette for light mode
/// Uses soft grays and blues instead of purple for a contemporary look
class LightModeColors {
  // Primary: Muted teal for a calm medical/security feel
  static const lightPrimary = Color(0xFF1F8A8A);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFCFEDED);
  static const lightOnPrimaryContainer = Color(0xFF0D3A3A);

  // Secondary: Slate
  static const lightSecondary = Color(0xFF475569);
  static const lightOnSecondary = Color(0xFFFFFFFF);

  // Tertiary: Softer teal accent
  static const lightTertiary = Color(0xFF2CA6A6);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surface and background
  static const lightSurface = Color(0xFFFBFDFD);
  static const lightOnSurface = Color(0xFF1A1C1E);
  static const lightBackground = Color(0xFFF7F9FA);
  static const lightSurfaceVariant = Color(0xFFE7EEF0);
  static const lightOnSurfaceVariant = Color(0xFF334155);

  // Outline and shadow
  static const lightOutline = Color(0xFF94A3B8);
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFF8FD2D2);
}

/// Dark mode colors with good contrast
class DarkModeColors {
  static const darkPrimary = Color(0xFF8FD2D2);
  static const darkOnPrimary = Color(0xFF0D3A3A);
  static const darkPrimaryContainer = Color(0xFF0F4E4E);
  static const darkOnPrimaryContainer = Color(0xFFCFEDED);

  static const darkSecondary = Color(0xFFB8C4D4);
  static const darkOnSecondary = Color(0xFF1F2937);

  static const darkTertiary = Color(0xFF7CCCCC);
  static const darkOnTertiary = Color(0xFF073434);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  static const darkSurface = Color(0xFF0B1220);
  static const darkOnSurface = Color(0xFFE5E7EB);
  static const darkSurfaceVariant = Color(0xFF111B2E);
  static const darkOnSurfaceVariant = Color(0xFFCBD5E1);

  // Outline and shadow
  static const darkOutline = Color(0xFF334155);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF1F8A8A);
}

/// AI mode colors: dark navy base + violet/cyan glow and glassy panels.
class AiModeColors {
  static const base = Color(0xFF070B14);
  static const base2 = Color(0xFF0A1222);
  static const surface = Color(0xFF0C162A);
  static const glass = Color(0xFF0C162A);
  static const border = Color(0xFF22304A);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const magenta = Color(0xFFEC4899);
  static const text = Color(0xFFEAF0FF);
  static const textDim = Color(0xFFB8C4E0);
  static const danger = Color(0xFFFF7A90);
  static const warning = Color(0xFFFFC36A);
  static const success = Color(0xFF34D399);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: LightModeColors.lightOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  dividerTheme: DividerThemeData(color: LightModeColors.lightOutline.withValues(alpha: 0.18), space: 1, thickness: 1),
  dataTableTheme: DataTableThemeData(
    headingRowColor: WidgetStatePropertyAll(LightModeColors.lightSurfaceVariant.withValues(alpha: 0.65)),
    dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
    headingTextStyle: _buildTextTheme(Brightness.light).labelLarge?.copyWith(fontWeight: FontWeight.w800, color: LightModeColors.lightOnSurfaceVariant),
    dataTextStyle: _buildTextTheme(Brightness.light).bodyMedium?.copyWith(color: LightModeColors.lightOnSurface),
    dividerThickness: 0.8,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.25))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.22))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.4)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: LightModeColors.lightOnSurface,
    contentTextStyle: _buildTextTheme(Brightness.light).bodyMedium?.copyWith(color: LightModeColors.lightSurface),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
  ),
  extensions: [
    AdminThemeTokens(
      background: LightModeColors.lightBackground,
      backgroundGradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFAFCFD), Color(0xFFF3F7F8)]),
      surface: LightModeColors.lightSurface,
      surfaceElevated: Colors.white,
      border: LightModeColors.lightOutline.withValues(alpha: 0.22),
      borderGlow: LightModeColors.lightPrimary.withValues(alpha: 0.28),
      primary: LightModeColors.lightPrimary,
      secondary: const Color(0xFF4F46E5),
      textPrimary: LightModeColors.lightOnSurface,
      textSecondary: LightModeColors.lightOnSurfaceVariant,
      success: const Color(0xFF16A34A),
      warning: const Color(0xFFF97316),
      danger: const Color(0xFFE11D48),
      info: const Color(0xFF2563EB),
      aiAccent: const Color(0xFF7C3AED),
      cardShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 10))],
      glowShadow: [BoxShadow(color: LightModeColors.lightPrimary.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10))],
    ),
  ],
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: DarkModeColors.darkOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  dividerTheme: DividerThemeData(color: DarkModeColors.darkOutline.withValues(alpha: 0.3), space: 1, thickness: 1),
  dataTableTheme: DataTableThemeData(
    headingRowColor: WidgetStatePropertyAll(DarkModeColors.darkSurfaceVariant.withValues(alpha: 0.75)),
    dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
    headingTextStyle: _buildTextTheme(Brightness.dark).labelLarge?.copyWith(fontWeight: FontWeight.w800, color: DarkModeColors.darkOnSurfaceVariant),
    dataTextStyle: _buildTextTheme(Brightness.dark).bodyMedium?.copyWith(color: DarkModeColors.darkOnSurface),
    dividerThickness: 0.8,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurfaceVariant,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.6))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.55))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.4)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF111827),
    contentTextStyle: _buildTextTheme(Brightness.dark).bodyMedium?.copyWith(color: DarkModeColors.darkOnSurface),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
  ),
  extensions: [
    AdminThemeTokens(
      background: DarkModeColors.darkSurface,
      backgroundGradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1220), Color(0xFF08101E)]),
      surface: const Color(0xFF0F172A),
      surfaceElevated: DarkModeColors.darkSurfaceVariant,
      border: DarkModeColors.darkOutline.withValues(alpha: 0.55),
      borderGlow: DarkModeColors.darkPrimary.withValues(alpha: 0.22),
      primary: const Color(0xFF22D3EE),
      secondary: DarkModeColors.darkPrimary,
      textPrimary: DarkModeColors.darkOnSurface,
      textSecondary: DarkModeColors.darkOnSurfaceVariant,
      success: const Color(0xFF34D399),
      warning: const Color(0xFFFB923C),
      danger: const Color(0xFFFB7185),
      info: const Color(0xFF60A5FA),
      aiAccent: const Color(0xFF7CCCCC),
      cardShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 22, offset: const Offset(0, 12))],
      glowShadow: [BoxShadow(color: const Color(0xFF22D3EE).withValues(alpha: 0.08), blurRadius: 28, offset: const Offset(0, 12))],
    ),
  ],
  textTheme: _buildTextTheme(Brightness.dark),
);

ThemeData get aiTheme {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AiModeColors.base,
    colorScheme: const ColorScheme.dark(
      primary: AiModeColors.violet,
      onPrimary: AiModeColors.text,
      secondary: AiModeColors.cyan,
      onSecondary: AiModeColors.base,
      tertiary: AiModeColors.magenta,
      onTertiary: AiModeColors.text,
      surface: AiModeColors.surface,
      onSurface: AiModeColors.text,
      error: AiModeColors.danger,
      onError: AiModeColors.base,
      outline: AiModeColors.border,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    dividerTheme: DividerThemeData(color: AiModeColors.border.withValues(alpha: 0.55), space: 1, thickness: 1),
    textTheme: _buildTextTheme(Brightness.dark).apply(bodyColor: AiModeColors.text, displayColor: AiModeColors.text),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0B1220),
      contentTextStyle: _buildTextTheme(Brightness.dark).bodyMedium?.copyWith(color: AiModeColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AiModeColors.surface.withValues(alpha: 0.72),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AiModeColors.border.withValues(alpha: 0.6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AiModeColors.border.withValues(alpha: 0.55))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AiModeColors.cyan, width: 1.3)),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(const Color(0xFF0F1B33).withValues(alpha: 0.9)),
      headingTextStyle: _buildTextTheme(Brightness.dark).labelLarge?.copyWith(fontWeight: FontWeight.w900, color: AiModeColors.textDim),
      dataTextStyle: _buildTextTheme(Brightness.dark).bodyMedium?.copyWith(color: AiModeColors.text),
      dividerThickness: 0.8,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AiModeColors.surface.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: AiModeColors.border.withValues(alpha: 0.72), width: 1),
      ),
    ),
  );

  return base.copyWith(
    extensions: [
      AdminThemeTokens(
        background: AiModeColors.base,
        backgroundGradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AiModeColors.base, AiModeColors.base2]),
        surface: AiModeColors.glass.withValues(alpha: 0.64),
        surfaceElevated: AiModeColors.surface.withValues(alpha: 0.78),
        border: AiModeColors.border.withValues(alpha: 0.65),
        borderGlow: AiModeColors.cyan.withValues(alpha: 0.55),
        primary: AiModeColors.violet,
        secondary: AiModeColors.cyan,
        textPrimary: AiModeColors.text,
        textSecondary: AiModeColors.textDim,
        success: AiModeColors.success,
        warning: AiModeColors.warning,
        danger: AiModeColors.danger,
        info: AiModeColors.cyan,
        aiAccent: AiModeColors.violet,
        cardShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 16))],
        glowShadow: [
          BoxShadow(color: AiModeColors.violet.withValues(alpha: 0.14), blurRadius: 34, offset: const Offset(0, 16)),
          BoxShadow(color: AiModeColors.cyan.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 18)),
        ],
      ),
    ],
  );
}

/// Build text theme using Inter font family
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
