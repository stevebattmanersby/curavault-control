import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _forgotMode = false;
  String? _error;
  String? _info;
  String? _devSupabaseError;
  String? _devRedirectTo;

  @override
  void initState() {
    super.initState();
    // If an invite/recovery link lands on /#/login (common with misconfigured
    // Supabase redirect URLs), forward to /set-password while preserving auth
    // params. Never display tokens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final base = Uri.base;
      final frag = base.fragment;
      if (frag.isEmpty) return;

      final hasAuthParams = frag.contains('access_token=') || frag.contains('code=') || frag.contains('type=invite') || frag.contains('type=recovery');
      if (!hasAuthParams) return;

      final qIndex = frag.indexOf('?');
      final query = (qIndex >= 0 && qIndex < frag.length - 1) ? frag.substring(qIndex + 1) : null;
      if (query == null || query.trim().isEmpty) return;

      context.go('${AppRoutes.setPassword}?$query');
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.contains('@') && s.contains('.') && s.length >= 6;
  }

  Future<void> _submit(AdminAuthStore auth) async {
    setState(() {
      _error = null;
      _info = null;
      _devSupabaseError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await auth.signInWithPassword(email: _emailCtrl.text, password: _passwordCtrl.text);

      // Post-login destination is handled by the router.
      if (mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      debugPrint('LoginPage sign-in failed: $e');
      if (!mounted) return;
      if (e is AdminAuthInvalidCredentialsException) {
        setState(() => _error = 'Invalid email or password.');
      } else if (e is AdminAuthNetworkException) {
        setState(() => _error = 'Network request to Supabase failed.');
      } else if (e is AdminAuthAllowListLookupException) {
        setState(() => _error = 'Authenticated, but failed to check admin allow-list.');
      } else if (e is AdminAccessDeniedException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('inactive')) {
          setState(() => _error = 'Admin user inactive.');
        } else if (msg.contains('allow-listed') || msg.contains('allow list') || msg.contains('allowlist')) {
          setState(() => _error = 'Authenticated but not allow-listed.');
        } else {
          setState(() => _error = e.message);
        }
      } else {
        // Avoid showing “Authentication failed” unless Supabase Auth itself failed.
        setState(() => _error = 'Authenticated, but an unexpected error occurred.');
      }
    }
  }

  Future<void> _requestPasswordReset(AdminAuthStore auth) async {
    final email = _emailCtrl.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }

    // DEV-ONLY: Show the exact redirectTo string that will be sent to Supabase.
    // Never display tokens/passwords.
    if (kDebugMode) {
      setState(() => _devRedirectTo = AdminAuthStore.passwordResetRedirectTo);
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // SECURITY: Always show a neutral message so we don't leak whether an email exists.
      // In development only, show the real error below the form.
      debugPrint('LoginPage resetPasswordForEmail failed: $e');
      if (kDebugMode) {
        setState(() => _devSupabaseError = e.toString());
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _error = null;
        _info = 'If this email has access, a reset link has been sent.';
      });
    }
  }

  void _enterForgotMode() {
    setState(() {
      _forgotMode = true;
      _error = null;
      _info = null;
      _devSupabaseError = null;
      _devRedirectTo = kDebugMode ? AdminAuthStore.passwordResetRedirectTo : null;
    });
  }

  void _exitForgotMode() {
    setState(() {
      _forgotMode = false;
      _error = null;
      _info = null;
      _devSupabaseError = null;
      _devRedirectTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AdminAuthStore>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                      child: Icon(Icons.shield_outlined, color: cs.onPrimary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CuraVault Control Site', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          Text('Secure admin access', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (auth.fatalConfigError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Text(
                      auth.fatalConfigError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) => _looksLikeEmail(v ?? '') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: AppSpacing.md),

                        if (!_forgotMode) ...[
                          TextFormField(
                            controller: _passwordCtrl,
                            autofillHints: const [AutofillHints.password],
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password'),
                            validator: (v) => (v ?? '').trim().length >= 8 ? null : 'Password must be at least 8 characters',
                            onFieldSubmitted: (_) => _submit(auth),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.error)),
                            ),
                          if (_info != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(_info!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: auth.isSigningIn ? null : () => _submit(auth),
                              icon: auth.isSigningIn
                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                                  : Icon(Icons.login, color: cs.onPrimary),
                              label: Text(
                                auth.isSigningIn ? 'Signing in…' : 'Sign in',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: auth.isSigningIn ? null : _enterForgotMode,
                              icon: Icon(Icons.lock_reset, color: cs.primary),
                              label: Text(
                                'Forgot password?',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: AppSpacing.sm),
                            DevLoginStagePanel(diagnostics: auth.loginDiagnostics),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                // Requirement: navigate to exactly /supabase-connectivity-test
                                onPressed: () => context.go(AppRoutes.supabaseConnectivityTest),
                                icon: Icon(Icons.wifi, color: cs.onSurfaceVariant),
                                label: Text(
                                  'Supabase connectivity test (dev)',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: AppSpacing.lg),
                          if (kDebugMode && _devRedirectTo != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEV: redirectTo sent to Supabase',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  SelectableText(
                                    _devRedirectTo!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          if (kDebugMode && _devRedirectTo != null) const SizedBox(height: AppSpacing.md),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.error)),
                            ),
                          if (_info != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                              child: Text(
                                _info!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimaryContainer, height: 1.35),
                              ),
                            ),
                          if (kDebugMode && _devSupabaseError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Text(
                                _devSupabaseError!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _requestPasswordReset(auth),
                              icon: Icon(Icons.send, color: cs.onPrimary),
                              label: Text(
                                'Send reset link',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: _exitForgotMode,
                            icon: Icon(Icons.arrow_back, color: cs.primary),
                            label: Text('Back to sign in', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
                          ),
                        ],
                        Text(
                          kIsWeb ? 'Tip: Use an approved admin account. Access is allow-listed in admin_users.' : 'Use an approved admin account.',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DEV-ONLY: Displays safe, non-secret login stage diagnostics to debug the
/// “signInWithPassword ok but login flow fails” scenario.
///
/// Never shows: password, access tokens, refresh tokens, API keys.
class DevLoginStagePanel extends StatelessWidget {
  final AdminLoginDiagnostics diagnostics;

  const DevLoginStagePanel({super.key, required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String line(String k, Object? v) => '$k: ${v ?? '—'}';

    final rows = <String>[
      'DEV: Login stages',
      line('signInWithPassword attempted', diagnostics.signInAttempted ? 'yes' : 'no'),
      line('signInWithPassword succeeded', diagnostics.signInSucceeded ? 'yes' : 'no'),
      line('auth.uid()', diagnostics.authUid),
      line('auth.email', diagnostics.authEmail),
      line('admin_users lookup attempted', diagnostics.adminUsersLookupAttempted ? 'yes' : 'no'),
      line('admin_users row found', diagnostics.adminUsersRowFound ? 'yes' : 'no'),
      line('admin_users.admin_user_id', diagnostics.adminUsersAdminUserId),
      line('admin_users.email', diagnostics.adminUsersEmail),
      line('role', diagnostics.role),
      line('is_active', diagnostics.isActive),
      line('route target after login', diagnostics.routeTargetAfterLogin),
      '—',
      line('login audit attempted', diagnostics.loginAuditAttempted ? 'yes' : 'no'),
      line('login audit succeeded', diagnostics.loginAuditSucceeded ? 'yes' : 'no'),
      line('audit table', diagnostics.loginAuditTable),
      line('attempted action_type', diagnostics.loginAuditActionType),
      line('auth.uid present', diagnostics.loginAuditAuthUidPresent),
      line('admin role present', diagnostics.loginAuditRolePresent),
      line('audit exception type', diagnostics.loginAuditExceptionType),
      line('audit exception message', diagnostics.loginAuditExceptionMessage),
      line('exception type', diagnostics.exceptionType),
      line('exception message', diagnostics.exceptionMessage),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rows.first, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            rows.skip(1).join('\n'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface, height: 1.35),
          ),
        ],
      ),
    );
  }
}
