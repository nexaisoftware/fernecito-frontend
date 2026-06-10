/// CTA Rompehielo — jerarquía clara sin animaciones llamativas.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

/// esEmisor: true = "Responde a {nombre}", false = "Romper el hielo con {nombre}"
/// esSecundario: jerarquía baja si ya hubo interacción.
class BotonRompehielo extends StatelessWidget {
  final String nombre;
  final bool esEmisor;
  final bool esSecundario;
  final VoidCallback? onTap;

  const BotonRompehielo({
    super.key,
    required this.nombre,
    this.esEmisor = false,
    this.esSecundario = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = esEmisor
        ? 'Responde a $nombre'
        : (esSecundario ? 'Ver rompehielo con $nombre' : 'Romper el hielo con $nombre');

    final bg = esSecundario
        ? ColoresApp.fondoSuperficie
        : ColoresApp.principalMarca;
    final fg = esSecundario ? ColoresApp.principalMarca : Colors.white;
    final border = esSecundario
        ? Border.all(color: ColoresApp.principalMarca.withValues(alpha: 0.45))
        : null;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: esSecundario
              ? null
              : [
                  BoxShadow(
                    color: ColoresApp.principalMarca.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: 20,
              color: fg,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
