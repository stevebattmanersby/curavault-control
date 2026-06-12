import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';

class AdminBreakpoints {
  static const double desktop = 1100;
  static const double tablet = 860;
}

class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({super.key, required this.title, this.subtitle, required this.child, this.actions});

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(subtitle!, style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding, this.header, this.aiEmphasis = false});

  final Widget? header;
  final Widget child;
  final EdgeInsets? padding;
  final bool aiEmphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations || MediaQuery.of(context).accessibleNavigation;
    final borderColor = aiEmphasis ? tokens.borderGlow.withValues(alpha: 0.75) : tokens.border;
    final shadows = aiEmphasis ? tokens.glowShadow : tokens.cardShadow;
    final cardColor = tokens.surfaceElevated.withValues(alpha: aiEmphasis ? 0.68 : 1);

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: shadows,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[header!, const SizedBox(height: AppSpacing.sm)],
            child,
          ],
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.deltaLabel, this.icon});

  final String label;
  final String value;
  final String? deltaLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AdminCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(value, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (deltaLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(deltaLabel!, style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
