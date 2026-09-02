import 'package:flutter/material.dart';

import '../../../../core/design/community_design.dart';

/// Fase 6 — S6 / IC-6 do `06-UI-SPEC.md`. Barreira de progresso da criação de
/// uma série de eventos fixos.
///
/// O progresso é **determinado** (`{done} de {total}`) porque o loop de
/// criação conhece o total real de ocorrências antes de começar. Percentual
/// inventado numa operação longa é pior que indicador indeterminado (A-10) —
/// e aqui não há desculpa, o número é conhecido.
///
/// **Não existe botão de cancelar, de propósito.** A criação da série é um
/// loop no cliente, sem transação (Achado #3 do `06-RESEARCH.md`): cancelar no
/// meio deixaria a série pela metade, com ocorrências já gravadas no servidor
/// e nenhuma forma de o usuário saber quantas. A saída de uma criação
/// interrompida é a copy de falha parcial do formulário, que informa o número
/// e nomeia "Excluir ocorrências futuras".
class SeriesProgressBarrier extends StatelessWidget {
  final int done;
  final int total;

  const SeriesProgressBarrier({
    super.key,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progresso = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: CommunityDesign.overlayPadding,
                decoration: CommunityDesign.overlayDecoration(colorScheme),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progresso,
                      minHeight: 4,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    // Semantics(liveRegion: true): operação longa precisa ser
                    // anunciada ao leitor de tela a cada avanço, não só
                    // desenhada.
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Criando ocorrências... $done de $total',
                        style: CommunityDesign.contentStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
