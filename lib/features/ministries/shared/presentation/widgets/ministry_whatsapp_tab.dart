import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../domain/ministry_contact.dart';

/// Aba WhatsApp do workspace: falar com quem está na equipe do ministério.
///
/// É a parte da aba WhatsApp do Batismo que só depende de pessoa e telefone.
/// O Batismo continua com a dele, mais rica — lá há aluno, turma e status de
/// batismo, que não existem em ministério nenhum além daquele.
///
/// Não grava nada: é uma tela de saída. Por isso não há `invalidate` depois
/// de agir nem checagem de escrita — quem chegou aqui já passou pelo escopo
/// do ministério.
///
/// **O que esta aba não faz, de propósito:** disparo em lote de verdade.
/// `wa.me` abre uma conversa por vez e não existe caminho de envio em massa
/// por ele. "Avisar a equipe" percorre uma fila com confirmação a cada
/// pessoa, e a tela diz isso com todas as letras — prometer envio em massa
/// aqui seria mentira de interface.
class MinistryWhatsAppTab extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryWhatsAppTab({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryWhatsAppTab> createState() => _MinistryWhatsAppTabState();
}

class _MinistryWhatsAppTabState extends ConsumerState<MinistryWhatsAppTab> {
  final _search = TextEditingController();
  final _message = TextEditingController(text: kMinistryDefaultNotice);
  String _query = '';
  _RoleFilter _role = _RoleFilter.all;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  List<MinistryMember> _apply(List<MinistryMember> members) {
    final query = _query.trim().toLowerCase();
    return members.where((m) {
      if (!_role.matches(m)) return false;
      if (query.isEmpty) return true;
      if (m.memberName.toLowerCase().contains(query)) return true;
      return m.role.label.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _sendToOne(MinistryMember member, String? ministryName) async {
    final text = renderMinistryNotice(
      _message.text,
      member: member,
      ministryName: ministryName,
    );
    final result = await launchWhatsAppMessage(
      phone: member.phone,
      message: text,
    );
    if (!mounted) return;
    final problem = switch (result) {
      WhatsAppLaunchResult.launched => null,
      WhatsAppLaunchResult.invalidPhone =>
        'O telefone de ${member.memberName} não dá para discar.',
      WhatsAppLaunchResult.cannotLaunch =>
        'Não foi possível abrir o WhatsApp neste aparelho.',
    };
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _sendToMany(
    List<MinistryMember> members,
    String? ministryName,
  ) async {
    final queue = members.where(ministryMemberHasWhatsApp).toList();
    if (queue.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QueueDialog(
        queue: queue,
        message: _message.text,
        ministryName: ministryName,
      ),
    );
  }

  void _insertVariable(String name) {
    final selection = _message.selection;
    final text = _message.text;
    final token = '{$name}';
    final at = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(
      selection.isValid ? selection.start : at,
      at,
      token,
    );
    setState(() {
      _message.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: (selection.isValid ? selection.start : at) + token.length,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(ministryMembersProvider(widget.ministryId));
    final ministryName = ref
        .watch(ministryByIdProvider(widget.ministryId))
        .maybeWhen(data: (m) => m?.name, orElse: () => null);

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _NoticesError(
        message: '$error',
        onRetry: () =>
            ref.invalidate(ministryMembersProvider(widget.ministryId)),
      ),
      data: (members) {
        final visible = _apply(members);
        final usable = visible.where(ministryMemberHasWhatsApp).length;
        final incomplete = visible
            .where(
              (m) =>
                  ministryPhoneState(m.phone) == MinistryPhoneState.incomplete,
            )
            .length;
        final unresolved = unresolvedMinistryVariables(_message.text);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ministryMembersProvider(widget.ministryId));
            await ref.read(ministryMembersProvider(widget.ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por nome ou função...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  for (final filter in _RoleFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _role == filter,
                        onSelected: (_) => setState(() => _role = filter),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _MessageComposer(
                controller: _message,
                unresolved: unresolved,
                onInsertVariable: _insertVariable,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _PhoneCountLine(
                usable: usable,
                total: visible.length,
                incomplete: incomplete,
              ),
              const SizedBox(height: 10),
              _QueueButton(
                usable: usable,
                onPressed: usable == 0
                    ? null
                    : () => _sendToMany(visible, ministryName),
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nenhum membro vinculado a este ministério ainda. '
                    'A aba Equipe é onde alguém entra.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Ninguém na equipe bate com esse filtro.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              for (final member in visible)
                _MemberRow(
                  member: member,
                  onSend: ministryMemberHasWhatsApp(member)
                      ? () => _sendToOne(member, ministryName)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _RoleFilter {
  all('Todos'),
  leaders('Liderança'),
  members('Membros');

  const _RoleFilter(this.label);

  final String label;

  bool matches(MinistryMember member) => switch (this) {
    _RoleFilter.all => true,
    _RoleFilter.leaders => member.role != MinistryRole.member,
    _RoleFilter.members => member.role == MinistryRole.member,
  };
}

/// O texto que vai sair, e as variáveis que ele sabe preencher.
class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final Set<String> unresolved;
  final ValueChanged<String> onInsertVariable;
  final VoidCallback onChanged;

  const _MessageComposer({
    required this.controller,
    required this.unresolved,
    required this.onInsertVariable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.message, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mensagem',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'Escreva o aviso da equipe...',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in kMinistryNoticeVariables.entries)
                Tooltip(
                  message: entry.value,
                  child: ActionChip(
                    label: Text('{${entry.key}}'),
                    onPressed: () => onInsertVariable(entry.key),
                  ),
                ),
            ],
          ),
          if (unresolved.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Dizer antes o que vai sair em branco: a alternativa é a pessoa
            // descobrir isso dentro da conversa do outro.
            Text(
              'Esta aba não sabe preencher '
              '${unresolved.map((v) => '{$v}').join(', ')} — '
              'vai sair em branco.',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quantos dá para acionar, e quantos têm ficha para consertar.
class _PhoneCountLine extends StatelessWidget {
  final int usable;
  final int total;

  /// Telefone gravado que não dá para discar. Fica de fora de [usable] e
  /// mesmo assim precisa aparecer: é ficha que alguém consegue consertar,
  /// não ficha vazia.
  final int incomplete;

  const _PhoneCountLine({
    required this.usable,
    required this.total,
    required this.incomplete,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    if (total == 0) {
      text = 'Ninguém nesta seleção';
    } else {
      final suffix = incomplete == 0
          ? ''
          : ' · $incomplete com telefone incompleto';
      final noun = total == 1 ? 'pessoa' : 'pessoas';
      text =
          '$usable de $total $noun '
          '${usable == 1 ? 'tem' : 'têm'} telefone$suffix';
    }
    return Text(text, style: CommunityDesign.metaStyle(context));
  }
}

class _QueueButton extends StatelessWidget {
  final int usable;
  final VoidCallback? onPressed;

  const _QueueButton({required this.usable, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(AppIcons.send, size: 18),
          label: Text(
            usable == 0 ? 'Ninguém para avisar' : 'Avisar a equipe ($usable)',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Uma conversa por vez, com confirmação a cada pessoa — o WhatsApp '
          'não tem envio em massa por link.',
          style: CommunityDesign.metaStyle(context),
        ),
      ],
    );
  }
}

/// Uma linha da lista: quem é, e o que dá (ou não dá) para fazer com ela.
class _MemberRow extends StatelessWidget {
  final MinistryMember member;

  /// Nulo quando não dá para abrir a conversa — o botão apaga e o motivo
  /// aparece escrito, não só no tooltip.
  final VoidCallback? onSend;

  const _MemberRow({required this.member, this.onSend});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final state = ministryPhoneState(member.phone);
    final name = member.memberName.trim();

    final subtitle = switch (state) {
      MinistryPhoneState.usable => member.role.label,
      MinistryPhoneState.incomplete =>
        '${member.role.label} · telefone incompleto',
      MinistryPhoneState.missing => '${member.role.label} · sem telefone',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state == MinistryPhoneState.usable
                    ? AppIcons.phone
                    : AppIcons.person,
                size: 17,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Sem nome' : name,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: CommunityDesign.metaStyle(context)),
                ],
              ),
            ),
            if (onSend != null)
              IconButton(
                onPressed: onSend,
                icon: const Icon(AppIcons.send, size: 18),
                tooltip: 'Abrir conversa',
              ),
          ],
        ),
      ),
    );
  }
}

/// A fila: uma conversa por vez, com o direito de pular.
class _QueueDialog extends StatefulWidget {
  final List<MinistryMember> queue;
  final String message;
  final String? ministryName;

  const _QueueDialog({
    required this.queue,
    required this.message,
    required this.ministryName,
  });

  @override
  State<_QueueDialog> createState() => _QueueDialogState();
}

class _QueueDialogState extends State<_QueueDialog> {
  int _index = 0;
  int _opened = 0;
  int _skipped = 0;

  Future<void> _open() async {
    final member = widget.queue[_index];
    final text = renderMinistryNotice(
      widget.message,
      member: member,
      ministryName: widget.ministryName,
    );
    final result = await launchWhatsAppMessage(
      phone: member.phone,
      message: text,
    );
    if (!mounted) return;
    if (result == WhatsAppLaunchResult.launched) {
      setState(() => _opened++);
    } else {
      setState(() => _skipped++);
    }
    _advance();
  }

  void _skip() {
    setState(() => _skipped++);
    _advance();
  }

  void _advance() {
    if (_index + 1 >= widget.queue.length) {
      setState(() => _index = widget.queue.length);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= widget.queue.length;
    if (done) {
      return AlertDialog(
        title: const Text('Fila encerrada'),
        content: Text(
          '$_opened ${_opened == 1 ? 'conversa aberta' : 'conversas abertas'}'
          '${_skipped == 0 ? '' : ' · $_skipped ${_skipped == 1 ? 'pulada' : 'puladas'}'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      );
    }

    final member = widget.queue[_index];
    final preview = renderMinistryNotice(
      widget.message,
      member: member,
      ministryName: widget.ministryName,
    );

    return AlertDialog(
      title: Text('${_index + 1} de ${widget.queue.length}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.memberName.trim().isEmpty
                ? 'Sem nome'
                : member.memberName.trim(),
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(preview, style: CommunityDesign.metaStyle(context)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Parar'),
        ),
        TextButton(onPressed: _skip, child: const Text('Pular')),
        FilledButton(onPressed: _open, child: const Text('Abrir conversa')),
      ],
    );
  }
}

class _NoticesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NoticesError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar a equipe.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
