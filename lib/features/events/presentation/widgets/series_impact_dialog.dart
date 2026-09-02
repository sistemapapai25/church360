// Fase 6 — diálogos de impacto de operação de série (S4 do `06-UI-SPEC.md`).
//
// Seis variantes estão previstas no contrato de UI; ESTE plano (06-04) entrega
// duas:
//   • deleteFuture  — DLG-5, "Excluir as ocorrências futuras?"   ← Plano 06-04
//   • nothingToDo   — DLG-6, "Nada a excluir"                    ← Plano 06-04
//   • applyToSeries — DLG-1, "Aplicar a toda a série?"           ← Plano 06-06
//   • extend        — DLG-2, "Estender a série?"                 ← Plano 06-06
//   • shorten       — DLG-3, "Encurtar a série?"                 ← Plano 06-06
//   • regenerate    — DLG-4, "Mudar o padrão de repetição?"      ← Plano 06-08
//
// O `switch` sobre a variante é EXAUSTIVO de propósito: quando os Planos 06-06
// e 06-08 acrescentarem os casos que faltam, o compilador aponta cada lugar que
// precisa de copy nova em vez de deixar um `default` silencioso escolher o
// texto errado para uma operação destrutiva.
//
// TODAS as contagens exibidas aqui vêm do servidor (`EventSeriesImpact`, modo
// `p_dry_run`), nunca de estimativa local — A-04 do `06-UI-SPEC.md`. Este
// widget não calcula nada: ele só formata o que a RPC já respondeu.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/event_series_impact.dart';

/// As seis variantes previstas pelo `06-UI-SPEC.md`. Ver o cabeçalho do
/// arquivo para o mapa variante → diálogo → plano que a entrega.
enum SeriesImpactVariant {
  deleteFuture,
  nothingToDo,
  applyToSeries,
  extend,
  shorten,
  regenerate,
}

const String _naoEntregueAinda =
    'Variante de diálogo de série ainda não entregue: DLG-1/2/3 são do Plano '
    '06-06 e DLG-4 é do Plano 06-08. Ver o cabeçalho de '
    'series_impact_dialog.dart.';

final DateFormat _dataBr = DateFormat('dd/MM/yyyy');

/// Título do diálogo (20/600).
String seriesImpactTitle(SeriesImpactVariant variant) {
  switch (variant) {
    case SeriesImpactVariant.deleteFuture:
      return 'Excluir as ocorrências futuras?';
    case SeriesImpactVariant.nothingToDo:
      // DLG-6 muda de "Nada a alterar" para "Nada a excluir" conforme o
      // gatilho. Enquanto só o caminho de REC-05 existe, este é o único
      // texto possível; os Planos 06-06/06-08 precisam parametrizar.
      return 'Nada a excluir';
    case SeriesImpactVariant.applyToSeries:
    case SeriesImpactVariant.extend:
    case SeriesImpactVariant.shorten:
    case SeriesImpactVariant.regenerate:
      throw UnimplementedError(_naoEntregueAinda);
  }
}

/// Rótulo do botão de confirmação. Carrega a contagem real — nunca um verbo
/// solto: o líder tem que ver o tamanho do que está confirmando no próprio
/// botão.
String seriesImpactConfirmLabel(
  SeriesImpactVariant variant,
  EventSeriesImpact impact,
) {
  switch (variant) {
    case SeriesImpactVariant.deleteFuture:
      return impact.futureCount == 1
          ? 'Excluir 1 ocorrência'
          : 'Excluir ${impact.futureCount} ocorrências';
    case SeriesImpactVariant.nothingToDo:
      return 'Entendi';
    case SeriesImpactVariant.applyToSeries:
    case SeriesImpactVariant.extend:
    case SeriesImpactVariant.shorten:
    case SeriesImpactVariant.regenerate:
      throw UnimplementedError(_naoEntregueAinda);
  }
}

