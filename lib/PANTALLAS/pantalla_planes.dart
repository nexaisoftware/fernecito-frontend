library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class PantallaPlanes extends StatelessWidget {
  const PantallaPlanes({super.key});

  @override
  Widget build(BuildContext context) => _PantallaProximamenteSocial(
    titulo: 'Planes',
    icono: CupertinoIcons.calendar_badge_plus,
    mensaje: 'Juntadas, planes de la comunidad y nuevos grupos para salir.',
  );
}

class _PantallaProximamenteSocial extends StatelessWidget {
  const _PantallaProximamenteSocial({
    required this.titulo,
    required this.icono,
    required this.mensaje,
  });

  final String titulo;
  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: ColoresApp.principalMarca.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icono,
                    size: 36,
                    color: ColoresApp.principalMarca,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Próximamente',
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    height: 1.25,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
