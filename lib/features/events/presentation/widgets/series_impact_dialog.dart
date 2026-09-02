// Fase 6 — diálogos de impacto de operação de série (S4 do `06-UI-SPEC.md`).
//
// O contrato de UI prevê seis diálogos; o enum tem sete casos porque DLG-6
// tem dois títulos (um por gatilho). Entregues até aqui — 06-04 as duas
// primeiras, 06-06 as duas seguintes:
//   • deleteFuture  — DLG-5, "Excluir as ocorrências futuras?"   ← Plano 06-04
//   • nothingToDo   — DLG-6, "Nada a excluir"                    ← Plano 06-04
//   • nothingToChange — DLG-6, "Nada a alterar"                  ← Plano 06-06
//   • applyToSeries — DLG-1, "Aplicar a toda a série?"           ← Plano 06-06
//   • extend        — DLG-2, "Estender a série?"                 ← pendente
//   • shorten       — DLG-3, "Encurtar a série?"                 ← pendente
//   • regenerate    — DLG-4, "Mudar o padrão de repetição?"      ← Plano 06-08
//
// applyToSeries é a ÚNICA variante NÃO destrutiva do conjunto: ela não apaga
// nem cria ocorrência nenhuma, só reescreve campos das futuras. Por isso o
// botão primário dela é accent, não `colorScheme.error` — a cor destrutiva
// aqui seria um alarme falso, e alarme falso é como um líder aprende a
// confirmar sem ler.
//
// O `switch` sobre a variante é EXAUSTIVO de propósito: quando as fatias que
// faltam acrescentarem os casos restantes, o compilador aponta cada lugar que
// precisa de copy nova em vez de deixar um `default` silencioso escolher o
// texto errado para uma operação destrutiva. Foi assim que a copy de DLG-6
// não virou "Nada a excluir" no caminho de aplicar.
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

  /// DLG-6 no gatilho NÃO destrutivo. O `06-UI-SPEC.md` prevê dois títulos
  /// para o mesmo diálogo — "Nada a excluir" no caminho de REC-05 e "Nada a
  /// alterar" nos demais —, e o corpo é o mesmo. Duas variantes em vez de um
  /// parâmetro de título porque o `switch` exaustivo continua sendo quem
  /// obriga cada caminho novo a declarar a própria copy; um título opcional
  /// com default silencioso faria o caminho novo herdar "excluir" sem que
  /// nada apitasse.
  nothingToChange,
  applyToSeries,
  extend,
  shorten,
  regenerate,
}

const String _naoEntregueAinda =
    'Variante de diálogo de série ainda não entregue: DLG-2/DLG-3 aguardam a '
    'fatia de encurtar/estender e DLG-4 é do Plano 06-08. Ver o cabeçalho de '
    'series_impact_dialog.dart.';

/// A variante confirma uma operação que APAGA alguma coisa?
///
/// Governa a cor do botão primário e nada mais. `applyToSeries` e `extend`
/// respondem `false`: nenhuma das duas remove ocorrência, inscrição ou
/// escala.
bool seriesImpactIsDestructive(SeriesImpactVariant variant) {
  switch (variant) {
    case SeriesImpactVariant.applyToSeries:
    case SeriesImpactVariant.extend:
    case SeriesImpactVariant.nothingToDo:
    case SeriesImpactVariant.nothingToChange:
      return false;
    case SeriesImpactVariant.deleteFuture:
    case SeriesImpactVariant.shorten:
    case SeriesImpactVariant.regenerate:
      return true;
  }
}

final DateFormat _dataBr = DateFormat('dd/MM/yyyy');

/// Título do diálogo (20/600).
String seriesImpactTitle(SeriesImpactVariant variant) {
  switch (variant) {
    case SeriesImpactVariant.deleteFuture:
      return 'Excluir as ocorrências futuras?';
    case SeriesImpactVariant.nothingToDo:
      return 'Nada a excluir';
    case SeriesImpactVariant.nothingToChange:
      return 'Nada a alterar';
    case SeriesImpactVariant.applyToSeries:
      return 'Aplicar a toda a série?';
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
    case SeriesImpactVariant.nothingToChange:
      return 'Entendi';
    case SeriesImpactVariant.applyToSeries:
      // Sem contagem no rótulo, ao contrário do botão destrutivo: aqui o
      // tamanho da operação está no corpo e nada é removido.
      return 'Aplicar à série';
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
    case SeriesImpactVariant.nothingToChange:
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

    // DLG-1 — a única variante que não remove nada. Duas linhas, e a segunda
    // some quando não há passado a tranquilizar (`m == 0`), pela mesma regra
    // de omissão das outras variantes. Não existe linha de inscrições aqui:
    // esta operação não cancela inscrição nenhuma.
    case SeriesImpactVariant.applyToSeries:
      final n = impact.futureCount;
      final m = impact.pastCount;
      final primeira = impact.firstFuture;
      final ultima = impact.lastFuture;

      final intervalo = (primeira == null || ultima == null)
          ? '.'
          : primeira == ultima
          ? ', em ${_dataBr.format(primeira)}.'
          : ', de ${_dataBr.format(primeira)} até ${_dataBr.format(ultima)}.';

      return [
        _paragrafo(context, [
          const TextSpan(text: 'As alterações vão valer para '),
          _numero(n),
          TextSpan(
            text: n == 1
                ? ' ocorrência futura$intervalo'
                : ' ocorrências futuras$intervalo',
          ),
        ]),

        if (m > 0)
          _paragrafo(context, [
            if (m == 1)
              const TextSpan(
                text: 'A ocorrência passada não será alterada.',
              )
            else ...[
              const TextSpan(text: 'As '),
              _numero(m),
              const TextSpan(
                text: ' ocorrências passadas não serão alteradas.',
              ),
            ],
          ]),
      ];

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

  bool get _informativo =>
      widget.variant == SeriesImpactVariant.nothingToDo ||
      widget.variant == SeriesImpactVariant.nothingToChange;

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
                          // Accent para as variantes que não removem nada
                          // (DLG-1); destrutivo só onde algo some de fato.
                          style: seriesImpactIsDestructive(widget.variant)
                              ? FilledButton.styleFrom(
                                  backgroundColor: cs.error,
                                  foregroundColor: cs.onError,
                                )
                              : null,
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
