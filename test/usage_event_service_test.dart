import 'package:curavault_admin/services/usage_event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsageEventService property guards', () {
    test('rejects unsafe keys', () {
      final props = UsageEventService.sanitizeProperties({'title': 'should-not-send'});
      final ok = UsageEventService.validateSafeProperties(props);
      expect(ok, isFalse);
    });

    test('rejects prompt/response/query tokens (case-insensitive)', () {
      final props = UsageEventService.sanitizeProperties({'PromptText': 'nope'});
      final ok = UsageEventService.validateSafeProperties(props);
      expect(ok, isFalse);
    });

    test('allows safe primitives and drops complex values', () {
      final props = UsageEventService.sanitizeProperties({
        'model': 'gpt-4o',
        'input_tokens': 10,
        'nested': {'ok': true, 'bad': Object()},
        'badObj': Object(),
      });

      expect(props['model'], 'gpt-4o');
      expect(props['input_tokens'], 10);
      expect(props.containsKey('badObj'), isFalse);
      expect((props['nested'] as Map)['ok'], true);
      expect((props['nested'] as Map).containsKey('bad'), isFalse);
    });
  });
}
