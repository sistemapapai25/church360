import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../../../events/domain/models/event.dart';
import '../../../../events/presentation/providers/events_provider.dart';
import '../../data/baptism_repository.dart';
import '../../domain/models/baptism_turma.dart';
import '../providers/baptism_providers.dart';

/// Abre o gerenciador de turmas do ministério.
///
/// Devolve `true` se alguma turma foi criada, alterada ou apagada — quem
/// chamou invalida as listas.
Future<bool> showBaptismTurmasSheet({
  required BuildContext context,
  required String ministryId,
  required bool canCreate,
  required bool canEdit,
  required bool canDelete,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TurmasSheet(
      ministryId: ministryId,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
    ),
  );
  return changed ?? false;
}

class _TurmasSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const _TurmasSheet({
    required this.ministryId,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  ConsumerState<_TurmasSheet> createState() => _TurmasSheetState();
}

class _TurmasSheetState extends ConsumerState<_TurmasSheet> {
  bool _changed = false;

  Future<void> _openForm({BaptismTurma? turma}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TurmaFormSheet(
        ministryId: widget.ministryId,
        turma: turma,
      ),
    );
    if (saved == true) {
      _changed = true;
      ref.invalidate(baptismTurmasProvider(widget.ministryId));
      ref.invalidate(baptismStudentsProvider(widget.ministryId));
    }
  }

  Future<void> _confirmDelete(BaptismTurma turma, int studentCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${turma.name}"?'),
        // O CASCADE da FK leva os alunos junto. Omitir isso aqui faria a
        // igreja perder cadastro sem nunca ter lido um aviso.
        content: Text(
          studentCount == 0
              ? 'A turma será apagada. Esta ação não pode ser desfeita.'
              : 'Os $studentCount alunos desta turma serão apagados junto. '
                  'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(baptismRepositoryProvider).deleteTurma(turma.id);
      _changed = true;
      ref.invalidate(baptismTurmasProvider(widget.ministryId));
      ref.invalidate(baptismStudentsProvider(widget.ministryId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(baptismTurmasProvider(widget.ministryId));
    final studentsAsync = ref.watch(baptismStudentsProvider(widget.ministryId));

    final counts = <String, int>{};
    studentsAsync.whenData((students) {
      for (final s in students) {
        counts[s.turmaId] = (counts[s.turmaId] ?? 0) + 1;
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedForeground.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Turmas',
                    style: CommunityDesign.titleStyle(context)
                        .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canCreate)
                  TextButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova turma'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada turma aponta o evento da agenda que é o batismo dela.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: turmasAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível carregar as turmas.\n$e',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
                data: (turmas) {
                  if (turmas.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Nenhuma turma ainda. Crie a primeira para poder '
                        'cadastrar alunos.',
                        textAlign: TextAlign.center,
                        style: CommunityDesign.metaStyle(context),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: turmas.length,
                    itemBuilder: (context, i) {
                      final t = turmas[i];
                      return _TurmaTile(
                        turma: t,
                        studentCount: counts[t.id] ?? 0,
                        onEdit:
                            widget.canEdit ? () => _openForm(turma: t) : null,
                        onDelete: widget.canDelete
                            ? () => _confirmDelete(t, counts[t.id] ?? 0)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_changed),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurmaTile extends StatelessWidget {
  final BaptismTurma turma;
  final int studentCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TurmaTile({
    required this.turma,
    required this.studentCount,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;

    final event = turma.eventName;
    final period = _periodLabel(turma);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CommunityDesign.cardSurfaceColor(Theme.of(context).colorScheme),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  turma.name,
                  style: CommunityDesign.titleStyle(context)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Editar turma',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Excluir turma',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: turma.status.label,
                tone: turma.status == BaptismTurmaStatus.ativa
                    ? AppStatusTone.active
                    : (turma.status == BaptismTurmaStatus.encerrada
                        ? AppStatusTone.done
                        : AppStatusTone.dropped),
              ),
              Text(
                '$studentCount ${studentCount == 1 ? 'aluno' : 'alunos'}',
                style: CommunityDesign.metaStyle(context),
              ),
              if (period != null)
                Text(period, style: CommunityDesign.metaStyle(context)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                event == null ? Icons.event_busy_outlined : Icons.event,
                size: 14,
                color: dark
                    ? AppTheme.darkMutedForeground
                    : AppTheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event ?? 'Sem evento de batismo vinculado',
                  style: CommunityDesign.metaStyle(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _periodLabel(BaptismTurma turma) {
    final start = turma.startDate;
    final end = turma.endDate;
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${_fmt(start)} a ${_fmt(end)}';
    }
    return start != null ? 'A partir de ${_fmt(start)}' : 'Até ${_fmt(end!)}';
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Formulário de turma, com o seletor de evento da agenda.
class _TurmaFormSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final BaptismTurma? turma;

  const _TurmaFormSheet({required this.ministryId, this.turma});

  @override
  ConsumerState<_TurmaFormSheet> createState() => _TurmaFormSheetState();
}

class _TurmaFormSheetState extends ConsumerState<_TurmaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;

  String? _eventId;
  DateTime? _startDate;
  DateTime? _endDate;
  late BaptismTurmaStatus _status;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.turma != null;

  @override
  void initState() {
    super.initState();
    final t = widget.turma;
    _name = TextEditingController(text: t?.name ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _eventId = t?.eventId;
    _startDate = t?.startDate;
    _endDate = t?.endDate;
    _status = t?.status ?? BaptismTurmaStatus.ativa;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: start ? 'Início das aulas' : 'Fim das aulas',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _startDate;
    final end = _endDate;
    // Mesmo CHECK que existe no banco (`baptism_turma_period_ordered`).
    // Validar aqui transforma um 23514 cru numa frase.
    if (start != null && end != null && end.isBefore(start)) {
      setState(() => _error = 'O fim das aulas não pode ser antes do início.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(baptismRepositoryProvider);
      final existing = widget.turma;

      if (existing == null) {
        await repo.createTurma(
          BaptismTurma(
            id: '',
            tenantId: '',
            ministryId: widget.ministryId,
            eventId: _eventId,
            name: _name.text,
            description: _description.text,
            startDate: _startDate,
            endDate: _endDate,
            status: _status,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.updateTurma(
          existing.copyWith(
            name: _name.text,
            description: _description.text,
            eventId: _eventId,
            clearEventId: _eventId == null,
            startDate: _startDate,
            clearStartDate: _startDate == null,
            endDate: _endDate,
            clearEndDate: _endDate == null,
            status: _status,
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _humanError(e);
        });
      }
    }
  }

  String _humanError(Object e) {
    final text = '$e';
    if (text.contains('row-level security') || text.contains('42501')) {
      return 'Você não tem permissão para gravar turmas neste ministério.';
    }
    if (text.contains('baptism_turma_unique_name_per_ministry')) {
      return 'Já existe uma turma com este nome neste ministério.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final eventsAsync = ref.watch(allEventsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.mutedForeground.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEdit ? 'Editar turma' : 'Nova turma',
                  style: CommunityDesign.titleStyle(context)
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome da turma *',
                    hintText: 'Sexta 19h',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o nome da turma'
                      : null,
                ),
                const SizedBox(height: 12),
                // Seletor de EVENTO, não filtro por tipo: o catálogo
                // `event_type` é por igreja, então um filtro fixo por rótulo
                // não acharia o evento da segunda igreja (D2 revista).
                eventsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Não foi possível carregar os eventos da agenda.',
                    style: CommunityDesign.metaStyle(context),
                  ),
                  data: (events) => DropdownButtonFormField<String?>(
                    initialValue: _eventId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Evento do batismo',
                      helperText: 'Pode ficar em branco até a data ser marcada',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem evento vinculado'),
                      ),
                      for (final e in _sortedEvents(events))
                        DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(
                            '${e.name} · ${_fmtDate(e.startDate)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _eventId = v),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Início das aulas',
                        value: _startDate,
                        onTap: () => _pickDate(start: true),
                        onClear: () => setState(() => _startDate = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Fim das aulas',
                        value: _endDate,
                        onTap: () => _pickDate(start: false),
                        onClear: () => setState(() => _endDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BaptismTurmaStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in BaptismTurmaStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? BaptismTurmaStatus.ativa),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isEdit ? 'Salvar' : 'Criar turma'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mais recentes primeiro: o evento que interessa é sempre o próximo, e a
  /// agenda da igreja tem anos de histórico.
  static List<Event> _sortedEvents(List<Event> events) {
    final sorted = [...events]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted;
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 16)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? 'Não definida' : _fmtDate(value!),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}
