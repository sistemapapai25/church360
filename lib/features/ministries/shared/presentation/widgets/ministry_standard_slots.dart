import '../../../batismo/presentation/screens/tabs/batismo_checklist_tab.dart';
import '../../../../courses/presentation/widgets/formacao_turmas_tab.dart';
import '../../../louvor/presentation/louvores_tab.dart';
import '../../domain/ministry_type_catalog.dart';
import 'ministry_finance_tab.dart';
import 'ministry_reports_tab.dart';
import 'ministry_scale_tab.dart';
import 'ministry_team_tab.dart';
import 'ministry_whatsapp_tab.dart';
import 'ministry_workspace_shell.dart';

/// Os widgets das abas que **todo** ministério pode ligar
/// ([MinistryTabKeys.standard]). As quatro telas de workspace partem daqui e
/// só trocam o que têm de próprio (o Painel do Raízes/Diaconato, o WhatsApp e
/// os Relatórios do Batismo) — assim uma aba nova entra uma vez e chega a
/// todos os ministérios.
Map<String, MinistryTabSlot> ministryStandardSlots(
  String ministryId, {
  int? teamCount,
}) => {
  MinistryTabKeys.equipe: MinistryTabSlot(
    defaultLabel: 'Equipe',
    count: teamCount?.toString(),
    builder: (_) => MinistryTeamTab(ministryId: ministryId),
  ),
  MinistryTabKeys.escala: MinistryTabSlot(
    defaultLabel: 'Escala',
    builder: (_) => MinistryScaleTab(ministryId: ministryId),
  ),
  MinistryTabKeys.financeiro: MinistryTabSlot(
    defaultLabel: 'Financeiro',
    builder: (_) => MinistryFinanceTab(ministryId: ministryId),
  ),
  MinistryTabKeys.louvores: MinistryTabSlot(
    defaultLabel: 'Louvores',
    builder: (_) => LouvoresTab(ministryId: ministryId),
  ),
  // Turma comum do ministério (o Batismo troca pela dele). A de Batismo
  // aqui criava turma no curso "Batismo" de qualquer ministério.
  MinistryTabKeys.alunos: MinistryTabSlot(
    defaultLabel: 'Turmas',
    builder: (_) => FormacaoTurmasTab(ministryId: ministryId),
  ),
  MinistryTabKeys.checklist: MinistryTabSlot(
    defaultLabel: 'Checklist',
    builder: (_) => BatismoChecklistTab(ministryId: ministryId),
  ),
  MinistryTabKeys.whatsapp: MinistryTabSlot(
    defaultLabel: 'WhatsApp',
    builder: (_) => MinistryWhatsAppTab(ministryId: ministryId),
  ),
  MinistryTabKeys.relatorios: MinistryTabSlot(
    defaultLabel: 'Relatórios',
    builder: (_) => MinistryReportsTab(ministryId: ministryId),
  ),
};
