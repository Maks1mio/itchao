import 'package:flutter/material.dart';

/// Сетевое изображение с ограничением decode-размера (меньше лагов в списках).
class ItchCachedNetworkImage extends StatelessWidget {
  const ItchCachedNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorWidget,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    int? cacheWidth;
    int? cacheHeight;
    if (width != null && width!.isFinite && width! > 0) {
      cacheWidth = (width! * dpr).round();
    }
    if (height != null && height!.isFinite && height! > 0) {
      cacheHeight = (height! * dpr).round();
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          errorWidget ??
          ColoredBox(
            color: const Color(0xFF2A2A2A),
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white24,
              size: (width ?? 48) * 0.3,
            ),
          ),
    );
  }
}
