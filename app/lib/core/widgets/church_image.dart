import 'package:flutter/material.dart';

enum ChurchImageType {
  hero,      // 16:9 grande
  card,      // 4:3 padrão conteúdo
  square,    // 1:1
}

class ChurchImage extends StatelessWidget {
  final String imageUrl;
  final ChurchImageType type;
  final double borderRadius;
  final bool enableOverlay;
  final Widget? child;

  const ChurchImage({
    super.key,
    required this.imageUrl,
    this.type = ChurchImageType.card,
    this.borderRadius = 16,
    this.enableOverlay = false,
    this.child,
  });

  double getAspectRatio() {
    switch (type) {
      case ChurchImageType.hero:
        return 16 / 9;
      case ChurchImageType.square:
        return 1;
      case ChurchImageType.card:
        return 4 / 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: getAspectRatio(),
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) =>
                  Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, size: 36),
                  ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),

            if (enableOverlay)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

            if (child != null)
              Positioned.fill(child: child!)
          ],
        ),
      ),
    );
  }
}
