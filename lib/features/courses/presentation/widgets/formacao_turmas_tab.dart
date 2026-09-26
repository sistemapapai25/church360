import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import 'course_turmas_section.dart';

/// Filtro por origem da aba Turmas.
enum TurmaOriginFilter {
  all('Todas as origens'),
  baptism('Batismo'),
  study('Grupos de estudo');

  final String label;
  const TurmaOriginFilter(this.label);

  bool accepts(CourseTurma turma) => switch (this) {
    TurmaOriginFilter.all => true,
    TurmaOriginFilter.baptism => turma.isBaptismTurma,
    TurmaOriginFilter.study => !turma.isBaptismTurma,
  };
}

/// Aba Turmas de Formação — a antiga central de Grupos de Estudo (Frente 5).
///
/// Tela global, sem `MinistryWorkspaceShell`. Lista o que a RLS de
/// `study_groups` deixa ver: liderança vê as turmas do ministério, aluno vê
/// a dele, qualquer um vê grupo público nativo. O card só navega para a
/// turma — excluir ou encerrar turma de Batismo pertence ao módulo de
/// origem, e nenhum dado pessoal entra na listagem.
class FormacaoTurmasTab extends ConsumerStatefulWidget {
  const FormacaoTurmasTab({super.key});

  @override
  ConsumerState<FormacaoTurmasTab> createState() => _FormacaoTurmasTabState();
}

class _FormacaoTurmasTabState extends ConsumerState<FormacaoTurmasTab> {
  final _search = TextEditingController();
  String _query = '';
  TurmaOriginFilter _origin = TurmaOriginFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickOrigin() async {
    final picked = await showModalBottomSheet<TurmaOriginFilter>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in TurmaOriginFilter.values)
              ListTile(
                title: Text(option.label),
                trailing: option == _origin ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _origin = picked);
  }

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(formacaoTurmasProvider);
    // Nome do curso e do ministério no card: turmas homônimas de
    // ministérios diferentes precisam se distinguir. Melhor esforço — se a
    // RLS esconder, o card sai sem a linha.
    final courses = ref.watch(allCoursesProvider).valueOrNull ?? const [];
    final ministries = ref.watch(allMinistriesProvider).valueOrNull ?? const [];
    final courseTitle = {for (final c in courses) c.id: c.title};
    final ministryName = {for (final m in ministries) m.id: m.name};
    final canCreate =
        ref
            .watch(currentUserHasPermissionProvider('study_groups.create'))
            .valueOrNull ??
        false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: AppFilterBar(
            searchController: _search,
            searchHint: 'Buscar turma...',
            onSearchChanged: (v) => setState(() => _query = v.trim()),
            filters: [
              AppFilterButton(
                label: _origin.label,
                icon: Icons.filter_list,
                active: _origin != TurmaOriginFilter.all,
                onTap: _pickOrigin,
              ),
            ],
            primaryAction: canCreate
                ? AppFilterAction(
                    label: 'Nova turma',
                    icon: Icons.add,
                    onPressed: () => context.push('/study-groups/new'),
                  )
                : null,
          ),
        ),
        Expanded(
          child: turmasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _Message(
              icon: AppIcons.error,
              text: 'Não foi possível carregar as turmas.',
              action: TextButton(
                onPressed: () => ref.invalidate(formacaoTurmasProvider),
                child: const Text('Tentar de novo'),
              ),
            ),
            data: (all) {
              final needle = _query.toLowerCase();
              final turmas = [
                for (final t in all)
                  if (_origin.accepts(t) &&
                      (needle.isEmpty || t.name.toLowerCase().contains(needle)))
                    t,
              ];
              if (turmas.isEmpty) {
                return _Message(
                  icon: AppIcons.study,
                  text: all.isEmpty
                      ? 'Nenhuma turma para você por aqui ainda.'
                      : 'Nenhuma turma com esse filtro.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(formacaoTurmasProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: turmas.length,
                  itemBuilder: (context, index) {
                    final turma = turmas[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FormacaoTurmaCard(
                        turma: turma,
                        courseTitle: courseTitle[turma.courseId],
                        ministryName: ministryName[turma.ministryId],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Card da aba Turmas: só navega. Sem menu, sem excluir, sem encerrar.
class FormacaoTurmaCard extends StatelessWidget {
  final CourseTurma turma;
  final String? courseTitle;
  final String? ministryName;

  const FormacaoTurmaCard({
    super.key,
    required this.turma,
    this.courseTitle,
    this.ministryName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = courseTurmaStatusTone(turma.status);
    final toneColor = tone.color(context);
    final dates = turma.periodLabel;
    final origin = turma.isBaptismTurma ? 'Batismo' : 'Grupo de estudo';
    final context2 = [
      if (courseTitle != null && courseTitle!.isNotEmpty) courseTitle!,
      if (ministryName != null && ministryName!.isNotEmpty) ministryName!,
    ].join(' · ');

    return GlassCard(
      onTap: () => context.push(turma.route),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: toneColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppIcons.study, size: 20, color: toneColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turma.name,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  context2.isEmpty ? origin : '$origin · $context2',
                  style: CommunityDesign.metaStyle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dates != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        AppIcons.calendar,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dates,
                          style: CommunityDesign.metaStyle(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: turma.status.displayName, tone: tone),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: CommunityDesign.contentStyle(context),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
