import 'package:flutter/material.dart';

class SupportAgent {
  final String key;
  final String name;
  final String role;
  final String iconName;
  final String? defaultWelcomeMessage;
  final String? defaultThemeColorHex;
  final bool allowAttachments;
  final bool allowImages;
  final bool defaultShowOnHome;
  final bool defaultShowOnDashboard;
  final bool defaultShowFloatingButton;

  const SupportAgent({
    required this.key,
    required this.name,
    required this.role,
    required this.iconName,
    this.defaultWelcomeMessage,
    this.defaultThemeColorHex,
    this.allowAttachments = true,
    this.allowImages = true,
    this.defaultShowOnHome = false,
    this.defaultShowOnDashboard = true,
    this.defaultShowFloatingButton = false,
  });
}

class AgentRuntimeConfig {
  final String agentKey;
  final String? displayName;
  final String? subtitle;
  final String? avatarUrl;
  final String? themeColorHex;
  final bool showOnHome;
  final bool showOnDashboard;
  final bool showFloatingButton;
  final String? floatingRoute;
  final List<String> allowedAccessLevels;
  final String? assistantId;

  const AgentRuntimeConfig({
    required this.agentKey,
    this.displayName,
    this.subtitle,
    this.avatarUrl,
    this.themeColorHex,
    this.showOnHome = false,
    this.showOnDashboard = false,
    this.showFloatingButton = false,
    this.floatingRoute,
    this.allowedAccessLevels = const [],
    this.assistantId,
  });

  factory AgentRuntimeConfig.fromJson(Map<String, dynamic> json) {
    final agentKey = (json['agent_key'] ?? json['key'] ?? '').toString();
    
    List<String> parseLevels(dynamic raw) {
      if (raw == null) return const <String>[];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        // Tenta parsear caso seja uma string representando lista (ex: "{admin,member}")
        final trimmed = raw.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          return trimmed
              .substring(1, trimmed.length - 1)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
           // Basic json parse attempt if needed, or just split
           return trimmed
              .substring(1, trimmed.length - 1)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return [trimmed];
      }
      return const <String>[];
    }

    final levels = parseLevels(json['allowed_access_levels']);

    bool readBool(String key, bool defaultValue) {
      final v = json[key];
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return defaultValue;
    }

    return AgentRuntimeConfig(
      agentKey: agentKey,
      displayName: json['display_name'] as String?,
      subtitle: json['subtitle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      themeColorHex: json['theme_color'] as String?,
      showOnHome: readBool('show_on_home', false),
      showOnDashboard: readBool('show_on_dashboard', true),
      showFloatingButton: readBool('show_floating_button', false),
      floatingRoute: json['floating_route'] as String?,
      allowedAccessLevels: levels,
      assistantId: json['assistant_id'] as String?,
    );
  }
}

class ResolvedAgent {
  final String key;
  final String name;
  final String role;
  final String? subtitle;
  final String? avatarUrl;
  final IconData icon;
  final Color themeColor;
  final bool showOnHome;
  final bool showOnDashboard;
  final bool showFloatingButton;
  final String? floatingRoute;
  final List<String> allowedAccessLevels;
  final String? assistantId;
  final String? welcomeMessage;
  final bool allowAttachments;
  final bool allowImages;

  const ResolvedAgent({
    required this.key,
    required this.name,
    required this.role,
    this.subtitle,
    this.avatarUrl,
    required this.icon,
    required this.themeColor,
    required this.showOnHome,
    required this.showOnDashboard,
    required this.showFloatingButton,
    this.floatingRoute,
    required this.allowedAccessLevels,
    this.assistantId,
    this.welcomeMessage,
    required this.allowAttachments,
    required this.allowImages,
  });
}

