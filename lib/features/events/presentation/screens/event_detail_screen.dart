import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/utils/share_link_utils.dart';

import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
import '../widgets/add_registration_dialog.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/domain/models/ministry.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/widgets/share_link_dialog.dart';

/// Tela de detalhes do evento
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isRegistrationShareEnabled(Event event) {
    return event.requiresRegistration && event.status == 'published' && !event.isPast;
  }

  String _buildEventRegistrationShareUrl(String eventId) {
    return ShareLinkUtils.buildShareUrl('/events/$eventId/register');
  }

  String _buildEventDetailShareUrl(String eventId) {
    return ShareLinkUtils.buildShareUrl('/events/$eventId');
  }

  void _shareRegistrationLink(Event event) {
    final url = _buildEventRegistrationShareUrl(event.id);
    showShareLinkDialog(
      context,
      title: 'Compartilhar inscrição',
      url: url,
      shareText: 'Inscreva-se no evento "${event.name}":\n$url',
    );
  }

  void _shareEventInfoLink(Event event) {
    final url = _buildEventDetailShareUrl(event.id);
    showShareLinkDialog(
      context,
      title: 'Compartilhar evento',
      url: url,
      shareText: 'Confira o evento "${event.name}":\n$url',
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Evento não encontrado')),
            body: const Center(child: Text('Evento não encontrado')),
          );
        }

        return Scaffold(
          backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            backgroundColor: CommunityDesign.headerColor(context),
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            titleSpacing: 0,
            leadingWidth: 54,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                tooltip: 'Voltar',
                onPressed: () => _handleBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.event,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Detalhes do evento',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _isRegistrationShareEnabled(event)
                    ? 'Compartilhar link de inscrição'
                    : 'Compartilhar informações do evento',
                icon: const Icon(Icons.share),
                onPressed: () => _isRegistrationShareEnabled(event)
                    ? _shareRegistrationLink(event)
                    : _shareEventInfoLink(event),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Informações'),
                Tab(
                  text: event.requiresRegistration
                      ? 'Inscritos (${event.registrationCount ?? 0})'
                      : 'Inscritos',
                ),
                const Tab(text: 'Escalas'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _InfoTab(event: event),
              _RegistrationsTab(event: event),
              _SchedulesTab(eventId: event.id),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro ao carregar evento: $error')),
      ),
    );
  }
}

/// Tab de informações do evento
class _InfoTab extends ConsumerWidget {
  final Event event;

