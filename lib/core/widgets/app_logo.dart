import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = size ?? width;
    final resolvedHeight = size ?? height;

    return SvgPicture.asset(
      'assets/images/church360-sf-p.svg',
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      placeholderBuilder: (context) => Image.asset(
        'assets/images/church360_logo.jpg',
        width: resolvedWidth,
        height: resolvedHeight,
        fit: fit,
      ),
    );
  }
}
