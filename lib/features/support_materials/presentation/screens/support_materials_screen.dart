import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/support_materials_provider.dart';
import '../../domain/models/support_material.dart';

/// Tela de listagem de materiais de apoio
class SupportMaterialsScreen extends ConsumerWidget {
  const SupportMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(allMaterialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material de Apoio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/support-materials/new');
            },
            tooltip: 'Novo Material',
          ),
        ],
      ),
      body: materialsAsync.when(
        data: (materials) {
          if (materials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum material cadastrado',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/support-materials/new');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Material'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return _MaterialCard(material: material);
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
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allMaterialsProvider);
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de material
class _MaterialCard extends ConsumerWidget {
  final SupportMaterial material;

  const _MaterialCard({required this.material});

  IconData _getIconForType(SupportMaterialType type) {
    switch (type) {
      case SupportMaterialType.pdf:
        return Icons.picture_as_pdf;
      case SupportMaterialType.powerpoint:
        return Icons.slideshow;
      case SupportMaterialType.video:
        return Icons.video_library;
      case SupportMaterialType.text:
        return Icons.article;
      case SupportMaterialType.audio:
        return Icons.audiotrack;
      case SupportMaterialType.link:
        return Icons.link;
      case SupportMaterialType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(SupportMaterialType type) {
    switch (type) {
      case SupportMaterialType.pdf:
        return Colors.red;
      case SupportMaterialType.powerpoint:
        return Colors.orange;
      case SupportMaterialType.video:
        return Colors.blue;
      case SupportMaterialType.text:
        return Colors.green;
      case SupportMaterialType.audio:
        return Colors.purple;
      case SupportMaterialType.link:
        return Colors.teal;
      case SupportMaterialType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/support-materials/${material.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícone do tipo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getColorForType(material.materialType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForType(material.materialType),
                      color: _getColorForType(material.materialType),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Título e tipo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getColorForType(material.materialType),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                material.materialType.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (material.category != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                material.category!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menu de ações
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'modules',
                        child: Row(
                          children: [
                            Icon(Icons.library_books, size: 20),
                            SizedBox(width: 8),
                            Text('Gerenciar Módulos'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'modules') {
                        context.push('/support-materials/${material.id}/modules?title=${Uri.encodeComponent(material.title)}');
                      } else if (value == 'edit') {
                        context.push('/support-materials/${material.id}/edit');
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, ref);
                      }
                    },
                  ),
                ],
              ),
              if (material.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  material.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (material.author != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      material.author!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              // Informações adicionais
              const SizedBox(height: 12),
              Row(
                children: [
                  if (material.fileSize != null) ...[
                    Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      material.formattedFileSize,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (material.videoDuration != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      material.formattedVideoDuration,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
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
        title: const Text('Excluir Material'),
        content: Text('Deseja realmente excluir "${material.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repository = ref.read(supportMaterialsRepositoryProvider);
              try {
                await repository.deleteMaterial(material.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Material excluído com sucesso')),
                );
                ref.invalidate(allMaterialsProvider);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao excluir: $e')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