/// Parágrafo do corpo (14/400) com os números de impacto em `w600`.
///
/// O número recebe peso, nunca tamanho próprio e nunca cor diferente do texto
/// ao redor — a cor destrutiva é reservada à linha de inscrições canceladas.
Widget _paragrafo(
  BuildContext context,
  List<InlineSpan> partes, {
  Color? cor,
}) {
  final base = CommunityDesign.contentStyle(context);
  return Text.rich(
    TextSpan(children: partes),
    style: cor == null ? base : base.copyWith(color: cor),
  );
}

TextSpan _numero(int valor) => TextSpan(
  text: '$valor',
  style: const TextStyle(fontWeight: FontWeight.w600),
);

/// Descrição do conjunto futuro atingido, com o intervalo de datas quando o
/// servidor devolveu as duas pontas.
///
/// `firstFuture`/`lastFuture` nulos com `futureCount > 0` não deveriam
/// acontecer, mas a frase degrada omitindo o intervalo em vez de imprimir
/// `null` ou inventar uma data.
List<InlineSpan> _linhaFuturas(EventSeriesImpact impact, String eventName) {
  final n = impact.futureCount;
  final primeira = impact.firstFuture;
  final ultima = impact.lastFuture;

  final sufixo = (primeira == null || ultima == null)
      ? '.'
      : primeira == ultima
      ? ', em ${_dataBr.format(primeira)}.'
      : ', de ${_dataBr.format(primeira)} até ${_dataBr.format(ultima)}.';

  return [
    _numero(n),
    TextSpan(
      text: n == 1
          ? ' ocorrência futura de "$eventName" será excluída$sufixo'
          : ' ocorrências futuras de "$eventName" serão excluídas$sufixo',
    ),
  ];
}

/// Corpo do diálogo, montado como função pura para que cada regra de contagem
/// possa ser verificada isoladamente por teste de widget.
///
/// Regras (todas do `06-UI-SPEC.md`, seção "Regras de contagem nos diálogos"):
///   • `m == 0` → a linha de ocorrências passadas é OMITIDA (não há passado a
///     tranquilizar);
///   • `k == 0` → a linha de inscrições é SUBSTITUÍDA por "Nenhuma pessoa
///     inscrita será afetada.", nunca omitida e nunca "0 inscrições";
///   • `k > 0` → a linha inteira em `colorScheme.error` com
///     `Icons.person_off_outlined` à esquerda, e é a ÚNICA linha destrutiva do
///     corpo;
///   • plural sempre pela contagem real — proibido o plural por parêntese
///     (`ocorrência` seguida de `s` entre parênteses), padrão que esta fase
///     remove da lista de eventos.
List<Widget> buildImpactBody(
  BuildContext context, {
  required SeriesImpactVariant variant,
  required EventSeriesImpact impact,
  required String eventName,
}) {
  final cs = Theme.of(context).colorScheme;

  switch (variant) {
    case SeriesImpactVariant.nothingToDo:
      final m = impact.pastCount;
      final passadas = m == 1
          ? 'A ocorrência passada é preservada'
          : 'As $m ocorrências passadas são preservadas';
      return [
        _paragrafo(context, [
          TextSpan(
            text: m == 0
                ? 'Esta série não tem ocorrências futuras. Se precisar mexer '
                      'em alguma ocorrência, edite ou exclua uma por uma.'
                : 'Esta série não tem ocorrências futuras. $passadas — se '
                      'precisar mexer em alguma, edite ou exclua uma por uma.',
          ),
        ]),
      ];

    case SeriesImpactVariant.deleteFuture:
      final m = impact.pastCount;
      final k = impact.affectedRegistrations;

      return [
        _paragrafo(context, _linhaFuturas(impact, eventName)),

        if (m > 0)
          _paragrafo(context, [
            if (m == 1)
              const TextSpan(
                text: 'A ocorrência passada será preservada, com inscrições, '
                    'presença e escalas.',
              )
            else ...[
              _numero(m),
              const TextSpan(
                text: ' ocorrências passadas serão preservadas, com '
                    'inscrições, presença e escalas.',
              ),
            ],
          ]),

        if (k == 0)
          _paragrafo(
            context,
            [const TextSpan(text: 'Nenhuma pessoa inscrita será afetada.')],
            cor: cs.onSurfaceVariant,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_off_outlined, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: _paragrafo(
                  context,
                  k == 1
                      ? [
                          const TextSpan(
                            text: '1 inscrição será cancelada e a pessoa '
                                'será avisada.',
                          ),
                        ]
                      : [
                          _numero(k),
                          const TextSpan(
                            text: ' inscrições serão canceladas e as pessoas '
                                'serão avisadas.',
                          ),
                        ],
                  cor: cs.error,
                ),
              ),
            ],
          ),

        _paragrafo(context, [
          const TextSpan(text: 'Esta ação não pode ser desfeita.'),
        ]),
      ];

    case SeriesImpactVariant.applyToSeries:
    case SeriesImpactVariant.extend:
    case SeriesImpactVariant.shorten:
    case SeriesImpactVariant.regenerate:
      throw UnimplementedError(_naoEntregueAinda);
  }
}

