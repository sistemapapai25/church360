import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../data/oauth_consent_api.dart';
import '../domain/oauth_client_allowlist.dart';
import 'external_navigation.dart' as external_navigation;

/// Tela de consentimento do login único (OAuth 2.1 / OIDC do Supabase Auth).
///
/// Chega aqui pelo `Authorization Path` configurado no painel
/// (`<Site URL>/oauth/consent?authorization_id=...`). A rota é protegida como
/// qualquer outra: sem sessão, o guard do GoRouter manda para
/// `/login?redirect=<esta URL inteira>` e o `safeRedirect` traz o usuário de
/// volta depois do login (senha ou Google). Com sessão, não há senha de novo.
///
/// Ela não decide QUEM pode usar o Lider360: só confirma a identidade. A
/// autorização continua inteira do lado do Lider360.
class OAuthConsentScreen extends StatefulWidget {
  final String? authorizationId;

  /// Pontos de injeção para teste e demonstração local.
  final OAuthConsentApi? api;
  final List<OAuthAllowedClient> allowlist;
  final void Function(String url)? navigateExternal;
  final Future<void> Function()? signOut;

  const OAuthConsentScreen({
    super.key,
    required this.authorizationId,
    this.api,
    this.allowlist = kOAuthAllowedClients,
    this.navigateExternal,
    this.signOut,
  });

  @override
  State<OAuthConsentScreen> createState() => _OAuthConsentScreenState();
}

enum _Fase {
  carregando,
  consentimento,
  redirecionando,
  clienteDesconhecido,
  pedidoInvalido,
  expirado,
  falhaRede,
  naoSuportado,
}

class _OAuthConsentScreenState extends State<OAuthConsentScreen> {
  static const _primaryBlue = Color(0xFF2563EB);
  static const _surfaceDark = Color(0xFF07111F);

  late final OAuthConsentApi _api = widget.api ?? _apiPadrao();
  _Fase _fase = _Fase.carregando;
  AuthorizationNeedsConsent? _pedido;
  OAuthAllowedClient? _client;
  bool _enviando = false;

  static OAuthConsentApi _apiPadrao() => OAuthConsentApi(
    httpClient: http.Client(),
    supabaseUrl: SupabaseConstants.supabaseUrl,
    apiKey: SupabaseConstants.supabaseAnonKey,
    accessToken: () =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _fase = _Fase.carregando);
    final id = widget.authorizationId;
    if (!isValidAuthorizationId(id)) {
      setState(() => _fase = _Fase.pedidoInvalido);
      return;
    }
    if (widget.navigateExternal == null &&
        !external_navigation.externalNavigationSupported) {
      setState(() => _fase = _Fase.naoSuportado);
      return;
    }

