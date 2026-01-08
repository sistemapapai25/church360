import 'package:flutter/material.dart';

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
    return InkWell(
      borderRadius: BorderRadius.circular(16), // Borda 16px
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Borda 16px
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), // Sombra leve
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
