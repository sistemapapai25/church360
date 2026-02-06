import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../widgets/image_upload_widget.dart';
import '../navigation/app_router.dart';
import '../../features/support_chat/data/support_agents_data.dart';
import '../../features/support_chat/presentation/providers/agents_providers.dart';
import '../../features/support_chat/presentation/widgets/universal_support_chat.dart';
import '../../features/ministries/presentation/providers/ministries_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/supabase_constants.dart';
import '../../features/members/presentation/providers/members_provider.dart';

class DeveloperSettingsScreen extends ConsumerStatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  ConsumerState<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends ConsumerState<DeveloperSettingsScreen> {
  final _uazapiBaseUrlController = TextEditingController();
  final _uazapiTokenController = TextEditingController();
  final _uazapiWebhookSecretController = TextEditingController();
  final _uazapiSendPathController = TextEditingController(text: '/send/text');
  final _uazapiStatusPathController = TextEditingController(text: '/instance/status');
  final _testPhoneController = TextEditingController();
  final _testTextController = TextEditingController(text: 'Teste Church360');
  final _advPathController = TextEditingController(text: '/messages');
  String _advMethod = 'POST';
  String _advAuth = 'BearerHeader';
  final _advTokenQueryNameController = TextEditingController(text: 'token');
  final _advHeaderNameController = TextEditingController(text: 'token');
  final _advNumberKeyController = TextEditingController(text: 'to');
  final _advTextKeyController = TextEditingController(text: 'text');
  String _advContentType = 'json';
  final _advExtraParamsController = TextEditingController(text: '{}');
  final Map<String, TextEditingController> _groupControllers = {};
  final _dispatchCronController = TextEditingController(text: '*/5 * * * *');
  final _pollerCronController = TextEditingController(text: '*/10 * * * *');
  
  // Support Chat
  String _selectedAgent = 'default';
  final _customAgentController = TextEditingController();
  bool _clearingCache = false;

  bool _loadingApis = true;
  bool _statusLoading = false;
  bool? _statusConnected;
  String _statusNumber = '';
  String _statusMessage = '';

  // Agent Config State
  bool _loadingAgents = false;
  final Map<String, String> _agentConfigs = {}; // Stores IDs
  final _agentIdControllers = <String, TextEditingController>{};
  final _agentKeyControllers = <String, TextEditingController>{};
  final _agentDisplayNameControllers = <String, TextEditingController>{};
  final _agentSubtitleControllers = <String, TextEditingController>{};
  final _agentThemeColorControllers = <String, TextEditingController>{};
  final _agentAvatarUrls = <String, String?>{};
  final _agentShowOnDashboard = <String, bool>{};
  final _agentShowOnHome = <String, bool>{};
  final _agentShowFloatingButton = <String, bool>{};
  final _agentFloatingRouteControllers = <String, TextEditingController>{};
  final _agentFloatingRouteSelections = <String, String?>{};
  final _agentAllowedAccessLevels = <String, Set<String>>{};
  late final List<Map<String, String>> _computedFloatingRouteOptions =
      _buildFloatingRouteOptions();

