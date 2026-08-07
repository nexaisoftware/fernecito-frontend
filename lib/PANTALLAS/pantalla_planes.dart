library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

/// Hub de Planes (comunidad).
///
/// Backend listo: `planes_*` RPCs + chat realtime `planes_mensajes` + edge
/// `asistente_plan_comunidad`. UI completa (scroll hub + chatbot crear + chat
/// grupal) se cablea en el siguiente paso sobre `ServicioPlanes`.
class PantallaPlanes extends StatelessWidget {
  const PantallaPlanes({super.key});

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
          'Planes',
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
                    CupertinoIcons.calendar_badge_plus,
                    size: 36,
                    color: ColoresApp.principalMarca,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Arquitectura lista',
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Juntadas en un local de Fernecito: te sumás, chateás en grupo '
                  'y te conocés antes de salir. Próximo paso: hub + chatbot de creación.',
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
