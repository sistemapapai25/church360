import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../members/presentation/providers/members_provider.dart';

import '../../../../core/design/community_design.dart';
import '../providers/groups_provider.dart' as groups;

class _GenderOption {
  const _GenderOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _GenderOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Dialog para cadastrar visitante
class VisitorFormDialog extends ConsumerStatefulWidget {
  final String meetingId;

  const VisitorFormDialog({
    super.key,
    required this.meetingId,
  });

  @override
  ConsumerState<VisitorFormDialog> createState() => _VisitorFormDialogState();
}

class _VisitorFormDialogState extends ConsumerState<VisitorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _howFoundUsController = TextEditingController();
  final _notesController = TextEditingController();

  String? _gender;
  bool _wantsContact = true;
  bool _wantsToReturn = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _howFoundUsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveVisitor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final member = await ref.read(currentMemberProvider.future);
      final userId = member?.id;
      
      final data = {
        'meeting_id': widget.meetingId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'age': _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
        'gender': _gender,
        'how_found_us': _howFoundUsController.text.trim().isEmpty ? null : _howFoundUsController.text.trim(),
        'wants_contact': _wantsContact,
        'wants_to_return': _wantsToReturn,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'created_by': userId,
      };

      await ref.read(groups.groupsRepositoryProvider).createVisitor(data);

      // Invalidar provider para recarregar lista
      ref.invalidate(groups.visitorsProvider(widget.meetingId));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitante cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cadastrar visitante: $e'),
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
    final genderOptions = <_GenderOption>[
      const _GenderOption(null, 'Não informado'),
      const _GenderOption('M', 'Masculino'),
      const _GenderOption('F', 'Feminino'),
    ];
    final selectedGender = genderOptions.firstWhere(
      (option) => option.value == _gender,
      orElse: () => genderOptions.first,
    );

    return Dialog(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cadastrar Visitante',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Formulário
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Nome
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira o nome';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Telefone e Idade
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: 'Idade',
                                prefixIcon: Icon(Icons.cake),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Gênero
                      DropdownMenu<_GenderOption>(
                        initialSelection: selectedGender,
                        label: const Text('Gênero'),
                        leadingIcon: const Icon(Icons.wc),
                        dropdownMenuEntries: genderOptions
                          .map((option) => DropdownMenuEntry<_GenderOption>(
                            value: option,
                            label: option.label,
                          ))
                          .toList(),
                        onSelected: (option) => setState(() => _gender = option?.value),
                      ),
                      const SizedBox(height: 16),

                      // Como conheceu
                      TextFormField(
                        controller: _howFoundUsController,
                        decoration: const InputDecoration(
                          labelText: 'Como conheceu o grupo?',
                          prefixIcon: Icon(Icons.info),
                          hintText: 'Ex: Indicação, Redes Sociais, etc.',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Endereço
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Endereço',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Checkboxes
                      CheckboxListTile(
                        title: const Text('Deseja ser contatado'),
                        value: _wantsContact,
                        onChanged: (value) => setState(() => _wantsContact = value ?? true),
                      ),
                      CheckboxListTile(
                        title: const Text('Demonstrou interesse em retornar'),
                        value: _wantsToReturn,
                        onChanged: (value) => setState(() => _wantsToReturn = value ?? false),
                      ),
                      const SizedBox(height: 16),

                      // Observações
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveVisitor,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
