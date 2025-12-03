import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/support_material.dart';
import '../../domain/models/support_material_module.dart';
import '../providers/support_materials_provider.dart';

/// Tela de visualização de material de apoio
class MaterialViewerScreen extends ConsumerStatefulWidget {
  final String materialId;

  const MaterialViewerScreen({
    super.key,
    required this.materialId,
  });

  @override
  ConsumerState<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends ConsumerState<MaterialViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final materialAsync = ref.watch(materialByIdProvider(widget.materialId));
    final modulesAsync = ref.watch(modulesByMaterialProvider(widget.materialId));

    return Scaffold(
      body: materialAsync.when(
        data: (material) {
          if (material == null) {
            return const Center(child: Text('Material não encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, material),

              // Conteúdo
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações do material
                    _buildMaterialInfo(material),

                    const Divider(height: 32),

                    // Lista de Módulos
                    modulesAsync.when(
                      data: (modules) {
                        if (modules.isEmpty) {
                          return _buildNoModulesContent();
                        }
                        return _buildModulesList(modules);
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('Erro ao carregar módulos: $error'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar material: $error'),
            ],
          ),
        ),
      ),
    );
  }

  /// App Bar com capa do material
  Widget _buildAppBar(BuildContext context, SupportMaterial material) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          material.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Capa do material (se tiver)
            if (material.coverImageUrl != null)
              Image.network(
                material.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultCover(material);
                },
              )
            else
              _buildDefaultCover(material),

            // Gradiente para melhorar legibilidade do título
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Botão de editar
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            context.push('/support-materials/${material.id}/edit');
          },
        ),
        // Botão de gerenciar módulos
        IconButton(
          icon: const Icon(Icons.library_books),
          onPressed: () {
            context.push(
              '/support-materials/${material.id}/modules?title=${Uri.encodeComponent(material.title)}',
            );
          },
        ),
      ],
    );
  }

  /// Capa padrão quando não há imagem
  Widget _buildDefaultCover(SupportMaterial material) {
    final color = _getColorForType(material.materialType);
    return Container(
      color: color,
      child: Center(
        child: Icon(
          _getIconForType(material.materialType),
          size: 80,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Lista de módulos disponíveis (vertical)
  Widget _buildModulesList(List<SupportMaterialModule> modules) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Módulos/Capítulos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${modules.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Lista vertical de módulos
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final module = modules[index];
              final moduleNumber = index + 1;
              return _buildModuleListItem(module, moduleNumber);
            },
          ),
        ],
      ),
    );
  }

  /// Item da lista de módulos
  Widget _buildModuleListItem(SupportMaterialModule module, int moduleNumber) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push(
            '/support-materials/${widget.materialId}/modules/${module.id}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Capa do módulo ou placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.shade100,
                ),
                child: module.coverImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          module.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.book,
                              size: 40,
                              color: Colors.blue.shade700,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.book,
                        size: 40,
                        color: Colors.blue.shade700,
                      ),
              ),
              const SizedBox(width: 16),
              // Informações do módulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge com número
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Módulo $moduleNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Título
                    Text(
                      module.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (module.description != null &&
                        module.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        module.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Ícone de navegação
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Informações do material
  Widget _buildMaterialInfo(SupportMaterial material) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo e autor
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getColorForType(material.materialType),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  material.materialType.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (material.author != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Por ${material.author}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),

          // Descrição
          if (material.description != null) ...[
            const SizedBox(height: 16),
            Text(
              material.description!,
              style: const TextStyle(fontSize: 16),
            ),
          ],

          // Botões de ação
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Download de arquivo
              if (material.fileUrl != null)
                ElevatedButton.icon(
                  onPressed: () => _downloadFile(material.fileUrl!),
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar Arquivo'),
                ),

              // Abrir vídeo
              if (material.videoUrl != null)
                ElevatedButton.icon(
                  onPressed: () => _openVideo(material.videoUrl!),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Assistir Vídeo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mensagem quando não há módulos
  Widget _buildNoModulesContent() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum módulo cadastrado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione módulos para organizar o conteúdo deste material',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
