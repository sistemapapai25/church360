import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/support_agent.dart';
import '../providers/agents_providers.dart';
import 'agent_avatar.dart';

/// Container visual do Chat de Suporte
/// Responsável pela aparência, animações e gerenciamento de estado (abrir/fechar).
class SupportChatContainer extends ConsumerStatefulWidget {
  final Widget Function(
    ValueChanged<ResolvedAgent> onAgentChanged,
    String agentKey,
    Color accentColor,
  )
  childBuilder;
  final String title;
  final Color accentColor;
  final bool defaultOpen;
  final Alignment position;
  final double bottomOffset;
  final String agentKey;

  const SupportChatContainer({
    super.key,
    required this.childBuilder,
    this.title = 'Fale Conosco',
    this.accentColor = const Color(0xFF2563EB), // Azul padrão (#2563eb)
    this.defaultOpen = false,
    this.position = Alignment.bottomRight,
    this.bottomOffset = 16.0,
    this.agentKey = 'default',
  });

  @override
  ConsumerState<SupportChatContainer> createState() =>
      _SupportChatContainerState();
}

class _SupportChatContainerState extends ConsumerState<SupportChatContainer>
    with SingleTickerProviderStateMixin {
  late bool _isOpen;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late String _currentAgentKey;
  late Color _currentAccentColor;
  bool _pinnedAgent = false;

  // Posição arrastável do botão flutuante (canto superior-esquerdo do
  // botão). null = ainda não foi movido pelo usuário; usa a posição padrão.
  static const String _positionPrefsKey = 'support_chat_button_position_v1';
  Offset? _buttonPosition;
  Offset? _dragStartOffset;
  Offset? _dragStartGlobalPos;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.defaultOpen;
    _currentAgentKey = widget.agentKey;
    _currentAccentColor = widget.accentColor;
    _loadSavedPosition();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (_isOpen) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_positionPrefsKey);
      if (raw == null) return;
      final parts = raw.split(',');
      if (parts.length != 2) return;
      final dx = double.tryParse(parts[0]);
      final dy = double.tryParse(parts[1]);
      if (dx == null || dy == null) return;
      if (!mounted) return;
      setState(() => _buttonPosition = Offset(dx, dy));
    } catch (_) {}
  }

  Future<void> _savePosition(Offset offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_positionPrefsKey, '${offset.dx},${offset.dy}');
    } catch (_) {}
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
        _pinnedAgent = false;
        _currentAgentKey = widget.agentKey;
        _currentAccentColor = widget.accentColor;
      }
    });
  }

  @override
  void didUpdateWidget(covariant SupportChatContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final agentKeyChanged =
        oldWidget.agentKey.toLowerCase() != widget.agentKey.toLowerCase();
    final colorChanged = oldWidget.accentColor != widget.accentColor;

    if (agentKeyChanged) {
      _pinnedAgent = false;
      _currentAgentKey = widget.agentKey;
      _currentAccentColor = widget.accentColor;
      return;
    }

    if (_isOpen) {
      if (_pinnedAgent) return;
      if (agentKeyChanged) _currentAgentKey = widget.agentKey;
      if (colorChanged) _currentAccentColor = widget.accentColor;
      return;
    }

    _pinnedAgent = false;
    if (agentKeyChanged) _currentAgentKey = widget.agentKey;
    if (colorChanged) _currentAccentColor = widget.accentColor;
  }

  void _handleAgentChanged(ResolvedAgent agent) {
    final normalizedKey = agent.key.toLowerCase();
    final normalizedWidgetKey = widget.agentKey.toLowerCase();
    final shouldPin = normalizedKey != normalizedWidgetKey;
    final already =
        _pinnedAgent &&
        _currentAgentKey.toLowerCase() == normalizedKey &&
        _currentAccentColor == agent.themeColor;
    if (already) return;

    void apply() {
      if (!mounted) return;
      setState(() {
        if (shouldPin) _pinnedAgent = true;
        _currentAgentKey = agent.key;
        _currentAccentColor = agent.themeColor;
      });
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return;
    }

    apply();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAgentsAsync = ref.watch(visibleAgentsForCurrentUserProvider);

    return visibleAgentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (visibleAgents) {
        if (visibleAgents.isEmpty) return const SizedBox.shrink();

        // Resolver agente atual (verificar se ainda é permitido)
        // Se o agente atual não estiver na lista visível, fallback para o primeiro disponível
        final resolved = visibleAgents.firstWhere(
          (a) => a.key.toLowerCase() == _currentAgentKey.toLowerCase(),
          orElse: () => visibleAgents.first,
        );

        // Se o agente não deve mostrar o botão flutuante, esconder tudo
        if (!resolved.showFloatingButton) {
          return const SizedBox.shrink();
        }

        // Se mudamos de agente por força de permissão (fallback),
        // seria ideal atualizar o estado, mas aqui apenas usamos o resolved para renderizar
        final effectiveKey = resolved.key;
        final effectiveColor = resolved.themeColor;

        // --- Configurações de Layout ---
        final size = MediaQuery.of(context).size;
        final mediaQuery = MediaQuery.of(context);
        final keyboardInset = mediaQuery.viewInsets.bottom;
        final topInset = mediaQuery.padding.top;
        final isMobile = size.width < 640;
        final isTablet = size.width >= 640 && size.width < 1024;

        // Constantes de Design
        const double kFloatingButtonSize = 65.0;
        const double kFloatingButtonGap = 15.0;
        const double kDesktopWidth = 400.0;
        const double kDesktopHeight = 600.0;
        const double kFloatingSpacing = 16.0;
        const double kScreenMargin = 8.0;

        // Posição padrão do botão (canto inferior direito), convertida para
        // left/top. widget.bottomOffset já inclui safeBottom + navbar height
        // quando necessário; se o teclado abrir, colamos nele em vez disso.
        final double defaultBottomOffset = keyboardInset > 0
            ? keyboardInset + kFloatingSpacing
            : widget.bottomOffset;
        final double defaultLeft = size.width - kFloatingButtonSize - 24;
        final double defaultTop =
            size.height - defaultBottomOffset - kFloatingButtonSize;

        // Limites para manter o botão sempre visível na tela, mesmo após
        // arrastar, girar o aparelho ou o teclado abrir.
        final double maxLeft = math.max(
          kScreenMargin,
          size.width - kFloatingButtonSize - kScreenMargin,
        );
        final double minTop = topInset + kScreenMargin;
        final double maxTop = math.max(
          minTop,
          size.height - keyboardInset - kFloatingButtonSize - kScreenMargin,
        );

        Offset buttonPosition =
            _buttonPosition ?? Offset(defaultLeft, defaultTop);
        buttonPosition = Offset(
          buttonPosition.dx.clamp(kScreenMargin, maxLeft),
          buttonPosition.dy.clamp(minTop, maxTop),
        );

        // Dimensões da Janela
        double chatWidth;
        double chatHeight;
        final double maxChatHeight =
            size.height -
            keyboardInset -
            (16 + topInset) -
            kFloatingButtonGap -
            16;

        if (isMobile) {
          chatWidth = size.width - 32; // Margem de 16px de cada lado
          chatHeight = math.min(size.height * 0.7, maxChatHeight);
        } else if (isTablet) {
          chatWidth = math.min(size.width * 0.85, 450);
          chatHeight = math.min(kDesktopHeight, maxChatHeight);
        } else {
          chatWidth = kDesktopWidth;
          chatHeight = math.min(kDesktopHeight, maxChatHeight);
        }
        chatHeight = math.max(0, chatHeight);

        // A janela abre no lado do botão com mais espaço livre na tela,
        // para nunca ser cortada pelas bordas.
        final bool openLeftward =
            buttonPosition.dx + kFloatingButtonSize / 2 > size.width / 2;
        final bool openUpward =
            buttonPosition.dy + kFloatingButtonSize / 2 > size.height / 2;

        double chatLeft = openLeftward
            ? buttonPosition.dx + kFloatingButtonSize - chatWidth
            : buttonPosition.dx;
        double chatTop = openUpward
            ? buttonPosition.dy - kFloatingButtonGap - chatHeight
            : buttonPosition.dy + kFloatingButtonSize + kFloatingButtonGap;

        chatLeft = chatLeft.clamp(
          kScreenMargin,
          math.max(kScreenMargin, size.width - chatWidth - kScreenMargin),
        );
        chatTop = chatTop.clamp(
          topInset + kScreenMargin,
          math.max(
            topInset + kScreenMargin,
            size.height - keyboardInset - chatHeight - kScreenMargin,
          ),
        );

        return SizedBox.expand(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                left: buttonPosition.dx,
                top: buttonPosition.dy,
                child: GestureDetector(
                  onPanStart: (details) {
                    _dragStartGlobalPos = details.globalPosition;
                    _dragStartOffset = buttonPosition;
                    _isDragging = false;
                  },
                  onPanUpdate: (details) {
                    final startGlobal = _dragStartGlobalPos;
                    final startOffset = _dragStartOffset;
                    if (startGlobal == null || startOffset == null) return;
                    final delta = details.globalPosition - startGlobal;
                    if (!_isDragging && delta.distance < 6) return;
                    final proposed = startOffset + delta;
                    setState(() {
                      _isDragging = true;
                      _buttonPosition = Offset(
                        proposed.dx.clamp(kScreenMargin, maxLeft),
                        proposed.dy.clamp(minTop, maxTop),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final wasDragging = _isDragging;
                    _dragStartGlobalPos = null;
                    _dragStartOffset = null;
                    if (wasDragging) {
                      setState(() => _isDragging = false);
                      _savePosition(_buttonPosition ?? buttonPosition);
                    } else {
                      _toggle();
                    }
                  },
                  child: Container(
                    width: kFloatingButtonSize,
                    height: kFloatingButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          effectiveColor,
                          effectiveColor.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: AgentAvatar(
                          agent: resolved,
                          size: kFloatingButtonSize - 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isOpen || _controller.isAnimating)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  left: chatLeft,
                  top: chatTop,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final dy = (_slideAnimation.value.dy * 200).clamp(
                        0.0,
                        20.0,
                      );
                      final scaleAlignment = openUpward
                          ? (openLeftward
                                ? Alignment.bottomRight
                                : Alignment.bottomLeft)
                          : (openLeftward
                                ? Alignment.topRight
                                : Alignment.topLeft);
                      return ClipRect(
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              alignment: scaleAlignment,
                              child: Container(
                                width: chatWidth,
                                height: chatHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      _buildHeader(resolved),
                                      Expanded(
                                        child: widget.childBuilder(
                                          _handleAgentChanged,
                                          effectiveKey,
                                          effectiveColor,
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
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ResolvedAgent resolved) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: resolved.themeColor,
      child: Row(
        children: [
          AgentAvatar(agent: resolved, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  resolved.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Botão Fechar
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: _toggle,
            tooltip: 'Fechar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
