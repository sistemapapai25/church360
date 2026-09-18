import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../../shared/presentation/widgets/ministry_scale_tab.dart';
import '../../../shared/presentation/widgets/ministry_tab_placeholder.dart';
import '../../../shared/presentation/widgets/ministry_team_tab.dart';
import '../../../shared/presentation/widgets/ministry_workspace_shell.dart';
import '../../domain/models/baptism_student.dart';
import '../providers/baptism_providers.dart';
import 'tabs/batismo_alunos_tab.dart';
import 'tabs/batismo_relatorios_tab.dart';
import 'tabs/batismo_whatsapp_tab.dart';

/// Workspace do Batismo nas Águas (Etapa 4 do plano).
///
/// As oito abas aparecem desde já. Equipe, Escala, Alunos, WhatsApp e
/// Relatórios estão prontas; Financeiro chega nas Etapas 2 e 5, e Checklist e
/// Presença depois. Até lá elas mostram um estado vazio honesto, para que a
/// estrutura do módulo fique visível e o que falta fique explícito.
class BatismoHomeScreen extends ConsumerWidget {
  final String ministryId;

  const BatismoHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'baptism.view',
      submoduleLabel: 'Batismo',
      builder: (context) => _BatismoWorkspace(ministryId: ministryId),
    );
  }
}

class _BatismoWorkspace extends ConsumerWidget {
  final String ministryId;

  const _BatismoWorkspace({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));
    final teamCount = membersAsync.maybeWhen(
      data: (m) => m.length,
      orElse: () => null,
    );

    // Alunos e turmas são observados aqui, e não só dentro da aba, porque a
    // linha de indicadores fica acima da barra de abas: sem isso o número
    // só apareceria depois de alguém abrir Alunos. O shell continua montando
    // apenas a aba ativa — o que sobe aqui são duas consultas, não a tela.
    final studentsAsync = ref.watch(baptismStudentsProvider(ministryId));
    final activeStudents = studentsAsync.maybeWhen(
      data: (list) => list
          .where((s) => s.status == BaptismStudentStatus.ativo)
          .length,
      orElse: () => null,
    );
    final studentCount = studentsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );
    final turmaCount = ref.watch(baptismTurmasProvider(ministryId)).maybeWhen(
          data: (list) => list.length,
          orElse: () => null,
        );

    return MinistryWorkspaceShell(
      ministryId: ministryId,
      fallbackTitle: 'Batismo nas Águas',
      stats: [
        if (teamCount != null)
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '$teamCount',
            icon: Icons.groups_outlined,
          ),
        if (activeStudents != null)
          MinistryWorkspaceStat(
            label: 'alunos ativos',
            value: '$activeStudents',
            icon: Icons.school_outlined,
          ),
        if (turmaCount != null && turmaCount > 0)
          MinistryWorkspaceStat(
            label: turmaCount == 1 ? 'turma' : 'turmas',
            value: '$turmaCount',
            icon: Icons.groups_2_outlined,
          ),
      ],
      tabs: [
        MinistryWorkspaceTab(
          label: 'Equipe',
          count: teamCount?.toString(),
          builder: (_) => MinistryTeamTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Escala',
          builder: (_) => MinistryScaleTab(ministryId: ministryId),
        ),
        const MinistryWorkspaceTab(
          label: 'Financeiro',
          builder: _financeiroPlaceholder,
        ),
        MinistryWorkspaceTab(
          label: 'Alunos',
          count: studentCount?.toString(),
          builder: (_) => BatismoAlunosTab(ministryId: ministryId),
        ),
        const MinistryWorkspaceTab(
          label: 'Checklist',
          builder: _checklistPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'Presença',
          builder: _presencaPlaceholder,
        ),
        MinistryWorkspaceTab(
          label: 'WhatsApp',
          builder: (_) => BatismoWhatsAppTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Relatórios',
          builder: (_) => BatismoRelatoriosTab(ministryId: ministryId),
        ),
      ],
    );
  }
}

Widget _financeiroPlaceholder(BuildContext context) =>
    const MinistryTabPlaceholder(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Caixa do ministério',
      description:
          'Entradas, saídas e alvos do departamento, com a saída esperando '
          'confirmação de quem responde pelo financeiro.',
    );

Widget _checklistPlaceholder(BuildContext context) =>
    const MinistryTabPlaceholder(
      icon: Icons.checklist_outlined,
      title: 'Checklist do batismo',
      description:
          'As etapas que cada candidato precisa cumprir até o dia do batismo.',
    );

Widget _presencaPlaceholder(BuildContext context) =>
    const MinistryTabPlaceholder(
      icon: Icons.how_to_reg_outlined,
      title: 'Presença nas aulas',
      description: 'Chamada por aula e o acompanhamento de quem está faltando.',
    );
