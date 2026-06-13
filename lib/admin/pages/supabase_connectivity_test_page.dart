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

  bool? _baseUrlProbeOk;
  int? _baseUrlStatus;
  String? _baseUrlExType;
  String? _baseUrlExMsg;

  bool? _authSessionOk;
  String? _authSessionExType;
  String? _authSessionExMsg;
  int? _authHealthStatus;

  bool? _restQueryOk;
  String? _restQueryExType;
  String? _restQueryExMsg;

  bool _isRunning = false;

  // Optional sign-in test (never prints secrets).
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool? _signInOk;
  String? _signInPhase;
  String? _signInExType;
  String? _signInExMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _runConnectivityTests() async {
    if (!kDebugMode) return;
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _supabaseInitialized = null;
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
    });

    final client = _tryClient();
    setState(() => _supabaseInitialized = client != null && SupabaseConfig.isInitialized);

    // 1) Raw HTTP probe to the project root.
    final url = Uri.parse(SupabaseConfig.supabaseUrl);
    final probe = await httpProbe(url, method: 'HEAD');
    setState(() {
      _baseUrlProbeOk = probe.ok;
      _baseUrlStatus = probe.statusCode;
      _baseUrlExType = probe.exceptionType;
      _baseUrlExMsg = probe.message;
    });

    // If we don't even have a client, remaining tests cannot run.
    if (client == null) {
      setState(() => _isRunning = false);
      return;
    }

    // 2) Auth reachability check.
    // We avoid any token/session display and don't send credentials.
    final authHealthUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/health');
    final authProbe = await httpProbe(authHealthUrl, method: 'GET');
    setState(() {
      _authSessionOk = authProbe.ok;
      _authHealthStatus = authProbe.statusCode;
      _authSessionExType = authProbe.exceptionType;
      _authSessionExMsg = authProbe.message;
    });

    // 3) REST query check (PostgREST).
    try {
      await client.from('admin_users').select('admin_user_id').limit(1);
      setState(() => _restQueryOk = true);
    } catch (e) {
      setState(() {
        _restQueryOk = false;
        _restQueryExType = e.runtimeType.toString();
        _restQueryExMsg = e.toString();
      });
    }

    setState(() => _isRunning = false);
  }

  Future<void> _runOptionalSignInTest() async {
    if (!kDebugMode) return;
    if (_isRunning) return;
    final client = _tryClient();
    setState(() {
      _signInOk = null;
      _signInPhase = 'before_sign_in';
      _signInExType = null;
      _signInExMsg = null;
      _isRunning = true;
    });

    if (client == null) {
      setState(() {
        _signInOk = false;
        _signInExType = 'StateError';
        _signInExMsg = 'Supabase client not initialized.';
        _isRunning = false;
      });
      return;
    }

    try {
      setState(() => _signInPhase = 'during_sign_in');
      await client.auth.signInWithPassword(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      setState(() {
        _signInOk = true;
        _signInPhase = 'after_sign_in';
      });
      // Immediately sign out to avoid leaving a session behind during debugging.
      try {
        await client.auth.signOut();
      } catch (_) {}
    } catch (e) {
      setState(() {
        _signInOk = false;
        _signInPhase = 'during_sign_in';
        _signInExType = e.runtimeType.toString();
        _signInExMsg = e.toString();
      });
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supabase Connectivity Test')),
        body: const Center(child: Text('This page is available in debug builds only.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Connectivity Test'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                kDebugMode ? 'DEV' : 'PROD',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _InfoCard(
            title: 'Config sanity',
            rows: [
              _KV('Supabase.initialize URL', SupabaseConfig.supabaseUrl),
              _KV('Expected base URL (no /rest/v1)', SupabaseConfig.supabaseUrl.endsWith('/rest/v1') ? 'WRONG' : 'OK'),
              _KV('SupabaseConfig.isInitialized', SupabaseConfig.isInitialized.toString()),
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
          _ResultCard(
            title: 'Results',
            items: [
              _TestResultItem(
                label: 'Supabase initialized',
                ok: _supabaseInitialized,
                detail: _supabaseInitialized == null ? null : (_supabaseInitialized! ? 'Client available' : 'Client missing'),
              ),
              _TestResultItem(
                label: 'HEAD https://…supabase.co',
                ok: _baseUrlProbeOk,
                detail: _baseUrlProbeOk == null
                    ? null
                    : (_baseUrlProbeOk! ? 'status=$_baseUrlStatus' : 'type=$_baseUrlExType msg=$_baseUrlExMsg'),
              ),
              _TestResultItem(
                label: 'Auth reachability (/auth/v1/health)',
                ok: _authSessionOk,
                detail: _authSessionOk == null
                    ? null
                    : (_authSessionOk! ? 'status=$_authHealthStatus' : 'type=$_authSessionExType msg=$_authSessionExMsg'),
              ),
              _TestResultItem(
                label: "REST query admin_users.select('admin_user_id')",
                ok: _restQueryOk,
                detail: _restQueryOk == null
                    ? null
                    : (_restQueryOk! ? 'ok' : 'type=$_restQueryExType msg=$_restQueryExMsg'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoCard(
            title: 'Optional sign-in probe (does not show secrets)',
            rows: const [
              _KV('Phase flag', 'Shows whether failure is before/during/after sign-in'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password (optional)')),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : _runOptionalSignInTest,
                  icon: Icon(Icons.login, color: cs.primary),
                  label: Text('Run sign-in probe', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ResultCard(
            title: 'Sign-in probe result',
            items: [
              _TestResultItem(label: 'signInWithPassword result', ok: _signInOk, detail: _signInPhase == null ? null : 'phase=$_signInPhase'),
              _TestResultItem(
                label: 'Exception',
                ok: _signInOk == null ? null : _signInOk,
                detail: _signInOk == true ? null : 'type=$_signInExType msg=$_signInExMsg',
              ),
            ],
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
