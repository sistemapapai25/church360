import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_branding.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

enum _RecoveryStatus { validating, ready, invalid, saving, saved }

/// A senha só pode ser alterada após o callback `passwordRecovery` do Auth.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;

  _RecoveryStatus _status = _RecoveryStatus.validating;
  String? _recoveryUserId;
  String? _error;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthState,
      onError: (_, __) => _invalidate(),
    );
    // O stream do SDK reapresenta o callback recente. Sem o callback, uma
    // sessão comum nunca pode autorizar a redefinição nesta rota.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _status == _RecoveryStatus.validating) _invalidate();
      }),
    );
  }

  void _onAuthState(AuthState state) {
    if (!mounted) return;
    if (state.event == AuthChangeEvent.passwordRecovery &&
        state.session != null) {
      setState(() {
        _recoveryUserId = state.session!.user.id;
        _status = _RecoveryStatus.ready;
        _error = null;
      });
      return;
    }
    if (_recoveryUserId != null &&
        (state.event == AuthChangeEvent.signedOut ||
            state.session?.user.id != _recoveryUserId)) {
      _invalidate();
    }
  }

  void _invalidate() {
    if (!mounted || _status == _RecoveryStatus.saved) return;
    setState(() {
      _status = _RecoveryStatus.invalid;
      _recoveryUserId = null;
      _error =
          'Não foi possível validar este link. Ele pode ter expirado, já ter sido usado ou ter sido aberto em outro dispositivo.';
    });
  }

  Future<void> _save() async {
    if (_status != _RecoveryStatus.ready ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (Supabase.instance.client.auth.currentUser?.id != _recoveryUserId) {
      _invalidate();
      return;
    }

    setState(() => _status = _RecoveryStatus.saving);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePasswordFromRecovery(password: _passwordController.text);
      _passwordController.clear();
      _confirmationController.clear();
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {
        // A senha já foi persistida; não transformar esse resultado em erro.
      }
      if (mounted) setState(() => _status = _RecoveryStatus.saved);
    } on AuthSessionMissingException {
      _invalidate();
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _RecoveryStatus.ready;
          _error = 'Não foi possível salvar a nova senha. Tente novamente.';
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: SizedBox(width: 82, height: 82, child: AppLogo()),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppBranding.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_status == _RecoveryStatus.validating)
                    const _Message(
                      icon: Icons.lock_clock_outlined,
                      title: 'Validando link',
                      message: 'Aguarde enquanto confirmamos sua recuperação.',
                      loading: true,
                    )
                  else if (_status == _RecoveryStatus.invalid)
                    _Message(
                      icon: Icons.link_off_outlined,
                      title: 'Link indisponível',
                      message: _error!,
                      action: 'Voltar para o login',
                      onAction: () => context.go('/login'),
                    )
                  else if (_status == _RecoveryStatus.saved)
                    _Message(
                      icon: Icons.check_circle_outline,
                      title: 'Senha alterada',
                      message:
                          'Sua nova senha foi salva. Entre novamente para continuar.',
                      action: 'Ir para o login',
                      onAction: () => context.go('/login'),
                    )
                  else
                    _form(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final saving = _status == _RecoveryStatus.saving;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Definir nova senha',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma senha nova para acessar sua conta.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _passwordField(
            controller: _passwordController,
            label: 'Nova senha',
            hidden: _hidePassword,
            onToggle: () => setState(() => _hidePassword = !_hidePassword),
            validator: (value) => value == null || value.length < 6
                ? 'Use pelo menos 6 caracteres.'
                : null,
          ),
          const SizedBox(height: 16),
          _passwordField(
            controller: _confirmationController,
            label: 'Confirmar nova senha',
            hidden: _hideConfirmation,
            onToggle: () =>
                setState(() => _hideConfirmation = !_hideConfirmation),
            validator: (value) => value != _passwordController.text
                ? 'As senhas não coincidem.'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar nova senha'),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) => TextFormField(
    controller: controller,
    enabled: _status != _RecoveryStatus.saving,
    obscureText: hidden,
    autofillHints: const [AutofillHints.newPassword],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: onToggle,
      ),
    ),
    validator: validator,
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      loading
          ? const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(),
            )
          : Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 20),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center),
      if (action != null) ...[
        const SizedBox(height: 24),
        FilledButton(onPressed: onAction, child: Text(action!)),
      ],
    ],
  );
}
