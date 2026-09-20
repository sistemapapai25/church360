import 'package:flutter/material.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../domain/models/baptism_student.dart';

/// Card de um aluno na aba Alunos.
///
/// Receita do sistema de design: `GlassCard` (raio 18), `StatusBadge` do
/// ciclo de vida, tags em pílula e as ações à direita em botão circular.
///
/// **Não há barra de progresso de presença.** A tabela de presença ainda não
/// existe (a aba Presença está em construção), e uma barra alimentada por
/// nada mostraria 0% para todo aluno — a tela pareceria dizer que ninguém
/// frequenta. Ela entra junto com a chamada.
class StudentCard extends StatelessWidget {
  final BaptismStudent student;

  /// Nulo quando o usuário não pode editar: o menu some junto.
  final VoidCallback? onEdit;

  /// Nulo quando o usuário não pode excluir.
  final VoidCallback? onDelete;

  /// Nulo quando o aluno não tem telefone: o botão fica apagado em vez de
  /// abrir o WhatsApp num número vazio.
  final VoidCallback? onWhatsApp;

  /// Quantas etapas do checklist este aluno cumpriu, de quantas se aplicam
  /// a ele.
  ///
  /// Nulo quando o checklist ainda está carregando ou falhou — nesse caso
  /// a pílula some e o resto do card continua de pé. Total zero também não
  /// mostra nada: "0/0" não informa, só ocupa espaço.
  final ({int done, int total})? checklist;

  const StudentCard({
    super.key,
    required this.student,
    this.onEdit,
    this.onDelete,
    this.onWhatsApp,
    this.checklist,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final turmaColor = CommunityDesign.accentForeground(
      context,
      AppTheme.secondary,
    );

    final age = student.age;
    final phone = student.phone?.trim();
    final meta = <String>[
      if (phone != null && phone.isNotEmpty) phone,
      if (age != null) '$age anos',
    ].join(' · ');

    final hasMenu = onEdit != null || onDelete != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      StatusBadge(
                        label: student.status.label,
                        tone: student.status.tone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CircleAction(
                  icon: AppIcons.message,
                  tooltip: onWhatsApp == null
                      ? 'Aluno sem telefone cadastrado'
                      : 'Enviar mensagem no WhatsApp',
                  color: accent,
                  onTap: onWhatsApp,
                ),
                if (hasMenu) ...[
                  const SizedBox(width: 6),
                  _StudentMenu(
                    onEdit: onEdit,
                    onDelete: onDelete,
                    color: muted,
                  ),
                ],
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(meta, style: CommunityDesign.metaStyle(context)),
            ],
            const SizedBox(height: 10),
            // Wrap, não Row: com selo + turma + origem, três pílulas não
            // cabem numa linha de 360px.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (student.turmaName != null)
                  _Pill(
                    label: student.turmaName!,
                    color: turmaColor,
                    background: turmaColor.withValues(alpha: 0.12),
                    icon: AppIcons.group,
                  ),
                if (checklist != null && checklist!.total > 0)
                  _Pill(
                    label: '${checklist!.done}/${checklist!.total} etapas',
                    color: CommunityDesign.accentForeground(
                      context,
                      AppTheme.primary,
                    ),
                    background: AppTheme.primary.withValues(alpha: 0.14),
                    icon: checklist!.done == checklist!.total
                        ? AppIcons.completed
                        : AppIcons.checklist,
                  ),
                if (student.source == BaptismStudentSource.publica)
                  _Pill(
                    label: 'Inscrição Pública',
                    color: CommunityDesign.accentForeground(
                      context,
                      AppTheme.warningColor,
                    ),
                    background: AppTheme.warningColor.withValues(alpha: 0.14),
                    icon: AppIcons.public,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  const _Pill({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final tint = enabled ? color : muted;

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: dark ? AppTheme.darkCard : AppTheme.card,
        foregroundColor: tint,
        disabledForegroundColor: muted,
        side: BorderSide(color: dark ? AppTheme.darkBorder : AppTheme.border),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _StudentMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color color;

  const _StudentMenu({this.onEdit, this.onDelete, required this.color});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      icon: Icon(AppIcons.more, size: 20, color: color),
      style: IconButton.styleFrom(
        backgroundColor: dark ? AppTheme.darkCard : AppTheme.card,
        side: BorderSide(color: dark ? AppTheme.darkBorder : AppTheme.border),
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(AppIcons.edit, size: 18),
                SizedBox(width: 10),
                Text('Editar'),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(AppIcons.delete, size: 18),
                SizedBox(width: 10),
                Text('Excluir'),
              ],
            ),
          ),
      ],
    );
  }
}