  const _InfoTab({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Nulo aqui significa "evento sem limite de capacidade", não zero.
    final capacidadeMaxima = event.maxCapacity;
    final totalInscritos = event.registrationCount ?? 0;
    final currentMember = ref.watch(currentMemberProvider).valueOrNull;
    EventRegistration? myRegistration;
    if (currentMember != null && event.requiresRegistration) {
      final registrations = ref
          .watch(eventRegistrationsProvider(event.id))
          .valueOrNull;
      if (registrations != null) {
        for (final r in registrations) {
          if (r.memberId == currentMember.id) {
            myRegistration = r;
            break;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do evento
          if (event.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                event.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Status
          _StatusChip(event: event),
          const SizedBox(height: 24),

          // Nome
          Text(
            event.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Descrição
          if (event.description != null && event.description!.isNotEmpty) ...[
            Text(
              event.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
          ],

          // Informações
          _InfoCard(
            icon: Icons.calendar_today,
            title: 'Data de Início',
            value: DateFormat('dd/MM/yyyy').format(event.startDate),
          ),
          _InfoCard(
            icon: Icons.access_time,
            title: 'Horário de Início',
            value: DateFormat('HH:mm').format(event.startDate),
          ),
          if (event.endDate != null)
            _InfoCard(
              icon: Icons.event_available,
              title: 'Data de Término',
              value: DateFormat('dd/MM/yyyy HH:mm').format(event.endDate!),
            ),
          if (event.location != null)
            _InfoCard(
              icon: Icons.location_on,
              title: 'Local',
              value: event.location!,
            ),
          if (event.eventType != null)
            _InfoCard(
              icon: Icons.category,
              title: 'Tipo',
              value: event.eventType!,
            ),
          if (event.maxCapacity != null)
            _InfoCard(
              icon: Icons.people,
              title: 'Capacidade Máxima',
              value: '${event.maxCapacity} pessoas',
            ),
          _InfoCard(
            icon: Icons.app_registration,
            title: 'Requer Inscrição',
            value: event.requiresRegistration ? 'Sim' : 'Não',
          ),
          if (event.requiresRegistration) ...[
            // IC-3 (REG-04): três estados mutuamente exclusivos derivados de
            // `maxCapacity`/`registrationCount`. `maxCapacity == null`
            // significa "sem limite" e NUNCA pode ser tratado como zero — daí
            // a comparação explícita com nulo em vez de `?? 0`. A UI só
            // antecipa o teto; quem decide a vaga é a RPC
            // `register_member_in_event` (Plano 05).
            _InfoCard(
              icon: Icons.how_to_reg,
              title: 'Inscritos',
              value: capacidadeMaxima == null
                  ? '$totalInscritos inscritos'
                  : '$totalInscritos / $capacidadeMaxima',
              valueColor: capacidadeMaxima == null
                  ? null
                  : (event.isFull ? colorScheme.error : colorScheme.primary),
            ),
            if (event.isFull)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: CommunityDesign.overlayDecoration(colorScheme)
                    .copyWith(
                      color: colorScheme.errorContainer,
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                // Acessibilidade: a lotação nunca é transmitida só por cor —
                // o banner traz ícone E rótulo textual, e o contador em
                // `error` sempre aparece acompanhado dele.
                child: Row(
                  children: [
                    Icon(Icons.event_busy, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Evento lotado',
                      style: CommunityDesign.titleStyle(context).copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Botão de inscrição / status de inscrito
          if (event.requiresRegistration && !event.isPast) ...[
            const SizedBox(height: 32),
            if (myRegistration != null) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/events/${event.id}/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A169),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    'INSCRITO — VER MEU INGRESSO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300] ?? Colors.grey),
                  ),
                  child: QrImageView(
                    data: myRegistration.qrCode ??
                        'EVENT_TICKET:${event.id}:${currentMember!.id}',
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: event.isFull
                      ? null
                      : () => context.push('/events/${event.id}/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: event.isFree
                        ? const Color(0xFF38A169)
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    event.isFree
                        ? Icons.card_giftcard
                        : Icons.confirmation_number,
                  ),
                  label: Text(
                    event.isFull
                        ? 'Evento lotado'
                        : event.isFree
                        ? 'INSCREVER-SE GRATUITAMENTE'
                        : 'COMPRAR INGRESSO',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Card de informação
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  /// Cor opcional do valor. Usada pelo contador de capacidade (IC-3): accent
  /// abaixo do limite, `error` no limite. Nulo mantém a cor padrão do tema.
  final Color? valueColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de status do evento
class _StatusChip extends StatelessWidget {
  final Event event;

  const _StatusChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String label = event.statusText;
    Color color;

    if (event.status == 'cancelled') {
      color = colorScheme.error;
    } else if (event.status == 'completed' || event.isPast) {
      color = colorScheme.onSurfaceVariant;
    } else if (event.isOngoing) {
      color = const Color(0xFF38A169); // Verde sucesso
    } else if (event.isUpcoming) {
      color = colorScheme.primary;
    } else {
      color = colorScheme.tertiary;
    }

    return CommunityDesign.badge(context, label.toUpperCase(), color);
  }
}

/// Tab de inscritos do evento
class _RegistrationsTab extends ConsumerWidget {
  final Event event;

  const _RegistrationsTab({required this.event});

  /// Verde de sucesso do módulo (mesma constante usada pelo _StatusChip).
  static const Color _checkInColor = Color(0xFF38A169);

  /// IC-3 (REG-04): motivo do estado desabilitado. Declarado uma única vez
  /// para que os dois pontos de adição (FAB e CTA do estado vazio) nunca
  /// divirjam na explicação dada ao usuário.
  static const String _lotadoTooltip =
      'Evento lotado — capacidade máxima atingida';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!event.requiresRegistration) {
      return const _RegistrationsEmptyState(
        icon: Icons.info_outline,
        heading: 'Este evento não requer inscrição',
        body:
            'Ative "Requer inscrição" na edição do evento para controlar a lista de participantes.',
      );
    }

    // IC-1 (REG-03): a autorização de escrita é composta — permissão global
    // OU responsável por ESTE evento. `loading` e `error` caem no ramo
    // seguro, nunca no permissivo (mesmo contrato do PermissionGate:69-73).
    // A LISTA nunca é escondida: restringir a leitura é escopo da Fase 3, e
    // gatá-la aqui criaria divergência com o que a RLS ainda entrega.
    final podeGerenciar = ref
        .watch(canManageEventRegistrationsProvider(event.id))
        .when(
          data: (valor) => valor,
          loading: () => false,
          error: (_, __) => false,
        );

    final registrationsAsync = ref.watch(eventRegistrationsProvider(event.id));

    return registrationsAsync.when(
      data: (registrations) {
        if (registrations.isEmpty) {
          return _RegistrationsEmptyState(
            icon: Icons.people_outline,
            heading: 'Nenhum inscrito ainda',
            body: podeGerenciar
                ? 'Adicione o primeiro inscrito ou compartilhe o link de inscrição do evento.'
                : 'Quando alguém se inscrever, o nome aparece aqui.',
            // Sem CTA para quem não pode gerenciar: não oferecer um botão
            // que o servidor vai negar. Quem pode gerenciar mas esbarra no
            // teto vê o botão desabilitado com o motivo — nunca escondido,
            // para não confundir lotação com perda de permissão.
            action: podeGerenciar
                ? Tooltip(
                    message: event.isFull ? _lotadoTooltip : '',
                    child: FilledButton.icon(
                      onPressed: event.isFull
                          ? null
                          : () => _showAddRegistrationDialog(context, event),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Adicionar primeiro inscrito'),
                    ),
                  )
                : null,
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(eventRegistrationsProvider(event.id));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: registrations.length,
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: CommunityDesign.overlayDecoration(
                      Theme.of(context).colorScheme,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          registration.memberName
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              '?',
                        ),
                      ),
                      title: Text(
                        registration.memberName ?? 'Membro desconhecido',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inscrito em: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.registeredAt)}',
                          ),
                          if (registration.isCheckedIn)
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: _checkInColor,
                                ),
                                const SizedBox(width: 4),
                                // Estado de check-in tem ícone E texto: nunca
                                // transmitido só por cor.
                                Text(
                                  'Check-in: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.checkedInAt!)}',
                                  style: const TextStyle(color: _checkInColor),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // Sem autorização, o trailing inteiro fica ausente —
                      // ausência silenciosa, como no resto do app.
                      trailing: podeGerenciar
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botão de check-in
                                if (!registration.isCheckedIn)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: _checkInColor,
                                    ),
                                    onPressed: () => _doCheckIn(
                                      context,
                                      ref,
                                      event.id,
                                      registration.memberId,
                                    ),
                                    tooltip: 'Fazer check-in',
                                  )
                                else
                                  IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      color: colorScheme.tertiary,
                                    ),
                                    onPressed: () => _cancelCheckIn(
                                      context,
                                      ref,
                                      event.id,
                                      registration.memberId,
                                    ),
                                    tooltip: 'Cancelar check-in',
                                  ),
                                // Botão de remover
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () => _confirmRemoveRegistration(
                                    context,
                                    ref,
                                    event.id,
                                    registration.memberId,
                                    registration.memberName ?? 'este membro',
                                  ),
                                  tooltip: 'Remover inscrito',
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            // FAB para adicionar inscrito — ausente (sem spinner no lugar)
            // enquanto o gate não conceder. Quando o gate concede e o evento
            // está lotado, o FAB fica VISÍVEL e DESABILITADO com o motivo no
            // tooltip (IC-3): esconder faria o responsável achar que perdeu a
            // permissão. As duas condições são ortogonais — a de lotação nunca
            // desfaz o gate do Plano 06.
            if (podeGerenciar)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: event.isFull
                      ? null
                      : () => _showAddRegistrationDialog(context, event),
                  tooltip: event.isFull
                      ? _lotadoTooltip
                      : 'Adicionar inscrito',
                  child: const Icon(Icons.person_add),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _RegistrationsEmptyState(
        icon: Icons.error_outline,
        iconColor: colorScheme.error,
        heading: 'Não foi possível carregar os inscritos.',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(eventRegistrationsProvider(event.id)),
          child: const Text('Tentar novamente'),
        ),
      ),
    );
  }

  Future<void> _showAddRegistrationDialog(
    BuildContext context,
    Event event,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AddRegistrationDialog(
        eventId: event.id,
        maxCapacity: event.maxCapacity,
      ),
    );
  }

  Future<void> _doCheckIn(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
  ) async {
    // Re-checagem TOCTOU (padrão Tier 1, Pitfall 20): a responsabilidade
    // pode ter sido removida depois que a tela foi montada. O servidor nega
    // de qualquer forma — isto é o que faz a UI explicar o motivo em vez de
    // mostrar uma falha crua.
    bool podeGerenciar;
    try {
      podeGerenciar = await ref.read(
        canManageEventRegistrationsProvider(eventId).future,
      );
    } catch (_) {
      podeGerenciar = false; // fail-closed, igual ao gate de renderização
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

    try {
      await ref.read(eventsRepositoryProvider).checkIn(eventId, memberId);
      ref.invalidate(eventRegistrationsProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in realizado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage:
              'Não foi possível registrar o check-in. Tente novamente.',
        );
      }
    }
  }

  Future<void> _cancelCheckIn(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
  ) async {
    bool podeGerenciar;
    try {
      podeGerenciar = await ref.read(
        canManageEventRegistrationsProvider(eventId).future,
      );
    } catch (_) {
      podeGerenciar = false;
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

    try {
      await ref.read(eventsRepositoryProvider).cancelCheckIn(eventId, memberId);
      ref.invalidate(eventRegistrationsProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Check-in cancelado.')));
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage:
              'Não foi possível cancelar o check-in. Tente novamente.',
        );
      }
    }
  }

  Future<void> _confirmRemoveRegistration(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String memberId,
    String memberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Remover inscrito?'),
          content: Text(
            '$memberName sai da lista de inscritos deste evento e a vaga volta a ficar livre.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    bool podeGerenciar;
    try {
      podeGerenciar = await ref.read(
        canManageEventRegistrationsProvider(eventId).future,
      );
    } catch (_) {
      podeGerenciar = false;
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

    try {
      await ref
          .read(eventsRepositoryProvider)
          .removeRegistration(eventId, memberId);
      ref.invalidate(eventRegistrationsProvider(eventId));
      ref.invalidate(eventByIdProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscrito removido.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage:
              'Não foi possível remover o inscrito. Tente novamente.',
        );
      }
    }
  }
}

/// Estado vazio / de erro da aba Inscritos. Copy vem verbatim do
/// `01-UI-SPEC.md`; cores saem do `colorScheme`, nunca de `Colors.*` cru.
class _RegistrationsEmptyState extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String heading;
  final String? body;
  final Widget? action;

  const _RegistrationsEmptyState({
    required this.icon,
    required this.heading,
    this.iconColor,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Tab de escalas de ministérios
class _SchedulesTab extends ConsumerWidget {
  final String eventId;

  const _SchedulesTab({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(eventSchedulesProvider(eventId));

    return schedulesAsync.when(
      data: (schedules) {
        // Agrupar escalas por ministério
        final Map<String, List<MinistrySchedule>> schedulesByMinistry = {};
        for (final schedule in schedules) {
          if (!schedulesByMinistry.containsKey(schedule.ministryId)) {
            schedulesByMinistry[schedule.ministryId] = [];
          }
          schedulesByMinistry[schedule.ministryId]!.add(schedule);
        }

        Widget buildMinistryCard({
          required String ministryId,
          required String ministryName,
          required List<MinistrySchedule> ministrySchedules,
        }) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: CommunityDesign.overlayDecoration(
              Theme.of(context).colorScheme,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(CommunityDesign.radius),
                      topRight: Radius.circular(CommunityDesign.radius),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.church, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ministryName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${ministrySchedules.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PermissionBuilder(
                  permission: 'ministries.manage_schedule',
                  builder: (context, hasPermission) {
                    if (!hasPermission) return const SizedBox.shrink();
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.blue,
                          ),
                          title: const Text('Adicionar membro'),
                          subtitle: const Text(
                            'Adicionar/ajustar escala deste ministério',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _openMinistryAutoScheduler(
                            context,
                            ministryId,
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.2),
                        ),
                      ],
                    );
                  },
                ),
                if (ministrySchedules.isNotEmpty)
                  ...ministrySchedules.map((schedule) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(schedule.memberName),
                      subtitle:
                          schedule.notes != null ? Text(schedule.notes!) : null,
                    );
                  }),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Lista de escalas agrupadas por ministério
            if (schedulesByMinistry.isEmpty)
              _EmptySchedulesContent(
                buildMinistryCard: buildMinistryCard,
              )
            else
              ...schedulesByMinistry.entries.map((entry) {
                final ministrySchedules = entry.value;
                final ministryName = ministrySchedules.first.ministryName;

                return buildMinistryCard(
                  ministryId: entry.key,
                  ministryName: ministryName,
                  ministrySchedules: ministrySchedules,
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      // CLAUDE.md: nunca renderizar o erro cru para o usuário.
      error: (error, _) =>
          const Center(child: Text('Não foi possível carregar as escalas.')),
    );
  }

  void _openMinistryAutoScheduler(BuildContext context, String ministryId) {
    context.push('/ministries/$ministryId/auto-scheduler');
  }
}

class _EmptySchedulesContent extends ConsumerWidget {
  final Widget Function({
    required String ministryId,
    required String ministryName,
    required List<MinistrySchedule> ministrySchedules,
  }) buildMinistryCard;

  const _EmptySchedulesContent({required this.buildMinistryCard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);

    return Column(
      children: [
        Container(
          decoration: CommunityDesign.overlayDecoration(
            Theme.of(context).colorScheme,
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum membro escalado',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione um ministério abaixo para adicionar membros',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ministriesAsync.when(
          data: (ministries) {
            if (ministries.isEmpty) {
              return Container(
                decoration: CommunityDesign.overlayDecoration(
                  Theme.of(context).colorScheme,
                ),
                padding: const EdgeInsets.all(16),
                child: const Text('Nenhum ministério ativo disponível'),
              );
            }

            return Column(
              children: [
                for (final m in ministries)
                  buildMinistryCard(
                    ministryId: m.id,
                    ministryName: m.name,
                    ministrySchedules: const [],
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          // CLAUDE.md: nunca renderizar o erro cru para o usuário.
          error: (error, _) => const Center(
            child: Text('Não foi possível carregar as escalas.'),
          ),
        ),
      ],
    );
  }
}
