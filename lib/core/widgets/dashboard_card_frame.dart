import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/breakpoints.dart';

/// Cards expandidos nesta sessão (B2). Vale enquanto o app está aberto; não
/// vai ao banco de propósito: expandir é um gesto de leitura, não uma
/// preferência.
final expandedDashboardCardsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// Moldura de cada card da Dashboard (B2 do roadmap Home/culto/Dashboard).
///
/// - **Celular (compact)**: devolve o card como está. Sem rolagem dentro da
///   rolagem da página; os cards já mostram um resumo e abrem a tela deles.
/// - **Tablet/PC**: altura máxima [maxHeight], conteúdo rolável por dentro
///   e, quando não cabe, um botão Expandir/Recolher. O estado fica em
///   [expandedDashboardCardsProvider], por [widgetKey].
///
/// Os cards não são reescritos: só ganham a moldura.
class DashboardCardFrame extends ConsumerStatefulWidget {
  final String widgetKey;
  final Widget child;
  final double maxHeight;

  const DashboardCardFrame({
    super.key,
    required this.widgetKey,
    required this.child,
    this.maxHeight = 420,
  });

  @override
  ConsumerState<DashboardCardFrame> createState() => _DashboardCardFrameState();
}

class _DashboardCardFrameState extends ConsumerState<DashboardCardFrame> {
  bool _overflows = false;

  void _toggle() {
    final notifier = ref.read(expandedDashboardCardsProvider.notifier);
    final next = {...notifier.state};
    if (!next.remove(widget.widgetKey)) next.add(widget.widgetKey);
    notifier.state = next;
  }

  @override
  Widget build(BuildContext context) {
    if (context.breakpoint == Breakpoint.compact) return widget.child;

    final expanded = ref.watch(
      expandedDashboardCardsProvider.select(
        (s) => s.contains(widget.widgetKey),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: expanded ? double.infinity : widget.maxHeight,
          ),
          // ScrollMetricsNotification chega sempre que o tamanho do conteúdo
          // muda (dado assíncrono que acaba de carregar, por exemplo): é o
          // sinal de "cabe ou não cabe", sem medir nada à mão.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              final overflows = n.metrics.maxScrollExtent > 0;
              if (overflows != _overflows) {
                setState(() => _overflows = overflows);
              }
              return false;
            },
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: widget.child,
            ),
          ),
        ),
        if (_overflows || expanded)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _toggle,
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(expanded ? 'Recolher' : 'Expandir'),
            ),
          ),
      ],
    );
  }
}
