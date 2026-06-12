import 'dart:convert';

import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';

class AdminCsvExport {
  static String auditLogsToCsv(List<AuditLogEntry> logs) {
    final rows = <List<String>>[];
    rows.add([
      'created_at',
      'admin_user_id',
      'target_user_id',
      'action_type',
      'result',
      'reason',
      'ticket_reference',
      'ip_address',
      'user_agent',
      'previous_value_json',
      'new_value_json',
    ]);

    for (final l in logs) {
      rows.add([
        l.createdAt.toIso8601String(),
        l.adminUserId,
        l.targetUserId ?? '',
        l.actionType,
        l.result,
        l.reason ?? '',
        l.ticketReference ?? '',
        l.ipAddress ?? '',
        l.userAgent ?? '',
        AdminAuditRedactor.jsonStringOrNull(l.previousValue),
        AdminAuditRedactor.jsonStringOrNull(l.newValue),
      ]);
    }

    final sb = StringBuffer();
    for (final r in rows) {
      sb.writeln(r.map(_escape).join(','));
    }
    return sb.toString();
  }

  static String _escape(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
    if (!needs) return v;
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }

  static List<int> utf8Bytes(String csv) => const Utf8Encoder().convert(csv);
}
