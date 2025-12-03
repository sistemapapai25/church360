import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/banners_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../reading_plans/presentation/providers/reading_plans_provider.dart';
import '../../../courses/presentation/providers/courses_provider.dart';

/// Tela de formulário para criar/editar banner
class BannerFormScreen extends ConsumerStatefulWidget {
  final String? bannerId;

  const BannerFormScreen({
    super.key,
    this.bannerId,
  });

  @override
  ConsumerState<BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends ConsumerState<BannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkUrlController = TextEditingController();

  String? _imageUrl;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;

  // Campos de vínculo
  String _linkType = 'external'; // 'external', 'event', 'reading_plan', 'course', 'message'
  String? _linkedId;

  bool get _isEditing => widget.bannerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadBanner();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    setState(() => _isLoading = true);

    try {
      final banner = await ref.read(bannerByIdProvider(widget.bannerId!).future);
      
      if (banner != null && mounted) {
        setState(() {
          _titleController.text = banner.title;
          _descriptionController.text = banner.description ?? '';
          _linkUrlController.text = banner.linkUrl ?? '';
          _imageUrl = banner.imageUrl;
          _isActive = banner.isActive;
          _linkType = banner.linkType;
          _linkedId = banner.linkedId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar banner: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBanner() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageUrl == null || _imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma imagem')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(bannersRepositoryProvider);
      
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'image_url': _imageUrl,
        'link_url': _linkUrlController.text.trim().isEmpty
            ? null
            : _linkUrlController.text.trim(),
        'link_type': _linkType,
        'linked_id': _linkedId,
        'is_active': _isActive,
      };

      if (_isEditing) {
        await repo.updateBanner(widget.bannerId!, data);
      } else {
        // Para novos banners, definir order_index como o próximo disponível
        final count = await repo.countBanners();
        data['order_index'] = count;
        await repo.createBanner(data);
      }

      // Atualizar a lista de banners
      ref.invalidate(allBannersProvider);
      ref.invalidate(activeBannersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing 
                  ? 'Banner atualizado com sucesso!' 
                  : 'Banner criado com sucesso!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar banner: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Widget para selecionar item vinculado (evento, plano, curso)
  Widget _buildLinkedItemSelector() {
    switch (_linkType) {
      case 'event':
        return _buildEventSelector();
      case 'reading_plan':
        return _buildReadingPlanSelector();
      case 'course':
        return _buildCourseSelector();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Seletor de Eventos
  Widget _buildEventSelector() {
    final eventsAsync = ref.watch(allEventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Text('Nenhum evento disponível');
        }

        return DropdownMenu<String>(
          initialSelection: _linkedId,
          label: const Text('Selecione o Evento'),
          leadingIcon: const Icon(Icons.event),
          dropdownMenuEntries: events
              .map((event) => DropdownMenuEntry<String>(value: event.id, label: event.name))
              .toList(),
          onSelected: (value) {
            setState(() {
              _linkedId = value;
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Erro ao carregar eventos: $error'),
    );
  }

  /// Seletor de Planos de Leitura
  Widget _buildReadingPlanSelector() {
    final plansAsync = ref.watch(allReadingPlansProvider);

    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return const Text('Nenhum plano de leitura disponível');
        }

        return DropdownMenu<String>(
          initialSelection: _linkedId,
          label: const Text('Selecione o Plano de Leitura'),
          leadingIcon: const Icon(Icons.book),
          dropdownMenuEntries: plans
              .map((plan) => DropdownMenuEntry<String>(value: plan.id, label: plan.title))
              .toList(),
          onSelected: (value) {
            setState(() {
              _linkedId = value;
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Erro ao carregar planos: $error'),
    );
  }

  /// Seletor de Cursos
  Widget _buildCourseSelector() {
    final coursesAsync = ref.watch(allCoursesProvider);

    return coursesAsync.when(
      data: (courses) {
        if (courses.isEmpty) {
          return const Text('Nenhum curso disponível');
        }

        return DropdownMenu<String>(
          initialSelection: _linkedId,
          label: const Text('Selecione o Curso'),
          leadingIcon: const Icon(Icons.school),
          dropdownMenuEntries: courses
              .map((course) => DropdownMenuEntry<String>(value: course.id, label: course.title))
              .toList(),
          onSelected: (value) {
            setState(() {
              _linkedId = value;
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Erro ao carregar cursos: $error'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Banner' : 'Novo Banner'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
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
              onPressed: _saveBanner,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Culto de Celebração',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira um título';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Breve descrição do banner',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Upload de Imagem
                    ImageUploadWidget(
                      initialImageUrl: _imageUrl,
                      onImageUrlChanged: (url) {
                        setState(() {
                          _imageUrl = url;
                        });
                      },
                      storageBucket: 'banner-images',
                      label: 'Imagem do Banner *',
                    ),
                    const SizedBox(height: 16),

                    // Tipo de Vínculo
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ação ao Clicar no Banner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Seletor de tipo
                            DropdownMenu<String>(
                              initialSelection: _linkType,
                              label: const Text('Tipo de Ação'),
                              leadingIcon: const Icon(Icons.touch_app),
                              dropdownMenuEntries: const [
                                DropdownMenuEntry(value: 'external', label: 'Link Externo'),
                                DropdownMenuEntry(value: 'event', label: 'Abrir Evento'),
                                DropdownMenuEntry(value: 'reading_plan', label: 'Abrir Plano de Leitura'),
                                DropdownMenuEntry(value: 'course', label: 'Abrir Curso'),
                              ],
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() {
                                  _linkType = value;
                                  _linkedId = null; // Limpar seleção anterior
                                  _linkUrlController.clear();
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Campo condicional baseado no tipo
                            if (_linkType == 'external') ...[
                              TextFormField(
                                controller: _linkUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'URL',
                                  hintText: 'https://exemplo.com',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                                keyboardType: TextInputType.url,
                              ),
                            ] else ...[
                              _buildLinkedItemSelector(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status (Ativo/Inativo)
                    Card(
                      child: SwitchListTile(
                        title: const Text('Banner Ativo'),
                        subtitle: Text(
                          _isActive
                              ? 'O banner será exibido no app'
                              : 'O banner não será exibido no app',
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        secondary: Icon(
                          _isActive ? Icons.visibility : Icons.visibility_off,
                          color: _isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Salvar
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveBanner,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isEditing ? 'Atualizar Banner' : 'Criar Banner'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
