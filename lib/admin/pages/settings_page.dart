import 'package:curavault_admin/admin/pages/section_placeholder.dart';
import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/admin/widgets/theme_selector.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeStore = context.watch<AdminThemeStore>();
    return SectionPlaceholderPage(
      title: 'Settings',
      subtitle: 'Appearance, security defaults, and environment settings.',
      icon: Icons.settings_outlined,
      sections: [
        PlaceholderSection.of(
          title: 'Appearance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Theme',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const ThemeSelector(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ThemePreferenceHint(mode: themeStore.mode),
              const SizedBox(height: AppSpacing.lg),
              const ThemePreview(),
            ],
          ),
        ),
        PlaceholderSection.of(
          title: 'Security defaults (example)',
          child: Column(
            children: const [
              _Row(label: 'Email visibility', value: 'Admins only'),
              _Row(label: 'PII in logs', value: 'Blocked'),
              _Row(label: 'AI prompt retention', value: 'Disabled (recommended)'),
              _Row(label: 'Support access window', value: '15 minutes'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemePreferenceHint extends StatelessWidget {
  const _ThemePreferenceHint({required this.mode});
  final AdminThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Theme is saved locally and (when permitted) synced to your admin profile.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme preview', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: const [
            _PreviewDashboardCard(),
            _PreviewAlert(),
            _PreviewTableRow(),
            _PreviewButtons(),
            _PreviewAiCard(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Preview uses admin-safe example content only.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PreviewDashboardCard extends StatelessWidget {
  const _PreviewDashboardCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: AdminCard(
        header: Text('Active paid users', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.people_alt_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2,184', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('↑ 4.2% vs last 30d', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAlert extends StatelessWidget {
  const _PreviewAlert();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: tokens.danger.withValues(alpha: 0.45), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: tokens.danger, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Failed payments increased in the last 24h.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTableRow extends StatelessWidget {
  const _PreviewTableRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 420,
      child: AdminCard(
        header: Text('Example table', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('User ID', style: t.labelMedium?.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w900))),
                  Expanded(child: Text('Plan', style: t.labelMedium?.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w900))),
                  Expanded(child: Text('Status', style: t.labelMedium?.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('usr_100012', style: t.bodyMedium)),
                Expanded(child: Text('premium', style: t.bodyMedium?.copyWith(color: tokens.textSecondary))),
                Expanded(child: _Pill(label: 'active', color: tokens.success)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewButtons extends StatelessWidget {
  const _PreviewButtons();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 360,
      child: AdminCard(
        header: Text('Buttons', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: () {},
              icon: Icon(Icons.check_circle_outline, color: cs.onPrimary),
              label: Text('Primary', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary)),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.tune, color: cs.onSurface),
              label: Text('Secondary', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAiCard extends StatelessWidget {
  const _PreviewAiCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 360,
      child: AdminCard(
        aiEmphasis: true,
        header: Row(
          children: [
            Icon(Icons.auto_awesome, color: tokens.secondary, size: 18),
            const SizedBox(width: 8),
            Text('AI usage (aggregate)', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tokens this month: 18.4M', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Estimated cost: \$4,120', style: t.bodyMedium?.copyWith(color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
