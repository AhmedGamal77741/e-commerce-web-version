import 'package:flutter/material.dart';

/// A thin wrapper around [Image.network] that guards against empty URLs
/// and provides consistent loading/error handling.
///
/// When the `url` is empty the [errorWidget] is shown immediately; otherwise
/// the remote image is fetched and the supplied callbacks are used.  This
/// prevents the "Connection closed before full header was received" logs that
/// occur when an empty string is passed to [Image.network].
class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? const Icon(Icons.image_not_supported);
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value:
                    progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
              ),
            );
      },
      errorBuilder: (ctx, error, stack) {
        return errorWidget ?? const Icon(Icons.image_not_supported);
      },
    );
  }
}
