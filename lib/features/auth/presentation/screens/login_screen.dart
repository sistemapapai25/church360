import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_branding.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/church_selection_gate.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

/// Tela de Login
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryBlue = Color(0xFF2563EB);
  static const _accentCyan = Color(0xFF7DD3FC);
  static const _accentNavy = Color(0xFF1E3A8A);
  static const _surfaceDark = Color(0xFF07111F);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late final AnimationController _ambientController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSendingReset = false;
  bool _googleLoginInProgress = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late final StreamSubscription<AuthState> _authSubscription;

  /// Destino preservado no `?redirect=` (LINK-03 / D-04), já saneado por
  /// [safeRedirect]. `null` quando não há parâmetro ou quando ele foi
  /// descartado pelo saneamento.
  String? _redirectDestino;
  bool _redirectResolvido = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _emailFocusNode.addListener(_syncFocusState);
    _passwordFocusNode.addListener(_syncFocusState);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      if (authState.event == AuthChangeEvent.signedIn &&
          _googleLoginInProgress) {
        unawaited(_finishGoogleLogin());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion && _ambientController.isAnimating) {
      _ambientController.stop();
    } else if (!reducedMotion && !_ambientController.isAnimating) {
      _ambientController.repeat(reverse: true);
    }

    // Resolvido uma única vez: `build` roda a cada rebuild e não pode ficar
    // repetindo o log de descarte.
    if (_redirectResolvido) return;
    _redirectResolvido = true;

    final raw = GoRouterState.of(context).uri.queryParameters['redirect'];
    if (raw == null || raw.isEmpty) return;

    final destino = safeRedirect(raw);
    if (destino == null) {
      // Destino inválido cai em `/home` EM SILÊNCIO - nenhuma mensagem nova
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

  void _syncFocusState() {
    if (!mounted) return;
    setState(() {
      _emailFocused = _emailFocusNode.hasFocus;
      _passwordFocused = _passwordFocusNode.hasFocus;
    });
  }

  void _logLogin(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[Login] $message');
    if (error != null) debugPrint('[Login] error=$error');
    if (stackTrace != null) debugPrint('[Login] stackTrace=$stackTrace');
  }

  @override
  void dispose() {
    _emailFocusNode
      ..removeListener(_syncFocusState)
      ..dispose();
    _passwordFocusNode
      ..removeListener(_syncFocusState)
      ..dispose();
    _ambientController.dispose();
    unawaited(_authSubscription.cancel());
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
        // seletor de igreja - quem clicou num link de inscrição cai na
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
        var message = AppErrorHandler.userMessage(e, feature: 'auth.login');

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
          content: const Text(
            'Se houver uma conta para este e-mail, você receberá as instruções de recuperação.',
          ),
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

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _isLoading = true;
      _googleLoginInProgress = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      _logLogin('attempt login provider=google');
      final started = await authRepo.signInWithGoogle(
        redirectPath: _redirectDestino,
      );
      if (!started) {
        throw const AuthException('Não foi possível abrir o login com Google.');
      }
    } catch (e, stackTrace) {
      _googleLoginInProgress = false;
      _logLogin(
        'google login failed type=${e.runtimeType}',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'auth.google_login',
          fallbackMessage:
              'Não foi possível entrar com o Google. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishGoogleLogin() async {
    if (!_googleLoginInProgress || !mounted) return;
    _googleLoginInProgress = false;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.ensureCurrentSessionAccount();
      final route = await ChurchSelectionGate.resolveNextRoute(
        Supabase.instance.client,
      );

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

      _logLogin('google login success, redirect to $proximaRota');
      if (mounted) context.go(proximaRota);
    } catch (e, stackTrace) {
      _logLogin(
        'google session setup failed type=${e.runtimeType}',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'auth.google_login',
          fallbackMessage:
              'A conta foi autenticada, mas não foi possível preparar seu acesso.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceDark,
      body: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, _) {
          final progress = MediaQuery.of(context).disableAnimations
              ? 0.35
              : _ambientController.value;

          return Stack(
            children: [
              Positioned.fill(child: _LoginAtmosphere(progress: progress)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 410),
                      child: _LoginGlassCard(
                        borderProgress: progress,
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 28),
                                _buildEmailField(),
                                const SizedBox(height: 16),
                                _buildPasswordField(),
                                const SizedBox(height: 6),
                                _buildForgotPasswordButton(),
                                const SizedBox(height: 18),
                                _buildSubmitButton(),
                                const SizedBox(height: 18),
                                _buildGoogleDivider(),
                                const SizedBox(height: 14),
                                _buildGoogleButton(),
                                const SizedBox(height: 22),
                                _buildSignupLink(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      height: 1.05,
    );

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: _accentCyan.withValues(alpha: 0.20),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const AppLogo(fit: BoxFit.cover),
        ),
        const SizedBox(height: 20),
        Text(
          AppBranding.appName,
          textAlign: TextAlign.center,
          style: titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          AppBranding.organizationName,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: _authInputDecoration(
        label: 'Email',
        hint: 'seu@email.com',
        icon: Icons.email_outlined,
        focused: _emailFocused,
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
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      onFieldSubmitted: (_) {
        if (!_isLoading) _handleLogin();
      },
      decoration: _authInputDecoration(
        label: 'Senha',
        hint: '********',
        icon: Icons.lock_outline,
        focused: _passwordFocused,
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white.withValues(
              alpha: _passwordFocused ? 0.90 : 0.56,
            ),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
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
    );
  }

  InputDecoration _authInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool focused,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(14);
    final baseBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: Colors.white.withValues(alpha: focused ? 0.92 : 0.46),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: focused ? 0.12 : 0.07),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      floatingLabelStyle: const TextStyle(color: Colors.white),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
      errorStyle: const TextStyle(color: Color(0xFFFFB4AB), height: 1.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1.2),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading || _isSendingReset ? null : _handlePasswordReset,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.78),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.32),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(_isSendingReset ? 'Enviando...' : 'Esqueci minha senha'),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: _isLoading ? 0.20 : 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.58),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  key: ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSignupLink(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Não tem uma conta?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/signup'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Criar conta'),
        ),
      ],
    );
  }

  Widget _buildGoogleDivider() {
    final color = Colors.white.withValues(alpha: 0.16);
    return Row(
      children: [
        Expanded(child: Divider(color: color, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: color, height: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleGoogleLogin,
      icon: const FaIcon(FontAwesomeIcons.google, size: 17),
      label: Text(_isLoading ? 'Abrindo Google...' : 'Continuar com Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        backgroundColor: Colors.white.withValues(alpha: 0.055),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LoginAtmosphere extends StatelessWidget {
  final double progress;

  const _LoginAtmosphere({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pulse = math.sin(progress * math.pi);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF112D57), Color(0xFF0B1B38), Color(0xFF050814)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.22 + (progress * 0.12), -0.94),
                  radius: 0.90 + (pulse * 0.05),
                  colors: [
                    _LoginScreenState._accentCyan.withValues(alpha: 0.34),
                    _LoginScreenState._primaryBlue.withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.78 - (progress * 0.10), 0.86),
                  radius: 0.74 + (pulse * 0.08),
                  colors: [
                    _LoginScreenState._accentNavy.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginPatternPainter(
                color: Colors.white.withValues(alpha: 0.030),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPatternPainter extends CustomPainter {
  final Color color;

  const _LoginPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const gap = 34.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoginPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LoginGlassCard extends StatefulWidget {
  final Widget child;
  final double borderProgress;

  const _LoginGlassCard({required this.child, required this.borderProgress});

  @override
  State<_LoginGlassCard> createState() => _LoginGlassCardState();
}

class _LoginGlassCardState extends State<_LoginGlassCard> {
  Offset _tilt = Offset.zero;
  bool _hovered = false;

  void _handleHover(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(event.position);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    final normalized = Offset(
      ((local.dx - center.dx) / center.dx).clamp(-1.0, 1.0),
      ((local.dy - center.dy) / center.dy).clamp(-1.0, 1.0),
    );

    setState(() {
      _hovered = true;
      _tilt = normalized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final targetTilt = _hovered && !reducedMotion ? _tilt : Offset.zero;

    return MouseRegion(
      onHover: _handleHover,
      onExit: (_) {
        setState(() {
          _hovered = false;
          _tilt = Offset.zero;
        });
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: targetTilt),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, tilt, child) {
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(-tilt.dy * 0.045)
            ..rotateY(tilt.dx * 0.045);

          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: CustomPaint(
              foregroundPainter: _LoginBorderPainter(
                progress: widget.borderProgress,
                active: _hovered,
              ),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.070),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-0.8, -1),
                              end: const Alignment(0.8, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.09),
                                Colors.transparent,
                              ],
                              stops: const [0.18, 0.46, 0.74],
                            ),
                          ),
                        ),
                      ),
                    ),
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBorderPainter extends CustomPainter {
  final double progress;
  final bool active;

  const _LoginBorderPainter({required this.progress, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.8),
      const Radius.circular(24),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: active ? 0.18 : 0.10),
    );

    final shader = SweepGradient(
      colors: [
        Colors.transparent,
        _LoginScreenState._accentCyan.withValues(alpha: active ? 0.78 : 0.46),
        Colors.white.withValues(alpha: active ? 0.70 : 0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 0.08, 0.14, 0.25],
      transform: GradientRotation(progress * math.pi * 2),
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.8 : 2.0
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}
