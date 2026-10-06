import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/share_link_utils.dart';

import '../../domain/models/event.dart';
import '../../domain/models/event_audience.dart';
import '../providers/events_provider.dart';
import '../widgets/add_registration_dialog.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../../../courses/presentation/providers/courses_provider.dart';
import '../../../courses/presentation/turma/professor_aula.dart';
import '../../../study_groups/domain/models/teaching_lesson.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/domain/models/ministry.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/widgets/share_link_dialog.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../../../../core/widgets/pearl_button.dart';
import '../../../../core/theme/app_theme.dart';

/// VIS-02/VIS-03: o evento tem algum dos dois controles de audiência
/// restrito? Os dois são independentes — basta um deles sair de `'all'`
/// para o evento ser "restrito" do ponto de vista da UI.
bool _isEventRestricted(Event event) {
  return event.visibilityScope != 'all' || event.registrationScope != 'all';
}

/// Tela de detalhes do evento
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  int _tab = 0;

  bool _isRegistrationShareEnabled(Event event) {
    return event.requiresRegistration &&
        event.status == 'published' &&
        !event.isPast;
  }

  String _buildEventRegistrationShareUrl(String eventId) {
    return ShareLinkUtils.buildShareUrl('/events/$eventId/register');
  }

  String _buildEventDetailShareUrl(String eventId) {
    return ShareLinkUtils.buildShareUrl('/events/$eventId');
  }

  /// D-06: evento restrito MANTÉM os dois botões de compartilhar, com aviso.
  /// O link já é protegido pela RLS de `public.event` (Plano 05) — quem não
  /// pertence ao alvo abre o link e não enxerga nada. O aviso existe para
  /// evitar constrangimento social de quem compartilha, **não** como
  /// controle de segurança. Esconder o botão não protegeria nada e tiraria
  /// uma capacidade legítima de quem pode ver o evento.
  String? _shareRestrictionWarning(Event event) {
    if (!_isEventRestricted(event)) return null;
    return 'Este evento é restrito. Somente quem pertence aos alvos escolhidos conseguirá abrir este link.';
  }

  void _shareRegistrationLink(Event event) {
    final url = _buildEventRegistrationShareUrl(event.id);
    showShareLinkDialog(
      context,
      title: 'Compartilhar inscrição',
      url: url,
      shareText: 'Inscreva-se no evento "${event.name}":\n$url',
      warning: _shareRestrictionWarning(event),
    );
  }

  void _shareEventInfoLink(Event event) {
    final url = _buildEventDetailShareUrl(event.id);
    showShareLinkDialog(
      context,
      title: 'Compartilhar evento',
      url: url,
      shareText: 'Confira o evento "${event.name}":\n$url',
      warning: _shareRestrictionWarning(event),
    );
  }

  /// VIS-02 / T-08-02 — decisão REVERTIDA de propósito na Fase 2 (D-02 do
  /// `.planning/phases/02-link-deep-linking/02-CONTEXT.md`, contrato normativo
  /// em `02-UI-SPEC.md`).
  ///
  /// T-08-02 (Fase 3) exigia copy NEUTRA (`'Este evento não está
  /// disponível.'`) para não confirmar a existência de um evento restrito a
  /// quem não pode vê-lo. D-02 reverteu isso conscientemente: quem chega por
  /// um link compartilhado **já sabe** que o evento existe (coerente com D-06
  /// da Fase 3, que mantém o botão de compartilhar em evento restrito), e a
  /// parede neutra deixava a pessoa sem entender o que fazer a seguir.
  ///
  /// Risco residual ACEITO por D-02/D-06 (T-02-14 do Plano 02-04): para
  /// qualquer autenticado do tenant, ver "não encontrado" em vez de "sem
  /// acesso" é um oráculo de existência de evento. Mitigado por os ids serem
  /// UUIDv4 não enumeráveis e por a RPC ser negada a `anon`. Registrado, não
  /// silenciado.
  ///
  /// Diferenciar os dois casos é IMPOSSÍVEL só no Flutter: sob a RLS de
  /// `public.event` ambos devolvem zero linhas. Quem decide é o servidor, via
  /// `get_event_access_status` (`eventAccessStatusProvider`). Esta árvore de
  /// estados é UX, não boundary — a autoridade real é a policy
  /// `event_visibility_restrict` / `event_visibility_restrict_anon`.
  ///
  /// Esqueleto único dos cinco estados de acesso. Todos usam o MESMO fundo do
  /// evento carregado com sucesso: quem chega por link não deve ver a cor de
  /// fundo mudar conforme o resultado (débito herdado do antigo
  /// `_buildUnavailableScreen`, que não declarava `backgroundColor`).
  Widget _buildAccessStateScreen(
    BuildContext context, {
    required IconData icon,
    required String heading,
    required String supportingText,
    required IconData primaryIcon,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final theme = Theme.of(context);
    final temSecundario = secondaryLabel != null && onSecondary != null;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(title: const Text('Evento')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone é decorativo e NUNCA vermelho: "sem acesso" e "não
              // encontrado" não são falhas do usuário nem do sistema.
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                supportingText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: temSecundario ? 32 : 24),
              FilledButton.icon(
                onPressed: onPrimary,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
              if (temSecundario) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Estado `loading`: cobre os DOIS awaits (evento e RPC de status). Regra 1
  /// do Interaction Contract — renderizar "não encontrado" sobre uma query
  /// ainda pendente é o caminho mais provável de erro no cold start do deep
  /// link.
  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(title: const Text('Carregando...')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildRestrictedScreen(BuildContext context) {
    return _buildAccessStateScreen(
      context,
      icon: AppIcons.lock,
      heading: 'Você não tem acesso a este evento',
      supportingText:
          'Este evento é restrito e você não está entre os públicos escolhidos. Se acha que deveria participar, fale com o responsável pelo evento.',
      primaryIcon: AppIcons.calendarFilled,
      primaryLabel: 'Voltar para a Agenda',
      onPrimary: () => context.go('/schedule'),
    );
  }

  Widget _buildNotFoundScreen(BuildContext context) {
    return _buildAccessStateScreen(
      context,
      icon: AppIcons.eventBusy,
      heading: 'Evento não encontrado',
      supportingText:
          'Este link pode estar incorreto, ou o evento pode ter sido removido.',
      primaryIcon: AppIcons.calendarFilled,
      primaryLabel: 'Voltar para a Agenda',
      onPrimary: () => context.go('/schedule'),
    );
  }

  /// LINK-03 / D-04: é este CTA que dispara o retorno pós-login para
  /// `/events/:id`. A rota continua PÚBLICA de propósito (desenho A do Achado
  /// #9 — fechá-la mataria o fluxo de convidado de `/register`), então o
  /// gatilho do `?redirect=` mora aqui, na tela, e não no `redirect` central
  /// do GoRouter. O saneamento do destino é feito por `safeRedirect` do
  /// `app_router.dart` (Plano 02-03).
  Widget _buildLoginRequiredScreen(BuildContext context) {
    final destino = Uri.encodeComponent('/events/${widget.eventId}');
    return _buildAccessStateScreen(
      context,
      icon: AppIcons.login,
      heading: 'Entre para ver este evento',
      supportingText:
          'Este evento não está aberto ao público. Faça login e você volta direto para ele.',
      primaryIcon: AppIcons.login,
      primaryLabel: 'Entrar',
      onPrimary: () => context.go('/login?redirect=$destino'),
      secondaryLabel: 'Voltar para a Agenda',
      onSecondary: () => context.go('/schedule'),
    );
  }

  /// Estado `error`: regra 2 do Interaction Contract. Falha de rede/servidor
  /// NUNCA cai em `not_found` — fail-closed em direção ao estado informativo,
  /// nunca ao conclusivo. Nenhuma mensagem crua de PostgREST na tela
  /// (T-02-16 / T-07-03).
  Widget _buildAccessErrorScreen(BuildContext context, Object error) {
    return _buildAccessStateScreen(
      context,
      icon: AppIcons.cloudOff,
      heading: 'Não foi possível carregar este evento.',
      supportingText: AppErrorHandler.userMessage(error, feature: 'events'),
      primaryIcon: AppIcons.refresh,
      primaryLabel: 'Tentar novamente',
      onPrimary: () {
        ref.invalidate(eventByIdProvider(widget.eventId));
        ref.invalidate(eventAccessStatusProvider(widget.eventId));
      },
      secondaryLabel: 'Voltar para a Agenda',
      onSecondary: () => context.go('/schedule'),
    );
  }

  /// Máquina de estados do `02-UI-SPEC.md`, alcançada só quando o evento
  /// resolveu `null` (restrito para mim OU inexistente).
  Widget _buildUnavailableScreen(BuildContext context) {
    // Sem sessão não se chama a RPC: `get_event_access_status` teve o
    // `EXECUTE` revogado de `anon` (migration `20260901000200`) justamente
    // para não virar oráculo de existência de evento para qualquer pessoa
    // com a publishable key. Chamar aqui devolveria `42501`, não um status.
    final semSessao =
        ref.watch(supabaseClientProvider).auth.currentSession == null;
    if (semSessao) {
      return _buildLoginRequiredScreen(context);
    }

    // COM sessão, quem sabe a diferença é o servidor. `'ok'`/`'login_required'`
    // são incoerentes com evento nulo aqui: caem em `error`, nunca em
    // `not_found` (regra 2 do Interaction Contract).
    final statusAsync = ref.watch(eventAccessStatusProvider(widget.eventId));
    return statusAsync.when(
      data: (status) {
        switch (status) {
          case 'restricted':
            return _buildRestrictedScreen(context);
          case 'not_found':
            return _buildNotFoundScreen(context);
          default:
            return _buildAccessErrorScreen(
              context,
              Exception(
                'Não foi possível confirmar o acesso a este evento. Tente novamente em instantes.',
              ),
            );
        }
      },
      loading: () => _buildLoadingScreen(context),
      error: (error, stack) => _buildAccessErrorScreen(context, error),
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
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    // Escalas: só a liderança dos ministérios (e o owner) vê a aba.
    final scaleScope = ref.watch(myScheduleMinistryIdsProvider);
    final showScales =
        scaleScope.hasValue && (scaleScope.value?.isNotEmpty ?? true);

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return _buildUnavailableScreen(context);
        }

        final tabs = [
          const AppTab(label: 'Informações'),
          AppTab(
            label: 'Inscritos',
            count: event.requiresRegistration
                ? '${event.registrationCount ?? 0}'
                : null,
          ),
          if (showScales) const AppTab(label: 'Escalas'),
        ];
        // A aba Escalas pode sumir depois de escolhida (escopo recarregado):
        // o índice volta a caber na lista.
        final selected = _tab.clamp(0, tabs.length - 1);

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
                icon: const Icon(AppIcons.back),
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
                    AppIcons.eventFilled,
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
                        'Evento',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.eventType ?? 'Detalhes do evento',
                        overflow: TextOverflow.ellipsis,
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
                icon: const Icon(AppIcons.share),
                onPressed: () => _isRegistrationShareEnabled(event)
                    ? _shareRegistrationLink(event)
                    : _shareEventInfoLink(event),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: AppTabs(
                  tabs: tabs,
                  selectedIndex: selected,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              // IndexedStack mantém as abas montadas: trocar de aba não perde
              // a rolagem de Inscritos/Escalas.
              Expanded(
                child: IndexedStack(
                  index: selected,
                  sizing: StackFit.expand,
                  children: [
                    _InfoTab(event: event),
                    _RegistrationsTab(event: event),
                    if (showScales) _SchedulesTab(eventId: event.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingScreen(context),
      // Estado de ERRO é distinto dos estados de acesso acima: aqui houve
      // falha real (rede/servidor) e o usuário pode tentar de novo. Nenhuma
      // mensagem crua de PostgREST na tela (T-07-03).
      error: (error, stack) => _buildAccessErrorScreen(context, error),
    );
  }
}

/// Aulas deste encontro de que eu sou professor ou aluno (as mesmas da
/// Agenda, que mostra o encontro no lugar delas). Sem nenhuma, nada.
class _EncounterLessons extends ConsumerWidget {
  final Event event;

  const _EncounterLessons({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = DateTime(event.startDate.year, event.startDate.month);
    final lessons = [
      for (final l
          in ref.watch(myTeachingLessonsOfMonthProvider(month)).valueOrNull ??
              const <TeachingLesson>[])
        if (l.eventId == event.id) l,
    ];
    if (lessons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aulas deste encontro', style: CommunityDesign.titleStyle(context)),
        const SizedBox(height: 12),
        for (final l in lessons)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TeachingLessonCard(lesson: l),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Tab de informações do evento
class _InfoTab extends ConsumerWidget {
  final Event event;

  const _InfoTab({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final mostraBarra = event.requiresRegistration && !event.isPast;
    final temDescricao =
        event.description != null && event.description!.isNotEmpty;

    // A barra de inscrição mora AQUI, abaixo da rolagem, e não no
    // bottomNavigationBar do Scaffold: assim ela só existe na aba
    // Informações e não colide com o PearlFab da aba Inscritos. Por ficar
    // fora da rolagem, nunca cobre o fim do conteúdo.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mostraBarra && myRegistration != null) ...[
                  const _RegisteredBanner(),
                  const SizedBox(height: 16),
                ],
                _EventMainCard(event: event),
                const SizedBox(height: 24),
                if (temDescricao) ...[
                  Text(
                    'Sobre o evento',
                    style: CommunityDesign.titleStyle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],
                if (event.eventType == 'aula') _EncounterLessons(event: event),
                if (event.courseId != null)
                  _CourseLinkCard(courseId: event.courseId!),
                _EventResponsibles(event: event),
              ],
            ),
          ),
        ),
        if (mostraBarra)
          EventRegistrationBar(
            event: event,
            registration: myRegistration,
            memberId: currentMember?.id,
          ),
      ],
    );
  }
}

/// Faixa "Você está inscrito" no topo da aba Informações.
class _RegisteredBanner extends StatelessWidget {
  const _RegisteredBanner();

  @override
  Widget build(BuildContext context) {
    final cor = AppStatusTone.active.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.checkCircle, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Você está inscrito',
              style: CommunityDesign.titleStyle(context).copyWith(color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card principal: imagem, selos, nome, data, local e vagas.
class _EventMainCard extends StatelessWidget {
  final Event event;

  const _EventMainCard({required this.event});

  static String _dataLonga(DateTime d) {
    final s = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _horario(Event e) {
    final inicio = DateFormat('HH:mm').format(e.startDate);
    final fim = e.endDate;
    if (fim == null) return inicio;
    if (DateUtils.isSameDay(fim, e.startDate)) {
      return '$inicio às ${DateFormat('HH:mm').format(fim)}';
    }
    return '$inicio · termina em '
        '${DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_BR').format(fim)}';
  }

  static Future<void> _abrirMapa(String local) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(local)}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Sem app de mapas/navegador: não há o que fazer além de não quebrar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final local = event.location?.trim();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.cardRadius),
              ),
              child: Image.network(
                event.imageUrl!,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(AppIcons.imageBroken, size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusChip(event: event),
                    _RestrictionBadge(event: event),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  event.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailLine(
                  icon: AppIcons.calendarFilled,
                  title: _dataLonga(event.startDate),
                  subtitle: _horario(event),
                ),
                if (local != null && local.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailLine(
                    icon: AppIcons.location,
                    title: local,
                    trailing: TextButton.icon(
                      onPressed: () => _abrirMapa(local),
                      icon: const Icon(AppIcons.map, size: 18),
                      label: const Text('Como chegar'),
                    ),
                  ),
                ],
                if (event.requiresRegistration) ...[
                  const SizedBox(height: 16),
                  _VacancyLine(event: event),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de vagas. IC-3 (REG-04): `maxCapacity == null` significa "sem
/// limite" e NUNCA pode ser tratado como zero. A UI só antecipa o teto;
/// quem decide a vaga é a RPC `register_member_in_event`.
class _VacancyLine extends StatelessWidget {
  final Event event;

  const _VacancyLine({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = event.registrationCount ?? 0;
    final maximo = event.maxCapacity;

    if (maximo == null) {
      return _DetailLine(
        icon: AppIcons.groupsFilled,
        title: '$total inscritos',
        subtitle: 'Sem limite de vagas',
      );
    }
    // Lotação nunca só por cor: ícone e texto próprios.
    if (event.isFull) {
      return _DetailLine(
        icon: AppIcons.eventBusy,
        color: colorScheme.error,
        title: 'Evento lotado',
        subtitle: '$total de $maximo vagas preenchidas',
      );
    }
    final restantes = (maximo - total).clamp(0, maximo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailLine(
          icon: AppIcons.groupsFilled,
          title: '$total de $maximo vagas',
          trailing: Text(
            '$restantes restantes',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: maximo == 0 ? 1 : (total / maximo).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Linha do card principal: ícone em quadrado, título, subtítulo e ação.
class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;

  const _DetailLine({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: cor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color ?? theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Responsáveis pelo evento (event_audience, role='responsible'). Só aparece
/// se houver algum com nome resolvido.
class _EventResponsibles extends ConsumerWidget {
  final Event event;

  const _EventResponsibles({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsaveis = ref
        .watch(eventResponsiblesProvider(event.id))
        .valueOrNull;
    if (responsaveis == null || responsaveis.isEmpty) {
      return const SizedBox.shrink();
    }
    final nomes = _nomesDosAlvos(ref, responsaveis, pessoas: true);
    if (nomes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Responsáveis', style: CommunityDesign.titleStyle(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final nome in nomes)
              Chip(
                avatar: const Icon(AppIcons.person, size: 18),
                label: Text(nome),
              ),
          ],
        ),
      ],
    );
  }
}

/// Barra fixa de inscrição da aba Informações.
///
/// T-08-01 — o gate de elegibilidade é UX, NÃO é boundary de segurança. A
/// autoridade é a RPC `register_member_in_event`, que reavalia a audiência
/// no servidor a cada tentativa.
///
/// T-08-05 — o ramo `error` mantém o botão HABILITADO de propósito: falha de
/// rede na RPC de elegibilidade não pode virar bloqueio para usuário
/// legítimo. Se ele realmente não puder, o servidor recusa.
@visibleForTesting
class EventRegistrationBar extends ConsumerWidget {
  final Event event;
  final EventRegistration? registration;
  final String? memberId;

  const EventRegistrationBar({
    super.key,
    required this.event,
    this.registration,
    this.memberId,
  });

  /// VIS-04: motivo único da recusa antecipada. Declarado uma vez para que o
  /// rótulo do botão e o tooltip nunca divirjam na explicação dada.
  static const String motivoInelegivel =
      'Inscrição restrita a grupos, ministérios, cargos ou turmas específicos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.surface.withValues(alpha: 0.94),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: registration != null
              ? _botao(
                  context,
                  icon: const Icon(AppIcons.qrCode),
                  label: 'Ver meu ingresso',
                  onTap: () => _mostrarIngresso(context),
                )
              : _cta(context, ref),
        ),
      ),
    );
  }

  Widget _cta(BuildContext context, WidgetRef ref) {
    final elegivel = ref
        .watch(amIEligibleToRegisterProvider(event.id))
        .when(
          data: (valor) => valor,
          loading: () => null, // desconhecido: desabilita com indicador
          error: (_, __) => true, // T-08-05: falha de rede não bloqueia
        );

    if (elegivel == null) {
      return _botao(
        context,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: 'Verificando sua inscrição...',
      );
    }
    if (!elegivel) {
      return Tooltip(
        message: motivoInelegivel,
        child: _botao(
          context,
          icon: const Icon(AppIcons.lock),
          label: motivoInelegivel,
        ),
      );
    }
    if (event.isFull) {
      return _botao(
        context,
        icon: const Icon(AppIcons.eventBusy),
        label: 'Evento lotado',
      );
    }
    return _botao(
      context,
      icon: const Icon(AppIcons.registration),
      label: 'Inscrever-se',
      onTap: () => context.push('/events/${event.id}/register'),
    );
  }

  /// Pílula de ~52 de altura. `onTap` nulo = desabilitado.
  Widget _botao(
    BuildContext context, {
    required Widget icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: PearlButton(
        width: double.infinity,
        height: 52,
        color: Theme.of(context).colorScheme.primary,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: const IconThemeData(color: Colors.white, size: 20),
                child: icon,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarIngresso(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seu ingresso',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(event.startDate),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Fundo branco sempre: leitor de QR precisa de contraste, também
              // no tema escuro.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data:
                      registration!.qrCode ??
                      'EVENT_TICKET:${event.id}:${memberId ?? ''}',
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Apresente este código na entrada.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etapa 4b da Formação (decisão 22/24): o evento que divulga um curso
/// abre o Curso, nunca pula direto para a turma. Enquanto carrega, ou se o
/// curso não voltar (RLS, removido), o card simplesmente não aparece.
class _CourseLinkCard extends ConsumerWidget {
  final String courseId;

  const _CourseLinkCard({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseByIdProvider(courseId)).valueOrNull;
    if (course == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/courses/$courseId/view'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(AppIcons.course, color: colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Curso',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ver curso',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  AppIcons.arrowForward,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// VIS-02/VIS-03: indicador de que o evento é restrito, e a quem.
///
/// T-08-03 (risco aceito): quem consegue renderizar este badge já passou
/// pela RLS de `public.event` — ou pertence a um dos alvos, ou é responsável
/// pelo evento, ou tem `events.edit`. Nenhum deles é terceiro não
/// autorizado, então exibir os nomes dos alvos aqui não é vazamento.
class _RestrictionBadge extends ConsumerWidget {
  final Event event;

  const _RestrictionBadge({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isEventRestricted(event)) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final audiencia = event.visibilityScope != 'all'
        ? ref
              .watch(
                eventAudienceProvider((eventId: event.id, role: 'visibility')),
              )
              .valueOrNull
        : null;
    final alvos = audiencia == null
        ? const <String>[]
        : _nomesDosAlvos(ref, audiencia);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.lock, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Restrito',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (alvos.isNotEmpty)
                  Text(
                    'Restrito a: ${alvos.join(', ')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
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

/// Resolve os nomes dos alvos de uma audiência (visibilidade no selo de
/// restrito, responsáveis na aba Informações). Best-effort por definição:
/// audiência ainda carregando, em erro, vazia ou com alvo cujo nome não foi
/// resolvido devolve lista vazia (ou omite o item), e o badge mostra apenas
/// "Restrito". Uuid cru NUNCA é exibido — não diz nada ao usuário e vaza
/// identificador interno.
///
/// Pessoas só entram com [pessoas] (responsáveis); no selo de restrito
/// continuam de fora, como antes.
List<String> _nomesDosAlvos(
  WidgetRef ref,
  List<EventAudience> audiencia, {
  bool pessoas = false,
}) {
  if (audiencia.isEmpty) return const [];

  // Cada catálogo só é consultado se houver alvo daquele tipo.
  final grupos =
      audiencia.any((a) => a.targetKind == EventAudienceTargetKind.group)
      ? {
          for (final g in ref.watch(allGroupsProvider).valueOrNull ?? [])
            g.id: g.name,
        }
      : const {};
  final ministerios =
      audiencia.any((a) => a.targetKind == EventAudienceTargetKind.ministry)
      ? {
          for (final m in ref.watch(allMinistriesProvider).valueOrNull ?? [])
            m.id: m.name,
        }
      : const {};
  final cargos =
      audiencia.any((a) => a.targetKind == EventAudienceTargetKind.role)
      ? {
          for (final c in ref.watch(allRolesProvider).valueOrNull ?? [])
            c.id: c.name,
        }
      : const {};
  final turmas =
      audiencia.any((a) => a.targetKind == EventAudienceTargetKind.turma)
      ? {
          for (final t
              in ref.watch(allStudyGroupsProvider).valueOrNull ?? [])
            t.id: t.name,
        }
      : const {};

  final pessoasPorId =
      pessoas &&
          audiencia.any((a) => a.targetKind == EventAudienceTargetKind.person)
      ? {
          for (final p in ref.watch(memberDirectoryProvider).valueOrNull ?? [])
            p.id: p.displayName,
        }
      : const {};

  final nomes = <String>[];
  for (final alvo in audiencia) {
    final nome = switch (alvo.targetKind) {
      EventAudienceTargetKind.group => grupos[alvo.groupId],
      EventAudienceTargetKind.ministry => ministerios[alvo.ministryId],
      // D-07: cargo desativado some de `allRolesProvider` mas continua
      // valendo como alvo — rótulo legível em vez de sumir ou virar uuid.
      EventAudienceTargetKind.role =>
        cargos[alvo.rbacRoleId] ?? 'Cargo desativado',
      EventAudienceTargetKind.turma => turmas[alvo.studyGroupId],
      EventAudienceTargetKind.person => pessoasPorId[alvo.userId],
    };
    if (nome is String && nome.trim().isNotEmpty) nomes.add(nome);
  }
  return nomes;
}

/// Chip de status do evento
class _StatusChip extends StatelessWidget {
  final Event event;

  const _StatusChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final tone = event.status == 'cancelled'
        ? AppStatusTone.dropped
        : event.status == 'completed' || event.isPast
        ? AppStatusTone.done
        : AppStatusTone.active;
    return StatusBadge(
      label: event.statusText,
      tone: tone,
      icon: AppIcons.event,
    );
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
        icon: AppIcons.info,
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
            icon: AppIcons.groupsFilled,
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
                      icon: const Icon(AppIcons.personAdd),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
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
                                    AppIcons.checkCircle,
                                    size: 16,
                                    color: _checkInColor,
                                  ),
                                  const SizedBox(width: 4),
                                  // Estado de check-in tem ícone E texto: nunca
                                  // transmitido só por cor.
                                  Text(
                                    'Check-in: ${DateFormat('dd/MM/yyyy HH:mm').format(registration.checkedInAt!)}',
                                    style: const TextStyle(
                                      color: _checkInColor,
                                    ),
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
                                        AppIcons.checkCircle,
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
                                        AppIcons.cancel,
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
                                      AppIcons.delete,
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
                child: PearlFab(
                  onPressed: event.isFull
                      ? null
                      : () => _showAddRegistrationDialog(context, event),
                  tooltip: event.isFull ? _lotadoTooltip : 'Adicionar inscrito',
                  icon: AppIcons.personAdd,
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _RegistrationsEmptyState(
        icon: AppIcons.error,
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
        // VIS-03: em evento restrito o diálogo lista só elegíveis; em evento
        // aberto continua usando o diretório de membros (REG-01 intacto).
        registrationScope: event.registrationScope,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Check-in realizado.')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inscrito removido.')));
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
        final scope = ref.watch(myScheduleMinistryIdsProvider).valueOrNull;
        for (final schedule in schedules) {
          if (scope != null && !scope.contains(schedule.ministryId)) continue;
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: EdgeInsets.zero,
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
                        const Icon(AppIcons.church, color: Colors.blue),
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
                              AppIcons.personAdd,
                              color: Colors.blue,
                            ),
                            title: const Text('Adicionar membro'),
                            subtitle: const Text(
                              'Adicionar/ajustar escala deste ministério',
                            ),
                            trailing: const Icon(AppIcons.forward, size: 16),
                            onTap: () =>
                                _openMinistryAutoScheduler(context, ministryId),
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ],
                      );
                    },
                  ),
                  if (ministrySchedules.isNotEmpty)
                    ...ministrySchedules.map((schedule) {
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(AppIcons.personFilled),
                        ),
                        title: Text(schedule.memberName),
                        subtitle: schedule.notes != null
                            ? Text(schedule.notes!)
                            : null,
                      );
                    }),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Lista de escalas agrupadas por ministério
            if (schedulesByMinistry.isEmpty)
              _EmptySchedulesContent(buildMinistryCard: buildMinistryCard)
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
  })
  buildMinistryCard;

  const _EmptySchedulesContent({required this.buildMinistryCard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);
    final scope = ref.watch(myScheduleMinistryIdsProvider).valueOrNull;

    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(AppIcons.calendarFilled, size: 48, color: Colors.grey[400]),
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
                  if (scope == null || scope.contains(m.id))
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
