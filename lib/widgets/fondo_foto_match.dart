import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/servicio_match.dart';

/// Fondo de la card de Match:
/// - Squad/usuario con foto → banner/avatar a full-bleed (`BoxFit.cover`).
/// - Sin URL (o error de red) → color sólido estable por id.
class FondoFotoMatch extends StatelessWidget {
  const FondoFotoMatch({super.key, required this.card});

  final MatchCard card;

  @override
  Widget build(BuildContext context) {
    final url = card.fotoUrl?.trim() ?? '';
    final fallback = colorFondoMatch(card);
    return SizedBox.expand(
      child: ColoredBox(
        color: fallback,
        child: url.isEmpty
            ? null
            : CachedNetworkImage(
                imageUrl: url,
                cacheKey: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                // Color sólido ya está detrás: placeholder/error transparentes.
                placeholder: (_, _) => const SizedBox.expand(),
                errorWidget: (_, _, _) => const SizedBox.expand(),
                imageBuilder: (context, imageProvider) => DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

Color colorFondoMatch(MatchCard card) {
  const palette = <Color>[
    Color(0xFF2D6A4F),
    Color(0xFF1D3557),
    Color(0xFF9B2226),
    Color(0xFF6A4C93),
    Color(0xFFBC6C25),
    Color(0xFF0077B6),
    Color(0xFF3A5A40),
    Color(0xFF6D597A),
  ];
  final seed = card.idGrupo ?? card.idUsuario ?? card.idPlan;
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}
