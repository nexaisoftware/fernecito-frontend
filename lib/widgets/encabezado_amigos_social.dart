/// Encabezados centrados para pestañas Social (Amigos / Squads).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class EncabezadoAmigosCentrado extends StatelessWidget {
  final int cantidad;

  const EncabezadoAmigosCentrado({super.key, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Column(
        children: [
          Text(
            'Amigos',
            style: GoogleFonts.baloo2(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              cantidad == 1 ? '1 amigo' : '$cantidad amigos',
              style: GoogleFonts.baloo2(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EncabezadoSquadsCentrado extends StatelessWidget {
  final int cantidad;

  const EncabezadoSquadsCentrado({super.key, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Column(
        children: [
          Text(
            'Mis squads',
            style: GoogleFonts.baloo2(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              cantidad == 1 ? '1 squad' : '$cantidad squads',
              style: GoogleFonts.baloo2(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