    try {
      final resultado = await _api.fetch(id!);
      if (!mounted) return;
      switch (resultado) {
        case AuthorizationAlreadyDecided(:final redirectUrl):
          // Consentimento dado antes: volta direto, mas só para um destino
          // que pertença a um client da allowlist.
          final client = clientForRedirect(
            redirectUrl,
            allowlist: widget.allowlist,
          );
          if (client == null) {
            setState(() => _fase = _Fase.clienteDesconhecido);
            return;
          }
          _client = client;
          _sair(redirectUrl);
        case AuthorizationNeedsConsent():
          _avaliarPedido(resultado);
      }
    } on OAuthConsentException catch (e) {
      if (!mounted) return;
      _tratarFalha(e.failure);
    }
  }

  void _avaliarPedido(AuthorizationNeedsConsent pedido) {
    final client = findAllowedClient(
      pedido.clientId,
      allowlist: widget.allowlist,
    );
    if (client == null) {
      setState(() => _fase = _Fase.clienteDesconhecido);
      return;
    }
    if (!redirectAllowed(pedido.redirectUri, client) ||
        !scopesAllowed(pedido.scope, client)) {
      setState(() => _fase = _Fase.pedidoInvalido);
      return;
    }
    setState(() {
      _pedido = pedido;
      _client = client;
      _fase = _Fase.consentimento;
    });
  }

  Future<void> _decidir({required bool aprovar}) async {
    final pedido = _pedido;
    final client = _client;
    if (pedido == null || client == null || _enviando) return;
    setState(() => _enviando = true);
    try {
      final redirectUrl = await _api.decide(
        pedido.authorizationId,
        approve: aprovar,
      );
      if (!mounted) return;
      if (!redirectAllowed(redirectUrl, client)) {
        setState(() {
          _enviando = false;
          _fase = _Fase.pedidoInvalido;
        });
        return;
      }
      _sair(redirectUrl);
    } on OAuthConsentException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _tratarFalha(e.failure);
    }
  }

  void _sair(String url) {
    setState(() => _fase = _Fase.redirecionando);
    (widget.navigateExternal ?? external_navigation.replaceLocation)(url);
  }

  void _tratarFalha(OAuthConsentFailure falha) {
    switch (falha) {
      case OAuthConsentFailure.sessionMissing:
        // Sessão expirou no meio do caminho: login de novo, voltando aqui.
        final volta = Uri(
          path: '/oauth/consent',
          queryParameters: {'authorization_id': widget.authorizationId ?? ''},
        ).toString();
        context.go('/login?redirect=${Uri.encodeComponent(volta)}');
      case OAuthConsentFailure.expired:
        setState(() => _fase = _Fase.expirado);
      case OAuthConsentFailure.invalidRequest:
      case OAuthConsentFailure.invalidResponse:
        setState(() => _fase = _Fase.pedidoInvalido);
      case OAuthConsentFailure.network:
        setState(() => _fase = _Fase.falhaRede);
    }
  }

  Future<void> _trocarConta() async {
    final volta = Uri(
      path: '/oauth/consent',
      queryParameters: {'authorization_id': widget.authorizationId ?? ''},
    ).toString();
    await (widget.signOut ?? () => Supabase.instance.client.auth.signOut())();
    if (!mounted) return;
    context.go('/login?redirect=${Uri.encodeComponent(volta)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF112D57), Color(0xFF0B1B38), Color(0xFF050814)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: _Cartao(child: _conteudo(context)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    return switch (_fase) {
      _Fase.carregando => const _Aguarde(texto: 'Verificando o pedido…'),
      _Fase.redirecionando => _Aguarde(
        texto: 'Voltando ao ${_client?.displayName ?? 'aplicativo'}…',
      ),
      _Fase.consentimento => _consentimento(context),
      _Fase.clienteDesconhecido => _Aviso(
        icone: Icons.block_rounded,
        titulo: 'Aplicativo não autorizado',
        texto:
            'Este aplicativo não está autorizado a usar o login do Church360.',
        acao: _voltarAoChurch360(context),
      ),
      _Fase.pedidoInvalido => _Aviso(
        icone: Icons.error_outline_rounded,
        titulo: 'Não foi possível continuar',
        texto:
            'O pedido de acesso não é válido. Volte ao aplicativo e tente entrar de novo.',
        acao: _voltarAoChurch360(context),
      ),
      _Fase.expirado => _Aviso(
        icone: Icons.timer_off_outlined,
        titulo: 'Pedido expirado',
        texto:
            'Este pedido de acesso expirou ou já foi usado. Volte ao aplicativo e tente entrar de novo.',
        acao: _voltarAoChurch360(context),
      ),
      _Fase.falhaRede => _Aviso(
        icone: Icons.wifi_off_rounded,
        titulo: 'Sem conexão com o servidor',
        texto: 'Verifique sua internet e tente novamente.',
        acao: _BotaoPrimario(texto: 'Tentar novamente', onPressed: _carregar),
      ),
      _Fase.naoSuportado => _Aviso(
        icone: Icons.language_rounded,
        titulo: 'Abra no navegador',
        texto:
            'A confirmação de acesso a outros aplicativos funciona na versão web do Church360.',
        acao: _voltarAoChurch360(context),
      ),
    };
  }

  Widget _consentimento(BuildContext context) {
    final nome = _client!.displayName;
    final email = _pedido?.userEmail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppLogo(height: 64, variant: AppLogoVariant.branca),
        const SizedBox(height: 22),
        Text(
          'Entrar no $nome',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'O $nome quer confirmar sua identidade usando sua conta Church360.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        if (email != null && email.isNotEmpty) ...[
          const SizedBox(height: 22),
          _ContaAtual(email: email, onTrocar: _enviando ? null : _trocarConta),
        ],
        const SizedBox(height: 18),
        Text(
          'Sua senha não é compartilhada. O que você pode fazer no $nome é definido pelo próprio $nome.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _BotaoPrimario(
          texto: 'Continuar',
          carregando: _enviando,
          onPressed: _enviando ? null : () => _decidir(aprovar: true),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _enviando ? null : () => _decidir(aprovar: false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _voltarAoChurch360(BuildContext context) => _BotaoPrimario(
    texto: 'Ir para o Church360',
    onPressed: () => context.go('/home'),
  );
}

class _Cartao extends StatelessWidget {
  final Widget child;
  const _Cartao({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ContaAtual extends StatelessWidget {
  final String email;
  final VoidCallback? onTrocar;
  const _ContaAtual({required this.email, required this.onTrocar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_circle_outlined,
            color: Colors.white.withValues(alpha: 0.80),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onTrocar,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7DD3FC),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Trocar conta'),
          ),
        ],
      ),
    );
  }
}

class _BotaoPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  const _BotaoPrimario({
    required this.texto,
    required this.onPressed,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    const azul = _OAuthConsentScreenState._primaryBlue;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: azul,
        disabledBackgroundColor: azul.withValues(alpha: 0.58),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 52),
      ),
      child: carregando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(texto, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _Aguarde extends StatelessWidget {
  final String texto;
  const _Aguarde({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(height: 56, variant: AppLogoVariant.branca),
          const SizedBox(height: 24),
          const SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Color(0xFF7DD3FC),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget acao;
  const _Aviso({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icone, color: const Color(0xFF7DD3FC), size: 44),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        acao,
      ],
    );
  }
}
