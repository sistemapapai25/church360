import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/prayer_request_provider.dart';
import '../../domain/models/prayer_request.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de listagem de pedidos de oração
class PrayerRequestsListScreen extends ConsumerStatefulWidget {
  const PrayerRequestsListScreen({super.key});

  @override
  ConsumerState<PrayerRequestsListScreen> createState() =>
      _PrayerRequestsListScreenState();
}

class _PrayerRequestsListScreenState
    extends ConsumerState<PrayerRequestsListScreen> {
  PrayerStatus? _selectedStatus;
  PrayerCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    // Buscar pedidos baseado nos filtros
    final prayerRequestsAsync = _selectedStatus != null
        ? ref.watch(prayerRequestsByStatusProvider(_selectedStatus!))
        : _selectedCategory != null
        ? ref.watch(prayerRequestsByCategoryProvider(_selectedCategory!))
        : ref.watch(allPrayerRequestsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        title: Text(
          'Pedidos de Oração',
          style: CommunityDesign.titleStyle(context),
        ),
        actions: [
          // Filtro por status
          PopupMenuButton<PrayerStatus?>(
            icon: Icon(
              _selectedStatus != null ? AppIcons.filter : AppIcons.filterOff,
              color: _selectedStatus != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Filtrar por status',
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
                _selectedCategory = null; // Limpar outro filtro
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              ...PrayerStatus.values.map(
                (status) => PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Text(status.icon),
                      const SizedBox(width: 8),
                      Text(status.displayName),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Filtro por categoria
          PopupMenuButton<PrayerCategory?>(
            icon: Icon(
              _selectedCategory != null
                  ? AppIcons.category
                  : AppIcons.categoryIcon,
              color: _selectedCategory != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Filtrar por categoria',
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
                _selectedStatus = null; // Limpar outro filtro
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todas')),
              ...PrayerCategory.values.map(
                (category) => PopupMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: prayerRequestsAsync.when(
        data: (prayerRequests) {
          if (prayerRequests.isEmpty) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.favorite,
                        size: 56,
                        color: cs.primary.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum pedido de oração encontrado',
                        style: CommunityDesign.titleStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Compartilhe suas necessidades de oração',
                        style: CommunityDesign.contentStyle(
                          context,
                        ).copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prayerRequests.length,
            itemBuilder: (context, index) {
              final prayerRequest = prayerRequests[index];
              return _PrayerRequestCard(prayerRequest: prayerRequest);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar pedidos: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: PermissionGate(
        permission: 'prayer_requests.create',
        child: PearlFab(
          onPressed: () {
            context.push('/prayer-requests/new');
          },
          color: Theme.of(context).colorScheme.primary,
          icon: AppIcons.add,
          label: 'Novo Pedido'.toUpperCase(),
        ),
      ),
    );
  }
}

/// Card de pedido de oração
class _PrayerRequestCard extends ConsumerWidget {
  final PrayerRequest prayerRequest;

  const _PrayerRequestCard({required this.prayerRequest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Buscar contador de orações
    final prayerCountAsync = ref.watch(prayerCountProvider(prayerRequest.id));

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () {
          context.push('/prayer-requests/${prayerRequest.id}');
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com categoria e status
            Row(
              children: [
                // Categoria
                CommunityDesign.badge(
                  context,
                  prayerRequest.category.displayName,
                  cs.primary,
                  icon: AppIcons.category,
                ),
                const SizedBox(width: 8),
                // Status
                StatusBadge(
                  label: prayerRequest.status.displayName,
                  tone: _getStatusTone(prayerRequest.status),
                  icon: _getStatusIcon(prayerRequest.status),
                ),
                const Spacer(),
                // Privacidade
                Icon(
                  _getPrivacyIcon(prayerRequest.privacy),
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Título
            Text(
              prayerRequest.title,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Descrição (preview)
            Text(
              prayerRequest.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CommunityDesign.contentStyle(context).copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Footer com data e contador de orações
            Row(
              children: [
                Icon(
                  AppIcons.accessTime,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  prayerRequest.timeAgo,
                  style: CommunityDesign.metaStyle(context),
                ),
                const Spacer(),
                // Contador de orações
                prayerCountAsync.when(
                  data: (count) => Row(
                    children: [
                      const Icon(
                        AppIcons.favorite,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count ${count == 1 ? 'oração' : 'orações'}',
                        style: CommunityDesign.metaStyle(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AppStatusTone _getStatusTone(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
      case PrayerStatus.praying:
        return AppStatusTone.active;
      case PrayerStatus.answered:
        return AppStatusTone.done;
      case PrayerStatus.cancelled:
        return AppStatusTone.dropped;
    }
  }

  IconData _getStatusIcon(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
        return AppIcons.pending;
      case PrayerStatus.praying:
        return AppIcons.favorite;
      case PrayerStatus.answered:
        return AppIcons.checkCircle;
      case PrayerStatus.cancelled:
        return AppIcons.cancel;
    }
  }

  IconData _getPrivacyIcon(PrayerPrivacy privacy) {
    switch (privacy) {
      case PrayerPrivacy.public:
        return AppIcons.public;
      case PrayerPrivacy.membersOnly:
        return AppIcons.groups;
      case PrayerPrivacy.leadersOnly:
        return AppIcons.admin;
      case PrayerPrivacy.private:
        return AppIcons.lock;
    }
  }
}
