import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';

/// Tela de formulário de membro (criar/editar)
class MemberFormScreen extends ConsumerStatefulWidget {
  final String? memberId; // null = criar, não-null = editar

  const MemberFormScreen({
    super.key,
    this.memberId,
  });

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _notesController = TextEditingController();

  // Valores selecionados
  DateTime? _birthdate;
  String? _gender;
  String? _maritalStatus;
  String _status = 'visitor';
  DateTime? _membershipDate;
  DateTime? _conversionDate;
  DateTime? _baptismDate;

  bool _isLoading = false;
  Member? _existingMember;

  @override
  void initState() {
    super.initState();
    if (widget.memberId != null) {
      _loadMember();
    }
  }

  Future<void> _loadMember() async {
    setState(() => _isLoading = true);
    
    try {
      final member = await ref.read(membersRepositoryProvider).getMemberById(widget.memberId!);
      
      if (member != null && mounted) {
        setState(() {
          _existingMember = member;
          _firstNameController.text = member.firstName;
          _lastNameController.text = member.lastName;
          _emailController.text = member.email ?? '';
          _phoneController.text = member.phone ?? '';
          _addressController.text = member.address ?? '';
          _cityController.text = member.city ?? '';
          _stateController.text = member.state ?? '';
          _zipCodeController.text = member.zipCode ?? '';
          _notesController.text = member.notes ?? '';
          
          _birthdate = member.birthdate;
          _gender = member.gender;
          _maritalStatus = member.maritalStatus;
          _status = member.status;
          _membershipDate = member.membershipDate;
          _conversionDate = member.conversionDate;
          _baptismDate = member.baptismDate;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar membro: $e'),
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(membersRepositoryProvider);

      if (widget.memberId == null) {
        // Criar novo - não passa o ID, deixa o Supabase gerar
        final memberData = <String, dynamic>{
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'status': _status,
        };

        // Adiciona campos opcionais apenas se não forem vazios
        if (_emailController.text.trim().isNotEmpty) {
          memberData['email'] = _emailController.text.trim();
        }
        if (_phoneController.text.trim().isNotEmpty) {
          memberData['phone'] = _phoneController.text.trim();
        }
        if (_birthdate != null) {
          memberData['birthdate'] = _birthdate!.toIso8601String().split('T')[0]; // Apenas a data
        }
        if (_gender != null) {
          memberData['gender'] = _gender;
        }
        if (_maritalStatus != null) {
          memberData['marital_status'] = _maritalStatus;
        }
        if (_membershipDate != null) {
          memberData['membership_date'] = _membershipDate!.toIso8601String().split('T')[0];
        }
        if (_conversionDate != null) {
          memberData['conversion_date'] = _conversionDate!.toIso8601String().split('T')[0];
        }
        if (_baptismDate != null) {
          memberData['baptism_date'] = _baptismDate!.toIso8601String().split('T')[0];
        }
        if (_addressController.text.trim().isNotEmpty) {
          memberData['address'] = _addressController.text.trim();
        }
        if (_cityController.text.trim().isNotEmpty) {
          memberData['city'] = _cityController.text.trim();
        }
        if (_stateController.text.trim().isNotEmpty) {
          memberData['state'] = _stateController.text.trim();
        }
        if (_zipCodeController.text.trim().isNotEmpty) {
          memberData['zip_code'] = _zipCodeController.text.trim();
        }
        if (_notesController.text.trim().isNotEmpty) {
          memberData['notes'] = _notesController.text.trim();
        }

        await repo.createMemberFromJson(memberData);
      } else {
        // Atualizar existente
        final member = Member(
          id: widget.memberId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          birthdate: _birthdate,
          gender: _gender,
          maritalStatus: _maritalStatus,
          status: _status,
          membershipDate: _membershipDate,
          conversionDate: _conversionDate,
          baptismDate: _baptismDate,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
          zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: _existingMember!.createdAt,
          updatedAt: DateTime.now(),
        );

        await repo.updateMember(member);
      }

      if (mounted) {
        // Invalida os providers para atualizar as listas
        ref.invalidate(allMembersProvider);
        ref.invalidate(activeMembersProvider);
        ref.invalidate(visitorsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.memberId == null
                  ? 'Membro criado com sucesso!'
                  : 'Membro atualizado com sucesso!',
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
            content: Text('Erro ao salvar membro: $e'),
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
        title: Text(widget.memberId == null ? 'Novo Membro' : 'Editar Membro'),
      ),
      body: _isLoading && widget.memberId != null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Informações Básicas
                  Text(
                    'Informações Básicas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _firstNameController,
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
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sobrenome *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira o sobrenome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Status
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status *',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'visitor', child: Text('Visitante')),
                      DropdownMenuItem(value: 'new_convert', child: Text('Novo Convertido')),
                      DropdownMenuItem(value: 'member_active', child: Text('Membro Ativo')),
                      DropdownMenuItem(value: 'member_inactive', child: Text('Membro Inativo')),
                      DropdownMenuItem(value: 'transferred', child: Text('Transferido')),
                    ],
                    onChanged: (value) {
                      setState(() => _status = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Contato
                  Text(
                    'Contato',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty && !value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Informações Pessoais
                  Text(
                    'Informações Pessoais',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Data de Nascimento
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake),
                    title: const Text('Data de Nascimento'),
                    subtitle: Text(
                      _birthdate != null
                          ? '${_birthdate!.day.toString().padLeft(2, '0')}/${_birthdate!.month.toString().padLeft(2, '0')}/${_birthdate!.year}'
                          : 'Não informada',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _birthdate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _birthdate = date);
                      }
                    },
                  ),
                  const Divider(),
                  
                  // Gênero
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gênero',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Masculino')),
                      DropdownMenuItem(value: 'female', child: Text('Feminino')),
                    ],
                    onChanged: (value) {
                      setState(() => _gender = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Estado Civil
                  DropdownButtonFormField<String>(
                    initialValue: _maritalStatus,
                    decoration: const InputDecoration(
                      labelText: 'Estado Civil',
                      prefixIcon: Icon(Icons.favorite),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'single', child: Text('Solteiro(a)')),
                      DropdownMenuItem(value: 'married', child: Text('Casado(a)')),
                      DropdownMenuItem(value: 'divorced', child: Text('Divorciado(a)')),
                      DropdownMenuItem(value: 'widowed', child: Text('Viúvo(a)')),
                    ],
                    onChanged: (value) {
                      setState(() => _maritalStatus = value);
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botão de salvar
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveMember,
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
                    label: Text(widget.memberId == null ? 'Criar Membro' : 'Salvar Alterações'),
                  ),
                ],
              ),
            ),
    );
  }
}

