import 'package:flutter/material.dart';

import '../../data/image_data_url.dart';

class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final memoryBytes = decodeImageDataUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: memoryBytes != null
          ? Image.memory(memoryBytes, width: width, height: height, fit: fit)
          : Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  PhotoPlaceholder(width: width, height: height),
            ),
    );
  }
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
