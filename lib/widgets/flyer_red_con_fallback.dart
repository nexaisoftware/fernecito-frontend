import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/constants.dart';
import '../core/promos_hot.dart';
import 'fernecito_loader.dart';

/// Flyer de red con el mismo fallback de marca que Ver Evento.
class FlyerRedConFallback extends StatelessWidget {
  const FlyerRedConFallback({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.assetFallback = kAssetFlyerMarcaDefault,
    this.mostrarLoader = true,
  });

  final String url;
  final BoxFit fit;
  final String assetFallback;
  final bool mostrarLoader;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return _asset(fit);
    }
    return CachedNetworkImage(
      imageUrl: url.trim(),
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => mostrarLoader
          ? ColoredBox(
              color: ColoresApp.fondoSuperficie,
              child: const Center(child: FernecitoLoader.inline(size: 16)),
            )
          : const ColoredBox(color: ColoresApp.fondoSuperficie),
      errorWidget: (_, __, ___) => _asset(fit),
    );
  }

  Widget _asset(BoxFit fit) {
    return Image.asset(
      assetFallback,
      fit: fit,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: ColoresApp.fondoSuperficie,
        child: const Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 64,
            color: ColoresApp.textoSecundario,
          ),
        ),
      ),
    );
  }
}
