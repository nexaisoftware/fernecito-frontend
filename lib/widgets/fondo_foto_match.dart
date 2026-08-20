import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/servicio_match.dart';

/// Fondo de la card de Match: portada/banner rellena TODO el contenedor
/// (`BoxFit.cover`). Color sólido solo si no hay URL.
class FondoFotoMatch extends StatelessWidget {
  const FondoFotoMatch({super.key, required this.card});

  final MatchCard card;

  @override
  Widget build(BuildContext context) {
    final url = card.fotoUrl?.trim() ?? '';
    final fallback = colorFondoMatch(card);
    return SizedBox.expand(
      child: url.isEmpty
          ? ColoredBox(color: fallback)
          : CachedNetworkImage(
              imageUrl: url,
              cacheKey: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => ColoredBox(color: fallback),
              errorWidget: (_, _, _) => ColoredBox(color: fallback),
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
