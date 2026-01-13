import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../providers/reading_plans_provider.dart';

class ReadingPlanFormScreen extends ConsumerStatefulWidget {
  final String? planId;

  const ReadingPlanFormScreen({super.key, this.planId});

  @override
  ConsumerState<ReadingPlanFormScreen> createState() =>
      _ReadingPlanFormScreenState();
}

class _ReadingPlanFormScreenState extends ConsumerState<ReadingPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationDaysController = TextEditingController();

  String? _imageUrl;
  String _category = 'general';
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadPlan();
    } else {
      _durationDaysController.text = '30';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    setState(() => _isLoading = true);
    try {
      final plan =
          await ref.read(readingPlanByIdProvider(widget.planId!).future);
      if (plan != null && mounted) {
        setState(() {
          _titleController.text = plan.title;
          _descriptionController.text = plan.description ?? '';
          _durationDaysController.text = plan.durationDays.toString();
          _imageUrl = plan.imageUrl;
          _category = plan.category ?? 'general';
          _isActive = plan.isActive;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar plano: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(readingPlansRepositoryProvider);

      final durationDays = int.parse(_durationDaysController.text.trim());
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'duration_days': durationDays,
        'image_url': _imageUrl?.trim().isEmpty == true ? null : _imageUrl,
        'status': _isActive ? 'active' : 'inactive',
        'category': _category == 'general' ? null : _category,
      };

      if (_isEditing) {
        await repo.updatePlan(widget.planId!, data);
      } else {
        await repo.createPlan(data);
      }

      ref.invalidate(allReadingPlansProvider);
      ref.invalidate(activeReadingPlansProvider);
      if (_isEditing) {
        ref.invalidate(readingPlanByIdProvider(widget.planId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Plano atualizado!' : 'Plano criado!',
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
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Plano de Leitura' : 'Novo Plano de Leitura',
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePlan,
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
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira um título';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _durationDaysController,
                      decoration: const InputDecoration(
                        labelText: 'Duração (dias) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a duração em dias';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Informe um número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ImageUploadWidget(
                      initialImageUrl: _imageUrl,
                      onImageUrlChanged: (url) {
                        setState(() {
                          _imageUrl = url;
                        });
                      },
                      storageBucket: 'banner-images',
                      label: 'Imagem do Plano (Opcional)',
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Categoria',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownMenu<String>(
                              initialSelection: _category,
                              label: const Text('Selecione a categoria'),
                              leadingIcon: const Icon(Icons.category),
                              dropdownMenuEntries: const [
                                DropdownMenuEntry(
                                  value: 'general',
                                  label: 'Geral',
                                ),
                                DropdownMenuEntry(
                                  value: 'complete_bible',
                                  label: 'Bíblia Completa',
                                ),
                                DropdownMenuEntry(
                                  value: 'new_testament',
                                  label: 'Novo Testamento',
                                ),
                                DropdownMenuEntry(
                                  value: 'old_testament',
                                  label: 'Antigo Testamento',
                                ),
                                DropdownMenuEntry(
                                  value: 'devotional',
                                  label: 'Devocional',
                                ),
                              ],
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() => _category = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: SwitchListTile(
                        title: const Text('Plano ativo'),
                        subtitle: Text(
                          _isActive
                              ? 'Visível no app para os usuários'
                              : 'Não aparece no app',
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _savePlan,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditing ? 'Salvar alterações' : 'Criar plano'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

