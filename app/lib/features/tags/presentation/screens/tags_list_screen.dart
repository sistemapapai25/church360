import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tags_provider.dart';
import '../../data/tags_repository.dart';
import 'tag_form_screen.dart';

/// Tela de listagem de tags
class TagsListScreen extends ConsumerWidget {
  const TagsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma tag encontrada',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TagFormScreen(),
                        ),
                      );
                      ref.invalidate(allTagsProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Primeira Tag'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTagsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tag.colorValue,
                      child: const Icon(Icons.label, color: Colors.white),
                    ),
                    title: Text(
                      tag.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tag.category != null)
                          Text('Categoria: ${tag.category}'),
                        Text('${tag.memberCount ?? 0} membros'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TagFormScreen(tagId: tag.id),
                              ),
                            );
                            ref.invalidate(allTagsProvider);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(context, ref, tag),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar tags: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allTagsProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TagFormScreen(),
            ),
          );
          ref.invalidate(allTagsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Tag'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, dynamic tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a tag "${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(tagsRepositoryProvider).deleteTag(tag.id);
        ref.invalidate(allTagsProvider);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag excluída com sucesso!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir tag: $e')),
          );
        }
      }
    }
  }
}

