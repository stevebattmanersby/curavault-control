import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: AppSpacing.md),
              Text('Checking admin access…'),
            ],
          ),
        ),
      ),
    );
  }
}
