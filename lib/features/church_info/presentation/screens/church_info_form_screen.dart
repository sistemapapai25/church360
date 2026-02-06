import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/church_info_provider.dart';
import '../../domain/models/church_info.dart';

/// Tela de formulário para editar informações da igreja
class ChurchInfoFormScreen extends ConsumerStatefulWidget {
  const ChurchInfoFormScreen({super.key});

  @override
  ConsumerState<ChurchInfoFormScreen> createState() => _ChurchInfoFormScreenState();
}

class _ChurchInfoFormScreenState extends ConsumerState<ChurchInfoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _missionController = TextEditingController();
  final _visionController = TextEditingController();
  final _historyController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  
  // Valores
  final List<TextEditingController> _valuesControllers = [];
  
  // Redes sociais
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _twitterController = TextEditingController();
  
  String? _logoUrl;
  bool _isLoading = false;
  ChurchInfo? _existingInfo;

  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    // Iniciar o carregamento dos dados se necessário
    // Usamos addPostFrameCallback para evitar modificações durante o build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(churchInfoProvider);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _missionController.dispose();
    _visionController.dispose();
    _historyController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _twitterController.dispose();
    for (var controller in _valuesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populateForm(ChurchInfo info) {
    setState(() {
      _existingInfo = info;
      _nameController.text = info.name;
      _missionController.text = info.mission ?? '';
      _visionController.text = info.vision ?? '';
      _historyController.text = info.history ?? '';
      _addressController.text = info.address ?? '';
      _phoneController.text = info.phone ?? '';
      _emailController.text = info.email ?? '';
      _websiteController.text = info.website ?? '';
      _logoUrl = info.logoUrl;
      
      // Valores
      _valuesControllers.clear();
      if (info.values != null) {
        for (var value in info.values!) {
          final controller = TextEditingController(text: value);
          _valuesControllers.add(controller);
        }
      }
      
      // Redes sociais
      if (info.socialMedia != null) {
        _whatsappController.text = info.socialMedia!['whatsapp'] ?? '';
        _facebookController.text = info.socialMedia!['facebook'] ?? '';
        _instagramController.text = info.socialMedia!['instagram'] ?? '';
        _youtubeController.text = info.socialMedia!['youtube'] ?? '';
        _twitterController.text = info.socialMedia!['twitter'] ?? '';
      }
      
      _dataLoaded = true;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      
      try {
        final bytes = await pickedFile.readAsBytes();
        final fileName = 'church_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Upload para Supabase Storage
        await Supabase.instance.client.storage
            .from('church-assets')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        
        // Obter URL pública
        final url = Supabase.instance.client.storage
            .from('church-assets')
            .getPublicUrl(fileName);
        
        setState(() {
          _logoUrl = url;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo atualizada com sucesso!')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao fazer upload da logo: $e')),
          );
        }
      }
    }
  }

  void _addValue() {
    setState(() {
      _valuesControllers.add(TextEditingController());
    });
  }

  void _removeValue(int index) {
    setState(() {
      _valuesControllers[index].dispose();
      _valuesControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(churchInfoRepositoryProvider);
      
      // Preparar valores
      final values = _valuesControllers
          .map((c) => c.text.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      
      // Preparar redes sociais
      final socialMedia = <String, String>{};
      if (_whatsappController.text.trim().isNotEmpty) {
        socialMedia['whatsapp'] = _whatsappController.text.trim();
      }
      if (_facebookController.text.trim().isNotEmpty) {
        socialMedia['facebook'] = _facebookController.text.trim();
      }
      if (_instagramController.text.trim().isNotEmpty) {
        socialMedia['instagram'] = _instagramController.text.trim();
      }
      if (_youtubeController.text.trim().isNotEmpty) {
        socialMedia['youtube'] = _youtubeController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        socialMedia['twitter'] = _twitterController.text.trim();
      }
      
      final data = {
        'name': _nameController.text.trim(),
        'logo_url': _logoUrl,
        'mission': _missionController.text.trim().isEmpty ? null : _missionController.text.trim(),
        'vision': _visionController.text.trim().isEmpty ? null : _visionController.text.trim(),
        'values': values.isEmpty ? null : values,
        'history': _historyController.text.trim().isEmpty ? null : _historyController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        'social_media': socialMedia.isEmpty ? null : socialMedia,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      ChurchInfo savedInfo;
      if (_existingInfo != null) {
        // Atualizar
        savedInfo = await repo.updateChurchInfo(_existingInfo!.id, data);
      } else {
        // Criar
        data['created_at'] = DateTime.now().toIso8601String();
        savedInfo = await repo.createChurchInfo(data);
      }
      
      // Invalidar provider para recarregar
      ref.invalidate(churchInfoProvider);
      
      if (mounted) {
        setState(() {
          _existingInfo = savedInfo;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informações salvas com sucesso!')),
        );
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
    // Escutar mudanças no provider
    ref.listen<AsyncValue<ChurchInfo?>>(churchInfoProvider, (previous, next) {
      next.when(
        data: (info) {
          if (!_dataLoaded) {
            if (info != null) {
              _populateForm(info);
            } else {
              setState(() => _dataLoaded = true);
            }
          }
        },
        error: (err, stack) {
           setState(() => _dataLoaded = true);
        },
        loading: () {},
      );
    });

    final churchInfoState = ref.watch(churchInfoProvider);
    
    if (churchInfoState.isLoading && !_dataLoaded) {
      return Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _existingInfo != null ? 'Editar Igreja' : 'Cadastrar Igreja',
          style: CommunityDesign.titleStyle(context).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
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
              onPressed: _submit,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Logo Section
            _buildSectionCard(
              title: 'Identidade Visual',
              children: [
                _buildLogoSection(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Basic Info Section
            _buildSectionCard(
              title: 'Informações Básicas',
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Igreja *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.church),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _missionController,
                  decoration: const InputDecoration(
                    labelText: 'Missão',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _visionController,
                  decoration: const InputDecoration(
                    labelText: 'Visão',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.visibility),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _historyController,
                  decoration: const InputDecoration(
                    labelText: 'História',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.history_edu),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                _buildValuesSection(),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Section
            _buildSectionCard(
              title: 'Contato e Localização',
              children: [
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
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
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Social Media Section
            _buildSectionCard(
              title: 'Redes Sociais',
              children: [
                TextFormField(
                  controller: _whatsappController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: 'Ex: 5511999999999',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'Digite o número com DDD (ex: 5511999999999)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.facebook),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.camera_alt),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _youtubeController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.video_library),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _twitterController,
                  decoration: const InputDecoration(
                    labelText: 'Twitter',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_existingInfo != null ? 'Salvar Alterações' : 'Cadastrar Igreja'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CommunityDesign.titleStyle(context).copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        if (_logoUrl != null)
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: Image.network(
                _logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: const AppLogo(),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const AppLogo(),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pickLogo,
          icon: const Icon(Icons.upload),
          label: Text(_logoUrl != null ? 'Alterar Logo' : 'Adicionar Logo'),
        ),
      ],
    );
  }

  Widget _buildValuesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Valores',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            TextButton.icon(
              onPressed: _addValue,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Valor'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_valuesControllers.isEmpty)
          const Text('Nenhum valor adicionado')
        else
          ..._valuesControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Valor ${index + 1}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.circle_outlined),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeValue(index),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
