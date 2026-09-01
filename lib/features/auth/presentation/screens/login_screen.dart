import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/constants/app_branding.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/church_selection_gate.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../providers/auth_provider.dart';

/// Tela de Login
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSendingReset = false;

  /// Destino preservado no `?redirect=` (LINK-03 / D-04), já saneado por
  /// [safeRedirect]. `null` quando não há parâmetro ou quando ele foi
  /// descartado pelo saneamento.
  String? _redirectDestino;
  bool _redirectResolvido = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolvido uma única vez: `build` roda a cada rebuild e não pode ficar
    // repetindo o log de descarte.
    if (_redirectResolvido) return;
    _redirectResolvido = true;

    final raw = GoRouterState.of(context).uri.queryParameters['redirect'];
    if (raw == null || raw.isEmpty) return;

    final destino = safeRedirect(raw);
    if (destino == null) {
      // Destino inválido cai em `/home` EM SILÊNCIO — nenhuma mensagem nova
      // para o usuário. O caso normal deste fallback é link velho ou
      // truncado, não ataque; assustar quem só quer entrar não ajuda.
      AppErrorHandler.log(
        Exception('Parametro ?redirect= descartado pelo saneamento'),
        feature: 'auth.login',
        context: {'redirect_bruto': raw},
      );
      return;
    }
    setState(() => _redirectDestino = destino);
  }

  void _logLogin(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[Login] $message');
    if (error != null) debugPrint('[Login] error=$error');
    if (stackTrace != null) debugPrint('[Login] stackTrace=$stackTrace');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _logLogin('validation failed');
      return;
    }

    // Limpa qualquer SnackBar de uma tentativa anterior (ex: "credenciais
    // inválidas") antes de tentar de novo. Sem isso, se o usuário errar mais
    // de uma vez, o ScaffoldMessenger enfileira as mensagens e elas continuam
    // aparecendo uma a uma mesmo depois do login bem-sucedido e da navegação
    // para /home.
    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      _logLogin('attempt login email=${_emailController.text.trim()}');

      await authRepo.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        final route = await ChurchSelectionGate.resolveNextRoute(
          Supabase.instance.client,
        );

        // D-04: o destino do link sobrevive ao login e também ao desvio pelo
        // seletor de igreja — quem clicou num link de inscrição cai na
        // inscrição, não na home. Sem destino válido, o comportamento é
        // exatamente o de antes.
        final destino = _redirectDestino;
        var proximaRota = route;
        if (destino != null) {
          if (route == '/home') {
            proximaRota = destino;
          } else if (route == '/select-church') {
            proximaRota =
                '/select-church?redirect=${Uri.encodeComponent(destino)}';
          }
        }

        _logLogin('login success, redirect to $proximaRota');
        if (mounted) context.go(proximaRota);
      }
    } catch (e, stackTrace) {
      _logLogin(
        'login failed type=${e.runtimeType}',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        final authRepo = ref.read(authRepositoryProvider);
        var message = AppErrorHandler.userMessage(
          e,
          feature: 'auth.login',
        );

        String? altActionLabel;
        VoidCallback? altAction;

        if (authRepo.isInvalidCredentialsError(e)) {
          final email = _emailController.text.trim();
          final status = await authRepo.getSignupStatus(email: email);
          if (!mounted) return;

          if (status == 'pre_registered') {
            message =
                'Seu e-mail foi pré-cadastrado pela igreja. Clique em "Criar conta" para definir sua senha e concluir o acesso.';
            altActionLabel = 'Criar conta';
            final uriEmail = Uri.encodeComponent(email);
            altAction = () => context.push('/signup?email=$uriEmail');
          } else {
            altActionLabel = 'Redefinir senha';
            altAction = _isSendingReset ? null : _handlePasswordReset;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            action: altActionLabel != null && altAction != null
                ? SnackBarAction(label: altActionLabel, onPressed: altAction)
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_isSendingReset) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um e-mail válido para redefinir a senha.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviamos um link de redefinição para $email.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'auth.password_reset',
        fallbackMessage: 'Não foi possível enviar o link. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CommunityDesign.radius),
              boxShadow: [CommunityDesign.overlayBaseShadow()],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: const AppLogo(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título
                  Text(
                    AppBranding.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    AppBranding.organizationName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: CommunityDesign.metaStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppBranding.loginPrompt,
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),

                  // S3 (D-04): explica por que o usuário caiu no login vindo de
                  // um link. Renderizada SOMENTE com `?redirect=` válido — sem
                  // ele nada é renderizado, nenhum espaço reservado. O path de
                  // destino NÃO é exibido: é dado controlável por quem monta a
                  // URL, e exibi-lo daria um canal de texto renderizado na tela
                  // de login (T-02-11).
                  if (_redirectDestino != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Faça login para abrir o link que você recebeu.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Campo de Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'seu@email.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu email';
                      }
                      if (!value.contains('@')) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Senha
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading || _isSendingReset
                          ? null
                          : _handlePasswordReset,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0B5FA5),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: Text(
                        _isSendingReset ? 'Enviando...' : 'Esqueci minha senha',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botão de Login
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5FA5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Link para Cadastro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Não tem uma conta? ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0B5FA5),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Criar Conta'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
