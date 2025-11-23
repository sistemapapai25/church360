import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/support_materials_provider.dart';
import '../../domain/models/support_material.dart';
import '../../domain/models/support_material_link.dart';
import '../../../../core/widgets/file_upload_widget.dart';
import '../../../../core/widgets/video_upload_widget.dart';
import '../widgets/entity_selector_dialog.dart';

/// Tela de formulário de material de apoio
class SupportMaterialFormScreen extends ConsumerStatefulWidget {
  final String? materialId;

  const SupportMaterialFormScreen({
    super.key,
    this.materialId,
  });

  @override
  ConsumerState<SupportMaterialFormScreen> createState() => _SupportMaterialFormScreenState();
}

class _SupportMaterialFormScreenState extends ConsumerState<SupportMaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _externalLinkController = TextEditingController();
  
  // State
  SupportMaterialType _materialType = SupportMaterialType.text;
  bool _isPublic = false;
  bool _isLoading = false;
  String? _fileUrl;
  String? _videoUrl;

  // Vinculações selecionadas
  final Map<MaterialLinkType, Map<String, String>> _selectedEntities = {};
  // MaterialLinkType -> {entityId: entityName}

  @override
  void initState() {
    super.initState();
    if (widget.materialId != null) {
      _loadMaterial();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    _externalLinkController.dispose();
    super.dispose();
  }

  /// Abre o dialog de seleção de entidades
  Future<void> _showEntitySelector(MaterialLinkType linkType) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EntitySelectorDialog(
        linkType: linkType,
        initialSelectedIds: _selectedEntities[linkType]?.keys.toList() ?? [],
      ),
    );

    if (result != null) {
      setState(() {
        final ids = result['ids'] as List<String>;
        final names = result['names'] as Map<String, String>;

        if (ids.isEmpty) {
          _selectedEntities.remove(linkType);
        } else {
          _selectedEntities[linkType] = names;
        }
      });
    }
  }

  /// Retorna o ícone para cada tipo de vinculação
  IconData _getIconForLinkType(MaterialLinkType linkType) {
    switch (linkType) {
      case MaterialLinkType.communionGroup:
        return Icons.group;
      case MaterialLinkType.course:
        return Icons.school;
      case MaterialLinkType.event:
        return Icons.event;
      case MaterialLinkType.ministry:
        return Icons.volunteer_activism;
      case MaterialLinkType.studyGroup:
        return Icons.menu_book;
      case MaterialLinkType.general:
        return Icons.public;
    }
  }

  /// Salva as vinculações do material
  Future<void> _saveLinks(dynamic repository, String materialId) async {
    // Deletar vinculações antigas
    await repository.deleteLinksByMaterial(materialId);

    // Criar novas vinculações
    for (final entry in _selectedEntities.entries) {
      final linkType = entry.key;
      final entities = entry.value;

      for (final entityId in entities.keys) {
        await repository.createLink({
          'material_id': materialId,
          'link_type': linkType.value,
          'linked_entity_id': entityId,
        });
      }
    }
  }

  Future<void> _loadMaterial() async {
    if (widget.materialId == null) return;

    final material = await ref.read(
      materialByIdProvider(widget.materialId!).future,
    );

    if (material != null && mounted) {
      setState(() {
        _titleController.text = material.title;
        _descriptionController.text = material.description ?? '';
        _authorController.text = material.author ?? '';
        _categoryController.text = material.category ?? '';
        _contentController.text = material.content ?? '';
        _videoUrlController.text = material.videoUrl ?? '';
        _externalLinkController.text = material.externalLink ?? '';
        _materialType = material.materialType;
        _isPublic = material.isPublic;
        _fileUrl = material.fileUrl;
        _videoUrl = material.videoUrl;
      });

      // Carregar vinculações
      await _loadLinks();
    }
  }

  /// Carrega as vinculações existentes do material
  Future<void> _loadLinks() async {
    if (widget.materialId == null) return;

    try {
      final links = await ref.read(
        linksByMaterialProvider(widget.materialId!).future,
      );

      if (links.isNotEmpty && mounted) {
        // Agrupar links por tipo
        final Map<MaterialLinkType, Map<String, String>> groupedLinks = {};

        for (final link in links) {
          if (!groupedLinks.containsKey(link.linkType)) {
            groupedLinks[link.linkType] = {};
          }
          // Aqui precisamos buscar o nome da entidade
          // Por enquanto vou usar o ID como nome, depois podemos melhorar
          groupedLinks[link.linkType]![link.linkedEntityId] = link.linkedEntityId;
        }

        setState(() {
          _selectedEntities.addAll(groupedLinks);
        });
      }
    } catch (e) {
      // Ignorar erro ao carregar links
      debugPrint('Erro ao carregar vinculações: $e');
    }
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(supportMaterialsRepositoryProvider);
      
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'author': _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        'category': _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        'material_type': _materialType.value,
        'content': _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        'file_url': _fileUrl,
        'video_url': _videoUrl ?? (_videoUrlController.text.trim().isEmpty
            ? null
            : _videoUrlController.text.trim()),
        'external_link': _externalLinkController.text.trim().isEmpty
            ? null
            : _externalLinkController.text.trim(),
        'is_public': _isPublic,
      };

      String materialId;

      if (widget.materialId == null) {
        // Criar novo
        final material = await repository.createMaterial(data);
        materialId = material.id;
      } else {
        // Atualizar existente
        materialId = widget.materialId!;
        await repository.updateMaterial(materialId, data);
      }

      // Salvar vinculações
      await _saveLinks(repository, materialId);

      // Invalidar providers
      ref.invalidate(allMaterialsProvider);
      ref.invalidate(materialByIdProvider(materialId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.materialId == null
                  ? 'Material criado com sucesso!'
                  : 'Material atualizado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar material: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.materialId == null ? 'Novo Material' : 'Editar Material',
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveMaterial,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
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

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Autor
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Autor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Categoria
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                hintText: 'Ex: Discipulado, Batismo, etc',
              ),
            ),
            const SizedBox(height: 16),

            // Tipo de Material
            DropdownMenu<SupportMaterialType>(
              initialSelection: _materialType,
              label: const Text('Tipo de Material *'),
              leadingIcon: const Icon(Icons.type_specimen),
              dropdownMenuEntries: SupportMaterialType.values
                  .map((type) => DropdownMenuEntry<SupportMaterialType>(value: type, label: type.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() => _materialType = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Campos específicos por tipo
            _buildTypeSpecificFields(),

            const SizedBox(height: 24),

            // Público/Privado
            SwitchListTile(
              title: const Text('Material Público'),
              subtitle: const Text(
                'Se marcado, o material estará disponível para todos',
              ),
              value: _isPublic,
              onChanged: (value) {
                setState(() => _isPublic = value);
              },
            ),
            const SizedBox(height: 24),

            // Seção de Vinculações
            _buildLinksSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_materialType) {
      case SupportMaterialType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conteúdo Transcrito',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Conteúdo',
                border: OutlineInputBorder(),
                hintText: 'Digite ou cole o conteúdo aqui...',
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16),
            // Vídeo explicativo (opcional)
            VideoUploadWidget(
              initialVideoUrl: _videoUrl,
              onVideoUrlChanged: (url) {
                setState(() {
                  _videoUrl = url;
                });
              },
              storageBucket: 'support-material-videos',
              label: 'Vídeo Explicativo (Opcional)',
            ),
          ],
        );

      case SupportMaterialType.video:
        return VideoUploadWidget(
          initialVideoUrl: _videoUrl,
          onVideoUrlChanged: (url) {
            setState(() {
              _videoUrl = url;
            });
          },
          storageBucket: 'support-material-videos',
          label: 'Vídeo',
        );

      case SupportMaterialType.link:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link Externo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _externalLinkController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'https://...',
              ),
            ),
          ],
        );

      case SupportMaterialType.pdf:
        return Column(
          children: [
            FileUploadWidget(
              initialFileUrl: _fileUrl,
              onFileUrlChanged: (url, name) {
                setState(() {
                  _fileUrl = url;
                });
              },
              storageBucket: 'support-material-files',
              label: 'Arquivo PDF',
              allowedExtensions: const ['pdf'],
              icon: Icons.picture_as_pdf,
            ),
            const SizedBox(height: 16),
            // Vídeo explicativo (opcional)
            VideoUploadWidget(
              initialVideoUrl: _videoUrl,
              onVideoUrlChanged: (url) {
                setState(() {
                  _videoUrl = url;
                });
              },
              storageBucket: 'support-material-videos',
              label: 'Vídeo Explicativo (Opcional)',
            ),
          ],
        );

      case SupportMaterialType.powerpoint:
        return Column(
          children: [
            FileUploadWidget(
              initialFileUrl: _fileUrl,
              onFileUrlChanged: (url, name) {
                setState(() {
                  _fileUrl = url;
                });
              },
              storageBucket: 'support-material-files',
              label: 'Arquivo PowerPoint',
              allowedExtensions: const ['ppt', 'pptx'],
              icon: Icons.slideshow,
            ),
            const SizedBox(height: 16),
            // Vídeo explicativo (opcional)
            VideoUploadWidget(
              initialVideoUrl: _videoUrl,
              onVideoUrlChanged: (url) {
                setState(() {
                  _videoUrl = url;
                });
              },
              storageBucket: 'support-material-videos',
              label: 'Vídeo Explicativo (Opcional)',
            ),
          ],
        );

      case SupportMaterialType.audio:
        return Column(
          children: [
            FileUploadWidget(
              initialFileUrl: _fileUrl,
              onFileUrlChanged: (url, name) {
                setState(() {
                  _fileUrl = url;
                });
              },
              storageBucket: 'support-material-files',
              label: 'Arquivo de Áudio',
              allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a'],
              icon: Icons.audiotrack,
            ),
            const SizedBox(height: 16),
            // Vídeo explicativo (opcional)
            VideoUploadWidget(
              initialVideoUrl: _videoUrl,
              onVideoUrlChanged: (url) {
                setState(() {
                  _videoUrl = url;
                });
              },
              storageBucket: 'support-material-videos',
              label: 'Vídeo Explicativo (Opcional)',
            ),
          ],
        );

      case SupportMaterialType.other:
        return Column(
          children: [
            FileUploadWidget(
              initialFileUrl: _fileUrl,
              onFileUrlChanged: (url, name) {
                setState(() {
                  _fileUrl = url;
                });
              },
              storageBucket: 'support-material-files',
              label: 'Arquivo',
              allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'zip'],
              icon: Icons.attach_file,
            ),
            const SizedBox(height: 16),
            // Vídeo explicativo (opcional)
            VideoUploadWidget(
              initialVideoUrl: _videoUrl,
              onVideoUrlChanged: (url) {
                setState(() {
                  _videoUrl = url;
                });
              },
              storageBucket: 'support-material-videos',
              label: 'Vídeo Explicativo (Opcional)',
            ),
          ],
        );
    }
  }

  Widget _buildLinksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vincular Material a:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione onde este material será disponibilizado',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Botões para selecionar entidades
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MaterialLinkType.values.map((linkType) {
                final hasSelection = _selectedEntities.containsKey(linkType) &&
                                    _selectedEntities[linkType]!.isNotEmpty;
                final count = hasSelection ? _selectedEntities[linkType]!.length : 0;

                return ActionChip(
                  avatar: Icon(
                    _getIconForLinkType(linkType),
                    size: 18,
                    color: hasSelection ? Colors.white : null,
                  ),
                  label: Text(
                    hasSelection
                        ? '${linkType.label} ($count)'
                        : linkType.label,
                  ),
                  backgroundColor: hasSelection
                      ? Theme.of(context).primaryColor
                      : null,
                  labelStyle: TextStyle(
                    color: hasSelection ? Colors.white : null,
                  ),
                  onPressed: () => _showEntitySelector(linkType),
                );
              }).toList(),
            ),

            // Chips das entidades selecionadas
            if (_selectedEntities.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._selectedEntities.entries.map((entry) {
                final linkType = entry.key;
                final entities = entry.value;

                if (entities.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linkType.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...entities.entries.map((entity) {
                          return Chip(
                            label: Text(entity.value),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedEntities[linkType]!.remove(entity.key);
                                if (_selectedEntities[linkType]!.isEmpty) {
                                  _selectedEntities.remove(linkType);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
