import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pill/segmented theme selector matching the Control Site design direction.
///
/// - Light (sun)
/// - Dark (moon)
/// - AI (sparkles)
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminThemeStore>();
    final tokens = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations || MediaQuery.of(context).accessibleNavigation;
    final height = compact ? 36.0 : 42.0;
    final padding = compact ? const EdgeInsets.all(2) : const EdgeInsets.all(3);

    final glow = store.mode == AdminThemeMode.ai;
    final outerShadow = glow && !reduceMotion
        ? [
            ...tokens.glowShadow,
            BoxShadow(color: tokens.secondary.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 14)),
          ]
        : tokens.cardShadow;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: store.mode == AdminThemeMode.ai ? 0.55 : 1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: glow ? tokens.borderGlow.withValues(alpha: 0.70) : tokens.border, width: 1),
        boxShadow: outerShadow,
      ),
      child: _Segments(compact: compact),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminThemeStore>();
    final tokens = context.tokens;

    final selected = store.mode;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800);
    final iconSize = compact ? 18.0 : 20.0;

    return SegmentedButton<AdminThemeMode>(
      showSelectedIcon: false,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: compact ? 10 : 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
        overlayColor: WidgetStatePropertyAll(tokens.primary.withValues(alpha: 0.06)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            if (selected == AdminThemeMode.ai) return tokens.primary.withValues(alpha: 0.22);
            if (selected == AdminThemeMode.dark) return tokens.primary.withValues(alpha: 0.20);
            return tokens.primary.withValues(alpha: 0.16);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.textPrimary;
          return tokens.textSecondary;
        }),
      ),
      segments: [
        ButtonSegment(
          value: AdminThemeMode.light,
          label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.wb_sunny_outlined, size: iconSize), if (!compact) const SizedBox(width: 8), if (!compact) Text('Light', style: labelStyle)]),
          tooltip: 'Light theme',
        ),
        ButtonSegment(
          value: AdminThemeMode.dark,
          label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.nightlight_outlined, size: iconSize), if (!compact) const SizedBox(width: 8), if (!compact) Text('Dark', style: labelStyle)]),
          tooltip: 'Dark theme',
        ),
        ButtonSegment(
          value: AdminThemeMode.ai,
          label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome, size: iconSize), if (!compact) const SizedBox(width: 8), if (!compact) Text('AI', style: labelStyle)]),
          tooltip: 'AI theme',
        ),
      ],
      selected: <AdminThemeMode>{selected},
      onSelectionChanged: (set) {
        final next = set.isEmpty ? selected : set.first;
        store.setMode(next);
      },
    );
  }
}
