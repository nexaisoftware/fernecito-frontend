/// Avatar circular de local/boliche con borde siempre visible.
/// Pioneros: borde dorado. Resto: color del tema activo.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/constants.dart';
import 'fernecito_loader.dart';

class AvatarLocal extends StatelessWidget {
  const AvatarLocal({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.esPionero = false,
    this.onTap,
    this.placeholderIcon = CupertinoIcons.house_fill,
    this.borderWidth,
    this.memCacheWidth,
    this.boxShadow,
  });

  final String? imageUrl;
  final double size;
  final bool esPionero;
  final VoidCallback? onTap;
  final IconData placeholderIcon;
  final double? borderWidth;
  final int? memCacheWidth;
  final List<BoxShadow>? boxShadow;

  static const doradoPionero = Color(0xFFE0B800);

  static bool urlEsAsset(String? url) =>
      url != null && url.trim().startsWith('assets/');

  static Color colorBorde({required bool esPionero}) =>
      esPionero ? doradoPionero : ColoresApp.principalMarca;

  static double anchoBorde({required bool esPionero}) =>
      esPionero ? 2.2 : 1.5;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final bw = borderWidth ?? anchoBorde(esPionero: esPionero);
    final bc = colorBorde(esPionero: esPionero);

    Widget imageChild;
    if (url.isEmpty) {
      imageChild = ColoredBox(
        color: ColoresApp.fondoSuperficie,
        child: Center(
          child: Icon(
            placeholderIcon,
            color: ColoresApp.textoSecundario,
            size: size * 0.42,
          ),
        ),
      );
    } else if (urlEsAsset(url)) {
      imageChild = Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: ColoresApp.fondoSuperficie,
          child: Icon(
            placeholderIcon,
            color: ColoresApp.textoSecundario,
            size: size * 0.42,
          ),
        ),
      );
    } else {
      imageChild = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: memCacheWidth,
        placeholder: (_, __) => const ColoredBox(
          color: ColoresApp.fondoSuperficie,
          child: FernecitoLoaderCentro(),
        ),
        errorWidget: (_, __, ___) => ColoredBox(
          color: ColoresApp.fondoSuperficie,
          child: Icon(
            placeholderIcon,
            color: ColoresApp.textoSecundario,
            size: size * 0.42,
          ),
        ),
      );
    }

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: bc, width: bw),
        boxShadow: boxShadow,
      ),
      child: ClipOval(child: imageChild),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: avatar);
    }
    return avatar;
  }
}
