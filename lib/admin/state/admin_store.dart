import 'dart:async';

import 'package:curavault_admin/admin/data/admin_repository.dart';
import 'package:curavault_admin/admin/data/mock_admin_repository.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_repository.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

class AdminStore extends ChangeNotifier {
  AdminStore({required AdminAuthStore auth, AdminRepository? repository})
      : _auth = auth,
        _repository = repository ?? _buildRepository() {
    _auth.addListener(_onAuthChanged);
  }

  static AdminRepository _buildRepository() {
    // Prefer Supabase-backed repository when env is configured.
    if (SupabaseConfig.supabaseUrl.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty && AdminAuthStore.supabaseServiceRoleKey.isEmpty) {
      return SupabaseAdminRepository();
    }
    return MockAdminRepository();
  }

  final AdminAuthStore _auth;

  final AdminRepository _repository;

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    // When an admin becomes authorized, load data.
    if (_auth.isAuthorized && !_isLoading && _currentAdmin == null) {
      unawaited(bootstrap());
    }

    // On sign out, clear sensitive state.
    if (!_auth.isSignedIn) {
      _currentAdmin = null;
      _users = const [];
      _supportSessions = const [];
      _auditLogs = const [];
      _dashboard = null;
      _usageAnalytics = null;
      _storage = null;
      _aiUsage = null;
      _billing = null;
      _compliance = null;
      _systemHealth = null;
      _securityChecklist = null;
      notifyListeners();
    }
  }

  AdminUser? _currentAdmin;
  AdminUser? get currentAdmin => _currentAdmin;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _userSearch = '';
  String get userQuery => _userSearch;

  UserListFilters _userFilters = const UserListFilters();
  UserListFilters get userFilters => _userFilters;

  List<UserAccountSummary> _users = const [];
  List<UserAccountSummary> get users => _users;

  List<AuditLogEntry> _auditLogs = const [];
  List<AuditLogEntry> get auditLogs => _auditLogs;

  AuditLogQuery _auditLogQuery = const AuditLogQuery();
  AuditLogQuery get auditLogQuery => _auditLogQuery;

  bool _isAuditLogsLoading = false;
  bool get isAuditLogsLoading => _isAuditLogsLoading;

  String _supportSearch = '';
  String get supportQuery => _supportSearch;

  SupportQueueFilters _supportFilters = const SupportQueueFilters();
  SupportQueueFilters get supportFilters => _supportFilters;

  List<SupportSessionSummary> _supportSessions = const [];
  List<SupportSessionSummary> get supportSessions => _supportSessions;

  // Plans & permissions
  List<PlanOverviewRow> _plansOverview = const [];
  List<PlanOverviewRow> get plansOverview => _plansOverview;

  List<FeatureFlagDefinition> _featureFlags = const [];
  List<FeatureFlagDefinition> get featureFlags => _featureFlags;

  List<LimitOverrideRow> _limitOverrides = const [];
  List<LimitOverrideRow> get limitOverrides => _limitOverrides;

  DashboardQuery _dashboardQuery = const DashboardQuery(range: AdminDateRangePreset.days30);
  DashboardQuery get dashboardQuery => _dashboardQuery;

  DashboardSnapshot? _dashboard;
  DashboardSnapshot? get dashboard => _dashboard;

  bool _isDashboardLoading = false;
  bool get isDashboardLoading => _isDashboardLoading;

  // Usage analytics
  UsageAnalyticsQuery _usageAnalyticsQuery = const UsageAnalyticsQuery(range: AdminDateRangePreset.days30);
  UsageAnalyticsQuery get usageAnalyticsQuery => _usageAnalyticsQuery;

  UsageAnalyticsSnapshot? _usageAnalytics;
  UsageAnalyticsSnapshot? get usageAnalytics => _usageAnalytics;

  bool _isUsageAnalyticsLoading = false;
  bool get isUsageAnalyticsLoading => _isUsageAnalyticsLoading;

  // Storage
  StorageQuery _storageQuery = const StorageQuery(range: AdminDateRangePreset.days30);
  StorageQuery get storageQuery => _storageQuery;

  StorageSnapshot? _storage;
  StorageSnapshot? get storage => _storage;

  bool _isStorageLoading = false;
  bool get isStorageLoading => _isStorageLoading;

  // AI usage
  AiUsageQuery _aiUsageQuery = const AiUsageQuery(range: AdminDateRangePreset.days30);
  AiUsageQuery get aiUsageQuery => _aiUsageQuery;

  AiUsageSnapshot? _aiUsage;
  AiUsageSnapshot? get aiUsage => _aiUsage;

  bool _isAiUsageLoading = false;
  bool get isAiUsageLoading => _isAiUsageLoading;

  // Billing
  BillingQuery _billingQuery = const BillingQuery(range: AdminDateRangePreset.days30);
  BillingQuery get billingQuery => _billingQuery;

  BillingSnapshot? _billing;
  BillingSnapshot? get billing => _billing;

  bool _isBillingLoading = false;
  bool get isBillingLoading => _isBillingLoading;

  // Compliance
  ComplianceQuery _complianceQuery = const ComplianceQuery(range: AdminDateRangePreset.days30);
  ComplianceQuery get complianceQuery => _complianceQuery;

  ComplianceSnapshot? _compliance;
  ComplianceSnapshot? get compliance => _compliance;

  bool _isComplianceLoading = false;
  bool get isComplianceLoading => _isComplianceLoading;

  // System health
  SystemHealthQuery _systemHealthQuery = const SystemHealthQuery(range: AdminDateRangePreset.days30);
  SystemHealthQuery get systemHealthQuery => _systemHealthQuery;

  SystemHealthSnapshot? _systemHealth;
  SystemHealthSnapshot? get systemHealth => _systemHealth;

  bool _isSystemHealthLoading = false;
  bool get isSystemHealthLoading => _isSystemHealthLoading;

  // Security checklist
  SecurityChecklistSnapshot? _securityChecklist;
  SecurityChecklistSnapshot? get securityChecklist => _securityChecklist;

  bool _isSecurityChecklistLoading = false;
  bool get isSecurityChecklistLoading => _isSecurityChecklistLoading;

  Future<void> bootstrap() async {
    // Never load admin data unless auth gate is satisfied.
    if (!_auth.isAuthorized) return;
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _currentAdmin = await _repository.getCurrentAdmin();
      await Future.wait([
        refreshUsers(),
        refreshSupportQueue(),
        refreshAuditLogs(),
        refreshDashboard(),
        refreshPlansOverview(),
        refreshFeatureFlags(),
        refreshLimitOverrides(),
        refreshUsageAnalytics(),
        refreshStorage(),
        refreshAiUsage(),
        refreshBilling(),
        refreshCompliance(),
        refreshSystemHealth(),
        refreshSecurityChecklist(),
      ]);
    } catch (e) {
      debugPrint('AdminStore.bootstrap failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSecurityChecklist() async {
    if (_isSecurityChecklistLoading) return;
    _isSecurityChecklistLoading = true;
    notifyListeners();
    try {
      _securityChecklist = await _repository.getSecurityChecklistSnapshot();
    } catch (e) {
      debugPrint('AdminStore.refreshSecurityChecklist failed: $e');
    } finally {
      _isSecurityChecklistLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSystemHealthQuery(SystemHealthQuery query) async {
    _systemHealthQuery = query;
    notifyListeners();
    await refreshSystemHealth();
  }

  Future<void> refreshSystemHealth() async {
    if (_isSystemHealthLoading) return;
    _isSystemHealthLoading = true;
    notifyListeners();
    try {
      _systemHealth = await _repository.getSystemHealthSnapshot(query: _systemHealthQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshSystemHealth failed: $e');
    } finally {
      _isSystemHealthLoading = false;
      notifyListeners();
    }
  }

  Future<void> setComplianceQuery(ComplianceQuery query) async {
    _complianceQuery = query;
    notifyListeners();
    await refreshCompliance();
  }

  Future<void> refreshCompliance() async {
    if (_isComplianceLoading) return;
    _isComplianceLoading = true;
    notifyListeners();
    try {
      _compliance = await _repository.getComplianceSnapshot(query: _complianceQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshCompliance failed: $e');
    } finally {
      _isComplianceLoading = false;
      notifyListeners();
    }
  }

  Future<void> performComplianceAction(ComplianceActionRequest request) async {
    try {
      await _repository.performComplianceAction(request: request);
      await refreshAuditLogs();
      await refreshCompliance();
    } catch (e) {
      debugPrint('AdminStore.performComplianceAction failed: $e');
      rethrow;
    }
  }

  Future<void> setBillingQuery(BillingQuery query) async {
    _billingQuery = query;
    notifyListeners();
    await refreshBilling();
  }

  Future<void> refreshBilling() async {
    if (_isBillingLoading) return;
    _isBillingLoading = true;
    notifyListeners();
    try {
      _billing = await _repository.getBillingSnapshot(query: _billingQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshBilling failed: $e');
    } finally {
      _isBillingLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAiUsageQuery(AiUsageQuery query) async {
    _aiUsageQuery = query;
    notifyListeners();
    await refreshAiUsage();
  }

  Future<void> refreshAiUsage() async {
    if (_isAiUsageLoading) return;
    _isAiUsageLoading = true;
    notifyListeners();
    try {
      _aiUsage = await _repository.getAiUsageSnapshot(query: _aiUsageQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshAiUsage failed: $e');
    } finally {
      _isAiUsageLoading = false;
      notifyListeners();
    }
  }

  Future<void> setUserQuery(String query) async {
    _userSearch = query;
    notifyListeners();
    await refreshUsers();
  }

  Future<void> setUserFilters(UserListFilters filters) async {
    _userFilters = filters;
    notifyListeners();
    await refreshUsers();
  }

  Future<void> refreshUsers() async {
    try {
      _users = await _repository.listUsers(query: UserListQuery(search: _userSearch, filters: _userFilters), limit: 50);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminStore.refreshUsers failed: $e');
    }
  }

  Future<UserAccountDetail?> getUserDetail(String userId) async {
    try {
      final detail = await _repository.getUserDetail(userId: userId);

      final actorId = _currentAdmin?.id;
      if (actorId != null && actorId.isNotEmpty) {
        await _repository.createAuditLog(
          entry: AdminAuditLogCreate(
            adminUserId: actorId,
            targetUserId: userId,
            actionType: 'user_viewed',
            newValue: const {'view': 'user_detail'},
            result: 'success',
          ),
        );
      }

      return detail;
    } catch (e) {
      debugPrint('AdminStore.getUserDetail failed: $e');
      return null;
    }
  }

  Future<void> performUserAdminAction(AdminActionRequest request) async {
    try {
      await _repository.performUserAdminAction(request: request);
      await refreshAuditLogs();
    } catch (e) {
      debugPrint('AdminStore.performUserAdminAction failed: $e');
      rethrow;
    }
  }

  Future<void> refreshAuditLogs() async {
    if (_isAuditLogsLoading) return;
    _isAuditLogsLoading = true;
    notifyListeners();
    try {
      _auditLogs = await _repository.listAuditLogs(query: _auditLogQuery, limit: 80);
    } catch (e) {
      debugPrint('AdminStore.refreshAuditLogs failed: $e');
    } finally {
      _isAuditLogsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAuditLogQuery(AuditLogQuery query) async {
    _auditLogQuery = query;
    notifyListeners();
    await refreshAuditLogs();
  }

  Future<void> setDashboardQuery(DashboardQuery query) async {
    _dashboardQuery = query;
    notifyListeners();
    await refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    if (_isDashboardLoading) return;
    _isDashboardLoading = true;
    notifyListeners();
    try {
      _dashboard = await _repository.getDashboardSnapshot(query: _dashboardQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshDashboard failed: $e');
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> setUsageAnalyticsQuery(UsageAnalyticsQuery query) async {
    _usageAnalyticsQuery = query;
    notifyListeners();
    await refreshUsageAnalytics();
  }

  Future<void> refreshUsageAnalytics() async {
    if (_isUsageAnalyticsLoading) return;
    _isUsageAnalyticsLoading = true;
    notifyListeners();
    try {
      _usageAnalytics = await _repository.getUsageAnalyticsSnapshot(query: _usageAnalyticsQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshUsageAnalytics failed: $e');
    } finally {
      _isUsageAnalyticsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setStorageQuery(StorageQuery query) async {
    _storageQuery = query;
    notifyListeners();
    await refreshStorage();
  }

  Future<void> refreshStorage() async {
    if (_isStorageLoading) return;
    _isStorageLoading = true;
    notifyListeners();
    try {
      _storage = await _repository.getStorageSnapshot(query: _storageQuery);
    } catch (e) {
      debugPrint('AdminStore.refreshStorage failed: $e');
    } finally {
      _isStorageLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSupportQuery(String query) async {
    _supportSearch = query;
    notifyListeners();
    await refreshSupportQueue();
  }

  Future<void> setSupportFilters(SupportQueueFilters filters) async {
    _supportFilters = filters;
    notifyListeners();
    await refreshSupportQueue();
  }

  Future<void> refreshSupportQueue() async {
    try {
      _supportSessions = await _repository.listSupportSessions(query: SupportQueueQuery(search: _supportSearch, filters: _supportFilters), limit: 60);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminStore.refreshSupportQueue failed: $e');
    }
  }

  Future<SupportSessionDetail?> getSupportSessionDetail(String supportSessionId) async {
    try {
      final detail = await _repository.getSupportSessionDetail(supportSessionId: supportSessionId);

      final actorId = _currentAdmin?.id;
      if (actorId != null && actorId.isNotEmpty) {
        await _repository.createAuditLog(
          entry: AdminAuditLogCreate(
            adminUserId: actorId,
            targetUserId: detail.userId,
            actionType: 'support_session_opened',
            newValue: {'support_session_id': supportSessionId},
            result: 'success',
          ),
        );
      }

      return detail;
    } catch (e) {
      debugPrint('AdminStore.getSupportSessionDetail failed: $e');
      return null;
    }
  }

  Future<DiagnosticsReport?> runDiagnostics(String userId) async {
    try {
      return await _repository.runDiagnostics(userId: userId);
    } catch (e) {
      debugPrint('AdminStore.runDiagnostics failed: $e');
      return null;
    }
  }

  Future<void> performSupportAction(SupportActionRequest request) async {
    try {
      await _repository.performSupportAction(request: request);
      await refreshAuditLogs();
      await refreshSupportQueue();
    } catch (e) {
      debugPrint('AdminStore.performSupportAction failed: $e');
      rethrow;
    }
  }

  Future<void> refreshPlansOverview() async {
    try {
      _plansOverview = await _repository.listPlansOverview(limit: 50);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminStore.refreshPlansOverview failed: $e');
    }
  }

  Future<UserEntitlements?> getUserEntitlements(String userId) async {
    try {
      return await _repository.getUserEntitlements(userId: userId);
    } catch (e) {
      debugPrint('AdminStore.getUserEntitlements failed: $e');
      return null;
    }
  }

  Future<void> refreshFeatureFlags() async {
    try {
      _featureFlags = await _repository.listFeatureFlags(limit: 50);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminStore.refreshFeatureFlags failed: $e');
    }
  }

  Future<void> refreshLimitOverrides() async {
    try {
      _limitOverrides = await _repository.listLimitOverrides(limit: 100);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminStore.refreshLimitOverrides failed: $e');
    }
  }
}
