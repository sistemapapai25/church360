import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _saving = false;
  bool _sendingLink = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirmation = true;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePasswordWithCurrentPassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmationController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível confirmar a senha atual ou salvar a nova senha.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendResetLink() async {
    if (_sendingLink) return;
    final email = ref.read(authRepositoryProvider).currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar o e-mail desta conta.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _sendingLink = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se houver uma conta para este e-mail, você receberá as instruções de recuperação.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar o link. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingLink = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alterar senha')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Proteja sua conta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Informe sua senha atual para definir uma nova.'),
                  const SizedBox(height: 24),
                  _passwordField(
                    controller: _currentPasswordController,
                    label: 'Senha atual',
                    hidden: _hideCurrent,
                    hints: const [AutofillHints.password],
                    onToggle: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe sua senha atual.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _passwordField(
                    controller: _newPasswordController,
                    label: 'Nova senha',
                    hidden: _hideNew,
                    hints: const [AutofillHints.newPassword],
                    onToggle: () => setState(() => _hideNew = !_hideNew),
                    validator: (value) => value == null || value.length < 6
                        ? 'Use pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _passwordField(
                    controller: _confirmationController,
                    label: 'Confirmar nova senha',
                    hidden: _hideConfirmation,
                    hints: const [AutofillHints.newPassword],
                    onToggle: () =>
                        setState(() => _hideConfirmation = !_hideConfirmation),
                    validator: (value) => value != _newPasswordController.text
                        ? 'As senhas não coincidem.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Alterar senha'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _sendingLink ? null : _sendResetLink,
                    child: Text(
                      _sendingLink ? 'Enviando link...' : 'Esqueci minha senha',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required Iterable<String> hints,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    obscureText: hidden,
    autofillHints: hints,
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
