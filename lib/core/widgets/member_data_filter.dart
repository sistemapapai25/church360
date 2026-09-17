import 'package:flutter/material.dart';

import '../design/community_design.dart';

/// Campos cadastrais que valem como recorte operacional.
///
/// A lista espelha o checklist de completude do perfil do membro
/// (`_completionFields` em `member_profile_screen.dart`) — só com os campos
/// que servem para **ação**: montar lista de contato, cobrar documento,
/// achar quem está sem foto. Não repete o que já tem filtro próprio.
enum MemberDataField {
  phone('Telefone'),
  email('E-mail'),
  cpf('CPF'),
  birthdate('Data de nascimento'),
  address('Endereço'),
  photo('Foto'),
  profession('Profissão');

  final String label;
  const MemberDataField(this.label);
}

/// Como o campo deve estar: preenchido ou vazio.
enum MemberDataPresence {
  filled('Com'),
  missing('Sem');

  final String prefix;
  const MemberDataPresence(this.prefix);
}

/// Seleção de "cadastro": um conjunto de exigências combinadas por E.
///
/// Escolher "Sem telefone" + "Sem e-mail" devolve quem não tem **nenhum** dos
/// dois — que é a pergunta útil ("quem não tenho como contatar?").
class MemberDataSelection {
  final Map<MemberDataField, MemberDataPresence> requirements;

  const MemberDataSelection({this.requirements = const {}});

  bool get isActive => requirements.isNotEmpty;

  int get activeCount => requirements.length;

  /// [values] mapeia cada campo para o valor cru do membro. O chamador monta
  /// esse mapa porque só ele conhece o modelo.
  bool matches(Map<MemberDataField, Object?> values) {
    for (final entry in requirements.entries) {
      final raw = values[entry.key];
      final filled = raw != null && !(raw is String && raw.trim().isEmpty);
      if (entry.value == MemberDataPresence.filled && !filled) return false;
      if (entry.value == MemberDataPresence.missing && filled) return false;
    }
    return true;
  }

  /// Cicla o campo entre: sem exigência → com → sem → sem exigência.
  MemberDataSelection toggle(MemberDataField field) {
    final next = Map<MemberDataField, MemberDataPresence>.from(requirements);
    switch (next[field]) {
      case null:
        next[field] = MemberDataPresence.filled;
      case MemberDataPresence.filled:
        next[field] = MemberDataPresence.missing;
      case MemberDataPresence.missing:
        next.remove(field);
    }
    return MemberDataSelection(requirements: next);
  }
}

/// Filtro visual de campos do cadastro. Cada chip tem três estados, trocados
/// pelo toque: neutro, "Com X" e "Sem X".
class MemberDataFilter extends StatelessWidget {
  final String label;
  final MemberDataSelection selection;
  final ValueChanged<MemberDataSelection> onChanged;
  final IconData icon;

  const MemberDataFilter({
    super.key,
    this.label = 'Dados do cadastro',
    required this.selection,
    required this.onChanged,
    this.icon = Icons.fact_check_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Toque para alternar entre Com, Sem e neutro.',
          style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MemberDataField.values.map((field) {
            final presence = selection.requirements[field];
            final active = presence != null;
            return FilterChip(
              label: Text(
                active ? '${presence.prefix} ${field.label.toLowerCase()}'
                       : field.label,
              ),
              selected: active,
              showCheckmark: false,
              avatar: active
                  ? Icon(
                      presence == MemberDataPresence.filled
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      size: 18,
                    )
                  : null,
              onSelected: (_) => onChanged(selection.toggle(field)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
