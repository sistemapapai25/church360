import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Aba Escala do workspace: quem está escalado, por evento.
///
/// É a mesma informação da seção "Histórico de Escalas" da ficha do
/// ministério, na casca do workspace. As três portas de saída (gerar,
/// regras e histórico completo) continuam sendo as telas que já existem —
/// aqui elas viram ações da barra, protegidas por
/// `ministries.manage_schedule`, a mesma permissão que as guardava na ficha.
class MinistryScaleTab extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryScaleTab({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryScaleTab> createState() => _MinistryScaleTabState();
}

class _MinistryScaleTabState extends ConsumerState<MinistryScaleTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Agrupa por evento preservando a ordem em que as escalas chegaram do
  /// repositório — que já vem ordenada por data. Um `Map` comum em Dart
  /// mantém a ordem de inserção, então não é preciso reordenar aqui.
  List<_EventScale> _group(List<MinistrySchedule> schedules) {
    final query = _query.trim().toLowerCase();
    final byEvent = <String, _EventScale>{};

    for (final schedule in schedules) {
      final group = byEvent.putIfAbsent(
        schedule.eventId,
        () => _EventScale(
          eventId: schedule.eventId,
          eventName: schedule.eventName,
          startDate: schedule.eventStartDate,
          entries: [],
        ),
      );
      group.entries.add(schedule);
    }

    final groups = byEvent.values.toList();
    if (query.isEmpty) return groups;

    // A busca casa com o nome do evento OU com quem está escalado: quando a
    // pergunta é "onde a Lilian está escalada?", filtrar só por evento não
    // responde.
    return groups.where((g) {
      if (g.eventName.toLowerCase().contains(query)) return true;
      return g.entries.any((e) => e.memberName.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(
      ministrySchedulesProvider(widget.ministryId),
    );

    final canManage = ref
        .watch(currentUserHasPermissionProvider('ministries.manage_schedule'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return schedulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ScaleError(
        message: '$error',
        onRetry: () =>
            ref.invalidate(ministrySchedulesProvider(widget.ministryId)),
      ),
      data: (schedules) {
        final groups = _group(schedules);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ministrySchedulesProvider(widget.ministryId));
            await ref.read(ministrySchedulesProvider(widget.ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por evento ou pessoa...',
                onSearchChanged: (v) => setState(() => _query = v),
                secondaryActions: [
                  if (canManage)
                    AppFilterAction(
                      label: 'Regras',
                      icon: Icons.tune,
                      onPressed: () => context.push(
                        '/ministries/${widget.ministryId}/schedule-rules',
                      ),
                    ),
                ],
                primaryAction: canManage
                    ? AppFilterAction(
                        label: 'Gerar escala',
                        icon: Icons.hub,
                        onPressed: () => context.push(
                          '/ministries/${widget.ministryId}/auto-scheduler',
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              if (schedules.isEmpty)
                _EmptyState(
                  title: 'Nenhuma escala registrada',
                  description: canManage
                      ? 'Este ministério ainda não foi escalado para nenhum '
                            'evento. Use "Gerar escala" para montar a primeira.'
                      : 'Este ministério ainda não foi escalado para nenhum '
                            'evento.',
                )
              else if (groups.isEmpty)
                _EmptyState(
                  title: 'Nada encontrado',
                  description: 'Nenhum evento ou pessoa bate com "$_query".',
                )
              else ...[
                Text(
                  groups.length == 1
                      ? '1 evento com escala'
                      : '${groups.length} eventos com escala',
                  style: CommunityDesign.metaStyle(context),
                ),
                const SizedBox(height: 10),
                for (final group in groups) _EventScaleCard(group: group),
              ],
              if (canManage) ...[
                const SizedBox(height: 16),
                _ScaleHistoryLink(ministryId: widget.ministryId),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// As escalas de um evento, já agrupadas.
class _EventScale {
  final String eventId;
  final String eventName;
  final DateTime? startDate;
  final List<MinistrySchedule> entries;

  _EventScale({
    required this.eventId,
    required this.eventName,
    required this.startDate,
    required this.entries,
  });
}

class _EventScaleCard extends StatelessWidget {
  final _EventScale group;

  const _EventScaleCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;

    final count = group.entries.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CommunityDesign.cardSurfaceColor(colorScheme),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // O ExpansionTile do Material desenha um divisor próprio em cima e
        // embaixo; sem isso ele corta a borda do card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_outlined, size: 19, color: accent),
          ),
          title: Text(
            group.eventName.trim().isEmpty ? 'Evento' : group.eventName,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (_formatDate(group.startDate) != null)
                _formatDate(group.startDate)!,
              count == 1 ? '1 escalado' : '$count escalados',
            ].join(' · '),
            style: CommunityDesign.metaStyle(context),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            for (final entry in group.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.memberName.trim().isEmpty
                            ? 'Sem nome'
                            : entry.memberName,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 13),
                      ),
                    ),
                    if (entry.functionName != null &&
                        entry.functionName!.trim().isNotEmpty)
                      Text(
                        entry.functionName!,
                        style: CommunityDesign.metaStyle(context),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Formata sem `toLocal()` de propósito: as datas do sistema guardam hora
  /// de parede de São Paulo rotulada como UTC, então converter para o fuso
  /// do aparelho jogaria o evento três horas para trás.
  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(date);
  }
}

class _ScaleHistoryLink extends StatelessWidget {
  final String ministryId;

  const _ScaleHistoryLink({required this.ministryId});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;

    return InkWell(
      onTap: () => context.push('/ministries/$ministryId/scale-history'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abrir histórico completo',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Escalas anteriores, com filtro por período.',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: accent),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String description;

  const _EmptyState({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 36,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
        ],
      ),
    );
  }
}

class _ScaleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ScaleError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar as escalas.',
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
