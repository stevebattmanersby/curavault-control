import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Indicates what powered a page's data.
///
/// CRITICAL: In release builds, the UI must never silently show mock data.
enum AdminDataSourceKind { live, mock, notInstrumented, error }

enum AdminDataSourceKey {
  dashboard,
  users,
  auditLogs,
  support,
  plansPermissions,
  usageAnalytics,
  storage,
  aiUsage,
  billing,
  compliance,
  systemHealth,
}

@immutable
class AdminDataSourceStatus {
  const AdminDataSourceStatus({required this.kind, this.message, this.queryName, this.rowCount, this.lastRefreshedAt, this.safeErrorMessage});

  final AdminDataSourceKind kind;
  final String? message;

  /// The RPC/view/table powering the page (safe metadata).
  final String? queryName;

  /// Count of rows returned by the last successful fetch (safe aggregate).
  final int? rowCount;

  /// When the page last refreshed (UTC recommended).
  final DateTime? lastRefreshedAt;

  /// A privacy-safe error message intended for UI display.
  final String? safeErrorMessage;

  AdminDataSourceStatus copyWith({AdminDataSourceKind? kind, String? message, String? queryName, int? rowCount, DateTime? lastRefreshedAt, String? safeErrorMessage}) =>
      AdminDataSourceStatus(kind: kind ?? this.kind, message: message ?? this.message, queryName: queryName ?? this.queryName, rowCount: rowCount ?? this.rowCount, lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt, safeErrorMessage: safeErrorMessage ?? this.safeErrorMessage);
}

/// Thrown when a backend view/RPC required by the Control Site is not deployed.
///
/// In release, this should result in a clear empty/error state, never mock data.
class AdminNotInstrumentedException implements Exception {
  AdminNotInstrumentedException([this.message = 'This data source is not instrumented yet.']);
  final String message;
  @override
  String toString() => message;
}

/// A small pill badge that shows the current admin page's data source.
class AdminDataSourceBadge extends StatelessWidget {
  const AdminDataSourceBadge({super.key, required this.status});

  final AdminDataSourceStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations || MediaQuery.of(context).accessibleNavigation;

    Color bg;
    Color fg;
    Color dot;
    String label;

    switch (status.kind) {
      case AdminDataSourceKind.live:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        dot = Colors.green;
        label = 'Live';
        break;
      case AdminDataSourceKind.mock:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        dot = Colors.orange;
        label = 'Mock';
        break;
      case AdminDataSourceKind.notInstrumented:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        dot = cs.outline;
        label = 'Not instrumented';
        break;
      case AdminDataSourceKind.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        dot = cs.error;
        label = 'Error';
        break;
    }

    final tooltipLines = <String>[];
    if ((status.message ?? '').trim().isNotEmpty) tooltipLines.add(status.message!.trim());
    if ((status.queryName ?? '').trim().isNotEmpty) tooltipLines.add('Query: ${status.queryName}');
    if (status.rowCount != null) tooltipLines.add('Rows: ${status.rowCount}');
    if (status.lastRefreshedAt != null) tooltipLines.add('Refreshed: ${status.lastRefreshedAt!.toIso8601String()}');
    if ((status.safeErrorMessage ?? '').trim().isNotEmpty) tooltipLines.add('Error: ${status.safeErrorMessage}');
    final tooltip = tooltipLines.isEmpty ? null : tooltipLines.join('\n');

    final pill = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    if (tooltip == null || tooltip.isEmpty) return pill;
    return Tooltip(message: tooltip, child: pill);
  }
}

/// Standard empty state when a live backend source isn't deployed yet.
class AdminNotInstrumentedPanel extends StatelessWidget {
  const AdminNotInstrumentedPanel({super.key, this.details});
  final String? details;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('This data source is not instrumented yet.', style: Theme.of(context).textTheme.titleMedium),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(details!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
