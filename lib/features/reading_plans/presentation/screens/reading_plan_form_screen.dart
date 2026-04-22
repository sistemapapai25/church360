import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../domain/models/reading_plan.dart';
import '../providers/reading_plans_provider.dart';

class _PlanModuleDraft {
  final TextEditingController titleController;
  final TextEditingController referenceController;
  final TextEditingController contentController;

  _PlanModuleDraft({String? title, String? reference, String? content})
    : titleController = TextEditingController(text: title ?? ''),
      referenceController = TextEditingController(text: reference ?? ''),
      contentController = TextEditingController(text: content ?? '');

  void dispose() {
    titleController.dispose();
    referenceController.dispose();
    contentController.dispose();
  }
}

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
  final List<_PlanModuleDraft> _modules = [];

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
    for (final module in _modules) {
      module.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _durationDaysController.dispose();
    super.dispose();
  }

  void _syncDurationWithModules() {
    if (_modules.isEmpty) return;
    final computedDays = _modules.length;
    final expected = computedDays.toString();
    if (_durationDaysController.text != expected) {
      _durationDaysController.text = expected;
    }
  }

  void _addModule({String? title, String? reference, String? content}) {
    setState(() {
      _modules.add(
        _PlanModuleDraft(title: title, reference: reference, content: content),
      );
      _syncDurationWithModules();
    });
  }

  void _removeModule(int index) {
    if (index < 0 || index >= _modules.length) return;
    setState(() {
      final removed = _modules.removeAt(index);
      removed.dispose();
      _syncDurationWithModules();
    });
  }

  void _moveModuleUp(int index) {
    if (index <= 0 || index >= _modules.length) return;
    setState(() {
      final item = _modules.removeAt(index);
      _modules.insert(index - 1, item);
      _syncDurationWithModules();
    });
  }

  void _moveModuleDown(int index) {
    if (index < 0 || index >= _modules.length - 1) return;
    setState(() {
      final item = _modules.removeAt(index);
      _modules.insert(index + 1, item);
      _syncDurationWithModules();
    });
  }

  List<Map<String, dynamic>> _buildModulesPayload() {
    final payload = <Map<String, dynamic>>[];
    for (final module in _modules) {
      final title = module.titleController.text.trim();
      final reference = module.referenceController.text.trim();
      final content = module.contentController.text.trim();

      if (title.isEmpty && reference.isEmpty && content.isEmpty) {
        continue;
      }

      final order = payload.length + 1;
      payload.add({
        'order': order,
        'title': title.isEmpty ? 'Módulo $order' : title,
        'reference': reference.isEmpty ? null : reference,
        'content': content.isEmpty ? null : content,
      });
    }
    return payload;
  }

  Future<void> _loadPlan() async {
    setState(() => _isLoading = true);
    try {
      final ReadingPlan? plan = await ref.read(
        readingPlanByIdProvider(widget.planId!).future,
      );
      if (plan != null && mounted) {
        setState(() {
          _titleController.text = plan.title;
          _descriptionController.text = plan.description ?? '';
          _durationDaysController.text = plan.durationDays.toString();
          _imageUrl = plan.imageUrl;
          _category = plan.category ?? 'general';
          _isActive = plan.isActive;

          for (final module in _modules) {
            module.dispose();
          }
          _modules.clear();
          for (final module in plan.modules) {
            _modules.add(
              _PlanModuleDraft(
                title: module.title,
                reference: module.reference,
                content: module.content,
              ),
            );
          }
          _syncDurationWithModules();
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.admin.load_plan',
        fallbackMessage: 'Nao foi possivel carregar o plano. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(readingPlansRepositoryProvider);

      final modulesPayload = _buildModulesPayload();
      final durationDays = modulesPayload.isNotEmpty
          ? modulesPayload.length
          : int.parse(_durationDaysController.text.trim());
      if (modulesPayload.isNotEmpty) {
        _durationDaysController.text = durationDays.toString();
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'duration_days': durationDays,
        'modules': modulesPayload,
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
            content: Text(_isEditing ? 'Plano atualizado!' : 'Plano criado!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.admin.save_plan',
        fallbackMessage: 'Nao foi possivel salvar o plano. Tente novamente.',
      );
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
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
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
                      readOnly: _modules.isNotEmpty,
                      decoration: InputDecoration(
                        labelText: 'Duração (dias) *',
                        border: OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_today),
                        helperText: _modules.isNotEmpty
                            ? 'Calculado automaticamente pela quantidade de módulos.'
                            : null,
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Módulos do Plano',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _addModule(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar módulo'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Cada módulo representa uma etapa diária do plano. '
                              'Ao concluir o último módulo, o plano é finalizado e pode ser reiniciado.',
                            ),
                            const SizedBox(height: 12),
                            if (_modules.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                child: const Text(
                                  'Nenhum módulo cadastrado. Clique em "Adicionar módulo".',
                                ),
                              )
                            else
                              ListView.separated(
                                itemCount: _modules.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final module = _modules[index];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Módulo ${index + 1}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Mover para cima',
                                              onPressed: index == 0
                                                  ? null
                                                  : () => _moveModuleUp(index),
                                              icon: const Icon(
                                                Icons.arrow_upward,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Mover para baixo',
                                              onPressed:
                                                  index == _modules.length - 1
                                                  ? null
                                                  : () =>
                                                        _moveModuleDown(index),
                                              icon: const Icon(
                                                Icons.arrow_downward,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Remover módulo',
                                              onPressed: () =>
                                                  _removeModule(index),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: module.titleController,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          decoration: const InputDecoration(
                                            labelText: 'Título do módulo *',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller:
                                              module.referenceController,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Referência bíblica (opcional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: module.contentController,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          minLines: 2,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Conteúdo/objetivo do módulo (opcional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
                      label: Text(
                        _isEditing ? 'Salvar alterações' : 'Criar plano',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
