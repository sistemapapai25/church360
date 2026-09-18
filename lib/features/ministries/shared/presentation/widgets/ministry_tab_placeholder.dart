import 'package:flutter/material.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';

/// Estado vazio honesto de uma aba do workspace que ainda não foi escrita.
///
/// As abas em construção aparecem na barra desde já, de propósito: a
/// estrutura completa do módulo fica visível e o que falta fica explícito,
/// em vez de a barra crescer em silêncio a cada entrega.
class MinistryTabPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const MinistryTabPlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final track = dark ? AppTheme.darkInput : AppTheme.muted;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: track,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: track,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'EM CONSTRUÇÃO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
