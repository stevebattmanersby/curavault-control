import 'dart:async';

import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles both admin invites and password recovery links.
///
/// This page:
/// - extracts a Supabase session from the URL (query or fragment)
/// - lets the user set a password via `updateUser`
/// - checks the admin allow-list (admin_users.admin_user_id == auth.uid() AND is_active=true)
/// - routes to /admin-test if allow-listed, else /unauthorized
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isRecovering = true;
  bool _isSaving = false;
  String? _error;
  String? _info;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenForInviteOrRecoveryEvents();
    _recoverFromUrl();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _listenForInviteOrRecoveryEvents() {
    // Invite/recovery links can arrive with tokens in the URL fragment.
    // Supabase may emit an auth state change once it parses them.
    try {
      _authSub?.cancel();
      _authSub = SupabaseConfig.auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        // For invite links, Supabase typically emits `signedIn` after parsing the URL.
        if (event.session != null && (event.event == AuthChangeEvent.passwordRecovery || event.event == AuthChangeEvent.signedIn)) {
          setState(() {
            _isRecovering = false;
            _error = null;
            _info = 'Session detected. Please set a password to continue.';
          });
        }
      });
    } catch (e) {
      debugPrint('[SetPasswordPage] Failed to listen for auth events: $e');
    }
  }

  Uri _sessionUriFromBase(Uri base) {
    if (base.queryParameters.isNotEmpty) return base;

    final frag = base.fragment;
    if (frag.isEmpty) return base;

    String? query;
    final qIndex = frag.indexOf('?');
    if (qIndex >= 0 && qIndex < frag.length - 1) {
      query = frag.substring(qIndex + 1);
    } else if (frag.contains('access_token=') || frag.contains('code=')) {
      query = frag;
    }

    if (query == null || query.trim().isEmpty) return base;

    final origin = '${base.scheme}://${base.authority}';
    return Uri.parse('$origin${base.path}?$query');
  }

  Future<void> _recoverFromUrl() async {
    setState(() {
      _isRecovering = true;
      _error = null;
      _info = null;
    });

    try {
      final base = Uri.base;
      final uri = _sessionUriFromBase(base);

      if (kDebugMode) {
        final hasQuery = uri.queryParameters.isNotEmpty;
        final hasFragment = base.fragment.isNotEmpty;
        debugPrint('[SetPasswordPage] linkDetected hasQuery=$hasQuery hasFragment=$hasFragment');
      }

      await SupabaseConfig.auth.getSessionFromUrl(uri);

      final hasSession = SupabaseConfig.auth.currentSession != null;
      if (!hasSession) {
        setState(() {
          _error =
              'No invite/recovery session found in this URL.\n\n'
              'Please open the link from your email again, or request a new password reset.';
        });
      } else {
        setState(() {
          _info = 'Session detected. Please set a password to continue.';
        });
      }
    } catch (e) {
      debugPrint('[SetPasswordPage] getSessionFromUrl failed: $e');
      setState(() {
        _error =
            'Unable to read the session from this link.\n\n'
            'Try requesting a new invite or password reset email.';
      });
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 12) return 'Use at least 12 characters';
    return null;
  }

  Future<bool> _isAllowListedAdmin() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return false;

      final row = await SupabaseConfig.client
          .from('admin_users')
          .select('admin_user_id')
          .eq('admin_user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('[SetPasswordPage] allow-list check failed: $e');
      return false;
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordCtrl.text.trim() != _confirmCtrl.text.trim()) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (SupabaseConfig.auth.currentSession == null) {
      setState(() => _error = 'Session expired. Please use the link from your email again.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseConfig.auth.updateUser(UserAttributes(password: _passwordCtrl.text.trim()));

      if (!mounted) return;
      final allowListed = await _isAllowListedAdmin();
      if (!mounted) return;

      if (allowListed) {
        context.go(AppRoutes.dashboard);
      } else {
        context.go(AppRoutes.unauthorized);
      }
    } catch (e) {
      debugPrint('[SetPasswordPage] updateUser failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to set password. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                      ),
                      child: Icon(Icons.key, color: cs.onPrimary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set password', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          Text(
                            'Finish setup for your admin account',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_isRecovering)
                  Row(
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                      const SizedBox(width: AppSpacing.md),
                      Text('Verifying link…', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  )
                else ...[
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer, height: 1.35),
                      ),
                    ),
                  if (_info != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Text(
                        _info!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimaryContainer, height: 1.35),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New password'),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirm password'),
                          validator: _validatePassword,
                          onFieldSubmitted: (_) => _isSaving ? null : _save(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                                : Icon(Icons.check_circle, color: cs.onPrimary),
                            label: Text(
                              _isSaving ? 'Saving…' : 'Set password',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                            ),
                            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton.icon(
                          onPressed: () => context.go(AppRoutes.login),
                          icon: Icon(Icons.arrow_back, color: cs.primary),
                          label: Text('Back to sign in', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