  static const _themeColorPresets = <Map<String, String>>[
    {'label': 'Azul', 'hex': '#2563EB'},
    {'label': 'Indigo', 'hex': '#4F46E5'},
    {'label': 'Roxo', 'hex': '#7C3AED'},
    {'label': 'Rosa', 'hex': '#DB2777'},
    {'label': 'Vermelho', 'hex': '#DC2626'},
    {'label': 'Laranja', 'hex': '#EA580C'},
    {'label': 'Âmbar', 'hex': '#D97706'},
    {'label': 'Verde', 'hex': '#16A34A'},
    {'label': 'Ciano', 'hex': '#0891B2'},
    {'label': 'Cinza', 'hex': '#475569'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadAgentConfigs();
      try {
        final supabase = ref.read(supabaseClientProvider);
        final data = await supabase
            .from('integration_settings')
            .select('base_url,instance_token,webhook_secret,send_path,status_path')
            .eq('provider', 'uazapi')
            .maybeSingle();
        if (data != null) {
          _uazapiBaseUrlController.text = (data['base_url'] ?? '').toString();
          _uazapiTokenController.text = (data['instance_token'] ?? '').toString();
          _uazapiWebhookSecretController.text = (data['webhook_secret'] ?? '').toString();
          final sp = (data['send_path'] ?? '').toString();
          if (sp.isNotEmpty) {
            _uazapiSendPathController.text = sp;
          }
          final stp = (data['status_path'] ?? '').toString();
          if (stp.isNotEmpty) {
            _uazapiStatusPathController.text = stp;
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _loadAgentConfigs() async {
    setState(() => _loadingAgents = true);
    final supabase = ref.read(supabaseClientProvider);
    try {
      final tenantId = SupabaseConstants.currentTenantId.trim();
      final response = await supabase
          .from('agent_config')
          .select('tenant_id, key, assistant_id, openai_api_key, display_name, subtitle, avatar_url, theme_color, show_on_home, show_on_dashboard, show_floating_button, floating_route, allowed_access_levels')
          .or('tenant_id.eq.$tenantId,tenant_id.is.null')
          .order('key');
      
      final raw = response as List;
      final byKey = <String, Map<String, dynamic>>{};
      for (final r in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(r);
        final key = (map['key'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        final rowTenant = (map['tenant_id'] ?? '').toString().trim();
        if (rowTenant.isEmpty) byKey.putIfAbsent(key.toLowerCase(), () => map);
      }
      for (final r in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(r);
        final key = (map['key'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        final rowTenant = (map['tenant_id'] ?? '').toString().trim();
        if (rowTenant == tenantId) byKey[key.toLowerCase()] = map;
      }
      final data = byKey.values.toList()
        ..sort((a, b) => (a['key'] ?? '').toString().compareTo((b['key'] ?? '').toString()));
      _agentConfigs.clear();
      for (final c in _agentIdControllers.values) {
        c.dispose();
      }
      for (final c in _agentKeyControllers.values) {
        c.dispose();
      }
      for (final c in _agentDisplayNameControllers.values) {
        c.dispose();
      }
      for (final c in _agentSubtitleControllers.values) {
        c.dispose();
      }
      for (final c in _agentThemeColorControllers.values) {
        c.dispose();
      }
      for (final c in _agentFloatingRouteControllers.values) {
        c.dispose();
      }
      _agentIdControllers.clear();
      _agentKeyControllers.clear();
      _agentDisplayNameControllers.clear();
      _agentSubtitleControllers.clear();
      _agentThemeColorControllers.clear();
      _agentFloatingRouteControllers.clear();
      _agentFloatingRouteSelections.clear();
      _agentAvatarUrls.clear();
      _agentShowOnDashboard.clear();
      _agentShowOnHome.clear();
      _agentShowFloatingButton.clear();
      _agentAllowedAccessLevels.clear();
      
      for (var item in data) {
        final key = item['key'].toString();
        final id = (item['assistant_id'] ?? '').toString();
        final apiKey = (item['openai_api_key'] ?? '').toString();
        final displayName = (item['display_name'] ?? '').toString();
        final subtitle = (item['subtitle'] ?? '').toString();
        final avatarUrl = (item['avatar_url'] ?? '').toString();
        final themeColor = (item['theme_color'] ?? '').toString();
        final allowedRaw = item['allowed_access_levels'];
        final allowedList = allowedRaw is List
            ? allowedRaw.map((e) => e.toString()).toList()
            : <String>[];

        bool readBool(String field, bool defaultValue) {
          final v = item[field];
          if (v == null) return defaultValue;
          if (v is bool) return v;
          if (v is num) return v != 0;
          final s = v.toString().trim().toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
          return defaultValue;
        }
        
        _agentConfigs[key] = id;
        _agentIdControllers[key] = TextEditingController(text: id);
        _agentKeyControllers[key] = TextEditingController(text: apiKey);
        _agentDisplayNameControllers[key] = TextEditingController(text: displayName);
        _agentSubtitleControllers[key] = TextEditingController(text: subtitle);
        _agentThemeColorControllers[key] = TextEditingController(text: themeColor);
        _agentAvatarUrls[key] = avatarUrl.isEmpty ? null : avatarUrl;
        _agentShowOnHome[key] = readBool('show_on_home', false);
        _agentShowOnDashboard[key] = readBool('show_on_dashboard', true);
        _agentShowFloatingButton[key] = readBool('show_floating_button', key == 'default');
        final fr = _normalizeRouteText((item['floating_route'] ?? '').toString());
        _agentFloatingRouteControllers[key] = TextEditingController(text: fr);
        _agentFloatingRouteSelections[key] = _routeDropdownValue(fr);
        _agentAllowedAccessLevels[key] = allowedList.map((e) => e.toString()).toSet();
      }
      
      for (final key in kSupportAgents.keys) {
        if (!_agentIdControllers.containsKey(key)) {
          _agentIdControllers[key] = TextEditingController();
          _agentKeyControllers[key] = TextEditingController();
          _agentDisplayNameControllers[key] = TextEditingController(text: kSupportAgents[key]?.name ?? '');
          _agentSubtitleControllers[key] = TextEditingController();
          _agentThemeColorControllers[key] = TextEditingController(text: kSupportAgents[key]?.defaultThemeColorHex ?? '');
          _agentAvatarUrls[key] = null;
          _agentShowOnHome[key] = false;
          _agentShowOnDashboard[key] = true;
          _agentShowFloatingButton[key] = key == 'default';
          _agentFloatingRouteControllers[key] = TextEditingController();
          _agentFloatingRouteSelections[key] = null;
          _agentAllowedAccessLevels[key] = <String>{};
        }
      }
      
    } catch (e) {
      for (final key in kSupportAgents.keys) {
        if (!_agentIdControllers.containsKey(key)) {
          _agentIdControllers[key] = TextEditingController();
          _agentKeyControllers[key] = TextEditingController();
          _agentDisplayNameControllers[key] = TextEditingController(text: kSupportAgents[key]?.name ?? '');
          _agentSubtitleControllers[key] = TextEditingController();
          _agentThemeColorControllers[key] = TextEditingController(text: kSupportAgents[key]?.defaultThemeColorHex ?? '');
          _agentAvatarUrls[key] = null;
          _agentShowOnHome[key] = false;
          _agentShowOnDashboard[key] = true;
          _agentShowFloatingButton[key] = key == 'default';
          _agentFloatingRouteControllers[key] = TextEditingController();
          _agentFloatingRouteSelections[key] = null;
          _agentAllowedAccessLevels[key] = <String>{};
        }
      }
    } finally {
      if (mounted) setState(() => _loadingAgents = false);
    }
  }

  Future<void> _saveAgentConfig(String key) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      var assistantId = _agentIdControllers[key]?.text.trim() ?? '';
      if (assistantId.startsWith('IDasst_')) {
        assistantId = assistantId.substring(2);
        _agentIdControllers[key]?.text = assistantId;
      }
      final apiKey = _agentKeyControllers[key]?.text.trim() ?? '';
      final displayName = _agentDisplayNameControllers[key]?.text.trim() ?? '';
      final subtitle = _agentSubtitleControllers[key]?.text.trim() ?? '';
      final avatarUrl = (_agentAvatarUrls[key] ?? '').trim();
      final themeColor = _agentThemeColorControllers[key]?.text.trim() ?? '';
      final allowed = (_agentAllowedAccessLevels[key] ?? {}).toList();
      final floatingRoute = _agentFloatingRouteControllers[key]?.text.trim() ?? '';
      final data = {
        'tenant_id': SupabaseConstants.currentTenantId,
        'key': key,
        'assistant_id': assistantId,
        'display_name': displayName.isEmpty ? null : displayName,
        'subtitle': subtitle.isEmpty ? null : subtitle,
        'avatar_url': avatarUrl.isEmpty ? null : avatarUrl,
        'theme_color': themeColor.isEmpty ? null : themeColor,
        'updated_at': DateTime.now().toIso8601String(),
        'show_on_home': _agentShowOnHome[key] ?? false,
        'show_on_dashboard': _agentShowOnDashboard[key] ?? true,
        'show_floating_button': _agentShowFloatingButton[key] ?? false,
        'floating_route': floatingRoute.isEmpty ? null : floatingRoute,
        'allowed_access_levels': allowed,
      };
      data['openai_api_key'] = apiKey;

      await supabase.from('agent_config').upsert(data, onConflict: 'tenant_id,key');
      ref.invalidate(agentRuntimeConfigsProvider);
      ref.invalidate(resolvedAgentsProvider);
      ref.invalidate(visibleAgentsForCurrentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Salvo: $key')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _deleteAgentConfig(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir Agente: $key?'),
        content: const Text(
            'Isso removerá as configurações deste agente. Se ele for um agente padrão do sistema, ele voltará às configurações originais (hardcoded). Se for um agente customizado, ele desaparecerá.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('agent_config')
          .delete()
          .eq('key', key)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
      ref.invalidate(agentRuntimeConfigsProvider);
      ref.invalidate(resolvedAgentsProvider);
      ref.invalidate(visibleAgentsForCurrentUserProvider);
      
      await _loadAgentConfigs(); // Recarrega a lista para refletir a mudança
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agente excluído: $key')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _agentIdControllers.values) {
      c.dispose();
    }
    for (final c in _agentKeyControllers.values) {
      c.dispose();
    }
    for (final c in _agentDisplayNameControllers.values) {
      c.dispose();
    }
    for (final c in _agentSubtitleControllers.values) {
      c.dispose();
    }
    for (final c in _agentThemeColorControllers.values) {
      c.dispose();
    }
    for (final c in _agentFloatingRouteControllers.values) {
      c.dispose();
    }
    _uazapiBaseUrlController.dispose();
    _uazapiTokenController.dispose();
    _uazapiWebhookSecretController.dispose();
    _uazapiSendPathController.dispose();
    _testPhoneController.dispose();
    _testTextController.dispose();
    _advPathController.dispose();
    _advTokenQueryNameController.dispose();
    _advHeaderNameController.dispose();
    _advNumberKeyController.dispose();
    _advTextKeyController.dispose();
    _advExtraParamsController.dispose();
    _dispatchCronController.dispose();
    _pollerCronController.dispose();
    for (final c in _groupControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color _getAgentColor(String key) {
    switch (key.toLowerCase()) {
      case 'kids':
      case 'infantil':
        return Colors.orange;
      case 'media':
      case 'midia':
        return Colors.purple;
      default:
        return const Color(0xFF2563EB);
    }
  }
  
  String _normalizeRouteText(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    return v.startsWith('/') ? v : '/$v';
  }

  List<String> _collectRoutePaths(List<RouteBase> routes) {
    final paths = <String>[];
    for (final r in routes) {
      if (r is GoRoute) {
        paths.add(r.path);
        paths.addAll(_collectRoutePaths(r.routes));
      } else if (r is ShellRoute) {
        paths.addAll(_collectRoutePaths(r.routes));
      }
    }
    return paths;
  }

  String _titleFromPath(String path) {
    final p = path.trim();
    if (p.isEmpty) return 'Tela';
    final uri = Uri.tryParse(p);
    final rawPath = uri?.path ?? p;
    final segs = rawPath
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segs.isEmpty) return 'Home';
    final words = segs.map((s) {
      if (s.startsWith(':')) return s;
      final w = s.replaceAll('-', ' ').replaceAll('_', ' ');
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' / ');
    return words;
  }

  List<Map<String, String>> _buildFloatingRouteOptions() {
    final base = <Map<String, String>>[
      {'label': 'Home (Dashboard)', 'path': '/home?tab=home'},
      {'label': 'Home (Devocionais)', 'path': '/home?tab=devotionals'},
      {'label': 'Home (Agenda)', 'path': '/home?tab=agenda'},
      {'label': 'Home (Contribua)', 'path': '/home?tab=contribution'},
      {'label': 'Home (Mais)', 'path': '/home?tab=more'},
      {'label': 'Dashboard (Gestão)', 'path': '/dashboard'},
      {'label': 'Central de Agentes (Gestão)', 'path': '/agents-center'},
    ];

    final paths = _collectRoutePaths(appRouter.configuration.routes);
    final list = <Map<String, String>>[...base];
    for (final p in paths) {
      final path = p.trim();
      if (path.isEmpty) continue;
      if (path == '/home') continue;
      final label = _titleFromPath(path);
      list.add({'label': label, 'path': path});
    }

    final byPath = <String, Map<String, String>>{};
    for (final o in list) {
      final p = (o['path'] ?? '').trim();
      final l = (o['label'] ?? '').trim();
      if (p.isEmpty || l.isEmpty) continue;
      byPath.putIfAbsent(p, () => {'label': l, 'path': p});
    }
    final out = byPath.values.toList();
    out.sort((a, b) => a['label']!.compareTo(b['label']!));
    return out;
  }

  String? _routeDropdownValue(String current) {
    final normalized = _normalizeRouteText(current);
    if (normalized.isEmpty) return null;
    final known = _computedFloatingRouteOptions.any((o) => o['path'] == normalized);
    return known ? normalized : '__custom__';
  }

  Color? _tryParseHexColor(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 3) {
      value = '${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}';
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final supabase = ref.watch(supabaseClientProvider);
    final memberAsync = ref.watch(currentMemberProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações de Desenvolvedor')),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(child: Text('Usuário não autenticado'));
          }
          return FutureBuilder<Map<String, dynamic>?>(
            future: supabase
                .from('user_account')
                .select('role_global')
                .eq('id', member.id)
                .eq('tenant_id', SupabaseConstants.currentTenantId)
                .maybeSingle(),
            builder: (context, snapshot) {
              final isOwner = (snapshot.data?['role_global']?.toString() ?? '') == 'owner';
              return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Support Chat / Multi-Agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ExpansionTile(
                              title: const Text('Configuração de IDs (OpenAI)'),
                              subtitle: const Text('Defina os IDs dos Assistentes'),
                              children: [
                                if (_loadingAgents)
                                  const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
                                else ...[
                                  ..._agentIdControllers.entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Agente: ${entry.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: entry.value,
                                                  decoration: InputDecoration(
                                                    labelText: 'ID do Assistente',
                                                    border: const OutlineInputBorder(),
                                                    hintText: 'asst_...',
                                                    isDense: true,
                                                    errorText: entry.value.text.trim().startsWith('IDasst_') 
                                                        ? 'Remova o prefixo "ID" (deve começar com "asst_")' 
                                                        : null,
                                                  ),
                                                  onChanged: (val) {
                                                    if (val.startsWith('IDasst_')) {
                                                      setState(() {});
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.save, color: Colors.green),
                                                onPressed: () {
                                                  var id = entry.value.text.trim();
                                                  if (id.startsWith('IDasst_')) {
                                                    id = id.substring(2);
                                                    entry.value.text = id;
                                                  }
                                                  _saveAgentConfig(entry.key);
                                                },
                                                tooltip: 'Salvar Config',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _agentKeyControllers[entry.key],
                                            decoration: const InputDecoration(
                                              labelText: 'OpenAI API Key (Opcional se usar ENV global)',
                                              border: OutlineInputBorder(),
                                              hintText: 'sk-...',
                                              isDense: true,
                                            ),
                                            obscureText: true,
                                          ),
                                          const Divider(),
                                        ],
                                      ),
                                    );
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Adicionar Agente Personalizado'),
                                      onPressed: () {
                                        showDialog(
                                          context: context, 
                                          builder: (ctx) {
                                            final keyCtrl = TextEditingController();
                                            return AlertDialog(
                                              title: const Text('Novo Agente'),
                                              content: TextField(
                                                controller: keyCtrl,
                                                decoration: const InputDecoration(labelText: 'Chave (ex: jovens)'),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                                FilledButton(
                                                  onPressed: () {
                                                    final k = keyCtrl.text.trim().toLowerCase();
                                                    if (k.isNotEmpty && !_agentIdControllers.containsKey(k)) {
                                                      setState(() {
                                                        _agentIdControllers[k] = TextEditingController();
                                                        _agentKeyControllers[k] = TextEditingController();
                                                        _agentDisplayNameControllers[k] = TextEditingController(text: k);
                                                        _agentSubtitleControllers[k] = TextEditingController();
                                                        _agentThemeColorControllers[k] = TextEditingController();
                                                        _agentAvatarUrls[k] = null;
                                                        _agentShowOnHome[k] = false;
                                                        _agentShowOnDashboard[k] = true;
                                                        _agentShowFloatingButton[k] = false;
                                                        _agentFloatingRouteControllers[k] = TextEditingController();
                                                        _agentAllowedAccessLevels[k] = <String>{};
                                                      });
                                                      Navigator.pop(ctx);
                                                    }
                                                  }, 
                                                  child: const Text('Adicionar')
                                                ),
                                              ],
                                            );
                                          }
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            ExpansionTile(
                              title: const Text('Edição de Agentes'),
                              subtitle: const Text('Nome, avatar, visibilidade e níveis'),
                              children: [
                                if (_loadingAgents)
                                  const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
                                else ...[
                                  ...(() {
                                    final keys = _agentIdControllers.keys.toList()..sort();
                                    return keys.map((key) {
                                      final showFab = _agentShowFloatingButton[key] ?? false;
                                      final allowed = _agentAllowedAccessLevels[key] ?? <String>{};
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Agente: $key', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _agentDisplayNameControllers[key],
                                              decoration: const InputDecoration(
                                                labelText: 'Nome de Exibição',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _agentSubtitleControllers[key],
                                              decoration: const InputDecoration(
                                                labelText: 'Subtítulo',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ImageUploadWidget(
                                              initialImageUrl: _agentAvatarUrls[key],
                                              onImageUrlChanged: (url) {
                                                setState(() {
                                                  _agentAvatarUrls[key] = url;
                                                });
                                              },
                                              storageBucket: 'agent-avatars',
                                              fallbackBuckets: const ['member-photos'],
                                              label: 'Avatar do Agente',
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _agentThemeColorControllers[key],
                                              decoration: const InputDecoration(
                                                labelText: 'Cor do Tema (Hex)',
                                                border: OutlineInputBorder(),
                                                hintText: '#2563EB',
                                                isDense: true,
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _tryParseHexColor(
                                                          _agentThemeColorControllers[key]?.text ?? '',
                                                        ) ??
                                                        Colors.transparent,
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .outlineVariant,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      for (final preset in _themeColorPresets)
                                                        ActionChip(
                                                          label: Text(preset['label']!),
                                                          onPressed: () {
                                                            final hex = preset['hex']!;
                                                            _agentThemeColorControllers[key]?.text = hex;
                                                            setState(() {});
                                                          },
                                                        ),
                                                      ActionChip(
                                                        label: const Text('Padrão'),
                                                        onPressed: () {
                                                          _agentThemeColorControllers[key]?.text = '';
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            SwitchListTile(
                                              value: _agentShowOnHome[key] ?? false,
                                              onChanged: (v) {
                                                setState(() {
                                                  _agentShowOnHome[key] = v;
                                                });
                                              },
                                              title: const Text('Mostrar na Home'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            SwitchListTile(
                                              value: _agentShowOnDashboard[key] ?? true,
                                              onChanged: (v) {
                                                setState(() {
                                                  _agentShowOnDashboard[key] = v;
                                                });
                                              },
                                              title: const Text('Mostrar na Dashboard'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            SwitchListTile(
                                              value: showFab,
                                              onChanged: (v) {
                                                setState(() {
                                                  _agentShowFloatingButton[key] = v;
                                                  if (v) {
                                                    final current =
                                                        _agentFloatingRouteControllers[key]?.text ?? '';
                                                    if (_normalizeRouteText(current).isEmpty) {
                                                      const defaultRoute = '/home?tab=home';
                                                      _agentFloatingRouteControllers[key]?.text = defaultRoute;
                                                      _agentFloatingRouteSelections[key] = defaultRoute;
                                                    }
                                                  }
                                                });
                                              },
                                              title: const Text('Exibir botão flutuante'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            const SizedBox(height: 8),
                                            (() {
                                              final currentText =
                                                  _agentFloatingRouteControllers[key]?.text ?? '';
                                              final computedSelection =
                                                  _agentFloatingRouteSelections[key] ??
                                                      _routeDropdownValue(currentText);
                                              final isKnown = computedSelection != null &&
                                                  computedSelection != '__custom__' &&
                                                  _computedFloatingRouteOptions
                                                      .any((o) => o['path'] == computedSelection);
                                              final safeValue = computedSelection == null
                                                  ? null
                                                  : (computedSelection == '__custom__'
                                                      ? '__custom__'
                                                      : (isKnown ? computedSelection : '__custom__'));
                                              return DropdownButtonFormField<String>(
                                              key: ValueKey<String>(
                                                '${key}_${safeValue ?? 'null'}_${showFab ? 'on' : 'off'}',
                                              ),
                                              initialValue: safeValue,
                                              decoration: const InputDecoration(
                                                labelText: 'Tela do botão flutuante',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              hint: const Text('Selecione uma tela'),
                                              items: [
                                                ..._computedFloatingRouteOptions.map(
                                                  (o) => DropdownMenuItem<String>(
                                                    value: o['path']!,
                                                    child: Text('${o['label']} (${o['path']})'),
                                                  ),
                                                ),
                                                const DropdownMenuItem<String>(
                                                  value: '__custom__',
                                                  child: Text('Customizada'),
                                                ),
                                              ],
                                              onChanged: showFab
                                                  ? (val) {
                                                      if (val == null) return;
                                                      setState(() {
                                                        _agentFloatingRouteSelections[key] = val;
                                                        if (val != '__custom__') {
                                                          _agentFloatingRouteControllers[key]?.text = val;
                                                        }
                                                      });
                                                    }
                                                  : null,
                                            );
                                            })(),
                                            const SizedBox(height: 8),
                                            if (showFab &&
                                                (_agentFloatingRouteSelections[key] == '__custom__' ||
                                                    _routeDropdownValue(
                                                          _agentFloatingRouteControllers[key]?.text ?? '',
                                                        ) ==
                                                        '__custom__'))
                                              TextField(
                                                controller: _agentFloatingRouteControllers[key],
                                                decoration: const InputDecoration(
                                                  labelText: 'Rota do botão flutuante (custom)',
                                                  border: OutlineInputBorder(),
                                                  hintText: '/home',
                                                  isDense: true,
                                                ),
                                                onChanged: (v) {
                                                  final normalized = _normalizeRouteText(v);
                                                  if (normalized != v.trim() && normalized != v) {
                                                    _agentFloatingRouteControllers[key]?.text = normalized;
                                                    _agentFloatingRouteControllers[key]?.selection =
                                                        TextSelection.collapsed(
                                                      offset: normalized.length,
                                                    );
                                                  }
                                                  setState(() {
                                                    _agentFloatingRouteSelections[key] =
                                                        _routeDropdownValue(normalized);
                                                  });
                                                },
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final level in const [
                                                  'visitor',
                                                  'attendee',
                                                  'member',
                                                  'leader',
                                                  'coordinator',
                                                  'admin',
                                                ])
                                                  FilterChip(
                                                    selected: allowed.contains(level),
                                                    label: Text(level),
                                                    onSelected: (v) {
                                                      setState(() {
                                                        final set = _agentAllowedAccessLevels[key] ?? <String>{};
                                                        if (v) {
                                                          set.add(level);
                                                        } else {
                                                          set.remove(level);
                                                        }
                                                        _agentAllowedAccessLevels[key] = set;
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: FilledButton.icon(
                                                    onPressed: () => _saveAgentConfig(key),
                                                    icon: const Icon(Icons.save),
                                                    label: const Text('Salvar agente'),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed: () => _deleteAgentConfig(key),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(color: Colors.red),
                                                  ),
                                                  child: const Icon(Icons.delete_outline),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 32),
                                          ],
                                        ),
                                      );
                                    });
                                  })(),
                                ],
                              ],
                            ),
                            const Divider(height: 32),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedAgent,
                              decoration: const InputDecoration(
                                labelText: 'Agente Selecionado',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'default', child: Text('Default (Padrão)')),
                                DropdownMenuItem(value: 'kids', child: Text('Kids (Infantil)')),
                                DropdownMenuItem(value: 'media', child: Text('Media (Mídia)')),
                                DropdownMenuItem(value: 'custom', child: Text('Customizado')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedAgent = val ?? 'default';
                                });
                              },
                            ),
                            if (_selectedAgent == 'custom') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _customAgentController,
                                decoration: const InputDecoration(
                                  labelText: 'Agent Key Customizada',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      final agentKey = _selectedAgent == 'custom' 
                                          ? _customAgentController.text.trim() 
                                          : _selectedAgent;
                                      
                                      if (agentKey.isEmpty) return;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => Scaffold(
                                            appBar: AppBar(title: Text('Chat: $agentKey')),
                                            body: UniversalSupportChat(
                                              agentKey: agentKey,
                                              accentColor: _getAgentColor(agentKey),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Testar Chat'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _clearingCache ? null : () async {
                                    setState(() => _clearingCache = true);
                                    final agentKey = _selectedAgent == 'custom' 
                                          ? _customAgentController.text.trim() 
                                          : _selectedAgent;
                                    
                                    final messenger = ScaffoldMessenger.of(context);
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove('support_thread_$agentKey');
                                    
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Cache limpo para: $agentKey')),
                                      );
                                      setState(() => _clearingCache = false);
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Limpar Thread'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Uazapi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _uazapiStatusPathController,
                              decoration: const InputDecoration(
                                labelText: 'Caminho de Status (ex.: /instance/status)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _uazapiBaseUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Base URL',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _uazapiSendPathController,
                              decoration: const InputDecoration(
                                labelText: 'Caminho do Endpoint (ex.: /send/text)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _uazapiTokenController,
                              decoration: const InputDecoration(
                                labelText: 'Token da Instância',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _uazapiWebhookSecretController,
                              decoration: const InputDecoration(
                                labelText: 'Webhook Secret (para callback)',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () async {
                                  final base = _uazapiBaseUrlController.text.trim();
                                  final token = _uazapiTokenController.text.trim();
                                  final whsec = _uazapiWebhookSecretController.text.trim();
                                  final sendPath = _uazapiSendPathController.text.trim();
                                  final statusPath = _uazapiStatusPathController.text.trim();
                                  try {
                                    final current = await supabase
                                        .from('integration_settings')
                                        .select()
                                        .eq('provider', 'uazapi')
                                        .maybeSingle();
                                    if (current != null) {
                                      await supabase
                                          .from('integration_settings')
                                          .update({
                                            'base_url': base,
                                            'instance_token': token,
                                            'webhook_secret': whsec,
                                            'send_path': sendPath.isNotEmpty ? sendPath : '/send/text',
                                            'status_path': statusPath.isNotEmpty ? statusPath : '/instance/status',
                                            'updated_by': member.id,
                                            'updated_at': DateTime.now().toIso8601String(),
                                          })
                                          .eq('provider', 'uazapi')
                                          .select();
                                    } else {
                                      await supabase
                                          .from('integration_settings')
                                          .insert({
                                            'provider': 'uazapi',
                                            'base_url': base,
                                            'instance_token': token,
                                            'webhook_secret': whsec,
                                            'send_path': sendPath.isNotEmpty ? sendPath : '/send/text',
                                            'status_path': statusPath.isNotEmpty ? statusPath : '/instance/status',
                                            'created_by': member.id,
                                            'updated_by': member.id,
                                            'updated_at': DateTime.now().toIso8601String(),
                                          })
                                          .select();
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('APIs salvas')),
                                      );
                                    }
                                  } catch (e) {
                                    final msg = e.toString();
                                    final isPgrst = msg.contains('PGRST204');
                                    final missingWebhook = isPgrst && msg.contains('webhook_secret');
                                    final missingMeta = isPgrst && (msg.contains('updated_by') || msg.contains('created_by') || msg.contains('updated_at'));
                                    final missingStatus = isPgrst && msg.contains('status_path');
                                    if (isPgrst) {
                                      try {
                                        final current = await supabase
                                            .from('integration_settings')
                                            .select()
                                            .eq('provider', 'uazapi')
                                            .maybeSingle();
                                        final data = <String, dynamic>{
                                          'base_url': base,
                                          'instance_token': token,
                                          'send_path': sendPath.isNotEmpty ? sendPath : '/send/text',
                                        };
                                        if (!missingStatus) {
                                          data['status_path'] = statusPath.isNotEmpty ? statusPath : '/instance/status';
                                        }
                                        if (!missingWebhook && whsec.isNotEmpty) {
                                          data['webhook_secret'] = whsec;
                                        }
                                        if (current != null) {
                                          await supabase
                                              .from('integration_settings')
                                              .update(data)
                                              .eq('provider', 'uazapi')
                                              .select();
                                        } else {
                                          data['provider'] = 'uazapi';
                                          await supabase
                                              .from('integration_settings')
                                              .insert(data)
                                              .select();
                                        }
                                        if (context.mounted) {
                                          final txt = missingWebhook
                                                  ? 'APIs salvas (sem webhook_secret)'
                                                  : missingMeta
                                                  ? 'APIs salvas (sem metadados)'
                                                  : 'APIs salvas';
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
                                        }
                                      } catch (e2) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Falha ao salvar APIs: $e2')),
                                          );
                                        }
                                      }
                                      return;
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Falha ao salvar APIs: $e')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Salvar APIs'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    ),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status da Instância', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_statusLoading)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                if (!_statusLoading)
                                  Icon(
                                    _statusConnected == true
                                        ? Icons.check_circle
                                        : _statusConnected == false
                                            ? Icons.cancel
                                            : Icons.help,
                                    color: _statusConnected == true
                                        ? Colors.green
                                        : _statusConnected == false
                                            ? Colors.red
                                            : Colors.grey,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusConnected == null
                                        ? 'Sem verificação'
                                        : (_statusConnected == true ? 'Conectado' : 'Desconectado') +
                                            (_statusNumber.isNotEmpty ? ' · número $_statusNumber' : ''),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final base = _uazapiBaseUrlController.text.trim();
                                    final token = _uazapiTokenController.text.trim();
                                    if (base.isEmpty || token.isEmpty) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha Base URL e Token')));
                                      }
                                      return;
                                    }
                                    setState(() {
                                      _statusLoading = true;
                                      _statusConnected = null;
                                      _statusNumber = '';
                                      _statusMessage = '';
                                    });
                                    try {
                                      final b = base.replaceAll(RegExp(r'/+$'), '');
                                      final configured = _uazapiStatusPathController.text.trim();
                                      final path = configured.isNotEmpty
                                          ? (configured.startsWith('/') ? configured : '/$configured')
                                          : '/instance/status';
                                      final endpoints = [path, '/status', '/instance/info'];
                                      final headerVariants = [
                                        {'Accept': 'application/json', 'Content-Type': 'application/json', 'token': token},
                                        {'Accept': 'application/json', 'Content-Type': 'application/json', 'Token': token},
                                      ];
                                      http.Response? okResp;
                                      Map<String, dynamic>? body;
                                      for (final ep in endpoints) {
                                        final uri = Uri.parse('$b$ep');
                                        bool success = false;
                                        for (final headers in headerVariants) {
                                          try {
                                            final resp = await http.get(uri, headers: headers);
                                            if (resp.statusCode >= 200 && resp.statusCode < 300) {
                                              okResp = resp;
                                              try {
                                                body = jsonDecode(resp.body) as Map<String, dynamic>;
                                              } catch (_) {
                                                body = null;
                                              }
                                              success = true;
                                              break;
                                            }
                                          } catch (_) {}
                                        }
                                        if (success) break;
                                        try {
                                          final url = uri.replace(queryParameters: {'token': token});
                                          final resp2 = await http.get(url, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'});
                                          if (resp2.statusCode >= 200 && resp2.statusCode < 300) {
                                            okResp = resp2;
                                            try {
                                              body = jsonDecode(resp2.body) as Map<String, dynamic>;
                                            } catch (_) {
                                              body = null;
                                            }
                                            break;
                                          }
                                        } catch (_) {}
                                      }
                                      if (okResp != null) {
                                        bool connected = false;
                                        String number = '';
                                        String message = '';
                                        try {
                                          bool resolveBool(dynamic v) {
                                            if (v is bool) return v;
                                            if (v is num) return v != 0;
                                            final s = v?.toString().toLowerCase() ?? '';
                                            return ['true', 'connected', 'online', 'ok', 'ready', 'authenticated', 'loggedin', 'logged_in'].contains(s);
                                          }
                                          String tryNumber(Map<String, dynamic> m) {
                                            final candidates = [
                                              m['number'],
                                              m['phone'],
                                              m['currentNumber'],
                                              m['instanceNumber'],
                                              m['whatsappNumber'],
                                              m['wid'],
                                              (m['me'] is Map ? (m['me'] as Map)['id'] : null),
                                            ];
                                            for (final c in candidates) {
                                              final s = (c ?? '').toString();
                                              if (s.isNotEmpty) return s;
                                            }
                                            return '';
                                          }
                                          bool deepConnected(dynamic v) {
                                            if (v is Map) {
                                              for (final entry in v.entries) {
                                                if (['connected','isConnected','online','authenticated','loggedIn','isLoggedIn','ready','status','state','connectionStatus'].contains(entry.key.toString())) {
                                                  if (resolveBool(entry.value)) return true;
                                                }
                                                if (deepConnected(entry.value)) return true;
                                              }
                                            } else if (v is List) {
                                              for (final e in v) {
                                                if (deepConnected(e)) return true;
                                              }
                                            } else {
                                              if (resolveBool(v)) return true;
                                            }
                                            return false;
                                          }
                                          connected = deepConnected(body ?? {});
                                          number = tryNumber(body ?? {});
                                          message = (body?['message'] ?? body?['detail'] ?? body?['error'] ?? '').toString();
                                          if (message.isEmpty && body != null) {
                                            final raw = jsonEncode(body);
                                            message = raw.length > 400 ? raw.substring(0, 400) : raw;
                                          }
                                        } catch (_) {}
                                        setState(() {
                                          _statusConnected = connected;
                                          _statusNumber = number;
                                          _statusMessage = message;
                                        });
                                      } else {
                                        setState(() {
                                          _statusConnected = false;
                                          _statusNumber = '';
                                          _statusMessage = 'Falha ao consultar status nos endpoints padrão';
                                        });
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                                      }
                                      setState(() {
                                        _statusConnected = false;
                                        _statusNumber = '';
                                        _statusMessage = e.toString();
                                      });
                                    } finally {
                                      setState(() {
                                        _statusLoading = false;
                                      });
                                    }
                                  },
                                  child: const Text('Verificar Status'),
                                ),
                              ],
                            ),
                            if (_statusMessage.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statusMessage,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Teste de Disparo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _testPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Número destino (WhatsApp)',
                                hintText: '+55XXXXXXXXXX',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _testTextController,
                              decoration: const InputDecoration(
                                labelText: 'Mensagem',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () async {
                                  final base = _uazapiBaseUrlController.text.trim();
                                  final token = _uazapiTokenController.text.trim();
                                  final to = _testPhoneController.text.trim();
                                  final text = _testTextController.text.trim();
                                  if (base.isEmpty || token.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha Base URL e Token')));
                                    }
                                    return;
                                  }
                                  if (to.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o número de destino')));
                                    }
                                    return;
                                  }
                                  try {
                                    final b = base.replaceAll(RegExp(r'/+$'), '');
                                    final number = to.replaceAll(RegExp(r'[^0-9]'), '');
                                    final sp = _uazapiSendPathController.text.trim();
                                    final p = sp.isEmpty
                                        ? '/send/text'
                                        : (sp.startsWith('/') ? sp : '/$sp');
                                    final directUri = Uri.parse('$b$p');
                                    final directHeaders = {
                                      'Accept': 'application/json',
                                      'Content-Type': 'application/json',
                                      'token': token,
                                    };
                                    final directBody = jsonEncode({'number': number, 'text': text});
                                    final directResp = await http.post(directUri, headers: directHeaders, body: directBody);
                                    if (directResp.statusCode >= 200 && directResp.statusCode < 300) {
                                      String id = '';
                                      try {
                                        final data = jsonDecode(directResp.body) as Map<String, dynamic>;
                                        id = (data['id'] ?? data['messageId'] ?? '').toString();
                                      } catch (_) {}
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id.isNotEmpty ? 'Enviado · id $id' : 'Enviado')));
                                      }
                                      return;
                                    } else {
                                      String msg = directResp.body;
                                      try {
                                        final parsed = jsonDecode(directResp.body) as Map<String, dynamic>;
                                        final m = (parsed['message'] ?? parsed['error'] ?? '').toString();
                                        if (m.isNotEmpty) msg = m;
                                      } catch (_) {}
                                      final snippet = msg.length > 300 ? msg.substring(0, 300) : msg;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falhou · código ${directResp.statusCode} · $snippet')));
                                      }
                                      return;
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                                    }
                                  }
                                },
                                child: const Text('Enviar teste via Uazapi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Envio Avançado (Rota/Contrato)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _advPathController.text = '/send/text';
                                      _advMethod = 'POST';
                                      _advAuth = 'CustomHeader';
                                      _advHeaderNameController.text = 'token';
                                      _advContentType = 'json';
                                      _advNumberKeyController.text = 'number';
                                      _advTextKeyController.text = 'text';
                                    });
                                  },
                                  child: const Text('Preset UazAPI · Envio'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _advPathController.text = '/instance/status';
                                      _advMethod = 'GET';
                                      _advAuth = 'CustomHeader';
                                      _advHeaderNameController.text = 'token';
                                      _advContentType = 'json';
                                      _advNumberKeyController.text = 'number';
                                      _advTextKeyController.text = 'text';
                                    });
                                  },
                                  child: const Text('Preset UazAPI · Status'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_uazapiBaseUrlController.text.trim().isEmpty) {
                                        _uazapiBaseUrlController.text = 'https://free.uazapi.com';
                                      }
                                    });
                                  },
                                  child: const Text('Preset Base URL'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _advPathController,
                              decoration: const InputDecoration(
                                labelText: 'Caminho da rota (ex.: /api/messages/send)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _advMethod,
                                    items: const [
                                      DropdownMenuItem(value: 'POST', child: Text('POST')),
                                      DropdownMenuItem(value: 'GET', child: Text('GET')),
                                    ],
                                    onChanged: (v) => setState(() => _advMethod = v ?? 'POST'),
                                    decoration: const InputDecoration(labelText: 'Método', border: OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _advAuth,
                                    items: const [
                                      DropdownMenuItem(value: 'BearerHeader', child: Text('Bearer Header')),
                                      DropdownMenuItem(value: 'ApiKeyHeader', child: Text('X-Api-Key Header')),
                                      DropdownMenuItem(value: 'QueryParam', child: Text('Token no Query')),
                                      DropdownMenuItem(value: 'CustomHeader', child: Text('Cabeçalho customizado')),
                                    ],
                                    onChanged: (v) => setState(() => _advAuth = v ?? 'BearerHeader'),
                                    decoration: const InputDecoration(labelText: 'Autenticação', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                            if (_advAuth == 'CustomHeader') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _advHeaderNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do cabeçalho de token (ex.: token, Token)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _advTokenQueryNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome do parâmetro de token (query)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _advContentType,
                                    items: const [
                                      DropdownMenuItem(value: 'json', child: Text('application/json')),
                                      DropdownMenuItem(value: 'form', child: Text('x-www-form-urlencoded')),
                                    ],
                                    onChanged: (v) => setState(() => _advContentType = v ?? 'json'),
                                    decoration: const InputDecoration(labelText: 'Content-Type', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _advNumberKeyController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome do parâmetro para número',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _advTextKeyController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome do parâmetro para texto',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _advExtraParamsController,
                              decoration: const InputDecoration(
                                labelText: 'Parâmetros extras (JSON)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () async {
                                  final base = _uazapiBaseUrlController.text.trim();
                                  final token = _uazapiTokenController.text.trim();
                                  final to = _testPhoneController.text.trim();
                                  final text = _testTextController.text.trim();
                                  final path = _advPathController.text.trim();
                                  final method = _advMethod;
                                  final auth = _advAuth;
                                  final tokenQueryName = _advTokenQueryNameController.text.trim();
                                  final headerName = _advHeaderNameController.text.trim();
                                  final numberKey = _advNumberKeyController.text.trim();
                                  final textKey = _advTextKeyController.text.trim();
                                  final contentType = _advContentType;
                                  Map<String, dynamic> extras = {};
                                  try {
                                    final raw = _advExtraParamsController.text.trim();
                                    if (raw.isNotEmpty) {
                                      extras = Map<String, dynamic>.from(jsonDecode(raw) as Map);
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON inválido em Parâmetros extras')));
                                    }
                                    return;
                                  }
                                  if (base.isEmpty || token.isEmpty || path.isEmpty || numberKey.isEmpty || textKey.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha Base URL, Token, Rota, número e texto')));
                                    }
                                    return;
                                  }
                                  if (auth == 'CustomHeader' && headerName.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome do cabeçalho de token')));
                                    }
                                    return;
                                  }
                                  try {
                                    final b = base.replaceAll(RegExp(r'/+$'), '');
                                    final p = path.startsWith('/') ? path : '/$path';
                                    final uriBase = Uri.parse('$b$p');
                                    final headers = <String, String>{
                                      'Accept': 'application/json',
                                    };
                                    if (auth == 'BearerHeader') headers['Authorization'] = 'Bearer $token';
                                    if (auth == 'ApiKeyHeader') headers['X-Api-Key'] = token;
                                    if (auth == 'CustomHeader') headers[headerName] = token;
                                    if (contentType == 'json' && method == 'POST') headers['Content-Type'] = 'application/json';
                                    if (contentType == 'form' && method == 'POST') headers['Content-Type'] = 'application/x-www-form-urlencoded';
                                    if (method == 'GET' && contentType == 'json') headers['Content-Type'] = 'application/json';
                                    final toDigits = to.replaceAll(RegExp(r'[^0-9]'), '');
                                    final toValue = to.contains('@') ? to : (toDigits.isNotEmpty ? toDigits : to);
                                    final payload = <String, dynamic>{
                                      numberKey: toValue,
                                      textKey: text,
                                      ...extras,
                                    };
                                    http.Response resp;
                                    if (method == 'GET') {
                                      final qp = <String, String>{
                                        numberKey: payload[numberKey].toString(),
                                        textKey: payload[textKey].toString(),
                                        ...extras.map((k, v) => MapEntry(k, v.toString())),
                                      };
                                      if (auth == 'QueryParam' && tokenQueryName.isNotEmpty) qp[tokenQueryName] = token;
                                      final url = uriBase.replace(queryParameters: qp);
                                      resp = await http.get(url, headers: headers);
                                    } else {
                                      if (auth == 'QueryParam' && tokenQueryName.isNotEmpty) {
                                        final url = uriBase.replace(queryParameters: {tokenQueryName: token});
                                        if (contentType == 'json') {
                                          resp = await http.post(url, headers: headers, body: jsonEncode(payload));
                                        } else {
                                          final body = Uri(queryParameters: payload.map((k, v) => MapEntry(k, v.toString()))).query;
                                          resp = await http.post(url, headers: headers, body: body);
                                        }
                                      } else {
                                        if (contentType == 'json') {
                                          resp = await http.post(uriBase, headers: headers, body: jsonEncode(payload));
                                        } else {
                                          final body = Uri(queryParameters: payload.map((k, v) => MapEntry(k, v.toString()))).query;
                                          resp = await http.post(uriBase, headers: headers, body: body);
                                        }
                                      }
                                    }
                                    if (resp.statusCode >= 200 && resp.statusCode < 300) {
                                      String id = '';
                                      try {
                                        final body = jsonDecode(resp.body) as Map<String, dynamic>;
                                        id = (body['id'] ?? body['messageId'] ?? '').toString();
                                      } catch (_) {}
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id.isNotEmpty ? 'Enviado · id $id' : 'Enviado')));
                                      }
                                    } else {
                                      String msg = resp.body;
                                      try {
                                        final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
                                        final m = (parsed['message'] ?? '').toString();
                                        if (m.isNotEmpty) msg = m;
                                      } catch (_) {}
                                      final snippet = msg.length > 200 ? msg.substring(0, 200) : msg;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falhou · código ${resp.statusCode} · $snippet')));
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                                    }
                                  }
                                },
                                child: const Text('Enviar avançado'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    FutureBuilder<Map<String, dynamic>?>(
                      future: supabase
                          .from('integration_settings')
                          .select()
                          .eq('provider', 'uazapi')
                          .maybeSingle(),
                      builder: (context, snapshot) {
                        if (_loadingApis && snapshot.connectionState == ConnectionState.done) {
                          _loadingApis = false;
                          final data = snapshot.data;
                          if (data != null) {
                          _uazapiBaseUrlController.text = (data['base_url'] ?? '').toString();
                          _uazapiTokenController.text = (data['instance_token'] ?? '').toString();
                          _uazapiWebhookSecretController.text = (data['webhook_secret'] ?? '').toString();
                          final sp = (data['send_path'] ?? '').toString();
                          if (sp.isNotEmpty) {
                            _uazapiSendPathController.text = sp;
                          }
                          final stp = (data['status_path'] ?? '').toString();
                          if (stp.isNotEmpty) {
                            _uazapiStatusPathController.text = stp;
                          }
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  FutureBuilder<List<dynamic>>(
                    future: supabase.rpc('get_schedulers').select(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final rows = snapshot.data!;
                        for (final r in rows) {
                          final m = r as Map<String, dynamic>;
                          final name = (m['jobname'] ?? '').toString();
                          final sched = (m['schedule'] ?? '').toString();
                          if (name == 'dispatch-processor' && sched.isNotEmpty) {
                            _dispatchCronController.text = sched;
                          }
                          if (name == 'status-poller' && sched.isNotEmpty) {
                            _pollerCronController.text = sched;
                          }
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (isOwner)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.lock, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Números de grupos (Owner)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Consumer(
                                builder: (context, ref, _) {
                                  final ministriesAsync = ref.watch(activeMinistriesProvider);
                                  return ministriesAsync.when(
                                    data: (list) {
                                      if (list.isEmpty) return const Text('Nenhum ministério ativo');
                                      for (final m in list) {
                                        _groupControllers.putIfAbsent(
                                          m.id,
                                          () => TextEditingController(text: m.whatsappGroupNumber ?? ''),
                                        );
                                      }
                                      return Column(
                                        children: [
                                          for (final m in list)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                children: [
                                                  Expanded(child: Text(m.name)),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 220,
                                                    child: TextField(
                                                      controller: _groupControllers[m.id]!,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Número do grupo',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  FilledButton(
                                                    onPressed: () async {
                                                      final repo = ref.read(ministriesRepositoryProvider);
                                                      final val = _groupControllers[m.id]!.text.trim();
                                                      await repo.updateMinistry(m.id, {'whatsapp_group_number': val});
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Atualizado')),
                                                        );
                                                      }
                                                    },
                                                    child: const Text('Salvar'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                    loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                                    error: (e, _) => Text('Erro: $e'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (isOwner)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.schedule),
                                SizedBox(width: 8),
                                Text('Agendamentos de Funções', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(child: Text('dispatch-processor')), 
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: _dispatchCronController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cron',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final anon = SupabaseConstants.supabaseAnonKey;
                                    final projectRef = Uri.parse(SupabaseConstants.supabaseUrl).host.split('.').first;
                                    final url = 'https://$projectRef.functions.supabase.co/dispatch-processor';
                                    await supabase.rpc('manage_scheduler', params: {
                                      'jobname': 'dispatch-processor',
                                      'schedule': _dispatchCronController.text.trim(),
                                      'url': url,
                                      'headers': {
                                        'Authorization': 'Bearer $anon',
                                        'Content-Type': 'application/json',
                                      },
                                      'body': {},
                                    }).select();
                                    try {
                                      await supabase.functions.invoke('dispatch-processor', body: {});
                                    } catch (_) {}
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento salvo')));
                                    }
                                  },
                                  child: const Text('Salvar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    final base = _uazapiBaseUrlController.text.trim();
                                    final token = _uazapiTokenController.text.trim();
                                    final sendPath = _uazapiSendPathController.text.trim();
                                    if (base.isEmpty || token.isEmpty) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha Base URL e Token')));
                                      }
                                      return;
                                    }
                                    try {
                                      await supabase.functions.invoke('dispatch-processor', body: {
                                        'base': base,
                                        'token': token,
                                        'path': sendPath,
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executado agora (processar regras)')));
                                      }
                                    } catch (e) {
                                      try {
                                        final anon = SupabaseConstants.supabaseAnonKey;
                                        final projectRef = Uri.parse(SupabaseConstants.supabaseUrl).host.split('.').first;
                                        final url = Uri.parse('https://$projectRef.functions.supabase.co/dispatch-processor');
                                        final resp = await http.post(
                                          url,
                                          headers: {
                                            'Authorization': 'Bearer $anon',
                                            'apikey': anon,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({'base': base, 'token': token, 'path': sendPath}),
                                        );
                                        if (resp.statusCode >= 200 && resp.statusCode < 300) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executado agora (fallback HTTP)')));
                                          }
                                        } else {
                                          String msg = resp.body;
                                          try {
                                            final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
                                            final m = (parsed['error'] ?? parsed['message'] ?? '').toString();
                                            if (m.isNotEmpty) msg = m;
                                          } catch (_) {}
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao executar: $msg')));
                                          }
                                        }
                                      } catch (e2) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao executar: $e2')));
                                        }
                                      }
                                    }
                                  },
                                  child: const Text('Executar agora'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(child: Text('status-poller')),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: _pollerCronController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cron',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final anon = SupabaseConstants.supabaseAnonKey;
                                    final projectRef = Uri.parse(SupabaseConstants.supabaseUrl).host.split('.').first;
                                    final url = 'https://$projectRef.functions.supabase.co/status-poller';
                                    await supabase.rpc('manage_scheduler', params: {
                                      'jobname': 'status-poller',
                                      'schedule': _pollerCronController.text.trim(),
                                      'url': url,
                                      'headers': {
                                        'Authorization': 'Bearer $anon',
                                        'Content-Type': 'application/json',
                                      },
                                      'body': {},
                                    }).select();
                                    try {
                                      await supabase.functions.invoke('status-poller', body: {});
                                    } catch (_) {}
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento salvo')));
                                    }
                                  },
                                  child: const Text('Salvar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      final statusPath = _uazapiStatusPathController.text.trim();
                                      await supabase.functions.invoke('status-poller', body: {
                                        'path': statusPath,
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executado agora')));
                                      }
                                    } catch (e) {
                                      try {
                                        final anon = SupabaseConstants.supabaseAnonKey;
                                        final projectRef = Uri.parse(SupabaseConstants.supabaseUrl).host.split('.').first;
                                        final url = Uri.parse('https://$projectRef.functions.supabase.co/status-poller');
                                        final resp = await http.post(
                                          url,
                                          headers: {
                                            'Authorization': 'Bearer $anon',
                                            'apikey': anon,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({'path': _uazapiStatusPathController.text.trim()}),
                                        );
                                        if (resp.statusCode >= 200 && resp.statusCode < 300) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executado agora (fallback HTTP)')));
                                          }
                                        } else {
                                          String msg = resp.body;
                                          try {
                                            final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
                                            final m = (parsed['error'] ?? parsed['message'] ?? '').toString();
                                            if (m.isNotEmpty) msg = m;
                                          } catch (_) {}
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao executar: $msg')));
                                          }
                                        }
                                      } catch (e2) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao executar: $e2')));
                                        }
                                      }
                                    }
                                  },
                                  child: const Text('Executar agora'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          return Center(child: Text('Erro ao carregar: $error'));
        },
      ),
    );
  }
}
