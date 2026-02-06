import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  ) childBuilder;
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
  ConsumerState<SupportChatContainer> createState() => _SupportChatContainerState();
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

  @override
  void initState() {
    super.initState();
    _isOpen = widget.defaultOpen;
    _currentAgentKey = widget.agentKey;
    _currentAccentColor = widget.accentColor;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

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
    final agentKeyChanged = oldWidget.agentKey.toLowerCase() != widget.agentKey.toLowerCase();
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
    final already = _pinnedAgent &&
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

        // Cálculos de Posição
        // BaseOffset considera a altura da NavBar (passada via widget.bottomOffset) + safeBottom
        // Mas se o teclado abrir, ignoramos isso e colamos no teclado
        final double baseBottomOffset = widget.bottomOffset; // widget.bottomOffset já inclui safeBottom + navbar height quando necessário
        
        final double buttonBottomPosition = keyboardInset > 0
            ? keyboardInset + kFloatingSpacing
            : baseBottomOffset;

        // A janela do chat fica acima do botão flutuante
        final double chatWindowBottomMargin =
            buttonBottomPosition + kFloatingButtonSize + kFloatingButtonGap;

        // Dimensões da Janela
        double chatWidth;
        double chatHeight;

        if (isMobile) {
          chatWidth = size.width - 32; // Margem de 16px de cada lado
          final maxHeight = size.height - chatWindowBottomMargin - (16 + topInset);
          chatHeight = math.min(size.height * 0.7, maxHeight);
        } else if (isTablet) {
          chatWidth = math.min(size.width * 0.85, 450);
          final maxHeight = size.height - chatWindowBottomMargin - (16 + topInset);
          chatHeight = math.min(kDesktopHeight, maxHeight);
        } else {
          chatWidth = kDesktopWidth;
          final maxHeight = size.height - chatWindowBottomMargin - (16 + topInset);
          chatHeight = math.min(kDesktopHeight, maxHeight);
        }
        chatHeight = math.max(0, chatHeight);

        return SizedBox.expand(
          child: Stack(
            alignment: widget.position,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                bottom: buttonBottomPosition,
                right: 24,
                child: GestureDetector(
                  onTap: _toggle,
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
                        child: AgentAvatar(agent: resolved, size: kFloatingButtonSize - 8),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isOpen || _controller.isAnimating)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  bottom: chatWindowBottomMargin,
                  right: 16,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final dy = (_slideAnimation.value.dy * 200).clamp(0.0, 20.0);
                      return ClipRect(
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: chatWidth,
                                height: chatHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
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
