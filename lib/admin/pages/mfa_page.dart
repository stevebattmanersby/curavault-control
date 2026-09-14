import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class MfaPage extends StatefulWidget {
  const MfaPage({super.key});

  @override
  State<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends State<MfaPage> {
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment(AdminAuthStore auth) async {
    setState(() => _error = null);
    try {
      await auth.startTotpEnrollment();
    } catch (_) {
      if (mounted) {
        setState(() => _error = auth.mfaError ?? 'Could not start MFA.');
      }
    }
  }

  Future<void> _verify(AdminAuthStore auth) async {
    setState(() => _error = null);
    try {
      await auth.verifyTotpCode(code: _codeCtrl.text);
      if (mounted && auth.isAuthorized) {
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = auth.mfaError ?? 'Invalid MFA code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AdminAuthStore>();
    final enrollment = auth.mfaEnrollment;
    final hasVerifiedTotp = auth.verifiedTotpFactors.isNotEmpty;
    final isEnrollment = !hasVerifiedTotp;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
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
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(Icons.phonelink_lock_outlined,
                          color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEnrollment
                                ? 'Set up authenticator app'
                                : 'Enter authenticator code',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Control Site access requires verified MFA.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null || auth.mfaError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      _error ?? auth.mfaError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onErrorContainer,
                            height: 1.35,
                          ),
                    ),
                  ),
                if (isEnrollment && enrollment == null) ...[
                  Text(
                    'Use an authenticator app to add a TOTP factor to this admin account.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          auth.isMfaBusy ? null : () => _startEnrollment(auth),
                      icon: auth.isMfaBusy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Icon(Icons.qr_code_2, color: cs.onPrimary),
                      label: Text(
                        auth.isMfaBusy ? 'Starting...' : 'Start setup',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                ] else ...[
                  if (enrollment != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Image.network(
                          enrollment.qrCode,
                          width: 180,
                          height: 180,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.qr_code_2,
                            size: 120,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Manual setup key',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(
                      enrollment.secret,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: '6-digit code',
                      counterText: '',
                    ),
                    onSubmitted: (_) => auth.isMfaBusy ? null : _verify(auth),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: auth.isMfaBusy ? null : () => _verify(auth),
                      icon: auth.isMfaBusy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Icon(Icons.verified_user_outlined,
                              color: cs.onPrimary),
                      label: Text(
                        auth.isMfaBusy ? 'Verifying...' : 'Verify and continue',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: auth.isMfaBusy ? null : auth.signOut,
                    icon: Icon(Icons.logout, color: cs.primary),
                    label: Text(
                      'Sign out',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: cs.primary),
                    ),
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