ResolvedAgent resolveAgent(
  SupportAgent base,
  AgentRuntimeConfig? cfg,
) {
  final colorHex = cfg?.themeColorHex ?? base.defaultThemeColorHex ?? '#3F8CFF';
  return ResolvedAgent(
    key: base.key,
    name: cfg?.displayName ?? base.name,
    role: base.role,
    subtitle: cfg?.subtitle,
    avatarUrl: cfg?.avatarUrl,
    icon: resolveIcon(base.iconName),
    themeColor: parseColor(colorHex),
    showOnHome: cfg?.showOnHome ?? base.defaultShowOnHome,
    showOnDashboard: cfg?.showOnDashboard ?? base.defaultShowOnDashboard,
    showFloatingButton: _resolveShowFloatingButton(base, cfg),
    floatingRoute: cfg?.floatingRoute,
    allowedAccessLevels: cfg?.allowedAccessLevels ?? const [],
    assistantId: cfg?.assistantId,
    welcomeMessage: base.defaultWelcomeMessage,
    allowAttachments: base.allowAttachments,
    allowImages: base.allowImages,
  );
}

bool _resolveShowFloatingButton(SupportAgent base, AgentRuntimeConfig? cfg) {
  // Se não tem config, usa o padrão do agente base
  if (cfg == null) return base.defaultShowFloatingButton;
  
  // Respeita a configuração explícita
  return cfg.showFloatingButton;
}

List<ResolvedAgent> filterAgentsForUser(
  List<ResolvedAgent> all,
  String userAccessLevel,
  Map<String, bool> permissionOverrides,
) {
  final user = _normalizeAccessLevel(userAccessLevel);
  final userWeight = _getLevelWeight(user);

  return all.where((agent) {
    final agentKey = agent.key.trim().toLowerCase();
    
    // 1. Verificar override explícito (permissão granular)
    // agents.access.{key}
    final permissionKey = 'agents.access.$agentKey';
    if (permissionOverrides.containsKey(permissionKey)) {
      // Se a permissão existe, respeita ela (seja true ou false)
      return permissionOverrides[permissionKey]!;
    }
    
    // 2. Admins veem tudo (se não foi explicitamente negado acima)
    if (user == 'admin') return true;

    // 3. Se não tem restrição de nível, todos veem
    if (agent.allowedAccessLevels.isEmpty) return true;
    
    // 4. Lógica de hierarquia
    // Verifica se o usuário tem nível igual ou superior a ALGUM dos níveis permitidos
    final allowedWeights = agent.allowedAccessLevels
        .map(_normalizeAccessLevel)
        .map(_getLevelWeight)
        .toSet();
        
    // Se o nível do usuário for >= a qualquer nível permitido
    // Ex: Agente permitido para 'member' (1). Usuário 'leader' (2). 2 >= 1 -> True.
    if (allowedWeights.any((w) => userWeight >= w)) return true;

    return false;
  }).toList();
}

int _getLevelWeight(String level) {
  switch (level) {
    case 'admin':
      return 4;
    case 'coordinator':
      return 3;
    case 'leader':
      return 2;
    case 'member':
      return 1;
    default:
      return 0; // visitor / undefined
  }
}

String _normalizeAccessLevel(String value) {
  final v = value.trim().toLowerCase();
  switch (v) {
    case 'adm':
      return 'admin';
    case 'ldr':
      return 'leader';
    case 'coord':
      return 'coordinator';
    case 'usr':
      return 'member';
    default:
      return v;
  }
}

Color parseColor(String hex) {
  var value = hex.trim();
  if (value.isEmpty) return const Color(0xFF3F8CFF);
  if (value.startsWith('#')) value = value.substring(1);

  if (value.length == 3) {
    value = '${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}';
  }

  if (value.length == 6) {
    value = 'FF$value';
  }

  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return const Color(0xFF3F8CFF);
  return Color(parsed);
}

IconData resolveIcon(String name) {
  switch (name) {
    case 'child_care':
      return Icons.child_care;
    case 'support_agent':
      return Icons.support_agent;
    case 'payments':
      return Icons.payments;
    case 'attach_money':
      return Icons.attach_money;
    case 'volunteer_activism':
      return Icons.volunteer_activism;
    case 'movie':
      return Icons.movie;
    case 'campaign':
      return Icons.campaign;
    default:
      return Icons.chat;
  }
}
