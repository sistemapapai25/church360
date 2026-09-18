import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/widgets/app_filter_bar.dart';
import '../../../data/baptism_repository.dart';
import '../../../domain/baptism_checklist_progress.dart';
import '../../../domain/models/baptism_checklist.dart';
import '../../../domain/models/baptism_student.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';
import '../../widgets/baptism_checklist_items_sheet.dart';

/// Aba Checklist do workspace do Batismo.
///
/// Duas coisas em uma tela: o catálogo de etapas do curso (atrás do botão
/// "Etapas") e o que cada aluno já cumpriu (a lista).
///
/// Marcar e desmarcar pedem `baptism.edit` — as duas, de propósito.
/// Desmarcar apaga a linha no banco, mas é a outra metade de marcar; se
/// pedisse `baptism.delete`, quem tem edit marcaria sem conseguir
/// desfazer.
class BatismoChecklistTab extends ConsumerStatefulWidget {
  final String ministryId;

  const BatismoChecklistTab({super.key, required this.ministryId});

  @override
  ConsumerState<BatismoChecklistTab> createState() =>
      _BatismoChecklistTabState();
}

class _BatismoChecklistTabState extends ConsumerState<BatismoChecklistTab> {
  static const _allTurmas = 'all';

  final _search = TextEditingController();
  String _query = '';
  String _turmaId = _allTurmas;

  /// Só pendentes: esconde quem já cumpriu tudo. É o filtro que a tela
  /// realmente usa no dia a dia — "quem ainda falta".
  bool _onlyPending = false;

  /// Alunos com a lista de etapas aberta.
  final _expanded = <String>{};

  /// Marcações em voo, por "studentId:itemId", para travar só a etapa
  /// tocada em vez da tela inteira.
  final _busy = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Filtro (puro, para poder ser testado)
  // -------------------------------------------------------------------

  List<BaptismStudentProgress> applyFilters(
    List<BaptismStudentProgress> progress,
  ) {
    final query = _query.trim().toLowerCase();

    return progress.where((p) {
      if (_turmaId != _allTurmas && p.student.turmaId != _turmaId) return false;
      // Aluno sem nenhuma etapa aplicável não conta como pendente: não há
      // o que cumprir. Sem isso, um ministério de catálogo vazio mostraria
      // todo mundo como pendente.
      if (_onlyPending && (p.total == 0 || p.isComplete)) return false;
      if (query.isEmpty) return true;
      return p.student.fullName.toLowerCase().contains(query);
    }).toList();
  }

  // -------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------

