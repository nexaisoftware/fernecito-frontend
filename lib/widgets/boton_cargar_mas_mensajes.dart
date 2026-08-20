library;

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class BotonCargarMasMensajes extends StatelessWidget {
  const BotonCargarMasMensajes({
    super.key,
    required this.onTap,
    this.cargando = false,
  });

  final VoidCallback? onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Center(
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          onPressed: cargando ? null : onTap,
          child: cargando
              ? const CupertinoActivityIndicator(radius: 9)
              : Text(
                  'Cargar más mensajes',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.principalMarca,
                  ),
                ),
        ),
      ),
    );
  }
}