/// O diálogo em si.
///
/// Prefira [showSeriesImpactDialog].
class SeriesImpactDialog extends StatefulWidget {
  final SeriesImpactVariant variant;
  final EventSeriesImpact impact;
  final String eventName;

  /// Executado ao confirmar, com o botão já desabilitado e mostrando
  /// `CircularProgressIndicator` de 16px no lugar do rótulo (IC-6).
  ///
  /// **Não deve lançar**: o tratamento de erro (copy PT-BR de
  /// `series_error.dart` + `AppErrorHandler`) é da tela chamadora, que conhece
  /// o `fallbackMessage` da operação. Se lançar, o diálogo fecha assim mesmo e
  /// a exceção propaga para quem chamou `showSeriesImpactDialog`.
  final Future<void> Function()? onConfirm;

  const SeriesImpactDialog({
    super.key,
    required this.variant,
    required this.impact,
    required this.eventName,
    this.onConfirm,
  });

  @override
  State<SeriesImpactDialog> createState() => _SeriesImpactDialogState();
}

class _SeriesImpactDialogState extends State<SeriesImpactDialog> {
  bool _executando = false;

  bool get _informativo => widget.variant == SeriesImpactVariant.nothingToDo;

  Future<void> _confirmar() async {
    // Anti duplo toque (T-04-05). A atomicidade real é da transação da RPC;
    // isto aqui é só UX.
    if (_executando) return;
    setState(() => _executando = true);
    try {
      await widget.onConfirm?.call();
    } finally {
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: CommunityDesign.overlayDecoration(cs),
          padding: CommunityDesign.overlayPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seriesImpactTitle(widget.variant),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final linha in buildImpactBody(
                        context,
                        variant: widget.variant,
                        impact: widget.impact,
                        eventName: widget.eventName,
                      )) ...[linha, const SizedBox(height: 16)],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _informativo
                    ? [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            seriesImpactConfirmLabel(
                              widget.variant,
                              widget.impact,
                            ),
                          ),
                        ),
                      ]
                    : [
                        TextButton(
                          onPressed: _executando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _executando ? null : _confirmar,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ),
                          child: _executando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  seriesImpactConfirmLabel(
                                    widget.variant,
                                    widget.impact,
                                  ),
                                ),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre o diálogo de impacto. Devolve `true` quando a operação foi confirmada
/// (e [onConfirm], se informado, já rodou até o fim).
Future<bool?> showSeriesImpactDialog(
  BuildContext context, {
  required SeriesImpactVariant variant,
  required EventSeriesImpact impact,
  required String eventName,
  Future<void> Function()? onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    // Operação destrutiva em massa: não fecha por toque fora enquanto a RPC
    // pode estar em voo.
    barrierDismissible: false,
    builder: (context) => SeriesImpactDialog(
      variant: variant,
      impact: impact,
      eventName: eventName,
      onConfirm: onConfirm,
    ),
  );
}
