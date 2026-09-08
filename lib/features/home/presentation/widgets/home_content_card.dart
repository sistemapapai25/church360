import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';

class HomeContentCard extends StatelessWidget {
  final Widget thumbnail;
  final String title;
  final VoidCallback? onTap;

  const HomeContentCard({
    super.key,
    required this.thumbnail,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16, // Mesmo radius compacto que a Home já usava.
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Área da imagem / thumbnail
          AspectRatio(
            aspectRatio: 16 / 9,
            child: thumbnail,
          ),
          Padding(
            padding: const EdgeInsets.all(10), // Padding interno ajustado
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
