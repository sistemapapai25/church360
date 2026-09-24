import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../domain/ministry_contact.dart';
import '../../domain/ministry_finance.dart';
import '../providers/ministry_finance_providers.dart';

/// Aba Relatórios do workspace: o panorama do departamento em uma tela —
/// equipe, escala e caixa.
///
/// Fica de fora, de propósito, tudo que é de um tipo de ministério: aluno,
/// turma e presença são do Batismo e continuam no relatório dele.
///
/// **O caixa só entra para quem já pode vê-lo.** A régua é a mesma da aba
/// Financeiro (`ministryFinanceAccessProvider`: vínculo **e**
/// `ministry_finance.view`, ou quem cuida do financeiro da igreja). Um
/// resumo que mostrasse o saldo para quem a aba Financeiro fecha seria a
/// mesma permissão furada pela porta dos fundos.
///
/// **Sem PDF nesta versão.** A fonte base do gerador só desenha Latin-1, e
/// travessão, bullet e emoji viram vão silencioso na folha — o relatório em
/// papel é a Etapa E do Batismo, que sanea o texto. Aqui a saída é o resumo
/// em texto, que o WhatsApp e o bloco de notas aceitam como está.
class MinistryReportsTab extends ConsumerWidget {
  final String ministryId;

  const MinistryReportsTab({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));
    final schedulesAsync = ref.watch(ministrySchedulesProvider(ministryId));
    final accessAsync = ref.watch(ministryFinanceAccessProvider(ministryId));
    final ministryName = ref
        .watch(ministryByIdProvider(ministryId))
        .maybeWhen(data: (m) => m?.name, orElse: () => null);

    final access = accessAsync.maybeWhen(
      data: (a) => a,
      orElse: () => MinistryFinanceAccess.none,
    );
    final summaryAsync = access.canView
        ? ref.watch(ministryFinanceSummaryProvider(ministryId))
        : null;

