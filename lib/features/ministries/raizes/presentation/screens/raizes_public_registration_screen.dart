import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/design/community_design.dart';
import '../providers/raizes_dashboard_provider.dart';

/// Nome do ministério/igreja e culto de hoje, pela RPC pública.
final raizesPublicInfoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, ministryId) =>
          ref.watch(raizesRepositoryProvider).getPublicInfo(ministryId),
    );

String raizesPublicErrorMessage(Object e) {
  final msg = e is PostgrestException ? e.message : '$e';
  if (msg.contains('MINISTRY_NOT_FOUND')) return 'Este link de cadastro não existe mais.';
  if (msg.contains('LGPD_REQUIRED')) return 'Para enviar, marque que você concorda com o uso dos seus dados.';
  if (msg.contains('INVALID_NAME')) return 'Escreva seu nome completo.';
  if (msg.contains('INVALID_PHONE')) return 'Confira o telefone, com DDD.';
  if (msg.contains('TOO_LONG')) return 'Algum campo ficou grande demais. Encurte e tente de novo.';
  if (msg.contains('TOO_MANY')) return 'Muitos cadastros agora. Espere alguns minutos e tente de novo.';
  return 'Não deu para enviar. Tente de novo ou fale com a equipe na mesa do visitante.';
}

/// Cadastro do visitante pelo QR Code da mesa do Raízes (manual §4 e §6).
///
/// Tela SEM LOGIN: a rota `/raizes/:ministryId/cadastro` está nas exceções
/// do redirect de autenticação, e o servidor decide tudo em
/// `raizes_public_info` e `raizes_register_public` (SECURITY DEFINER, anon).
class RaizesPublicRegistrationScreen extends ConsumerStatefulWidget {
  final String ministryId;
  const RaizesPublicRegistrationScreen({super.key, required this.ministryId});

  @override
  ConsumerState<RaizesPublicRegistrationScreen> createState() =>
      _RaizesPublicRegistrationScreenState();
}

class _RaizesPublicRegistrationScreenState
    extends ConsumerState<RaizesPublicRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _neighborhood = TextEditingController();
  final _invitedBy = TextEditingController();
  final _prayer = TextEditingController();
  String? _marital;
  bool _wantsVisit = false;
  bool _wantsContact = true;
  bool _wantsLifeHouse = false;
  bool _lgpd = false;
  final Set<String> _profiles = {};
  bool _sending = false;
  String? _error;
  bool _done = false;

  static const _profileLabels = {
    'casais': 'Casais',
    'jovens': 'Jovens',
    'adolescentes': 'Adolescentes',
    'infantil': 'Infantil',
    'homens': 'Homens',
    'mulheres': 'Mulheres',
  };
  static const _maritalLabels = {
    'single': 'Solteiro(a)',
    'married': 'Casado(a)',
    'divorced': 'Divorciado(a)',
    'widowed': 'Viúvo(a)',
    'other': 'Outro',
  };

  @override
  void dispose() {
    for (final c in [_name, _phone, _neighborhood, _invitedBy, _prayer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_lgpd) {
      setState(() => _error = raizesPublicErrorMessage('LGPD_REQUIRED'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(raizesRepositoryProvider)
          .registerPublic(
            ministryId: widget.ministryId,
            fullName: _name.text,
            phone: _phone.text,
            neighborhood: _neighborhood.text,
            invitedBy: _invitedBy.text,
            maritalStatus: _marital,
            prayerRequest: _prayer.text,
            wantsVisit: _wantsVisit,
            wantsContact: _wantsContact,
            wantsLifeHouse: _wantsLifeHouse,
            profiles: _profiles.toList(),
          );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = raizesPublicErrorMessage(e);
        });
      }
    }
  }

  InputDecoration _deco(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(raizesPublicInfoProvider(widget.ministryId));
    final meta = CommunityDesign.metaStyle(context);
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: info.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(
                icon: Icons.link_off,
                title: 'Link indisponível',
                text: raizesPublicErrorMessage(e),
              ),
              data: (i) => _done
                  ? const _Message(
                      icon: Icons.favorite_outline,
                      title: 'Que alegria ter você aqui!',
                      text:
                          'Seu cadastro foi recebido. A equipe do Raízes vai '
                          'entrar em contato. Volte sempre!',
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Seja bem-vindo(a)!',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            [
                              i['church_name'],
                              if (i['culto_name'] != null) i['culto_name'],
                            ].whereType<String>().join(' · '),
                            style: meta,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('raizes-public-name'),
                            controller: _name,
                            maxLength: 120,
                            textCapitalization: TextCapitalization.words,
                            decoration: _deco('Nome completo *'),
                            validator: (v) => (v ?? '').trim().length < 3
                                ? 'Escreva seu nome completo.'
                                : null,
                          ),
                          TextFormField(
                            key: const ValueKey('raizes-public-phone'),
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: _deco('Telefone / WhatsApp com DDD *'),
                            validator: (v) =>
                                (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                                ? 'Confira o telefone, com DDD.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _neighborhood,
                            maxLength: 120,
                            decoration: _deco('Bairro'),
                          ),
                          TextFormField(
                            controller: _invitedBy,
                            maxLength: 200,
                            decoration: _deco('Quem te convidou?'),
                          ),
                          DropdownButtonFormField<String?>(
                            initialValue: _marital,
                            decoration: _deco('Estado civil'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Prefiro não dizer'),
                              ),
                              for (final e in _maritalLabels.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                            onChanged: (v) => setState(() => _marital = v),
                          ),
                          const SizedBox(height: 12),
                          Text('Você se encaixa em:', style: meta),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final e in _profileLabels.entries)
                                FilterChip(
                                  label: Text(e.value),
                                  selected: _profiles.contains(e.key),
                                  onSelected: (on) => setState(
                                    () => on
                                        ? _profiles.add(e.key)
                                        : _profiles.remove(e.key),
                                  ),
                                ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Quero receber contato da igreja'),
                            value: _wantsContact,
                            onChanged: (v) => setState(() => _wantsContact = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Gostaria de receber uma visita'),
                            value: _wantsVisit,
                            onChanged: (v) => setState(() => _wantsVisit = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Quero conhecer uma Casa de Vida perto de mim',
                            ),
                            value: _wantsLifeHouse,
                            onChanged: (v) =>
                                setState(() => _wantsLifeHouse = v),
                          ),
                          TextFormField(
                            controller: _prayer,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: _deco('Pedido de oração (opcional)'),
                          ),
                          CheckboxListTile(
                            key: const ValueKey('raizes-public-lgpd'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _lgpd,
                            onChanged: (v) => setState(() => _lgpd = v ?? false),
                            title: const Text(
                              'Concordo que a igreja guarde estes dados para '
                              'me acompanhar e entrar em contato. Posso pedir '
                              'para apagar quando quiser.',
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton(
                            key: const ValueKey('raizes-public-submit'),
                            onPressed: _sending ? null : _submit,
                            child: Text(_sending ? 'Enviando...' : 'Enviar'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Message({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}
