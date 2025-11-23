import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/prayer_request_provider.dart';
import '../../domain/models/prayer_request.dart';

/// Tela de formulário para criar/editar pedido de oração
class PrayerRequestFormScreen extends ConsumerStatefulWidget {
  final String? prayerRequestId;

  const PrayerRequestFormScreen({
    super.key,
    this.prayerRequestId,
  });

  @override
  ConsumerState<PrayerRequestFormScreen> createState() => _PrayerRequestFormScreenState();
}

class _PrayerRequestFormScreenState extends ConsumerState<PrayerRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  PrayerCategory _selectedCategory = PrayerCategory.personal;
  PrayerPrivacy _selectedPrivacy = PrayerPrivacy.public;
  bool _isLoading = false;

  bool get _isEditing => widget.prayerRequestId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final actions = ref.read(prayerRequestActionsProvider);

      if (_isEditing) {
        await actions.updatePrayerRequest(
          id: widget.prayerRequestId!,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          privacy: _selectedPrivacy,
        );
      } else {
        await actions.createPrayerRequest(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          privacy: _selectedPrivacy,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Pedido atualizado com sucesso!'
                  : 'Pedido criado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se estiver editando, carregar dados
    if (_isEditing) {
      final prayerRequestAsync = ref.watch(prayerRequestByIdProvider(widget.prayerRequestId!));
      
      prayerRequestAsync.whenData((prayerRequest) {
        if (prayerRequest != null && _titleController.text.isEmpty) {
          _titleController.text = prayerRequest.title;
          _descriptionController.text = prayerRequest.description;
          _selectedCategory = prayerRequest.category;
          _selectedPrivacy = prayerRequest.privacy;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Pedido' : 'Novo Pedido de Oração'),
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
                hintText: 'Ex: Oração pela minha família',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira um título';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Categoria
            DropdownMenu<PrayerCategory>(
              initialSelection: _selectedCategory,
              label: const Text('Categoria *'),
              leadingIcon: const Icon(Icons.category),
              dropdownMenuEntries: PrayerCategory.values
                  .map((category) => DropdownMenuEntry<PrayerCategory>(
                        value: category,
                        label: '${category.icon} ${category.displayName}',
                      ))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Privacidade
            DropdownMenu<PrayerPrivacy>(
              initialSelection: _selectedPrivacy,
              label: const Text('Privacidade *'),
              leadingIcon: const Icon(Icons.lock),
              dropdownMenuEntries: PrayerPrivacy.values
                  .map((privacy) => DropdownMenuEntry<PrayerPrivacy>(
                        value: privacy,
                        label: privacy.displayName,
                      ))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPrivacy = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                hintText: 'Compartilhe seu pedido de oração...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira a descrição';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Botão de salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Atualizar' : 'Criar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
