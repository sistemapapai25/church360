import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../data/baptism_repository.dart';
import '../../domain/models/baptism_checklist.dart';
import '../../domain/models/baptism_turma.dart';
import '../providers/baptism_providers.dart';

/// Abre o gerenciador de etapas do checklist.
///
/// Devolve `true` se alguma etapa foi criada, alterada ou apagada — quem
/// chamou invalida as listas.
Future<bool> showBaptismChecklistItemsSheet({
  required BuildContext context,
  required String ministryId,
  required List<BaptismTurma> turmas,
  required bool canCreate,
  required bool canEdit,
  required bool canDelete,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ItemsSheet(
      ministryId: ministryId,
      turmas: turmas,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
    ),
  );
  return changed ?? false;
}

/// Abre direto o formulário de etapa, sem passar pelo gerenciador.
///
/// Serve ao botão "Adicionar etapa" do catálogo que a aba Checklist mostra
/// no topo: quem já está olhando a lista de etapas não precisa abrir uma
/// segunda lista de etapas para chegar ao mesmo formulário.
///
/// Devolve `true` se a etapa foi salva — quem chamou invalida as listas.
Future<bool> showBaptismChecklistItemFormSheet({
  required BuildContext context,
  required String ministryId,
  required List<BaptismTurma> turmas,
  BaptismChecklistItem? item,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ItemFormSheet(
      ministryId: ministryId,
      turmas: turmas,
      item: item,
    ),
  );
  return saved ?? false;
}

class _ItemsSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final List<BaptismTurma> turmas;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const _ItemsSheet({
    required this.ministryId,
    required this.turmas,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  ConsumerState<_ItemsSheet> createState() => _ItemsSheetState();
}

class _ItemsSheetState extends ConsumerState<_ItemsSheet> {
  bool _changed = false;

  Future<void> _openForm({BaptismChecklistItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemFormSheet(
        ministryId: widget.ministryId,
        turmas: widget.turmas,
        item: item,
      ),
    );
    if (saved == true) {
      _changed = true;
      ref.invalidate(baptismChecklistItemsProvider(widget.ministryId));
      ref.invalidate(baptismChecklistProgressProvider(widget.ministryId));
      ref.invalidate(baptismChecklistTallyProvider(widget.ministryId));
    }
  }

  /// Liga/desliga a etapa sem apagá-la.
  ///
  /// É o caminho recomendado: desligar tira a etapa da tela e do
  /// denominador do progresso, mas preserva quem já a cumpriu. Apagar leva
  /// as marcações junto e não tem volta.
  Future<void> _toggleActive(BaptismChecklistItem item) async {
    try {
      await ref
          .read(baptismRepositoryProvider)
          .updateChecklistItem(item.copyWith(isActive: !item.isActive));
      _changed = true;
      ref.invalidate(baptismChecklistItemsProvider(widget.ministryId));
      ref.invalidate(baptismChecklistProgressProvider(widget.ministryId));
      ref.invalidate(baptismChecklistTallyProvider(widget.ministryId));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _confirmDelete(BaptismChecklistItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${item.title}"?'),
        // O CASCADE de baptism_student_checklist.item_id leva as marcações
        // junto. Sem este aviso, quem apagasse uma etapa para "limpar a
        // lista" perderia o histórico de quem já a tinha cumprido, sem
        // nenhum sinal na tela.
        content: const Text(
          'Todas as marcações desta etapa serão apagadas junto, para todos '
          'os alunos. Para tirar a etapa da lista sem perder o histórico, '
          'desligue-a em vez de excluir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(baptismRepositoryProvider).deleteChecklistItem(item.id);
      _changed = true;
      ref.invalidate(baptismChecklistItemsProvider(widget.ministryId));
      ref.invalidate(baptismChecklistEntriesProvider(widget.ministryId));
      ref.invalidate(baptismChecklistProgressProvider(widget.ministryId));
      ref.invalidate(baptismChecklistTallyProvider(widget.ministryId));
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível salvar: $error')),
    );
  }

  String _turmaName(String turmaId) {
    for (final t in widget.turmas) {
      if (t.id == turmaId) return t.name;
    }
    return 'turma removida';
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(baptismChecklistItemsProvider(widget.ministryId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Etapas do curso',
                        style: CommunityDesign.titleStyle(context)
                            .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.canCreate)
                      TextButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nova etapa'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Não foi possível carregar: $error'),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            widget.canCreate
                                ? 'Nenhuma etapa cadastrada ainda.\nCrie a primeira em "Nova etapa".'
                                : 'Nenhuma etapa cadastrada ainda.',
                            textAlign: TextAlign.center,
                            style: CommunityDesign.metaStyle(context),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ItemRow(
                          item: item,
                          scopeLabel: item.turmaId == null
                              ? 'Todas as turmas'
                              : _turmaName(item.turmaId!),
                          canEdit: widget.canEdit,
                          canDelete: widget.canDelete,
                          onEdit: () => _openForm(item: item),
                          onToggleActive: () => _toggleActive(item),
                          onDelete: () => _confirmDelete(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final BaptismChecklistItem item;
  final String scopeLabel;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.scopeLabel,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: item.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                if ((item.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!.trim(),
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusBadge(
                      label: scopeLabel,
                      tone: AppStatusTone.active,
                      icon: Icons.groups_2_outlined,
                    ),
                    if (!item.isActive)
                      const StatusBadge.dropped(
                        label: 'Desligada',
                        icon: Icons.visibility_off_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                if (canEdit)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.isActive ? 'Desligar' : 'Religar'),
                  ),
                if (canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'toggle':
                    onToggleActive();
                  case 'delete':
                    onDelete();
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Formulário de uma etapa.
class _ItemFormSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final List<BaptismTurma> turmas;
  final BaptismChecklistItem? item;

  const _ItemFormSheet({
    required this.ministryId,
    required this.turmas,
    this.item,
  });

  @override
  ConsumerState<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _order;

  /// Nulo = etapa de todas as turmas.
  String? _turmaId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _order = TextEditingController(text: '${item?.orderIndex ?? 0}');
    _turmaId = item?.turmaId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(baptismRepositoryProvider);
    final existing = widget.item;

    try {
      if (existing == null) {
        await repo.createChecklistItem(
          BaptismChecklistItem(
            // O banco gera os três: id por DEFAULT, tenant_id por
            // current_tenant_id() e created_at por now(). O que vai no
            // INSERT é só o que toWriteJson() monta.
            id: '',
            tenantId: '',
            ministryId: widget.ministryId,
            turmaId: _turmaId,
            title: _title.text,
            description: _description.text,
            orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.updateChecklistItem(
          existing.copyWith(
            title: _title.text,
            description: _description.text,
            clearDescription: _description.text.trim().isEmpty,
            orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            turmaId: _turmaId,
            clearTurmaId: _turmaId == null,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // 23505 é a UNIQUE parcial: já existe etapa com este título no
            // mesmo alcance. Mostrar o código cru não ajudaria ninguém.
            '$error'.contains('23505')
                ? 'Já existe uma etapa com este nome neste alcance.'
                : 'Não foi possível salvar: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Nova etapa' : 'Editar etapa',
                style: CommunityDesign.titleStyle(context)
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome da etapa',
                  hintText: 'Ex.: Entrevista pastoral',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Dê um nome para a etapa'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _turmaId,
                decoration: const InputDecoration(labelText: 'Alcance'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as turmas'),
                  ),
                  for (final t in widget.turmas)
                    DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text('Só a turma ${t.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _turmaId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ordem',
                  helperText: 'Menor aparece primeiro. Empate cai no nome.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
