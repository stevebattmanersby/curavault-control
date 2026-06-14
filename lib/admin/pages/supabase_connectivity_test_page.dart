import 'package:curavault_admin/admin/utils/http_probe.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectivityTestPage extends StatefulWidget {
  const SupabaseConnectivityTestPage({super.key});

  @override
  State<SupabaseConnectivityTestPage> createState() => _SupabaseConnectivityTestPageState();
}

class _SupabaseConnectivityTestPageState extends State<SupabaseConnectivityTestPage> {
  bool? _supabaseInitialized;
  String? _supabaseInitDetail;

  bool? _urlSanityOk;
  String? _urlSanityDetail;

  bool? _baseUrlProbeOk;
  int? _baseUrlStatus;
  String? _baseUrlExType;
  String? _baseUrlExMsg;

  bool? _browserFetchGetHealthOk;
  int? _browserFetchGetHealthStatus;
  String? _browserFetchGetHealthExType;
  String? _browserFetchGetHealthExMsg;

  bool? _browserFetchOptionsTokenOk;
  int? _browserFetchOptionsTokenStatus;
  String? _browserFetchOptionsTokenExType;
  String? _browserFetchOptionsTokenExMsg;

  bool? _authSessionOk;
  String? _authSessionExType;
  String? _authSessionExMsg;
  int? _authHealthStatus;

  bool? _restQueryOk;
  String? _restQueryExType;
  String? _restQueryExMsg;

  bool? _sdkSignInOk;
  bool? _sdkSignInReceivedHttpStatus;
  int? _sdkSignInStatus;
  String? _sdkSignInExType;
  String? _sdkSignInExMsg;

  bool? _postgrestApikeyExpected;
  bool? _postgrestAuthHeaderExpected;
  String? _keyKind;
  String? _keyFormatDetail;

  String? _supabaseFlutterConstraint;
  String? _initializeParamUsed;

  bool _isRunning = false;

