import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../members/domain/models/member_directory_entry.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../providers/events_provider.dart';
import '../utils/event_full_error.dart';

/// Diálogo público para adicionar um inscrito a um evento.
class AddRegistrationDialog extends ConsumerStatefulWidget {
  final String eventId;

  /// Capacidade máxima do evento, quando conhecida. Serve apenas para
  /// interpolar o número na copy de `EVENT_FULL` (REG-04) — nenhuma decisão
  /// de vaga é tomada no cliente. Nulo significa "sem limite" ou "capacidade
  /// não disponível neste contexto", nunca zero.
  final int? maxCapacity;

  /// VIS-03: escopo de elegibilidade de inscrição do evento (`'all'` ou
  /// `'restricted'`). Recebido pronto do chamador, que já tem o [Event] em
  /// mãos — evita uma segunda leitura de `event` só para decidir a fonte da
  /// lista. O default `'all'` mantém o comportamento da Fase 1 intacto para
  /// qualquer call site que não passe o escopo.
  final String registrationScope;

  const AddRegistrationDialog({
    super.key,
    required this.eventId,
    this.maxCapacity,
    this.registrationScope = 'all',
  });

  @override
  ConsumerState<AddRegistrationDialog> createState() =>
      _AddRegistrationDialogState();
}

class _AddRegistrationDialogState
    extends ConsumerState<AddRegistrationDialog> {
  String? _selectedMemberId;
  String _searchQuery = '';
  bool _submitting = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// VIS-03: a inscrição deste evento é restrita a alvos de audiência?
  bool get _inscricaoRestrita => widget.registrationScope != 'all';

  /// Instância única da família de elegíveis deste evento — resolvida uma vez
  /// para que observar e invalidar apontem sempre para o mesmo provider.
  late final _fonteDeElegiveis = eligibleMembersProvider(widget.eventId);

  @override
  Widget build(BuildContext context) {
    // REG-01: o provider antigo consultava `public.user_account` direto, e a
    // policy `user_account_select_tenant` só libera a leitura de terceiros
    // para conta elevada (`is_elevated_current_user`) — por isso a lista
    // vinha vazia para qualquer responsável comum. `memberDirectoryProvider`
    // usa a RPC `get_tenant_member_directory` (migration 20260807000001),
    // que é `SECURITY DEFINER` e foi criada para o mesmo bug na área Kids.
    //
    // VIS-03: quando a inscrição é RESTRITA, a fonte muda para a lista de
    // elegíveis, que devolve as MESMAS colunas vindas de
    // `list_event_eligible_members`. "Don't Hand-Roll": a resolução de
    // grupo/ministério/cargo é do servidor; reimplementar esse filtro em Dart
    // exigiria expor as tabelas de vínculo de cargo e de grupo ao cliente e
    // criaria uma segunda verdade sobre audiência. Evento aberto continua no
    // caminho original, intocado — não regredir REG-01 (T-08-06).
    final memberDirectoryAsync = _inscricaoRestrita
        ? ref
              .watch(_fonteDeElegiveis)
              .whenData(
                (linhas) => linhas
                    .map(MemberDirectoryEntry.fromJson)
                    .toList(growable: false),
              )
        : ref.watch(memberDirectoryProvider);
    final registrationsAsync = ref.watch(
      eventRegistrationsProvider(widget.eventId),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Adicionar Inscrito'),
      content: SizedBox(
        width: double.maxFinite,
        child: memberDirectoryAsync.when(
          data: (directory) {
            return registrationsAsync.when(
              data: (registrations) {
                final registeredMemberIds = registrations
                    .map((r) => r.memberId)
                    .toSet();
                final availableMembers = directory
                    .where((m) => !registeredMemberIds.contains(m.id))
                    .toList();

                // VIS-03: lista de elegíveis vazia tem causa própria e copy
                // própria. A medição SQL 13 do Plano 03-01 mostrou que alvo
                // do tipo cargo só alcança quem tem login — é a causa nº 1 de
                // "restringi a inscrição e não aparece ninguém". Cair no
                // "Todos já estão inscritos" aqui seria mentira.
                if (_inscricaoRestrita && directory.isEmpty) {
                  return _buildEmptyState(
                    context,
                    icon: Icons.lock_outline,
                    heading: 'Nenhum membro elegível para este evento.',
                    body:
                        'A inscrição está restrita aos alvos escolhidos, e alvo do tipo cargo alcança apenas membros com conta de acesso ao aplicativo.',
                  );
                }

                if (availableMembers.isEmpty) {
                  return _buildEmptyState(
                    context,
                    icon: Icons.how_to_reg,
                    heading: 'Todos já estão inscritos',
                    body:
                        'Não há mais ninguém no cadastro de membros para adicionar a este evento.',
                  );
                }

                if (_selectedMemberId != null &&
                    !availableMembers.any((m) => m.id == _selectedMemberId)) {
                  _selectedMemberId = null;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar membro...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: Builder(
                        builder: (context) {
                          var filtered = availableMembers;
                          if (_searchQuery.isNotEmpty) {
                            final q = _searchQuery.toLowerCase();
                            filtered = filtered.where((m) {
                              return m.displayName.toLowerCase().contains(q) ||
                                  ((m.nickname?.toLowerCase().contains(q)) ??
                                      false);
                            }).toList();
                          }

                          if (filtered.isEmpty) {
                            return _buildEmptyState(
                              context,
                              icon: Icons.search_off,
                              heading: 'Nenhum resultado para "$_searchQuery"',
                              body:
                                  'Confira a grafia ou tente buscar pelo apelido.',
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final m = filtered[index];
                              final isSelected = _selectedMemberId == m.id;
                              final hasAvatar =
                                  m.avatarUrl != null && m.avatarUrl!.trim().isNotEmpty;
                              final hasNickname =
                                  m.nickname != null && m.nickname!.trim().isNotEmpty;
                              return ListTile(
                                leading: hasAvatar
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(m.avatarUrl!),
                                      )
                                    : CircleAvatar(child: Text(m.initials)),
                                title: Text(m.displayName),
                                subtitle: hasNickname ? Text(m.nickname!) : null,
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                                onTap: _submitting
                                    ? null
                                    : () {
                                        setState(() => _selectedMemberId = m.id);
                                      },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.primary),
          onPressed: (_selectedMemberId == null || _submitting)
              ? null
              : () => _addRegistration(context),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String heading,
    required String body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Não foi possível carregar a lista de membros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            // Invalida a fonte realmente usada: o diretório em evento aberto,
            // a lista de elegíveis em evento restrito.
            onPressed: () => _inscricaoRestrita
                ? ref.invalidate(_fonteDeElegiveis)
                : ref.invalidate(memberDirectoryProvider),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Future<void> _addRegistration(BuildContext context) async {
    if (_selectedMemberId == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      // REG-03: re-checagem TOCTOU antes de chamar a API. A autorização pode
      // ter mudado entre a abertura do diálogo e o toque em "Adicionar"; se
      // mudou, mostra a copy de negação e não chama o repositório. O
      // servidor nega de qualquer forma (policy do Plano 04).
      bool podeGerenciar;
      try {
        podeGerenciar = await ref.read(
          canManageEventRegistrationsProvider(widget.eventId).future,
        );
      } catch (_) {
        podeGerenciar = false; // fail-closed
      }
      if (!podeGerenciar) {
        if (context.mounted) {
          AppErrorHandler.showSnackBar(
            context,
            Exception(
              'Você não tem permissão para gerenciar os inscritos deste evento.',
            ),
            feature: 'events',
          );
        }
        return;
      }

      await ref
          .read(eventsRepositoryProvider)
          .addRegistration(widget.eventId, _selectedMemberId!);
      ref.invalidate(eventRegistrationsProvider(widget.eventId));
      ref.invalidate(eventByIdProvider(widget.eventId));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscrito adicionado.')),
        );
      }
    } catch (e) {
      // REG-04: a UI antecipa o teto, mas quem decide é a RPC. Se o servidor
      // recusou por capacidade, a tela achava que havia vaga e perdeu uma
      // corrida — invalidar evento e lista faz o contador convergir para o
      // estado real, em vez de deixar o usuário tentando em loop (T-07-04).
      if (isEventFullError(e)) {
        AppErrorHandler.log(e, feature: 'events');
        ref.invalidate(eventByIdProvider(widget.eventId));
        ref.invalidate(eventRegistrationsProvider(widget.eventId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(eventFullMessage(widget.maxCapacity))),
          );
        }
        return;
      }

      // Conflito de duplicidade: a copy genérica de `23505` do AppErrorHandler
      // ("Esse item ja existe") não diz nada ao responsável — aqui o contexto
      // é conhecido e a copy do UI-SPEC é mais precisa. Nenhum outro código
      // específico é sobrescrito: `42501` continua indo pelo handler.
      if (e is PostgrestException && (e.code ?? '').trim() == '23505') {
        AppErrorHandler.log(e, feature: 'events');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este membro já está inscrito neste evento.'),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage: 'Não foi possível adicionar o inscrito. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
