import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/support_chat/domain/models/support_agent.dart';

void main() {
  group('AgentRuntimeConfig.fromJson', () {
    test('parses booleans and postgres array-like access levels', () {
      final cfg = AgentRuntimeConfig.fromJson({
        'agent_key': 'kids',
        'display_name': 'Kids Bot',
        'show_on_home': '1',
        'show_on_dashboard': 'false',
        'show_floating_button': 1,
        'allowed_access_levels': '{member,leader}',
      });

      expect(cfg.agentKey, 'kids');
      expect(cfg.displayName, 'Kids Bot');
      expect(cfg.showOnHome, isTrue);
      expect(cfg.showOnDashboard, isFalse);
      expect(cfg.showFloatingButton, isTrue);
      expect(cfg.allowedAccessLevels, ['member', 'leader']);
    });

    test('uses defaults for invalid booleans and empty levels', () {
      final cfg = AgentRuntimeConfig.fromJson({
        'key': 'financeiro',
        'show_on_home': 'invalid',
        'show_on_dashboard': 'invalid',
        'show_floating_button': 'invalid',
        'allowed_access_levels': null,
      });

      expect(cfg.agentKey, 'financeiro');
      expect(cfg.showOnHome, isFalse);
      expect(cfg.showOnDashboard, isTrue);
      expect(cfg.showFloatingButton, isFalse);
      expect(cfg.allowedAccessLevels, isEmpty);
    });
  });

  group('resolveAgent', () {
    test('respects explicit floating button config', () {
      const base = SupportAgent(
        key: 'default',
        name: 'Atendimento',
        role: 'Suporte geral',
        iconName: 'support_agent',
        defaultThemeColorHex: '#3F8CFF',
        defaultShowFloatingButton: false,
      );
      const cfg = AgentRuntimeConfig(
        agentKey: 'default',
        showFloatingButton: true,
      );

      final resolved = resolveAgent(base, cfg);
      expect(resolved.showFloatingButton, isTrue);
    });
  });

  group('filterAgentsForUser', () {
    final baseAgents = <ResolvedAgent>[
      const ResolvedAgent(
        key: 'kids',
        name: 'Kids',
        role: 'Role',
        icon: Icons.child_care,
        themeColor: Color(0xFF3F8CFF),
        showOnHome: true,
        showOnDashboard: true,
        showFloatingButton: false,
        allowedAccessLevels: ['member'],
        allowAttachments: true,
        allowImages: true,
      ),
      const ResolvedAgent(
        key: 'pastoral',
        name: 'Pastoral',
        role: 'Role',
        icon: Icons.support_agent,
        themeColor: Color(0xFF3F8CFF),
        showOnHome: false,
        showOnDashboard: true,
        showFloatingButton: false,
        allowedAccessLevels: ['admin'],
        allowAttachments: true,
        allowImages: true,
      ),
    ];

    test('allows higher hierarchy levels for lower-restricted agents', () {
      final result = filterAgentsForUser(baseAgents, 'leader', const {});
      final keys = result.map((e) => e.key).toSet();

      expect(keys.contains('kids'), isTrue);
      expect(keys.contains('pastoral'), isFalse);
    });

    test('applies explicit permission override before hierarchy', () {
      final result = filterAgentsForUser(baseAgents, 'member', const {
        'agents.access.kids': false,
      });

      expect(result.where((a) => a.key == 'kids'), isEmpty);
    });
  });

  group('utilities', () {
    test('parseColor supports short hex and fallback', () {
      expect(parseColor('#abc'), const Color(0xFFAABBCC));
      expect(parseColor('invalid'), const Color(0xFF3F8CFF));
    });

    test('resolveIcon falls back to chat icon when unknown', () {
      expect(resolveIcon('unknown_icon'), Icons.chat);
    });
  });
}
