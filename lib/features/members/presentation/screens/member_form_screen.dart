import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/viacep_service.dart';
import '../providers/members_provider.dart';
import '../../domain/models/member.dart';

/// Tela de formulário de membro (criar/editar)
class MemberFormScreen extends ConsumerStatefulWidget {
  final String? memberId; // null = criar, não-null = editar
  final String? initialStatus; // Status inicial ao criar (ex: 'visitor')
  final String? initialEmail; // Email inicial ao criar (ex: email do usuário logado)

  const MemberFormScreen({
    super.key,
    this.memberId,
    this.initialStatus,
    this.initialEmail,
  });

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _professionController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressComplementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _notesController = TextEditingController();

  // Valores selecionados
  DateTime? _birthdate;
  String? _gender;
  String? _maritalStatus;
  DateTime? _marriageDate;
  String _status = 'visitor';
  String? _memberType;
  DateTime? _membershipDate;
  DateTime? _conversionDate;
  DateTime? _baptismDate;

  bool _isLoading = false;
  bool _isSearchingCep = false;
  Member? _existingMember;

  @override
  void initState() {
    super.initState();
    // Definir status inicial se fornecido
    if (widget.initialStatus != null) {
      _status = widget.initialStatus!;
    }
    // Definir email inicial se fornecido
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
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
          _firstNameController.text = member.firstName ?? '';
          _lastNameController.text = member.lastName ?? '';
          _nicknameController.text = member.nickname ?? '';
          _emailController.text = member.email;
          _phoneController.text = member.phone ?? '';
          _cpfController.text = member.cpf ?? '';
          _professionController.text = member.profession ?? '';
          _addressController.text = member.address ?? '';
          _addressComplementController.text = member.addressComplement ?? '';
          _neighborhoodController.text = member.neighborhood ?? '';
          _cityController.text = member.city ?? '';
          _stateController.text = member.state ?? '';
          _zipCodeController.text = member.zipCode ?? '';
          _notesController.text = member.notes ?? '';

          _birthdate = member.birthdate;
          _gender = member.gender;
          _maritalStatus = member.maritalStatus;
          _marriageDate = member.marriageDate;
          _status = member.status;
          _memberType = member.memberType;
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
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    _addressComplementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  /// Buscar endereço pelo CEP usando a API ViaCEP
  Future<void> _searchCep() async {
    final cep = _zipCodeController.text.trim();

    // Validar se o CEP tem 8 dígitos
    if (!ViaCepService.isValidCep(cep)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CEP inválido. Digite 8 dígitos.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearchingCep = true;
    });

    try {
      // Buscar endereço na API ViaCEP
      final address = await ViaCepService.fetchAddress(cep);

      // Preencher os campos automaticamente
      setState(() {
        _addressController.text = address.logradouro;
        _neighborhoodController.text = address.bairro;
        _cityController.text = address.localidade;
        _stateController.text = address.uf;

        // Se a API retornar complemento, preencher também
        if (address.complemento.isNotEmpty) {
          _addressComplementController.text = address.complemento;
        }

        // Formatar o CEP
        _zipCodeController.text = ViaCepService.formatCep(cep);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Endereço encontrado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingCep = false;
        });
      }
    }
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
        if (_nicknameController.text.trim().isNotEmpty) {
          memberData['nickname'] = _nicknameController.text.trim();
        }
        if (_emailController.text.trim().isNotEmpty) {
          memberData['email'] = _emailController.text.trim();
        }
        if (_phoneController.text.trim().isNotEmpty) {
          memberData['phone'] = _phoneController.text.trim();
        }
        if (_cpfController.text.trim().isNotEmpty) {
          memberData['cpf'] = _cpfController.text.trim();
        }
        if (_professionController.text.trim().isNotEmpty) {
          memberData['profession'] = _professionController.text.trim();
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
        if (_marriageDate != null) {
          memberData['marriage_date'] = _marriageDate!.toIso8601String().split('T')[0];
        }
        if (_memberType != null) {
          memberData['member_type'] = _memberType;
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
        if (_addressComplementController.text.trim().isNotEmpty) {
          memberData['address_complement'] = _addressComplementController.text.trim();
        }
        if (_neighborhoodController.text.trim().isNotEmpty) {
          memberData['neighborhood'] = _neighborhoodController.text.trim();
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

        memberData['id'] = const Uuid().v4();
        await repo.createMemberFromJson(memberData);
      } else {
        // Atualizar existente
        // Validar que email não está vazio (campo obrigatório)
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          throw Exception('Email é obrigatório');
        }

        // Construir fullName a partir de firstName e lastName
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final fullName = '$firstName $lastName'.trim();

        // Garantir que fullName nunca seja vazio (usar email como fallback)
        final finalFullName = fullName.isNotEmpty ? fullName : email;

        final member = Member(
          id: widget.memberId!,
          email: email,
          fullName: finalFullName,
          firstName: firstName.isEmpty ? null : firstName,
          lastName: lastName.isEmpty ? null : lastName,
          nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          cpf: _cpfController.text.trim().isEmpty ? null : _cpfController.text.trim(),
          profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
          birthdate: _birthdate,
          gender: _gender,
          maritalStatus: _maritalStatus,
          marriageDate: _marriageDate,
          status: _status,
          memberType: _memberType,
          membershipDate: _membershipDate,
          conversionDate: _conversionDate,
          baptismDate: _baptismDate,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          addressComplement: _addressComplementController.text.trim().isEmpty ? null : _addressComplementController.text.trim(),
          neighborhood: _neighborhoodController.text.trim().isEmpty ? null : _neighborhoodController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
          zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: _existingMember?.createdAt ?? DateTime.now(),
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
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveMember,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: _isLoading && widget.memberId != null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Seção: Dados Pessoais
                  _buildSectionTitle('Dados Pessoais'),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Primeiro Nome *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Campo obrigatório';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sobrenome *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Campo obrigatório';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Apelido
                  TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Apelido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                      // Mostrar hint se o campo está bloqueado
                      helperText: widget.initialEmail != null
                          ? 'Email vinculado à sua conta (não editável)'
                          : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    // Bloquear edição se foi fornecido um email inicial
                    readOnly: widget.initialEmail != null,
                    enabled: widget.initialEmail == null,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email é obrigatório';
                      }
                      // Validação básica de email
                      if (!value.contains('@')) {
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
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Data de Nascimento
                  InkWell(
                    onTap: () => _selectDate(context, _birthdate, (date) {
                      setState(() {
                        _birthdate = date;
                      });
                    }),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Nascimento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      child: Text(
                        _birthdate != null
                            ? DateFormat('dd/MM/yyyy').format(_birthdate!)
                            : 'Selecione a data',
                        style: TextStyle(
                          color: _birthdate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gênero
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gênero',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Masculino')),
                      DropdownMenuItem(value: 'female', child: Text('Feminino')),
                      DropdownMenuItem(value: 'other', child: Text('Outro')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gender = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // CPF
                  TextFormField(
                    controller: _cpfController,
                    decoration: const InputDecoration(
                      labelText: 'CPF',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                      hintText: '000.000.000-00',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Estado Civil
                  DropdownButtonFormField<String>(
                    initialValue: _maritalStatus,
                    decoration: const InputDecoration(
                      labelText: 'Estado Civil',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.favorite),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'single', child: Text('Solteiro(a)')),
                      DropdownMenuItem(value: 'married', child: Text('Casado(a)')),
                      DropdownMenuItem(value: 'divorced', child: Text('Divorciado(a)')),
                      DropdownMenuItem(value: 'widowed', child: Text('Viúvo(a)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _maritalStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Data de Casamento (só aparece se casado)
                  if (_maritalStatus == 'married') ...[
                    InkWell(
                      onTap: () => _selectDate(context, _marriageDate, (date) {
                        setState(() {
                          _marriageDate = date;
                        });
                      }),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de Casamento',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.favorite_border),
                        ),
                        child: Text(
                          _marriageDate != null
                              ? DateFormat('dd/MM/yyyy').format(_marriageDate!)
                              : 'Selecione a data',
                          style: TextStyle(
                            color: _marriageDate != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Profissão
                  TextFormField(
                    controller: _professionController,
                    decoration: const InputDecoration(
                      labelText: 'Profissão',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seção: Endereço
                  _buildSectionTitle('Endereço'),
                  const SizedBox(height: 16),

                  // CEP
                  TextFormField(
                    controller: _zipCodeController,
                    decoration: InputDecoration(
                      labelText: 'CEP',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pin_drop),
                      hintText: '00000-000',
                      suffixIcon: _isSearchingCep
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              tooltip: 'Buscar CEP',
                              onPressed: _searchCep,
                            ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Auto-buscar quando digitar 8 dígitos
                      final cleanCep = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleanCep.length == 8 && !_isSearchingCep) {
                        _searchCep();
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Complemento
                  TextFormField(
                    controller: _addressComplementController,
                    decoration: const InputDecoration(
                      labelText: 'Complemento',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.apartment),
                      hintText: 'Apto, Bloco, etc',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Endereço
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bairro
                  TextFormField(
                    controller: _neighborhoodController,
                    decoration: const InputDecoration(
                      labelText: 'Bairro',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cidade
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estado
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map),
                      hintText: 'UF',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                  ),
                  const SizedBox(height: 24),

                  // Seção: Informações Eclesiásticas
                  _buildSectionTitle('Informações Eclesiásticas'),
                  const SizedBox(height: 16),

                  // Status
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'visitor', child: Text('Visitante')),
                      DropdownMenuItem(value: 'new_convert', child: Text('Novo Convertido')),
                      DropdownMenuItem(value: 'member_active', child: Text('Membro Ativo')),
                      DropdownMenuItem(value: 'member_inactive', child: Text('Membro Inativo')),
                      DropdownMenuItem(value: 'transferred', child: Text('Transferido')),
                      DropdownMenuItem(value: 'deceased', child: Text('Falecido')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value!;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo obrigatório';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Data de Conversão
                  InkWell(
                    onTap: () => _selectDate(context, _conversionDate, (date) {
                      setState(() {
                        _conversionDate = date;
                      });
                    }),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Conversão',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.church),
                      ),
                      child: Text(
                        _conversionDate != null
                            ? DateFormat('dd/MM/yyyy').format(_conversionDate!)
                            : 'Selecione a data',
                        style: TextStyle(
                          color: _conversionDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data de Batismo
                  InkWell(
                    onTap: () => _selectDate(context, _baptismDate, (date) {
                      setState(() {
                        _baptismDate = date;
                      });
                    }),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Batismo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop),
                      ),
                      child: Text(
                        _baptismDate != null
                            ? DateFormat('dd/MM/yyyy').format(_baptismDate!)
                            : 'Selecione a data',
                        style: TextStyle(
                          color: _baptismDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data de Membresia
                  InkWell(
                    onTap: () => _selectDate(context, _membershipDate, (date) {
                      setState(() {
                        _membershipDate = date;
                      });
                    }),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Membresia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                      child: Text(
                        _membershipDate != null
                            ? DateFormat('dd/MM/yyyy').format(_membershipDate!)
                            : 'Selecione a data',
                        style: TextStyle(
                          color: _membershipDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tipo de Membro
                  DropdownButtonFormField<String>(
                    initialValue: _memberType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Membro',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'titular', child: Text('Titular')),
                      DropdownMenuItem(value: 'congregado', child: Text('Congregado')),
                      DropdownMenuItem(value: 'cooperador', child: Text('Cooperador')),
                      DropdownMenuItem(value: 'crianca', child: Text('Criança')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _memberType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Seção: Observações
                  _buildSectionTitle('Observações'),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  // Botão Salvar
                  ElevatedButton.icon(
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
                    label: Text(_isLoading ? 'Salvando...' : (widget.memberId == null ? 'Criar Membro' : 'Salvar Alterações')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
