import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';

class SectionPlaceholderPage extends StatelessWidget {
  const SectionPlaceholderPage(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.sections});

  final String title;
  final String subtitle;
  final IconData icon;
  final List<PlaceholderSection> sections;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminPageScaffold(
      title: title,
      subtitle: subtitle,
      child: ListView(
        children: [
          AdminCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Icon(icon, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'This section is scaffolded with privacy-safe placeholders. Connect Supabase to populate real operational metrics (never medical content).',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in sections) ...[
            AdminCard(
                header: Text(s.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                child: s.child),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class PlaceholderSection {
  const PlaceholderSection({required this.title, required this.child});

  static PlaceholderSection of(
          {required String title, required Widget child}) =>
      PlaceholderSection(title: title, child: child);

  final String title;
  final Widget child;
}
