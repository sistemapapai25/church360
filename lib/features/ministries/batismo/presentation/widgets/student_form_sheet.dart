import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/pearl_button.dart';
import '../../data/baptism_repository.dart';
import '../../domain/models/baptism_member_suggestion.dart';
import '../../domain/models/baptism_student.dart';
import '../../domain/models/baptism_turma.dart';

/// Abre o formulário de aluno (cadastro ou edição) numa folha inferior.
///
/// Devolve `true` quando algo foi gravado — quem chamou invalida as listas.
Future<bool> showStudentFormSheet({
  required BuildContext context,
  required String ministryId,
  required List<BaptismTurma> turmas,
  BaptismStudent? student,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Colors.transparent,
    builder: (_) => _StudentFormSheet(
      ministryId: ministryId,
      turmas: turmas,
      student: student,
    ),
  );
  return saved ?? false;
}

class _StudentFormSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final List<BaptismTurma> turmas;
  final BaptismStudent? student;

  const _StudentFormSheet({
    required this.ministryId,
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

  /// Ficha de membro vinculada, quando o aluno veio da busca. Vai para
  /// `baptism_student.user_id` — a FK é `ON DELETE SET NULL`, e por isso o
  /// nome continua gravado na linha do aluno mesmo se a ficha sumir.
  String? _memberId;
  String? _memberName;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<BaptismMemberSuggestion> _suggestions = const [];
  bool _searching = false;
  String? _searchError;
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
    _turmaId =
        s?.turmaId ??
        (widget.turmas.length == 1 ? widget.turmas.first.id : null);
    _memberId = s?.userId;
    // Na edição não há de onde tirar o nome da ficha sem uma consulta a
    // mais; o nome do aluno serve de legenda, e é o que a pessoa reconhece.
    _memberName = s?.userId == null ? null : s?.fullName;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Busca com 350ms de espera entre teclas. Sem isso seria uma ida ao
  /// banco por caractere digitado.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final term = value.trim();

    if (term.length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }

    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(term);
    });
  }

  Future<void> _runSearch(String term) async {
    try {
      final repo = ref.read(baptismRepositoryProvider);
      final result = await repo.searchMembers(
        ministryId: widget.ministryId,
        query: term,
      );
      if (!mounted) return;
      // A resposta pode chegar depois de a pessoa ter limpado o campo.
      if (_searchController.text.trim() != term) return;
      setState(() {
        _suggestions = result;
        _searching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = 'Não foi possível buscar membros agora.';
      });
    }
  }

  /// Preenche o formulário com a ficha escolhida.
  ///
  /// Os campos seguem EDITÁVEIS: o cadastro de membros é magro (telefone
  /// em 21 das 199 fichas) e quem está com a pessoa na frente costuma ter
  /// o dado mais novo. O que for corrigido aqui fica no aluno e NÃO volta
  /// para a ficha do membro.
  void _applyMember(BaptismMemberSuggestion m) {
    setState(() {
      _memberId = m.id;
      _memberName = m.displayName;
      _name.text = m.displayName;
      if ((m.phone ?? '').trim().isNotEmpty) _phone.text = m.phone!.trim();
      if ((m.email ?? '').trim().isNotEmpty) _email.text = m.email!.trim();
      _birthDate ??= m.birthdate;
      _suggestions = const [];
      _searchController.clear();
      _searchError = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _clearMember() {
    setState(() {
      _memberId = null;
      _memberName = null;
    });
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
            userId: _memberId,
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
            userId: _memberId,
            clearUserId: _memberId == null,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.dialogRadius),
          ),
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
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                // A busca vem ANTES do nome de propósito: o caminho comum é
                // "a pessoa já é da casa", e achar a ficha preenche o resto
                // sozinho. Quem é visitante ignora o campo e digita o nome.
                _MemberSearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  searching: _searching,
                  error: _searchError,
                  suggestions: _suggestions,
                  onPick: _applyMember,
                  linkedName: _memberName,
                  onUnlink: _clearMember,
                ),
                const SizedBox(height: 12),
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
                  isExpanded: true,
                  initialValue: _turmaId,
                  decoration: const InputDecoration(labelText: 'Turma *'),
                  items: [
                    for (final t in widget.turmas)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
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
                          ? const Icon(AppIcons.calendar, size: 18)
                          : IconButton(
                              icon: const Icon(AppIcons.close, size: 18),
                              tooltip: 'Limpar data de nascimento',
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
                      child: PearlButton(
                        color: AppTheme.primary,
                        width: double.infinity,
                        height: 48,
                        onTap: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryForeground,
                                ),
                              )
                            : Text(
                                _isEdit ? 'Salvar' : 'Cadastrar',
                                style: const TextStyle(
                                  color: AppTheme.primaryForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

/// Campo de busca de membro, com as sugestões abaixo do campo.
///
/// Lista embutida em vez do overlay do `Autocomplete`: dentro de uma folha
/// inferior com teclado aberto, o overlay se descola do campo e às vezes
/// fica atrás do teclado.
class _MemberSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool searching;
  final String? error;
  final List<BaptismMemberSuggestion> suggestions;
  final ValueChanged<BaptismMemberSuggestion> onPick;
  final String? linkedName;
  final VoidCallback onUnlink;

  const _MemberSearchField({
    required this.controller,
    required this.onChanged,
    required this.searching,
    required this.error,
    required this.suggestions,
    required this.onPick,
    required this.linkedName,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    // Com ficha vinculada o campo de busca sai de cena: o que importa
    // passa a ser quem está vinculado e como desfazer.
    if (linkedName != null) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Membro vinculado',
          helperText:
              'Os dados abaixo podem ser corrigidos sem alterar a ficha',
        ),
        child: Row(
          children: [
            const Icon(AppIcons.link, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(linkedName!, overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: onUnlink, child: const Text('Desvincular')),
          ],
        ),
      );
    }

    final term = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Buscar membro',
            hintText: 'Digite 3 letras do nome',
            prefixIcon: const Icon(AppIcons.search),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (term.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(AppIcons.close, size: 18),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        )),
            helperText: 'Opcional — quem não tem ficha é só digitar o nome',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
          ),
        ],
        // "Nenhum membro encontrado" só aparece depois da busca terminar.
        // Durante a digitação seria um não-achou que ainda não é verdade.
        if (!searching &&
            error == null &&
            term.length >= 3 &&
            suggestions.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Nenhum membro encontrado com "$term".',
            style: CommunityDesign.metaStyle(context),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.mutedForeground.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, i) {
                final m = suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(m.displayName),
                  subtitle: Text(
                    m.subtitle,
                    style: CommunityDesign.metaStyle(context),
                  ),
                  onTap: () => onPick(m),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
