import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/batismo/domain/models/baptism_public_info.dart';
import '../../../ministries/batismo/presentation/providers/baptism_providers.dart';
import '../../../ministries/batismo/presentation/utils/baptism_registration_errors.dart';
import '../../../ministries/batismo/data/baptism_repository.dart';

/// Resultado da inscrição feita pelo curso.
enum CourseEnrollResult { cancelled, enrolled }

/// "Inscrever-se" do curso (decisão 21): o mesmo caso de uso do link
/// público, pela mesma `register_baptism_public`, com os campos já
/// preenchidos pela ficha de quem está logado. Com mais de uma turma
/// aberta, pergunta qual.
///
/// Identidade continua sendo decidida no servidor: a RPC só vincula a
/// inscrição ao cadastro se houver exatamente uma ficha do tenant com o
/// login. Nome e telefone digitados nunca decidem isso.
Future<CourseEnrollResult> showCourseEnrollSheet(
  BuildContext context, {
  required String ministryId,
  required List<BaptismPublicTurma> turmas,
}) async {
  final result = await showModalBottomSheet<CourseEnrollResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CourseEnrollSheet(ministryId: ministryId, turmas: turmas),
  );
  return result ?? CourseEnrollResult.cancelled;
}

class CourseEnrollSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final List<BaptismPublicTurma> turmas;

  const CourseEnrollSheet({
    super.key,
    required this.ministryId,
    required this.turmas,
  });

  @override
  ConsumerState<CourseEnrollSheet> createState() => _CourseEnrollSheetState();
}

class _CourseEnrollSheetState extends ConsumerState<CourseEnrollSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String? _turmaId;
  DateTime? _birthDate;
  bool _prefilled = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.turmas.length == 1) _turmaId = widget.turmas.single.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Preenche uma vez só, quando a ficha chega; depois o campo é de quem
  /// digita.
  void _prefill() {
    if (_prefilled) return;
    final member = ref.read(currentMemberProvider).valueOrNull;
    final authEmail = _authEmail();
    if (member == null && authEmail == null) return;
    _prefilled = true;
    if (member != null) {
      _name.text = member.fullName?.trim().isNotEmpty == true
          ? member.fullName!.trim()
          : '';
      _phone.text = member.phone?.trim() ?? '';
      _birthDate = member.birthdate;
    }
    final email = member?.email.trim().isNotEmpty == true
        ? member!.email.trim()
        : authEmail;
    _email.text = email ?? '';
  }

  String? _authEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final turmaId = _turmaId;
    if (turmaId == null) {
      setState(() => _error = 'Escolha a turma em que você quer entrar.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref
          .read(baptismRepositoryProvider)
          .registerPublicStudent(
            ministryId: widget.ministryId,
            turmaId: turmaId,
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text.trim().isEmpty ? null : _email.text,
            birthDate: _birthDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop(CourseEnrollResult.enrolled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = baptismRegistrationErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta para preencher quando a ficha terminar de carregar.
    ref.watch(currentMemberProvider);
    _prefill();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final formato = DateFormat('dd/MM/yyyy');

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
                  'Inscrever-se',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confira seus dados. A liderança fala com você pelo '
                  'WhatsApp com os próximos passos.',
                  style: CommunityDesign.metaStyle(context),
                ),
                const SizedBox(height: 16),
                if (widget.turmas.length > 1) ...[
                  Text(
                    'Escolha a turma',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (final turma in widget.turmas)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: turma.id == _turmaId,
                      leading: Icon(
                        turma.id == _turmaId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(turma.name),
                      subtitle: _turmaPeriod(turma, formato) == null
                          ? null
                          : Text(_turmaPeriod(turma, formato)!),
                      onTap: _sending
                          ? null
                          : () => setState(() {
                              _turmaId = turma.id;
                              _error = null;
                            }),
                    ),
                  const SizedBox(height: 8),
                ] else ...[
                  Text(
                    'Turma: ${widget.turmas.single.name}',
                    style: CommunityDesign.contentStyle(context),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Escreva seu nome completo.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9()\-\s+]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp *',
                    hintText: '(62) 99999-9999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  // Mesma régua da RPC (10 dígitos). Ficha com "(11) " só
                  // não passa daqui.
                  validator: (v) {
                    final digitos = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    return digitos.length < 10
                        ? 'Informe o WhatsApp com DDD.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail (opcional)',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return value.contains('@') ? null : 'E-mail inválido.';
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _sending ? null : _pickBirthDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de nascimento (opcional)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Escolher'
                          : formato.format(_birthDate!),
                      style: TextStyle(
                        color: _birthDate == null
                            ? Theme.of(context).hintColor
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _sending ? null : _submit,
                    child: Text(
                      _sending ? 'Enviando...' : 'Confirmar inscrição',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _turmaPeriod(BaptismPublicTurma turma, DateFormat formato) {
    final parts = [
      if (turma.startDate != null)
        'Aulas de ${formato.format(turma.startDate!)}',
      if (turma.endDate != null) 'até ${formato.format(turma.endDate!)}',
      if (turma.eventDate != null)
        'Batismo em ${formato.format(turma.eventDate!)}',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// Depois de inscrever: recarrega o que o hub lê. A matrícula só aparece
/// se a RPC conseguiu vincular a inscrição ao cadastro.
void invalidateAfterCourseEnroll(WidgetRef ref, String ministryId) {
  ref.invalidate(myBaptismEnrollmentsProvider);
  ref.invalidate(baptismPublicInfoProvider(ministryId));
}
