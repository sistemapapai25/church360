import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/support_material_module.dart';
import '../providers/support_materials_provider.dart';

/// Tela de visualização de módulo individual
class ModuleViewerScreen extends ConsumerWidget {
  final String materialId;
  final String moduleId;

  const ModuleViewerScreen({
    super.key,
    required this.materialId,
    required this.moduleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(modulesByMaterialProvider(materialId));

    return Scaffold(
      body: modulesAsync.when(
        data: (modules) {
          // Encontra o módulo atual
          final moduleIndex = modules.indexWhere((m) => m.id == moduleId);
          if (moduleIndex == -1) {
            return const Center(child: Text('Módulo não encontrado'));
          }

          final module = modules[moduleIndex];
          final moduleNumber = moduleIndex + 1;

          return CustomScrollView(
            slivers: [
              // App Bar com capa
              _buildAppBar(context, module, moduleNumber, modules.length),

              // Conteúdo
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações do módulo
                    _buildModuleInfo(module, moduleNumber),

                    const Divider(height: 32),

                    // Conteúdo/Transcrição
                    if (module.content != null && module.content!.isNotEmpty)
                      _buildContent(module.content!),

                    // Botões de ação
                    _buildActionButtons(context, module),

                    const SizedBox(height: 32),

                    // Navegação entre módulos
                    _buildModuleNavigation(
                      context,
                      modules,
                      moduleIndex,
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
              Text('Erro ao carregar módulo: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    SupportMaterialModule module,
    int moduleNumber,
    int totalModules,
  ) {
    return SliverAppBar(
      expandedHeight: module.coverImageUrl != null ? 250 : 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Módulo $moduleNumber',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ],
          ),
        ),
        background: module.coverImageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    module.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.blue.shade700,
                        child: const Icon(
                          Icons.book,
                          size: 80,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  // Gradiente para melhorar legibilidade
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
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade700,
                      Colors.blue.shade900,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.book,
                  size: 60,
                  color: Colors.white70,
                ),
              ),
      ),
    );
  }

  Widget _buildModuleInfo(SupportMaterialModule module, int moduleNumber) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge com número do módulo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Módulo $moduleNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Text(
            module.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Descrição (se houver)
          if (module.description != null && module.description!.isNotEmpty)
            Text(
              module.description!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conteúdo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SupportMaterialModule module) {
    final hasFile = module.fileUrl != null && module.fileUrl!.isNotEmpty;
    final hasVideo = module.videoUrl != null && module.videoUrl!.isNotEmpty;

    if (!hasFile && !hasVideo) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ações',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (hasFile)
                ElevatedButton.icon(
                  onPressed: () => _launchUrl(module.fileUrl!),
                  icon: const Icon(Icons.download),
                  label: Text(module.fileName ?? 'Baixar Arquivo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              if (hasVideo)
                ElevatedButton.icon(
                  onPressed: () => _launchUrl(module.videoUrl!),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Assistir Vídeo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleNavigation(
    BuildContext context,
    List<SupportMaterialModule> modules,
    int currentIndex,
  ) {
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < modules.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Botão Anterior
          Expanded(
            child: hasPrevious
                ? OutlinedButton.icon(
                    onPressed: () {
                      final previousModule = modules[currentIndex - 1];
                      context.push(
                        '/support-materials/$materialId/modules/${previousModule.id}',
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
          // Botão Próximo
          Expanded(
            child: hasNext
                ? ElevatedButton.icon(
                    onPressed: () {
                      final nextModule = modules[currentIndex + 1];
                      context.push(
                        '/support-materials/$materialId/modules/${nextModule.id}',
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Próximo'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
