import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/devotional_provider.dart';
import '../../domain/models/devotional.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';

/// Tela de listagem de devocionais
class DevotionalsListScreen extends ConsumerStatefulWidget {
  const DevotionalsListScreen({super.key});

  @override
  ConsumerState<DevotionalsListScreen> createState() => _DevotionalsListScreenState();
}

class _DevotionalsListScreenState extends ConsumerState<DevotionalsListScreen> {
  bool _showDrafts = false;

  @override
  Widget build(BuildContext context) {
    // Verificar se é coordenador+ para mostrar rascunhos
    final isCoordinatorAsync = ref.watch(isCoordinatorOrAboveProvider);
    
    // Buscar devocionais
    final devotionalsAsync = _showDrafts
        ? ref.watch(allDevotionalsIncludingDraftsProvider)
        : ref.watch(allDevotionalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devocionais'),
        actions: [
          // Toggle para mostrar rascunhos (apenas Coordenadores+)
          isCoordinatorAsync.when(
            data: (isCoordinator) {
              if (!isCoordinator) return const SizedBox.shrink();
              
              return IconButton(
                icon: Icon(
                  _showDrafts ? Icons.visibility : Icons.visibility_off,
                  color: _showDrafts ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: _showDrafts ? 'Ocultar rascunhos' : 'Mostrar rascunhos',
                onPressed: () {
                  setState(() {
                    _showDrafts = !_showDrafts;
                  });
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: devotionalsAsync.when(
        data: (devotionals) {
          if (devotionals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum devocional encontrado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os devocionais aparecerão aqui',
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
            itemCount: devotionals.length,
            itemBuilder: (context, index) {
              final devotional = devotionals[index];
              return _DevotionalCard(devotional: devotional);
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
              Text('Erro ao carregar devocionais: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: CoordinatorOnlyWidget(
        child: FloatingActionButton.extended(
          onPressed: () {
            context.push('/devotionals/new');
          },
          icon: const Icon(Icons.add),
          label: const Text('Novo Devocional'),
        ),
      ),
    );
  }
}

/// Card de devocional
class _DevotionalCard extends ConsumerWidget {
  final Devotional devotional;

  const _DevotionalCard({required this.devotional});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Buscar se usuário já leu
    final hasReadAsync = ref.watch(hasUserReadDevotionalProvider(devotional.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/devotionals/${devotional.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com data e status
              Row(
                children: [
                  // Ícone de status
                  Icon(
                    devotional.isToday
                        ? Icons.today
                        : devotional.isFuture
                            ? Icons.schedule
                            : Icons.history,
                    size: 20,
                    color: devotional.isToday
                        ? Colors.green
                        : devotional.isFuture
                            ? Colors.orange
                            : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  // Data
                  Expanded(
                    child: Text(
                      devotional.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  // Badge de rascunho
                  if (!devotional.isPublished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RASCUNHO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  // Badge de lido
                  hasReadAsync.when(
                    data: (hasRead) {
                      if (!hasRead) return const SizedBox.shrink();
                      
                      return Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'LIDO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Título
              Text(
                devotional.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Referência bíblica
              if (devotional.scriptureReference != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      devotional.scriptureReference!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Preview do conteúdo
              Text(
                devotional.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

