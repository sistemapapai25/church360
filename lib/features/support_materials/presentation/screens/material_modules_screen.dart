import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/support_materials_provider.dart';
import '../../domain/models/support_material_module.dart';
import '../../../../core/widgets/file_upload_widget.dart';
import '../../../../core/widgets/video_upload_widget.dart';
import '../../../../core/widgets/image_upload_widget.dart';

/// Tela de gerenciamento de módulos/capítulos de um material
class MaterialModulesScreen extends ConsumerStatefulWidget {
  final String materialId;
  final String materialTitle;

  const MaterialModulesScreen({
    super.key,
    required this.materialId,
    required this.materialTitle,
  });

  @override
  ConsumerState<MaterialModulesScreen> createState() => _MaterialModulesScreenState();
}

class _MaterialModulesScreenState extends ConsumerState<MaterialModulesScreen> {
  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(modulesByMaterialProvider(widget.materialId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Módulos/Capítulos'),
            Text(
              widget.materialTitle,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModuleDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Novo Módulo'),
      ),
      body: modulesAsync.when(
        data: (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum módulo cadastrado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicione módulos/capítulos para organizar o conteúdo',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            onReorder: (oldIndex, newIndex) => _reorderModules(modules, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Card(
                key: ValueKey(module.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    module.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: module.content != null
                      ? Text(
                          module.content!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (module.videoUrl != null)
                        const Icon(Icons.video_library, color: Colors.blue),
                      if (module.fileUrl != null)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.attach_file, color: Colors.green),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showModuleDialog(context, module),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteModule(module.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erro ao carregar módulos: $error'),
        ),
      ),
    );
  }

  Future<void> _reorderModules(
    List<SupportMaterialModule> modules,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final repository = ref.read(supportMaterialsRepositoryProvider);
    
    // Criar nova lista com a ordem atualizada
    final reorderedModules = List<SupportMaterialModule>.from(modules);
    final module = reorderedModules.removeAt(oldIndex);
    reorderedModules.insert(newIndex, module);

    // Atualizar order_index de todos os módulos
    for (int i = 0; i < reorderedModules.length; i++) {
      await repository.updateModule(
        reorderedModules[i].id,
        {'order_index': i},
      );
    }

    // Invalidar provider
    ref.invalidate(modulesByMaterialProvider(widget.materialId));
  }

  Future<void> _deleteModule(String moduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja realmente excluir este módulo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(supportMaterialsRepositoryProvider);
        await repository.deleteModule(moduleId);
        
        ref.invalidate(modulesByMaterialProvider(widget.materialId));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Módulo excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir módulo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showModuleDialog(BuildContext context, SupportMaterialModule? module) {
    showDialog(
      context: context,
      builder: (context) => ModuleFormDialog(
        materialId: widget.materialId,
        module: module,
        onSaved: () {
          ref.invalidate(modulesByMaterialProvider(widget.materialId));
        },
      ),
    );
  }
}

/// Dialog para criar/editar módulo
class ModuleFormDialog extends ConsumerStatefulWidget {
  final String materialId;
  final SupportMaterialModule? module;
  final VoidCallback onSaved;

  const ModuleFormDialog({
    super.key,
    required this.materialId,
    this.module,
    required this.onSaved,
  });

  @override
  ConsumerState<ModuleFormDialog> createState() => _ModuleFormDialogState();
}

class _ModuleFormDialogState extends ConsumerState<ModuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _fileUrl;
  String? _videoUrl;
  String? _coverImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _titleController.text = widget.module!.title;
      _contentController.text = widget.module!.content ?? '';
      _fileUrl = widget.module!.fileUrl;
      _videoUrl = widget.module!.videoUrl;
      _coverImageUrl = widget.module!.coverImageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(supportMaterialsRepositoryProvider);
      
      final data = {
        'material_id': widget.materialId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        'file_url': _fileUrl,
        'video_url': _videoUrl,
        'cover_image_url': _coverImageUrl,
      };

      if (widget.module == null) {
        // Criar novo
        await repository.createModule(data);
      } else {
        // Atualizar existente
        await repository.updateModule(widget.module!.id, data);
      }

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.module == null
                  ? 'Módulo criado com sucesso!'
                  : 'Módulo atualizado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar módulo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.module == null ? 'Novo Módulo' : 'Editar Módulo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Título
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título do Módulo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Título é obrigatório';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Upload de Capa
                    ImageUploadWidget(
                      initialImageUrl: _coverImageUrl,
                      onImageUrlChanged: (url) => setState(() => _coverImageUrl = url),
                      storageBucket: 'support-material-covers',
                      label: 'Capa do Módulo (Opcional)',
                    ),
                    const SizedBox(height: 16),

                    // Conteúdo/Transcrição
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Conteúdo/Transcrição',
                        border: OutlineInputBorder(),
                        hintText: 'Digite ou cole o conteúdo aqui...',
                        helperText: 'Texto do módulo, transcrição, anotações, etc.',
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 16),

                    // Upload de Arquivo
                    FileUploadWidget(
                      initialFileUrl: _fileUrl,
                      onFileUrlChanged: (url, name) => setState(() => _fileUrl = url),
                      storageBucket: 'support-material-files',
                      label: 'Arquivo do Módulo (Opcional)',
                      allowedExtensions: const [
                        'pdf',
                        'ppt',
                        'pptx',
                        'doc',
                        'docx',
                        'xls',
                        'xlsx',
                        'txt',
                        'mp3',
                        'wav',
                      ],
                      icon: Icons.attach_file,
                    ),
                    const SizedBox(height: 16),

                    // Upload de Vídeo ou Link do YouTube
                    VideoUploadWidget(
                      initialVideoUrl: _videoUrl,
                      onVideoUrlChanged: (url) => setState(() => _videoUrl = url),
                      storageBucket: 'support-material-videos',
                      label: 'Vídeo Explicativo (Opcional)',
                      allowYouTubeLink: true,
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
