// Fase 6 — REC-02 / D-01 / D-12. Toggle de escopo da edição de uma ocorrência
// de série (S2/IC-3 do `06-UI-SPEC.md`).
//
// Três regras são o coração deste widget:
//
//   1. DESLIGADO POR PADRÃO, SEMPRE. O estado nunca é lembrado entre
//      aberturas do formulário (D-01). Quem liga o toggle é que afeta a
//      série; o caminho padrão continua sendo editar uma linha isolada,
//      exatamente como antes desta fase. Por isso `enabled` é propriedade do
//      chamador e este widget não guarda cópia dela.
//
//   2. CAMPOS DE PADRÃO APARECEM DESABILITADOS, NÃO ESCONDIDOS (A-07).
//      Escondê-los faria o líder concluir que a série perdeu a definição — e
//      ele acabou de ver o badge "Série" logo acima.
//
//   3. TODO CAMPO DO FORMULÁRIO É REPLICÁVEL (D-03), sem lista fixa na UI. O
//      que o formulário edita, a série recebe: o payload enviado à RPC é o
//      mesmo mapa `data` que o formulário já monta para uma ocorrência. Este
//      widget não conhece — e não pode conhecer — a lista de campos.
//
// GATE DE UI É UX, NUNCA BOUNDARY (IC-8, padrão T-08-01 da Fase 3). A
// AUTORIDADE REAL É A RPC `public.apply_event_series_update` (migration
// `20260902000600`), que resolve o ator por `auth.uid()` e o tenant por
// `current_tenant_id()` DENTRO do servidor e recusa com `PERMISSION_DENIED`
// quem não for responsável pelo evento nem tiver `events.edit`. Esconder o
// toggle aqui evita um disparo acidental; não impede nada. O tratamento de
// `PERMISSION_DENIED` no `catch` da tela é mantido mesmo com este gate.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/event_series.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../providers/events_provider.dart';

class SeriesScopeToggle extends ConsumerStatefulWidget {
  /// A ocorrência aberta no formulário — é ela que vira o modelo da série.
  final String eventId;

  /// O lote (`event.batch_id`) a que a ocorrência pertence.
  final String batchId;

  /// Data da ocorrência aberta, para o subtítulo do estado desligado.
  final DateTime occurrenceDate;

  /// Definição do padrão. `null` = **série legada** (IC-7), não erro.
  final EventSeries? series;

  /// Estado do toggle. Propriedade do formulário, nunca deste widget.
  final bool enabled;

  final ValueChanged<bool> onChanged;

  /// `n` — ocorrências futuras, vindo da prévia do servidor. `null` enquanto
  /// não carregou: o subtítulo usa a variante sem número, nunca imprime
  /// `null` e nunca estima localmente.
  final int? futureCount;

  /// Os campos de padrão e o campo `Repetir até`, construídos pelo
  /// formulário. Ficam sempre visíveis; este widget decide se são operáveis.
  final Widget child;

  const SeriesScopeToggle({
    super.key,
    required this.eventId,
    required this.batchId,
    required this.occurrenceDate,
    required this.series,
    required this.enabled,
    required this.onChanged,
    required this.child,
    this.futureCount,
  });

  @override
  ConsumerState<SeriesScopeToggle> createState() => _SeriesScopeToggleState();
}

class _SeriesScopeToggleState extends ConsumerState<SeriesScopeToggle> {
  /// Série legada não tem padrão salvo — os campos de padrão continuam
  /// desabilitados mesmo com o toggle ligado (IC-7). O toggle em si segue
  /// disponível: aplicar campos comuns às futuras não depende de conhecer o
  /// padrão (A-14).
  bool get _serieLegada => widget.series == null;

  bool get _camposHabilitados => widget.enabled && !_serieLegada;

  String _subtitulo() {
    if (!widget.enabled) {
      final data = DateFormat('dd/MM/yyyy').format(widget.occurrenceDate);
      return 'Só esta ocorrência, de $data, será alterada.';
    }

    final n = widget.futureCount;
    if (n == null) {
      // Sem número do servidor a frase perde a contagem, nunca a verdade.
      return 'As ocorrências futuras desta série serão alteradas. '
          'As passadas não são tocadas.';
    }
    if (n == 0) {
      return 'Esta série não tem ocorrências futuras. Nada será alterado.';
    }
    if (n == 1) {
      return 'A ocorrência futura desta série será alterada. '
          'As passadas não são tocadas.';
    }
    return 'As $n ocorrências futuras desta série serão alteradas. '
        'As passadas não são tocadas.';
  }

  Widget _blocoSerieLegada(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Padrão de repetição não registrado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Esta série foi criada antes desta atualização, então o '
                  'padrão não ficou salvo. Você ainda pode aplicar alterações '
                  'de campos comuns a todas as ocorrências futuras. Para mudar '
                  'o padrão ou o período, exclua as ocorrências futuras e crie '
                  'a série de novo.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // FAIL-CLOSED: `loading` e `error` dos dois providers resolvem para
    // `false` (via `valueOrNull`), e sem autorização o toggle nem é
    // construído.
    //
    // Isto DIVERGE DE PROPÓSITO da decisão de elegibilidade do Plano 03-08,
    // onde o ramo `error` mantinha o botão de inscrição HABILITADO. Lá havia
    // um usuário legítimo a proteger de uma falha de rede, e o servidor
    // recusaria se fosse o caso. Aqui há uma operação em massa sobre dezenas
    // de ocorrências a proteger de um disparo acidental — o custo de errar
    // para o lado permissivo não é simétrico.
    final ehResponsavel = ref.watch(isEventResponsibleProvider(widget.eventId));
    final temEventsEdit = ref.watch(
      currentUserHasPermissionProvider('events.edit'),
    );
    final autorizado =
        (ehResponsavel.valueOrNull ?? false) ||
        (temEventsEdit.valueOrNull ?? false);
    if (!autorizado) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_serieLegada) ...[
          _blocoSerieLegada(context, cs),
          const SizedBox(height: 16),
        ],

        // Nenhum ajuste de densidade visual nem encolhimento do alvo de
        // toque é aplicado a este controle — os dois parâmetros do
        // `SwitchListTile` que fariam isso são PROIBIDOS aqui. Este é o toque
        // que decide o alcance de uma operação em massa, e ele mantém o alvo
        // mínimo de 48x48 do Material (Contrato de Acessibilidade).
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aplicar a toda a série (futuras)'),
          subtitle: Text(_subtitulo()),
          value: widget.enabled,
          onChanged: widget.onChanged,
        ),

        if (!widget.enabled) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ligue "Aplicar a toda a série" para mudar o padrão ou o período.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Os campos ficam VISÍVEIS e inoperantes (A-07). O `AbsorbPointer` é
        // a garantia estrutural — o formulário também constrói os campos com
        // `enabled: false`, mas um campo novo que esqueça o parâmetro não
        // vira, por isso, um caminho de escrita.
        AbsorbPointer(
          absorbing: !_camposHabilitados,
          child: Opacity(
            opacity: _camposHabilitados ? 1 : 0.6,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
