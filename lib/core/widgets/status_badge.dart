import 'package:flutter/material.dart';

import '../design/community_design.dart';
import '../theme/app_theme.dart';

/// Tom de um badge de status de registro.
///
/// Sao tres estados de ciclo de vida de um cadastro (aluno de turma,
/// matricula, inscricao), nao niveis de gravidade:
///
/// - [active]   — em andamento (verde `success`);
/// - [done]     — concluido (azul `primary` / `ring` no escuro);
/// - [dropped]  — desistiu / inativo (cinza `mutedForeground`).
///
/// [dropped] e NEUTRO de proposito. Usar `error` aqui faria uma lista de
/// alunos parecer uma lista de falhas.
enum AppStatusTone {
  active,
  done,
  dropped;

  /// Cor do tom ja resolvida para o tema em uso.
  ///
  /// O escuro nao repete o claro: `done` cai para `darkRing` e `dropped`
  /// para `darkMutedForeground`, que sao os pares escuros que o tema ja
  /// declara. O verde de `active` nao tem par escuro no tema, entao passa
  /// por [CommunityDesign.accentForeground], que o clareia ate um piso de
  /// luminosidade — o mesmo tratamento que os badges da Comunidade ja
  /// recebem. Sem isso ele ficaria escuro sobre fundo escuro, que foi
  /// exatamente o bug do PR #82.
  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case AppStatusTone.active:
        return CommunityDesign.accentForeground(context, AppTheme.statusActive);
      case AppStatusTone.done:
        return dark ? AppTheme.statusDoneDark : AppTheme.statusDone;
      case AppStatusTone.dropped:
        return dark ? AppTheme.statusDroppedDark : AppTheme.statusDropped;
    }
  }
}

/// Selo de status de um registro: pilula, ponto solido e rotulo curto.
///
/// Receita do sistema de design (componente Badge, familia "status de
/// registro"): fundo na cor do status a 14%, borda a 35%, ponto solido de
/// 6px e texto 11px bold em maiusculas.
///
/// Existe em `core/` porque o app ja tem quatro badges de status
/// reinventados em telas diferentes (`_StatusBadge` do Diaconato e do
/// Raizes, `_VisibilityBadge`, `_Badge`) — ver
/// `.planning/design/ICON_INVENTORY.md`, item 12. Telas novas usam este;
/// as antigas podem migrar depois.
///
/// Para marcar TIPO de conteudo (Oracao, Classificado, Testemunho...) o
/// componente certo continua sendo `CommunityDesign.typeBadge`.
class StatusBadge extends StatelessWidget {
  /// Rotulo curto. E exibido em maiusculas — nao precisa vir assim.
  final String label;
  final AppStatusTone tone;

  /// Icone opcional no lugar do ponto solido.
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  const StatusBadge.active({super.key, required this.label, this.icon})
    : tone = AppStatusTone.active;

  const StatusBadge.done({super.key, required this.label, this.icon})
    : tone = AppStatusTone.done;

  const StatusBadge.dropped({super.key, required this.label, this.icon})
    : tone = AppStatusTone.dropped;

  @override
  Widget build(BuildContext context) {
    final color = tone.color(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 11, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