    final loading = membersAsync.isLoading || schedulesAsync.isLoading;
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final members = membersAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <MinistryMember>[],
    );
    final schedules = schedulesAsync.maybeWhen(
      data: (s) => s,
      orElse: () => const <MinistrySchedule>[],
    );
    final summary = summaryAsync?.maybeWhen(data: (s) => s, orElse: () => null);

    final team = _TeamNumbers.from(members);
    final scale = _ScaleNumbers.from(schedules);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ministryMembersProvider(ministryId));
        ref.invalidate(ministrySchedulesProvider(ministryId));
        if (access.canView) {
          ref.invalidate(ministryFinanceSummaryProvider(ministryId));
        }
        await ref.read(ministryMembersProvider(ministryId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _ReportCard(
            icon: AppIcons.group,
            title: 'Equipe',
            lines: [
              _ReportLine('Pessoas na equipe', '${team.total}'),
              _ReportLine('Liderança', '${team.leaders}'),
              _ReportLine('Membros', '${team.members}'),
              _ReportLine(
                'Com telefone utilizável',
                '${team.withPhone} de ${team.total}',
              ),
              if (team.incompletePhone > 0)
                _ReportLine(
                  'Telefone incompleto na ficha',
                  '${team.incompletePhone}',
                  warn: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _ReportCard(
            icon: AppIcons.calendar,
            title: 'Escala',
            lines: [
              _ReportLine('Escalas registradas', '${scale.total}'),
              _ReportLine('Daqui para frente', '${scale.upcoming}'),
              _ReportLine(
                'Próximo compromisso',
                scale.nextLabel ?? 'nenhum agendado',
              ),
              _ReportLine('Pessoas escaladas', '${scale.distinctPeople}'),
            ],
          ),
          const SizedBox(height: 10),
          if (access.canView && summary != null)
            _ReportCard(
              icon: AppIcons.finance,
              title: 'Caixa do departamento',
              lines: [
                _ReportLine('Entradas', _money.format(summary.entradas)),
                _ReportLine('Saídas', _money.format(summary.saidas)),
                _ReportLine('Saldo', _money.format(summary.saldo)),
                if (summary.pendentesCount > 0)
                  _ReportLine(
                    'Aguardando aprovação',
                    '${summary.pendentesCount} · '
                        '${_money.format(summary.pendentesTotal)}',
                    warn: true,
                  ),
              ],
            )
          else
            _ReportCard(
              icon: AppIcons.finance,
              title: 'Caixa do departamento',
              lines: const [
                _ReportLine(
                  'Fora deste resumo',
                  'sem permissão de ver o caixa',
                ),
              ],
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _copy(
              context,
              ministryName: ministryName,
              team: team,
              scale: scale,
              summary: access.canView ? summary : null,
            ),
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copiar resumo'),
          ),
          const SizedBox(height: 6),
          Text(
            'Copia o texto acima para colar onde você quiser.',
            style: CommunityDesign.metaStyle(context),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(
    BuildContext context, {
    required String? ministryName,
    required _TeamNumbers team,
    required _ScaleNumbers scale,
    required MinistryFinanceSummary? summary,
  }) async {
    final buffer = StringBuffer()
      ..writeln(ministryName ?? 'Ministério')
      ..writeln('Resumo de ${DateFormat('dd/MM/yyyy').format(DateTime.now())}')
      ..writeln()
      ..writeln('Equipe: ${team.total} '
          '(${team.leaders} na liderança, ${team.members} membros)')
      ..writeln('Com telefone utilizável: ${team.withPhone} de ${team.total}');
    if (team.incompletePhone > 0) {
      buffer.writeln('Telefone incompleto: ${team.incompletePhone}');
    }
    buffer
      ..writeln()
      ..writeln('Escalas registradas: ${scale.total}')
      ..writeln('Daqui para frente: ${scale.upcoming}')
      ..writeln('Proximo compromisso: ${scale.nextLabel ?? 'nenhum agendado'}')
      ..writeln('Pessoas escaladas: ${scale.distinctPeople}');
    if (summary != null) {
      buffer
        ..writeln()
        ..writeln('Entradas: ${_money.format(summary.entradas)}')
        ..writeln('Saidas: ${_money.format(summary.saidas)}')
        ..writeln('Saldo: ${_money.format(summary.saldo)}');
      if (summary.pendentesCount > 0) {
        buffer.writeln(
          'Aguardando aprovacao: ${summary.pendentesCount} '
          '(${_money.format(summary.pendentesTotal)})',
        );
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resumo copiado.')));
  }
}

final NumberFormat _money = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
);

class _TeamNumbers {
  final int total;
  final int leaders;
  final int members;
  final int withPhone;
  final int incompletePhone;

  const _TeamNumbers({
    required this.total,
    required this.leaders,
    required this.members,
    required this.withPhone,
    required this.incompletePhone,
  });

  factory _TeamNumbers.from(List<MinistryMember> list) {
    final leaders = list.where((m) => m.role != MinistryRole.member).length;
    return _TeamNumbers(
      total: list.length,
      leaders: leaders,
      members: list.length - leaders,
      withPhone: list.where(ministryMemberHasWhatsApp).length,
      incompletePhone: list
          .where(
            (m) => ministryPhoneState(m.phone) == MinistryPhoneState.incomplete,
          )
          .length,
    );
  }
}

class _ScaleNumbers {
  final int total;
  final int upcoming;
  final int distinctPeople;
  final String? nextLabel;

  const _ScaleNumbers({
    required this.total,
    required this.upcoming,
    required this.distinctPeople,
    required this.nextLabel,
  });

  factory _ScaleNumbers.from(List<MinistrySchedule> list) {
    final now = DateTime.now();
    final dated = list.where((s) => s.eventStartDate != null).toList()
      ..sort((a, b) => a.eventStartDate!.compareTo(b.eventStartDate!));
    final next = dated.where((s) => !s.eventStartDate!.isBefore(now)).toList();

    String? label;
    if (next.isNotEmpty) {
      final first = next.first;
      // A data vem como hora de parede rotulada UTC (contrato do projeto):
      // formatar direto é o que mostra a hora que a pessoa marcou.
      label =
          '${DateFormat('dd/MM').format(first.eventStartDate!)} · '
          '${first.eventName}';
    }

    return _ScaleNumbers(
      total: list.length,
      upcoming: next.length,
      distinctPeople: list.map((s) => s.memberId).toSet().length,
      nextLabel: label,
    );
  }
}

class _ReportLine {
  final String label;
  final String value;
  final bool warn;

  const _ReportLine(this.label, this.value, {this.warn = false});
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_ReportLine> lines;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.label,
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    line.value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: line.warn ? Colors.orange : muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
