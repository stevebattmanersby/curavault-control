import 'package:flutter/material.dart';

@immutable
class AdminChangeConfirmation {
  const AdminChangeConfirmation({required this.reason, required this.ticketReference});
  final String reason;
  final String? ticketReference;
}

/// Bottom-sheet confirmation that requires a reason and shows before/after values.
class AdminChangeConfirmSheet extends StatefulWidget {
  const AdminChangeConfirmSheet({
    super.key,
    required this.title,
    required this.summary,
    required this.previousValue,
    required this.newValue,
    required this.confirmLabel,
  });

  final String title;
  final String summary;
  final String previousValue;
  final String newValue;
  final String confirmLabel;

  static Future<AdminChangeConfirmation?> show(
    BuildContext context, {
    required String title,
    required String summary,
    required String previousValue,
    required String newValue,
    String confirmLabel = 'Confirm change',
  }) =>
      showModalBottomSheet<AdminChangeConfirmation>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: AdminChangeConfirmSheet(title: title, summary: summary, previousValue: previousValue, newValue: newValue, confirmLabel: confirmLabel),
        ),
      );

  @override
  State<AdminChangeConfirmSheet> createState() => _AdminChangeConfirmSheetState();
}

class _AdminChangeConfirmSheetState extends State<AdminChangeConfirmSheet> {
  final _reasonController = TextEditingController();
  final _ticketController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    _ticketController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Reason is required.');
      return;
    }
    final ticket = _ticketController.text.trim();
    Navigator.of(context).pop(AdminChangeConfirmation(reason: reason, ticketReference: ticket.isEmpty ? null : ticket));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: t.titleLarge),
            const SizedBox(height: 8),
            Text(widget.summary, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            _ValueDiffCard(previousValue: widget.previousValue, newValue: widget.newValue),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'Explain why this change is needed…',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Ticket reference (optional)',
                hintText: 'e.g. SUP-1234',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: cs.onSurface)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.confirmLabel, style: TextStyle(color: cs.onPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueDiffCard extends StatelessWidget {
  const _ValueDiffCard({required this.previousValue, required this.newValue});
  final String previousValue;
  final String newValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change preview', style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ValueTile(label: 'Previous', value: previousValue)),
              const SizedBox(width: 12),
              Expanded(child: _ValueTile(label: 'New', value: newValue, emphasize: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value, style: t.titleMedium?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}
