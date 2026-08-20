/// CTA Rompehielo — compacto, ancho al texto, redondeado suave.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

/// esEmisor: true = "Responde a {nombre}", false = "Romper hielo con {nombre}"
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

  String get _nombreCorto {
    final t = nombre.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final corto = _nombreCorto;
    final label = esEmisor
        ? 'Responde a $corto'
        : (esSecundario
            ? 'Ver rompehielo con $corto'
            : 'Romper hielo con $corto');

    final bg = esSecundario
        ? ColoresApp.fondoSuperficie
        : ColoresApp.principalMarca;
    final fg = esSecundario ? ColoresApp.principalMarca : Colors.white;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chat_bubble_2_fill, size: 15, color: fg),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
