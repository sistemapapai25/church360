import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/testimony_provider.dart';
import '../../domain/models/testimony.dart';

/// Tela de listagem e gerenciamento de testemunhos (ADMIN)
class TestimoniesListScreen extends ConsumerWidget {
  const TestimoniesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testimoniesAsync = ref.watch(allTestimoniesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Testemunhos'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/testimonies/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Testemunho'),
      ),
      body: testimoniesAsync.when(
        data: (testimonies) {
          if (testimonies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum testemunho cadastrado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para criar o primeiro testemunho',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTestimoniesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: testimonies.length,
              itemBuilder: (context, index) {
                final testimony = testimonies[index];
                return _TestimonyCard(testimony: testimony);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar testemunhos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(allTestimoniesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: Card de Testemunho
// =====================================================

class _TestimonyCard extends ConsumerWidget {
  final Testimony testimony;

  const _TestimonyCard({required this.testimony});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/home/testimonies/${testimony.id}/edit'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Título + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      testimony.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge de visibilidade
                  _VisibilityBadge(isPublic: testimony.isPublic),
                ],
              ),
              const SizedBox(height: 8),

              // Descrição
              Text(
                testimony.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Informações adicionais
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  // Data de criação
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(testimony.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  // Contato WhatsApp
                  if (testimony.allowWhatsappContact)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Permite contato',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                              ),
                        ),
                      ],
                    ),
                ],
              ),

              // Ações
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botão Editar
                  TextButton.icon(
                    onPressed: () => context.push('/home/testimonies/${testimony.id}/edit'),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),

                  // Botão Deletar
                  TextButton.icon(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Testemunho'),
        content: Text('Deseja realmente excluir o testemunho "${testimony.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(testimonyRepositoryProvider);
                await repo.deleteTestimony(testimony.id);
                ref.invalidate(allTestimoniesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Testemunho excluído com sucesso!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// WIDGET: Badge de Visibilidade
// =====================================================

class _VisibilityBadge extends StatelessWidget {
  final bool isPublic;

  const _VisibilityBadge({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPublic ? Colors.green : Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 14,
            color: isPublic ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Público' : 'Privado',
            style: TextStyle(
              color: isPublic ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
