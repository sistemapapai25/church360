import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../../shared/presentation/widgets/ministry_tab_placeholder.dart';
import '../../../shared/presentation/widgets/ministry_team_tab.dart';
import '../../../shared/presentation/widgets/ministry_workspace_shell.dart';

/// Workspace do Batismo nas Águas (Etapa 4 do plano).
///
/// As sete abas aparecem desde já; Alunos chega na Etapa 6 e Financeiro nas
/// Etapas 2 e 5. Até lá elas mostram um estado vazio honesto, para que a
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
    // Enquanto a aba Alunos não existe, o único indicador que o módulo
    // consegue afirmar com honestidade é o tamanho da equipe. Alunos e
    // turmas entram aqui na Etapa 6.
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));
    final teamCount = membersAsync.maybeWhen(
      data: (m) => m.length,
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
      ],
      tabs: [
        MinistryWorkspaceTab(
          label: 'Equipe',
          count: teamCount?.toString(),
          builder: (_) => MinistryTeamTab(ministryId: ministryId),
        ),
        const MinistryWorkspaceTab(
          label: 'Financeiro',
          builder: _financeiroPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'Alunos',
          builder: _alunosPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'Checklist',
          builder: _checklistPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'Presença',
          builder: _presencaPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'WhatsApp',
          builder: _whatsappPlaceholder,
        ),
        const MinistryWorkspaceTab(
          label: 'Relatórios',
          builder: _relatoriosPlaceholder,
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

Widget _alunosPlaceholder(BuildContext context) => const MinistryTabPlaceholder(
      icon: Icons.school_outlined,
      title: 'Alunos e turmas',
      description:
          'Cadastro dos candidatos, turma de cada um e o progresso nas aulas.',
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

Widget _whatsappPlaceholder(BuildContext context) =>
    const MinistryTabPlaceholder(
      icon: Icons.chat_outlined,
      title: 'Comunicação',
      description:
          'Mensagem individual pelo WhatsApp e os avisos em massa da turma.',
    );

Widget _relatoriosPlaceholder(BuildContext context) =>
    const MinistryTabPlaceholder(
      icon: Icons.description_outlined,
      title: 'Relatórios',
      description: 'Listas de presença e o relatório da turma em PDF.',
    );