  Future<void> _toggle({
    required BaptismStudent student,
    required BaptismChecklistItem item,
    required bool done,
  }) async {
    final key = '${student.id}:${item.id}';
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));

    final repo = ref.read(baptismRepositoryProvider);
    try {
      if (done) {
        await repo.unmarkChecklistItem(studentId: student.id, itemId: item.id);
      } else {
        await repo.markChecklistItems([
          (studentId: student.id, itemId: item.id),
        ]);
      }
      if (!mounted) return;
      // Realtime não é habilitado por migration neste banco: sem este
      // invalidate a tela ficaria mostrando o estado anterior até alguém
      // trocar de aba.
      invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Marca de uma vez tudo o que falta para um aluno.
  ///
  /// Um upsert só, com `onConflict` — as etapas já marcadas entram no lote
  /// e são ignoradas em vez de estourar 409.
  Future<void> _completeAll(BaptismStudentProgress progress) async {
    final pending = [
      for (final item in progress.items)
        if (!progress.isDone(item))
          (studentId: progress.student.id, itemId: item.id),
    ];
    if (pending.isEmpty) return;

    try {
      await ref.read(baptismRepositoryProvider).markChecklistItems(pending);
      if (!mounted) return;
      invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  Future<void> _openItems({
    required List<BaptismTurma> turmas,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) async {
    final changed = await showBaptismChecklistItemsSheet(
      context: context,
      ministryId: widget.ministryId,
      turmas: turmas,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    if (changed && mounted) invalidateBaptismData(ref, widget.ministryId);
  }

  Future<T?> _pickOption<T>({
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: CommunityDesign.titleStyle(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                title: Text(option.$2),
                trailing: option.$1 == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
  }

  String _turmaLabel(List<BaptismTurma> turmas) {
    if (_turmaId == _allTurmas) return 'Todas as turmas';
    for (final t in turmas) {
      if (t.id == _turmaId) return t.name;
    }
    return 'Turma';
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progressAsync =
        ref.watch(baptismChecklistProgressProvider(widget.ministryId));
    // O estado vazio pergunta ao CATÁLOGO, não aos alunos visíveis. Um
    // ministério com etapas só de uma turma, olhando alunos de outra,
    // diria "nenhuma etapa cadastrada" e mandaria cadastrar de novo o que
    // já existe.
    final hasActiveItems = ref
        .watch(baptismChecklistItemsProvider(widget.ministryId))
        .maybeWhen(
          data: (items) => items.any((i) => i.isActive),
          orElse: () => false,
        );
    final turmasAsync = ref.watch(baptismTurmasProvider(widget.ministryId));
    final turmas = turmasAsync.maybeWhen(
      data: (t) => t,
      orElse: () => const <BaptismTurma>[],
    );

    bool can(BaptismWriteAction action) => ref
        .watch(
          baptismCanWriteProvider(
            (ministryId: widget.ministryId, action: action),
          ),
        )
        .maybeWhen(data: (v) => v, orElse: () => false);

    final canCreate = can(BaptismWriteAction.create);
    final canEdit = can(BaptismWriteAction.edit);
    final canDelete = can(BaptismWriteAction.delete);

    return progressAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ChecklistError(
        message: '$error',
        onRetry: () => invalidateBaptismData(ref, widget.ministryId),
      ),
      data: (progress) {
        final visible = applyFilters(progress);

        return RefreshIndicator(
          onRefresh: () async {
            invalidateBaptismData(ref, widget.ministryId);
            await ref.read(
              baptismChecklistProgressProvider(widget.ministryId).future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar aluno...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  AppFilterButton(
                    label: _turmaLabel(turmas),
                    icon: Icons.groups_2_outlined,
                    active: _turmaId != _allTurmas,
                    onTap: () async {
                      final picked = await _pickOption<String>(
                        title: 'Turma',
                        current: _turmaId,
                        options: [
                          (_allTurmas, 'Todas as turmas'),
                          for (final t in turmas) (t.id, t.name),
                        ],
                      );
                      if (picked != null) setState(() => _turmaId = picked);
                    },
                  ),
                  AppFilterButton(
                    label: _onlyPending ? 'Só pendentes' : 'Todos',
                    icon: Icons.pending_actions_outlined,
                    active: _onlyPending,
                    onTap: () => setState(() => _onlyPending = !_onlyPending),
                  ),
                ],
                secondaryActions: [
                  AppFilterAction(
                    label: 'Etapas do curso',
                    icon: Icons.checklist_outlined,
                    onPressed: () => _openItems(
                      turmas: turmas,
                      canCreate: canCreate,
                      canEdit: canEdit,
                      canDelete: canDelete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasActiveItems)
                _EmptyState(
                  icon: Icons.checklist_outlined,
                  title: 'Nenhuma etapa cadastrada',
                  message: canCreate
                      ? 'O checklist é o processo do seu curso — entrevista, '
                            'aulas, entrega de material. Cadastre as etapas em '
                            '"Etapas do curso" e elas passam a valer para os '
                            'alunos.'
                      : 'Ainda não há etapas cadastradas neste ministério.',
                )
              else if (visible.isEmpty)
                _EmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'Nenhum aluno neste filtro',
                  message: _onlyPending
                      ? 'Ninguém com etapa pendente no filtro atual.'
                      : 'Nenhum aluno bate com a busca.',
                )
              else
                for (final p in visible)
                  _StudentChecklistCard(
                    progress: p,
                    expanded: _expanded.contains(p.student.id),
                    canEdit: canEdit,
                    busyKeys: _busy,
                    onToggleExpanded: () => setState(() {
                      if (!_expanded.remove(p.student.id)) {
                        _expanded.add(p.student.id);
                      }
                    }),
                    onToggleItem: (item, done) => _toggle(
                      student: p.student,
                      item: item,
                      done: done,
                    ),
                    onCompleteAll: () => _completeAll(p),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Um aluno, com a barra de progresso e as etapas dele.
class _StudentChecklistCard extends StatelessWidget {
  final BaptismStudentProgress progress;
  final bool expanded;
  final bool canEdit;
  final Set<String> busyKeys;
  final VoidCallback onToggleExpanded;
  final void Function(BaptismChecklistItem item, bool done) onToggleItem;
  final VoidCallback onCompleteAll;

  const _StudentChecklistCard({
    required this.progress,
    required this.expanded,
    required this.canEdit,
    required this.busyKeys,
    required this.onToggleExpanded,
    required this.onToggleItem,
    required this.onCompleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.student.fullName,
                          style: CommunityDesign.titleStyle(context)
                              .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.ratio,
                                  minHeight: 6,
                                  backgroundColor: theme.dividerColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${progress.done}/${progress.total}',
                              style: CommunityDesign.metaStyle(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: theme.dividerColor),
            if (progress.items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(
                  'Nenhuma etapa se aplica à turma deste aluno.',
                  style: CommunityDesign.metaStyle(context),
                ),
              )
            else ...[
              for (final item in progress.items)
                _ItemTile(
                  item: item,
                  done: progress.isDone(item),
                  canEdit: canEdit,
                  busy: busyKeys.contains('${progress.student.id}:${item.id}'),
                  onToggle: () => onToggleItem(item, progress.isDone(item)),
                ),
              if (canEdit && !progress.isComplete)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                    child: TextButton.icon(
                      onPressed: onCompleteAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Marcar tudo'),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final BaptismChecklistItem item;
  final bool done;
  final bool canEdit;
  final bool busy;
  final VoidCallback onToggle;

  const _ItemTile({
    required this.item,
    required this.done,
    required this.canEdit,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // Sem baptism.edit o checkbox fica desabilitado em vez de sumir: a
      // pessoa precisa enxergar o que já foi cumprido mesmo sem poder
      // mexer.
      onTap: canEdit && !busy ? onToggle : null,
      leading: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              done ? Icons.check_box : Icons.check_box_outline_blank,
              color: done
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).hintColor,
            ),
      title: Text(
        item.title,
        style: CommunityDesign.contentStyle(context).copyWith(fontSize: 14),
      ),
      subtitle: (item.description ?? '').trim().isEmpty
          ? null
          : Text(
              item.description!.trim(),
              style: CommunityDesign.metaStyle(context),
            ),
      trailing: item.turmaId != null
          ? Icon(
              Icons.push_pin_outlined,
              size: 16,
              color: Theme.of(context).hintColor,
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CommunityDesign.titleStyle(context)
                .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
        ],
      ),
    );
  }
}

class _ChecklistError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChecklistError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar o checklist.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context)
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
