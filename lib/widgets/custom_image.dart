import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CustomImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Handle empty or invalid URLs locally
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: errorWidget ??
            Icon(
              Icons.image_not_supported,
              color: Colors.grey[400],
              size: (width != null && width! < 50) ? 20 : 32,
            ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                   width: 20,
                   height: 20,
                   child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: errorWidget ??
                  Icon(
                    Icons.broken_image,
                    color: Colors.grey[400],
                    size: (width != null && width! < 50) ? 20 : 32,
                  ),
            ),
      ),
    );
  }
}
