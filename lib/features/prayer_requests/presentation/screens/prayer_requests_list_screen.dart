import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/prayer_request_provider.dart';
import '../../domain/models/prayer_request.dart';

/// Tela de listagem de pedidos de oração
class PrayerRequestsListScreen extends ConsumerStatefulWidget {
  const PrayerRequestsListScreen({super.key});

  @override
  ConsumerState<PrayerRequestsListScreen> createState() => _PrayerRequestsListScreenState();
}

class _PrayerRequestsListScreenState extends ConsumerState<PrayerRequestsListScreen> {
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
      appBar: AppBar(
        title: const Text('Pedidos de Oração'),
        actions: [
          // Filtro por status
          PopupMenuButton<PrayerStatus?>(
            icon: Icon(
              _selectedStatus != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _selectedStatus != null ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filtrar por status',
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
                _selectedCategory = null; // Limpar outro filtro
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Todos'),
              ),
              ...PrayerStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Text(status.icon),
                    const SizedBox(width: 8),
                    Text(status.displayName),
                  ],
                ),
              )),
            ],
          ),
          // Filtro por categoria
          PopupMenuButton<PrayerCategory?>(
            icon: Icon(
              _selectedCategory != null ? Icons.category : Icons.category_outlined,
              color: _selectedCategory != null ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filtrar por categoria',
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
                _selectedStatus = null; // Limpar outro filtro
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Todas'),
              ),
              ...PrayerCategory.values.map((category) => PopupMenuItem(
                value: category,
                child: Row(
                  children: [
                    Text(category.icon),
                    const SizedBox(width: 8),
                    Text(category.displayName),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: prayerRequestsAsync.when(
        data: (prayerRequests) {
          if (prayerRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum pedido de oração encontrado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compartilhe suas necessidades de oração',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar pedidos: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/prayer-requests/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Pedido'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/prayer-requests/${prayerRequest.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com categoria e status
              Row(
                children: [
                  // Categoria
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prayerRequest.category.icon),
                        const SizedBox(width: 4),
                        Text(
                          prayerRequest.category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(prayerRequest.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prayerRequest.status.icon),
                        const SizedBox(width: 4),
                        Text(
                          prayerRequest.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(prayerRequest.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Privacidade
                  Icon(
                    _getPrivacyIcon(prayerRequest.privacy),
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Título
              Text(
                prayerRequest.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Descrição (preview)
              Text(
                prayerRequest.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),

              // Footer com data e contador de orações
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    prayerRequest.timeAgo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  // Contador de orações
                  prayerCountAsync.when(
                    data: (count) => Row(
                      children: [
                        const Icon(Icons.favorite, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '$count ${count == 1 ? 'oração' : 'orações'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Color _getStatusColor(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.pending:
        return Colors.orange;
      case PrayerStatus.praying:
        return Colors.blue;
      case PrayerStatus.answered:
        return Colors.green;
      case PrayerStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getPrivacyIcon(PrayerPrivacy privacy) {
    switch (privacy) {
      case PrayerPrivacy.public:
        return Icons.public;
      case PrayerPrivacy.membersOnly:
        return Icons.people;
      case PrayerPrivacy.leadersOnly:
        return Icons.admin_panel_settings;
      case PrayerPrivacy.private:
        return Icons.lock;
    }
  }
}