  int _runClickCount = 0;
  DateTime? _runStartedAt;
  String? _fatalErrorType;
  String? _fatalErrorMessage;
  String? _fatalErrorStack;

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    super.dispose();
  }

  SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _describeKeyKind(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return 'empty';
    if (trimmed.startsWith('sb_publishable_')) return 'sb_publishable_*';
    if (trimmed.startsWith('sb_')) return 'sb_*';
    if (trimmed.startsWith('eyJ')) return 'jwt (eyJ*)';
    return 'unknown';
  }

  bool _looksLikeJwt(String key) {
    final trimmed = key.trim();
    if (!trimmed.startsWith('eyJ')) return false;
    return trimmed.split('.').length >= 3;
  }

  int? _extractStatusCodeFromException(Object e) {
    final s = e.toString();
    final m = RegExp(r'statusCode\s*[:=]\s*(\d{3})').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  Future<void> _runConnectivityTests() async {
    if (_isRunning) return;

    debugPrint('[SupabaseConnectivityTest] run button clicked');
    setState(() {
      _runClickCount += 1;
      _runStartedAt = DateTime.now();
      _isRunning = true;

      _fatalErrorType = null;
      _fatalErrorMessage = null;
      _fatalErrorStack = null;

      // Reset results so the UI immediately reflects “running”.
      _supabaseInitialized = null;
      _supabaseInitDetail = null;
      _urlSanityOk = null;
      _urlSanityDetail = null;
      _baseUrlProbeOk = null;
      _baseUrlStatus = null;
      _baseUrlExType = null;
      _baseUrlExMsg = null;
      _authSessionOk = null;
      _authSessionExType = null;
      _authSessionExMsg = null;
      _authHealthStatus = null;
      _restQueryOk = null;
      _restQueryExType = null;
      _restQueryExMsg = null;

      _browserFetchGetHealthOk = null;
      _browserFetchGetHealthStatus = null;
      _browserFetchGetHealthExType = null;
      _browserFetchGetHealthExMsg = null;

      _browserFetchOptionsTokenOk = null;
      _browserFetchOptionsTokenStatus = null;
      _browserFetchOptionsTokenExType = null;
      _browserFetchOptionsTokenExMsg = null;

      _sdkSignInOk = null;
      _sdkSignInReceivedHttpStatus = null;
      _sdkSignInStatus = null;
      _sdkSignInExType = null;
      _sdkSignInExMsg = null;

      _postgrestApikeyExpected = null;
      _postgrestAuthHeaderExpected = null;
      _keyKind = null;
      _keyFormatDetail = null;

      _supabaseFlutterConstraint = null;
      _initializeParamUsed = null;
    });

    debugPrint('[SupabaseConnectivityTest] test run starts');

    try {
      // Test 1) Supabase initialized
      debugPrint('[SupabaseConnectivityTest] starting: supabase initialized');
      final client = _tryClient();
      final initOk = client != null && SupabaseConfig.isInitialized;
      setState(() {
        _supabaseInitialized = initOk;
        _supabaseInitDetail = initOk
            ? 'Client available'
            : (client == null ? 'Supabase.instance.client threw / unavailable' : 'SupabaseConfig.isInitialized=false');
      });
      debugPrint('[SupabaseConnectivityTest] ${initOk ? 'success' : 'fail'}: supabase initialized');

      // Test 2) URL sanity check
      debugPrint('[SupabaseConnectivityTest] starting: URL sanity check');
      try {
        final raw = SupabaseConfig.supabaseUrl;
        final parsed = Uri.parse(raw);
        final ok = parsed.hasScheme && parsed.host.isNotEmpty && !raw.endsWith('/rest/v1') && !raw.contains(' ');
        setState(() {
          _urlSanityOk = ok;
          _urlSanityDetail = ok ? 'OK (${parsed.scheme}://${parsed.host})' : 'Check URL format (must be project root, not /rest/v1)';
        });
        debugPrint('[SupabaseConnectivityTest] ${ok ? 'success' : 'fail'}: URL sanity check');
      } catch (e, st) {
        setState(() {
          _urlSanityOk = false;
          _urlSanityDetail = 'type=${e.runtimeType} msg=${e.toString()}';
        });
        debugPrint('[SupabaseConnectivityTest] fail: URL sanity check: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // Test 3) Raw HTTP probe to the project root.
      debugPrint('[SupabaseConnectivityTest] starting: GET project URL');
      try {
        final url = Uri.parse(SupabaseConfig.supabaseUrl);
        // Use GET instead of HEAD because some environments block HEAD or omit CORS headers.
        final probe = await httpProbe(url, method: 'GET');
        setState(() {
          _baseUrlProbeOk = probe.ok;
          _baseUrlStatus = probe.statusCode;
          _baseUrlExType = probe.exceptionType;
          _baseUrlExMsg = probe.message;
        });
        debugPrint('[SupabaseConnectivityTest] ${probe.ok ? 'success' : 'fail'}: GET project URL status=${probe.statusCode} type=${probe.exceptionType}');
      } catch (e, st) {
        setState(() {
          _baseUrlProbeOk = false;
          _baseUrlStatus = null;
          _baseUrlExType = e.runtimeType.toString();
          _baseUrlExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: GET project URL: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // If we don't even have a client, remaining tests cannot run.
      if (client == null) {
        debugPrint('[SupabaseConnectivityTest] aborting remaining tests: no Supabase client');
        return;
      }

      // Test 4) Auth reachability check.
      debugPrint('[SupabaseConnectivityTest] starting: Auth health endpoint');
      try {
        final authHealthUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/health');
        final authProbe = await httpProbe(authHealthUrl, method: 'GET');
        setState(() {
          _authSessionOk = authProbe.ok;
          _authHealthStatus = authProbe.statusCode;
          _authSessionExType = authProbe.exceptionType;
          _authSessionExMsg = authProbe.message;
        });
        debugPrint('[SupabaseConnectivityTest] ${authProbe.ok ? 'success' : 'fail'}: Auth health status=${authProbe.statusCode} type=${authProbe.exceptionType}');
      } catch (e, st) {
        setState(() {
          _authSessionOk = false;
          _authHealthStatus = null;
          _authSessionExType = e.runtimeType.toString();
          _authSessionExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: Auth health endpoint: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // Test 4b) Browser fetch GET (explicit).
      debugPrint('[SupabaseConnectivityTest] starting: Browser fetch GET /auth/v1/health');
      try {
        final healthUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/health');
        final probe = await httpProbe(healthUrl, method: 'GET', headers: const {'accept': 'application/json'});
        setState(() {
          _browserFetchGetHealthOk = probe.ok;
          _browserFetchGetHealthStatus = probe.statusCode;
          _browserFetchGetHealthExType = probe.exceptionType;
          _browserFetchGetHealthExMsg = probe.message;
        });
        debugPrint(
          '[SupabaseConnectivityTest] ${probe.ok ? 'success' : 'fail'}: Browser fetch GET /auth/v1/health status=${probe.statusCode} type=${probe.exceptionType}',
        );
      } catch (e, st) {
        setState(() {
          _browserFetchGetHealthOk = false;
          _browserFetchGetHealthStatus = null;
          _browserFetchGetHealthExType = e.runtimeType.toString();
          _browserFetchGetHealthExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: Browser fetch GET /auth/v1/health: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // Test 4c) OPTIONS preflight-style check for token endpoint.
      debugPrint('[SupabaseConnectivityTest] starting: Browser fetch OPTIONS /auth/v1/token (preflight)');
      try {
        final tokenUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/token');
        final probe = await httpProbe(
          tokenUrl,
          method: 'OPTIONS',
          headers: const {
            'access-control-request-method': 'POST',
            'access-control-request-headers': 'apikey, authorization, content-type',
          },
        );
        setState(() {
          _browserFetchOptionsTokenOk = probe.ok;
          _browserFetchOptionsTokenStatus = probe.statusCode;
          _browserFetchOptionsTokenExType = probe.exceptionType;
          _browserFetchOptionsTokenExMsg = probe.message;
        });
        debugPrint(
          '[SupabaseConnectivityTest] ${probe.ok ? 'success' : 'fail'}: Browser fetch OPTIONS /auth/v1/token status=${probe.statusCode} type=${probe.exceptionType}',
        );
      } catch (e, st) {
        setState(() {
          _browserFetchOptionsTokenOk = false;
          _browserFetchOptionsTokenStatus = null;
          _browserFetchOptionsTokenExType = e.runtimeType.toString();
          _browserFetchOptionsTokenExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: Browser fetch OPTIONS /auth/v1/token: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // Test 4d) Package/key compatibility check (safe).
      debugPrint('[SupabaseConnectivityTest] starting: package/key compatibility check');
      try {
        final key = SupabaseConfig.anonKey;
        final kind = _describeKeyKind(key);
        final jwt = _looksLikeJwt(key);
        setState(() {
          _supabaseFlutterConstraint = '>=1.10.0 (pubspec constraint)';
          _initializeParamUsed = 'anonKey';
          _keyKind = kind;
          _keyFormatDetail = jwt
              ? 'Looks like JWT (3-part, eyJ…)'
              : (kind.startsWith('sb_') ? 'Looks like sb_* publishable key' : 'Unrecognized key prefix');
        });
        debugPrint('[SupabaseConnectivityTest] package/key check: kind=$kind jwt=$jwt');
      } catch (e) {
        setState(() {
          _keyKind = 'error';
          _keyFormatDetail = 'type=${e.runtimeType} msg=${e.toString()}';
        });
      }

      // Test 5) REST query check (PostgREST).
      debugPrint('[SupabaseConnectivityTest] starting: PostgREST admin_users query');
      try {
        await client.from('admin_users').select('admin_user_id').limit(1);
        setState(() {
          _restQueryOk = true;
          _restQueryExType = null;
          _restQueryExMsg = null;
        });
        debugPrint('[SupabaseConnectivityTest] success: PostgREST admin_users query');
      } catch (e, st) {
        setState(() {
          _restQueryOk = false;
          _restQueryExType = e.runtimeType.toString();
          _restQueryExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: PostgREST admin_users query: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }

      // Test 5b) PostgREST “headers check” (safe inference).
      debugPrint('[SupabaseConnectivityTest] starting: PostgREST headers check (expected)');
      try {
        final hasKey = SupabaseConfig.anonKey.trim().isNotEmpty;
        final hasSession = client.auth.currentSession?.accessToken.isNotEmpty ?? false;
        setState(() {
          _postgrestApikeyExpected = hasKey;
          _postgrestAuthHeaderExpected = hasSession;
        });
        debugPrint('[SupabaseConnectivityTest] expected headers: apikey=$hasKey auth=$hasSession');
      } catch (e) {
        setState(() {
          _postgrestApikeyExpected = false;
          _postgrestAuthHeaderExpected = false;
        });
        debugPrint('[SupabaseConnectivityTest] headers check failed: ${e.runtimeType}: $e');
      }

      // Test 6) SDK sign-in test (uses user input; never logs credentials).
      debugPrint('[SupabaseConnectivityTest] starting: Supabase SDK signInWithPassword');
      try {
        final email = _signInEmailController.text.trim();
        final password = _signInPasswordController.text;

        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _sdkSignInOk = false;
            _sdkSignInReceivedHttpStatus = false;
            _sdkSignInStatus = null;
            _sdkSignInExType = 'InputValidation';
            _sdkSignInExMsg = 'Enter an email + password to run this test. (Not stored or logged)';
          });
        } else {
          await client.auth.signInWithPassword(email: email, password: password);
          await client.auth.signOut();
          setState(() {
            _sdkSignInOk = true;
            _sdkSignInReceivedHttpStatus = true;
            _sdkSignInStatus = 200;
            _sdkSignInExType = null;
            _sdkSignInExMsg = null;
          });
        }
        debugPrint('[SupabaseConnectivityTest] ${_sdkSignInOk == true ? 'success' : 'fail'}: SDK signInWithPassword');
      } catch (e, st) {
        final status = _extractStatusCodeFromException(e);
        setState(() {
          _sdkSignInOk = false;
          _sdkSignInReceivedHttpStatus = status != null;
          _sdkSignInStatus = status;
          _sdkSignInExType = e.runtimeType.toString();
          _sdkSignInExMsg = e.toString();
        });
        debugPrint('[SupabaseConnectivityTest] fail: SDK signInWithPassword: ${e.runtimeType}: $e');
        if (kDebugMode) debugPrint(st.toString());
      }
    } catch (e, st) {
      // Catch anything unexpected that occurs before/around individual tests.
      debugPrint('[SupabaseConnectivityTest] FATAL: ${e.runtimeType}: $e');
      if (kDebugMode) debugPrint(st.toString());
      setState(() {
        _fatalErrorType = e.runtimeType.toString();
        _fatalErrorMessage = e.toString();
        _fatalErrorStack = kDebugMode ? st.toString() : null;
      });
    } finally {
      debugPrint('[SupabaseConnectivityTest] test run completes');
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final safeProjectOrigin = () {
      try {
        final parsed = Uri.parse(SupabaseConfig.supabaseUrl);
        if (!parsed.hasScheme || parsed.host.isEmpty) return 'Invalid URL';
        return '${parsed.scheme}://${parsed.host}';
      } catch (_) {
        return 'Invalid URL';
      }
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Connectivity Test Page v2'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                kReleaseMode ? 'RELEASE' : 'DEBUG',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _BannerCard(
            text: 'Temporary diagnostics page — remove before production.',
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoCard(
            title: 'Config sanity',
            rows: [
              _KV('Project origin', safeProjectOrigin),
              _KV('URL has unexpected /rest/v1 suffix', SupabaseConfig.supabaseUrl.endsWith('/rest/v1') ? 'yes (misconfigured)' : 'no'),
              _KV('SupabaseConfig.isInitialized', SupabaseConfig.isInitialized.toString()),
              _KV('Supabase key kind (safe)', _keyKind ?? '—'),
              _KV('Key format detail (safe)', _keyFormatDetail ?? '—'),
              _KV('supabase_flutter (constraint)', _supabaseFlutterConstraint ?? '—'),
              _KV('Supabase.initialize param used', _initializeParamUsed ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoCard(
            title: 'SDK sign-in test (optional)',
            rows: [
              Text(
                'To isolate “Failed to fetch” vs invalid credentials, you can run a sign-in attempt. This page does not log or display what you type. Prefer a throwaway test user.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _signInEmailController,
                decoration: const InputDecoration(labelText: 'Email (test)'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _signInPasswordController,
                decoration: const InputDecoration(labelText: 'Password (test)'),
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isRunning ? null : _runConnectivityTests,
                  icon: _isRunning
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                      : Icon(Icons.wifi_tethering, color: cs.onPrimary),
                  label: Text(
                    _isRunning ? 'Running…' : 'Run connectivity tests',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoCard(
            title: 'Run status',
            rows: [
              _KV('Run button clicked', _runClickCount > 0 ? 'yes ($_runClickCount)' : 'no'),
              _KV('State', _isRunning ? 'Running tests…' : 'Idle'),
              _KV('Run started at', _runStartedAt == null ? '—' : _runStartedAt!.toIso8601String()),
            ],
          ),
          if (_fatalErrorType != null || _fatalErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _FatalErrorBox(type: _fatalErrorType, message: _fatalErrorMessage, stack: _fatalErrorStack),
          ],
          const SizedBox(height: AppSpacing.md),
          _ResultCard(
            title: 'Results',
            items: [
              _TestResultItem(
                label: 'Supabase initialized',
                ok: _supabaseInitialized,
                detail: _supabaseInitialized == null ? null : _supabaseInitDetail,
              ),
              _TestResultItem(
                label: 'URL sanity check',
                ok: _urlSanityOk,
                detail: _urlSanityOk == null ? null : _urlSanityDetail,
              ),
              _TestResultItem(
                label: 'GET project URL',
                ok: _baseUrlProbeOk,
                detail: _baseUrlProbeOk == null ? null : (_baseUrlProbeOk! ? 'status=$_baseUrlStatus' : 'type=$_baseUrlExType msg=$_baseUrlExMsg'),
              ),
              _TestResultItem(
                label: 'Auth health endpoint (/auth/v1/health)',
                ok: _authSessionOk,
                detail: _authSessionOk == null ? null : (_authSessionOk! ? 'status=$_authHealthStatus' : 'type=$_authSessionExType msg=$_authSessionExMsg'),
              ),
              _TestResultItem(
                label: 'Browser fetch GET (/auth/v1/health)',
                ok: _browserFetchGetHealthOk,
                detail: _browserFetchGetHealthOk == null
                    ? null
                    : (_browserFetchGetHealthOk!
                        ? 'status=$_browserFetchGetHealthStatus'
                        : 'type=$_browserFetchGetHealthExType msg=$_browserFetchGetHealthExMsg'),
              ),
              _TestResultItem(
                label: 'Browser fetch OPTIONS (/auth/v1/token) preflight',
                ok: _browserFetchOptionsTokenOk,
                detail: _browserFetchOptionsTokenOk == null
                    ? null
                    : (_browserFetchOptionsTokenOk!
                        ? 'status=$_browserFetchOptionsTokenStatus'
                        : 'type=$_browserFetchOptionsTokenExType msg=$_browserFetchOptionsTokenExMsg'),
              ),
              _TestResultItem(
                label: "PostgREST admin_users query",
                ok: _restQueryOk,
                detail: _restQueryOk == null ? null : (_restQueryOk! ? 'ok' : 'type=$_restQueryExType msg=$_restQueryExMsg'),
              ),
              _TestResultItem(
                label: 'PostgREST headers check (expected)',
                ok: (_postgrestApikeyExpected == null || _postgrestAuthHeaderExpected == null) ? null : true,
                detail: (_postgrestApikeyExpected == null || _postgrestAuthHeaderExpected == null)
                    ? null
                    : 'apikey header expected=${_postgrestApikeyExpected == true ? 'yes' : 'no'}; Authorization header expected=${_postgrestAuthHeaderExpected == true ? 'yes' : 'no'}',
              ),
              _TestResultItem(
                label: 'SDK signInWithPassword',
                ok: _sdkSignInOk,
                detail: _sdkSignInOk == null
                    ? null
                    : (_sdkSignInOk!
                        ? 'ok (signed out immediately after)'
                        : 'receivedHttpStatus=${_sdkSignInReceivedHttpStatus == true ? 'yes' : 'no'}'
                            '${_sdkSignInStatus == null ? '' : ' status=$_sdkSignInStatus'}'
                            ' type=$_sdkSignInExType msg=$_sdkSignInExMsg'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String text;

  const _BannerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          ...rows,
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final List<_TestResultItem> items;

  const _ResultCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: e)),
        ],
      ),
    );
  }
}

class _TestResultItem extends StatelessWidget {
  final String label;
  final bool? ok;
  final String? detail;

  const _TestResultItem({required this.label, required this.ok, this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = ok == null
        ? Icons.hourglass_top
        : ok == true
            ? Icons.check_circle
            : Icons.cancel;
    final iconColor = ok == null
        ? cs.onSurfaceVariant
        : ok == true
            ? Colors.green
            : cs.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (detail != null) ...[
                  const SizedBox(height: 6),
                  Text(detail!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;

  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 210, child: Text(k, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _FatalErrorBox extends StatelessWidget {
  final String? type;
  final String? message;
  final String? stack;

  const _FatalErrorBox({this.type, this.message, this.stack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: cs.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Unexpected error', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onErrorContainer))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (type != null) Text('Type: $type', style: t.bodyMedium?.copyWith(color: cs.onErrorContainer, height: 1.35)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text('Message: $message', style: t.bodyMedium?.copyWith(color: cs.onErrorContainer, height: 1.35)),
          ],
          if (stack != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Stack (dev only):', style: t.bodySmall?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Text(stack!, style: t.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.25, color: cs.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }
}
