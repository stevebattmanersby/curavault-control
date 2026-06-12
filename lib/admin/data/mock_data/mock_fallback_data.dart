import 'package:curavault_admin/admin/data/admin_repository.dart';
import 'package:curavault_admin/admin/data/mock_admin_repository.dart';

/// Mock fallback repository used when live Supabase summary tables/views
/// are not available yet.
///
/// This is deliberately kept separate from the Supabase query layer so it's
/// obvious what is real vs mocked.
class MockFallbackData {
  static AdminRepository create() => MockAdminRepository();
}
