import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminAuditRedactor', () {
    test('redacts sensitive top-level and nested fields', () {
      final redacted = AdminAuditRedactor.redactMap({
        'reason': 'billing correction',
        'document_name': 'scan.pdf',
        'nested': {
          'promptText': 'private prompt',
          'count': 4,
        },
      });

      expect(redacted?['reason'], 'billing correction');
      expect(redacted?['document_name'], AdminAuditRedactor.redacted);
      expect((redacted?['nested'] as Map)['promptText'],
          AdminAuditRedactor.redacted);
      expect((redacted?['nested'] as Map)['count'], 4);
    });

    test('redacts diagnostic-looking free text and truncates long safe text',
        () {
      final redacted = AdminAuditRedactor.redactMap({
        'safe_label': List.filled(250, 'A').join(),
        'comment': 'User reported a diagnosis in this text.',
      });

      expect((redacted?['safe_label'] as String).length, lessThan(250));
      expect(redacted?['comment'], AdminAuditRedactor.redacted);
    });
  });
}
