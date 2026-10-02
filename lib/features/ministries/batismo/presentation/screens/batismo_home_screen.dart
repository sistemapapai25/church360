import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/domain/ministry_type_catalog.dart';
import '../../../shared/presentation/providers/ministry_type_catalog_providers.dart';
import '../../../shared/presentation/widgets/ministry_standard_slots.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../../shared/presentation/widgets/ministry_workspace_shell.dart';
import '../../domain/models/baptism_student.dart';
import '../providers/baptism_providers.dart';
import 'tabs/batismo_alunos_tab.dart';
import 'tabs/batismo_relatorios_tab.dart';
import 'tabs/batismo_whatsapp_tab.dart';

/// Workspace do Batismo nas Águas (Etapa 4 do plano).
///
/// Parte das abas de [ministryStandardSlots] e troca só o que é dele: a
/// contagem de Alunos e as versões próprias de WhatsApp e Relatórios.
///
/// Entra quem é do ministério (ou tem visão global), sem `baptism.view`:
/// desde 01/10 quem é do ministério vê alunos, checklist e presença, e a
/// permissão só decide criar/editar/excluir.
class BatismoHomeScreen extends ConsumerWidget {
  final String ministryId;

  const BatismoHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
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
      tabs: ministryTabsFromCatalog(
        catalog: ref.watch(ministryTypeCatalogSyncProvider),
        typeCode: MinistryTypeCodes.batismo,
        slots: {
          ...ministryStandardSlots(ministryId, teamCount: teamCount),
          MinistryTabKeys.alunos: MinistryTabSlot(
            defaultLabel: 'Alunos',
            count: studentCount?.toString(),
            builder: (_) => BatismoAlunosTab(ministryId: ministryId),
          ),
          MinistryTabKeys.whatsapp: MinistryTabSlot(
            defaultLabel: 'WhatsApp',
            builder: (_) => BatismoWhatsAppTab(ministryId: ministryId),
          ),
          MinistryTabKeys.relatorios: MinistryTabSlot(
            defaultLabel: 'Relatórios',
            builder: (_) => BatismoRelatoriosTab(ministryId: ministryId),
          ),
        },
      ),
    );
  }
}
