import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/baptism_repository.dart';
import '../../domain/models/baptism_public_info.dart';
import '../providers/baptism_providers.dart';
import '../utils/baptism_registration_errors.dart';

/// Formulário público de inscrição no batismo — o destino do "Link de
/// inscrição".
///
/// É uma tela SEM LOGIN: quem abre veio de um link no WhatsApp e quase
/// nunca tem conta no app. Por isso ela não usa nada do guard de
/// ministério, não lê `baptism_turma` direto e não mostra aluno nenhum. As
/// duas únicas conversas com o banco são as RPCs
/// `baptism_public_registration_info` e `register_baptism_public`, que
/// decidem no servidor o que pode ser lido e gravado.
///
/// A rota (`/batismo/:ministryId/inscricao`) está na lista de exceções do
/// redirect de autenticação, como `/events/:id/register` — sem isso o link
/// jogaria o visitante na tela de login e a inscrição morreria ali.
class BaptismPublicRegistrationScreen extends ConsumerStatefulWidget {
  final String ministryId;

  const BaptismPublicRegistrationScreen({super.key, required this.ministryId});

  @override
  ConsumerState<BaptismPublicRegistrationScreen> createState() =>
      _BaptismPublicRegistrationScreenState();
}

class _BaptismPublicRegistrationScreenState
    extends ConsumerState<BaptismPublicRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String? _turmaId;
  DateTime? _birthDate;
  bool _sending = false;
  String? _error;

  /// Nome da turma em que a pessoa entrou. Não-nulo = inscrição feita.
  String? _confirmedTurma;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String _humanError(Object error) => baptismRegistrationErrorMessage(error);

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

  Future<void> _submit(List<BaptismPublicTurma> turmas) async {
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
      final turma = turmas.firstWhere(
        (t) => t.id == turmaId,
        orElse: () => turmas.first,
      );
      setState(() {
        _sending = false;
        _confirmedTurma = turma.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _humanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(baptismPublicInfoProvider(widget.ministryId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Largura de leitura: a tela nasce no celular, mas quem abre o
            // link no computador não merece um formulário de 1900px.
            constraints: const BoxConstraints(maxWidth: 520),
            child: infoAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PublicMessage(
                icon: Icons.link_off,
                title: 'Link indisponível',
                message: _humanError(error),
              ),
              data: (info) => _confirmedTurma != null
                  ? _PublicMessage(
                      icon: Icons.check_circle_outline,
                      title: 'Inscrição confirmada!',
                      message:
                          'Você entrou na turma ${_confirmedTurma!} de ${info.ministryName}. '
                          'A liderança vai falar com você pelo WhatsApp com os próximos passos.',
                      tone: _MessageTone.success,
                    )
                  : _buildForm(context, info),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, BaptismPublicInfo info) {
    if (!info.hasTurmas) {
      return _PublicMessage(
        icon: Icons.event_busy_outlined,
        title: 'Inscrições fechadas',
        message:
            'No momento não há turma aberta em ${info.ministryName}. '
            'Fale com a liderança da igreja para saber quando a próxima começa.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          info.ministryName,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15),
        ),
        const SizedBox(height: 8),
        Text(
          info.ministryDescription?.isNotEmpty == true
              ? info.ministryDescription!
              : 'Preencha seus dados para entrar na próxima turma do batismo.',
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 24),
        _SectionLabel(info.turmas.length == 1 ? 'Turma' : 'Escolha a turma'),
        for (final turma in info.turmas)
          _TurmaOption(
            turma: turma,
            selected: turma.id == _turmaId,
            onTap: () => setState(() {
              _turmaId = turma.id;
              _error = null;
            }),
          ),
        const SizedBox(height: 20),
        const _SectionLabel('Seus dados'),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome completo *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.length < 3) return 'Escreva seu nome completo.';
                  return null;
                },
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
                // Mesma régua da RPC (10 dígitos): validar aqui transforma
                // um INVALID_PHONE cru numa frase antes da viagem.
                validator: (v) {
                  final digitos = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digitos.length < 10) {
                    return 'Informe o WhatsApp com DDD.';
                  }
                  return null;
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
                  if (!value.contains('@')) return 'E-mail inválido.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento (opcional)',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Escolher'
                        : DateFormat('dd/MM/yyyy').format(_birthDate!),
                    style: TextStyle(
                      color: _birthDate == null
                          ? Theme.of(context).hintColor
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _sending ? null : () => _submit(info.turmas),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_sending ? 'Enviando...' : 'Confirmar inscrição'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Seus dados ficam com a liderança do ministério e são usados só '
          'para o contato sobre o batismo.',
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }
}

/// Uma turma escolhível, com o que ajuda a decidir: período das aulas e a
/// data do batismo, quando já estão marcados.
class _TurmaOption extends StatelessWidget {
  final BaptismPublicTurma turma;
  final bool selected;
  final VoidCallback onTap;

  const _TurmaOption({
    required this.turma,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final border = dark ? AppTheme.darkBorder : AppTheme.border;
    final formato = DateFormat('dd/MM/yyyy');

    final linhas = <String>[
      if (turma.startDate != null || turma.endDate != null)
        [
          if (turma.startDate != null)
            'Aulas de ${formato.format(turma.startDate!)}',
          if (turma.endDate != null) 'até ${formato.format(turma.endDate!)}',
        ].join(' '),
      if (turma.eventDate != null)
        'Batismo em ${formato.format(turma.eventDate!)}',
      if (turma.description != null && turma.description!.isNotEmpty)
        turma.description!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : null,
            border: Border.all(
              color: selected ? accent : border,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.outline,
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
                      ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    for (final linha in linhas) ...[
                      const SizedBox(height: 4),
                      Text(linha, style: CommunityDesign.metaStyle(context)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageTone { neutral, success }

/// Estado de tela cheia: link inválido, inscrições fechadas ou confirmação.
class _PublicMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final _MessageTone tone;

  const _PublicMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = _MessageTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    // Nenhum destes estados é falha de quem abriu o link — nada de
    // vermelho, mesmo quando o link não vale mais.
    final color = tone == _MessageTone.success
        ? accent
        : Theme.of(context).colorScheme.outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}
