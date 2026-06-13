import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  String? _error;

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
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await auth.signInWithPassword(email: _emailCtrl.text, password: _passwordCtrl.text);
    } catch (e) {
      debugPrint('LoginPage sign-in failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed. Check your credentials and admin allow-list.');
    }
  }

  Future<void> _requestPasswordReset(AdminAuthStore auth) async {
    setState(() => _error = null);

    final email = _emailCtrl.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _error = 'Enter your email first, then click “Forgot password”.');
      return;
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _error = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset email sent (if the account exists).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onInverseSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to send reset email. Please try again.');
    }
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
                            onPressed: auth.isSigningIn ? null : () => _requestPasswordReset(auth),
                            icon: Icon(Icons.lock_reset, color: cs.primary),
                            label: Text(
                              'Forgot password?',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
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
