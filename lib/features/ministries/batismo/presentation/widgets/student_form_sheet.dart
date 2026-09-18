import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/baptism_repository.dart';
import '../../domain/models/baptism_student.dart';
import '../../domain/models/baptism_turma.dart';

/// Abre o formulário de aluno (cadastro ou edição) numa folha inferior.
///
/// Devolve `true` quando algo foi gravado — quem chamou invalida as listas.
Future<bool> showStudentFormSheet({
  required BuildContext context,
  required List<BaptismTurma> turmas,
  BaptismStudent? student,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StudentFormSheet(
      turmas: turmas,
      student: student,
    ),
  );
  return saved ?? false;
}

class _StudentFormSheet extends ConsumerStatefulWidget {
  final List<BaptismTurma> turmas;
  final BaptismStudent? student;

  const _StudentFormSheet({
    required this.turmas,
    this.student,
  });

  @override
  ConsumerState<_StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends ConsumerState<_StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;

  String? _turmaId;
  DateTime? _birthDate;
  late BaptismStudentStatus _status;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _name = TextEditingController(text: s?.fullName ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _birthDate = s?.birthDate;
    _status = s?.status ?? BaptismStudentStatus.ativo;
    // Numa turma só, ela já vem escolhida — é o caso normal da igreja que
    // roda uma turma por vez.
    _turmaId = s?.turmaId ??
        (widget.turmas.length == 1 ? widget.turmas.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final turmaId = _turmaId;
    if (turmaId == null) {
      setState(() => _error = 'Escolha a turma do aluno.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(baptismRepositoryProvider);
      final existing = widget.student;

      if (existing == null) {
        await repo.createStudent(
          BaptismStudent(
            id: '',
            tenantId: '',
            turmaId: turmaId,
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text,
            birthDate: _birthDate,
            status: _status,
            source: BaptismStudentSource.manual,
            notes: _notes.text,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.updateStudent(
          existing.copyWith(
            turmaId: turmaId,
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text,
            birthDate: _birthDate,
            clearBirthDate: _birthDate == null,
            status: _status,
            notes: _notes.text,
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

  /// A negativa da policy chega como erro cru do PostgREST. Sem tradução, o
  /// usuário lê "new row violates row-level security policy" e abre chamado.
  String _humanError(Object e) {
    final text = '$e';
    if (text.contains('row-level security') || text.contains('42501')) {
      return 'Você não tem permissão para gravar alunos neste ministério.';
    }
    if (text.contains('baptism_student_unique_member_per_turma')) {
      return 'Esta pessoa já está nesta turma.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                  _isEdit ? 'Editar aluno' : 'Novo aluno',
                  style: CommunityDesign.titleStyle(context)
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o nome do aluno'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _turmaId,
                  decoration: const InputDecoration(labelText: 'Turma *'),
                  items: [
                    for (final t in widget.turmas)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _turmaId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '(11) 91234-5678',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de nascimento',
                      suffixIcon: _birthDate == null
                          ? const Icon(Icons.calendar_today, size: 18)
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _birthDate = null),
                            ),
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Não informada'
                          : _formatDate(_birthDate!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BaptismStudentStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in BaptismStudentStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? BaptismStudentStatus.ativo),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isEdit ? 'Salvar' : 'Cadastrar'),
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
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
