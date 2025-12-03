import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/testimony_provider.dart';

/// Tela de formulário de testemunho (criar/editar)
class TestimonyFormScreen extends ConsumerStatefulWidget {
  final String? testimonyId;

  const TestimonyFormScreen({super.key, this.testimonyId});

  @override
  ConsumerState<TestimonyFormScreen> createState() => _TestimonyFormScreenState();
}

class _TestimonyFormScreenState extends ConsumerState<TestimonyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = true;
  bool _allowWhatsappContact = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.testimonyId != null) {
      _loadTestimony();
    }
  }

  Future<void> _loadTestimony() async {
    try {
      final testimony = await ref.read(testimonyByIdProvider(widget.testimonyId!).future);
      if (testimony != null && mounted) {
        setState(() {
          _titleController.text = testimony.title;
          _descriptionController.text = testimony.description;
          _isPublic = testimony.isPublic;
          _allowWhatsappContact = testimony.allowWhatsappContact;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar testemunho: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTestimony() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(testimonyRepositoryProvider);

      if (widget.testimonyId == null) {
        // Criar novo
        await repo.createTestimony(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
          allowWhatsappContact: _allowWhatsappContact,
        );
      } else {
        // Atualizar existente
        await repo.updateTestimony(
          id: widget.testimonyId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
          allowWhatsappContact: _allowWhatsappContact,
        );
      }

      // Invalidar providers
      ref.invalidate(allTestimoniesProvider);
      ref.invalidate(publicTestimoniesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.testimonyId == null
                  ? 'Testemunho criado com sucesso!'
                  : 'Testemunho atualizado com sucesso!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
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
    final isEditing = widget.testimonyId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Testemunho' : 'Novo Testemunho'),
        centerTitle: true,
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
                hintText: 'Ex: Deus transformou minha vida',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Título é obrigatório';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Testemunho *',
                hintText: 'Compartilhe como Deus agiu em sua vida...',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Testemunho é obrigatório';
                }
                if (value.trim().length < 20) {
                  return 'Testemunho deve ter pelo menos 20 caracteres';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
              maxLines: 8,
              maxLength: 2000,
            ),
            const SizedBox(height: 24),

            // Visibilidade
            Card(
              child: SwitchListTile(
                title: const Text('Testemunho Público'),
                subtitle: Text(
                  _isPublic
                      ? 'Visível para todos os usuários do app'
                      : 'Visível apenas para você e administradores',
                ),
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                secondary: Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: _isPublic ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Contato WhatsApp
            Card(
              child: SwitchListTile(
                title: const Text('Permitir Contato via WhatsApp'),
                subtitle: const Text(
                  'Outros membros poderão entrar em contato com você',
                ),
                value: _allowWhatsappContact,
                onChanged: (value) => setState(() => _allowWhatsappContact = value),
                secondary: Icon(
                  Icons.phone,
                  color: _allowWhatsappContact ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Botão Salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveTestimony,
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
              label: Text(
                _isLoading
                    ? 'Salvando...'
                    : (isEditing ? 'Atualizar Testemunho' : 'Criar Testemunho'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

