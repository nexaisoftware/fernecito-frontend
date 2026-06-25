import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:google_fonts/google_fonts.dart';

import '../core/compartir_evento.dart';
import '../core/constants.dart';

/// Acción liviana para compartir un evento con preview rica (OG + mensaje).
class BotonCompartirEvento extends StatefulWidget {
  const BotonCompartirEvento({
    super.key,
    required this.idEvento,
    required this.titulo,
    this.nombreLocal,
    this.fechaIso,
    this.ciudad,
    this.compacto = false,
    this.etiqueta = 'Compartir evento',
  });

  final String idEvento;
  final String titulo;
  final String? nombreLocal;
  final String? fechaIso;
  final String? ciudad;
  final bool compacto;
  final String etiqueta;

  @override
  State<BotonCompartirEvento> createState() => _BotonCompartirEventoState();
}

class _BotonCompartirEventoState extends State<BotonCompartirEvento> {
  final GlobalKey _anclaKey = GlobalKey();

  Future<void> _onTap() async {
    Rect? origin;
    final ctx = _anclaKey.currentContext;
    if (ctx != null) {
      origin = origenCompartirDesdeContexto(ctx);
    } else if (mounted) {
      origin = origenCompartirDesdeContexto(context);
    }

    await compartirEvento(
      idEvento: widget.idEvento,
      titulo: widget.titulo,
      nombreLocal: widget.nombreLocal,
      fechaIso: widget.fechaIso,
      ciudad: widget.ciudad,
      sharePositionOrigin: origin,
      feedbackContext: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deshabilitado = widget.idEvento.trim().isEmpty;

    final color = deshabilitado
        ? ColoresApp.textoSecundario.withValues(alpha: 0.45)
        : ColoresApp.principalMarca;

    // Variante compacta: pill cuadrado (mismo look que los botones de acción de
    // la card). Evita el linkcito huérfano alineado a la derecha.
    if (widget.compacto) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: deshabilitado ? null : _onTap,
        minimumSize: const Size(48, 40),
        child: Semantics(
          key: _anclaKey,
          button: true,
          label: 'Compartir evento',
          child: Container(
            width: 50,
            decoration: BoxDecoration(
              color: ColoresApp.fondoSuperficie.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: ColoresApp.principalMarca.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Icon(Icons.share, size: 17, color: color),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        onPressed: deshabilitado ? null : _onTap,
        minimumSize: const Size(32, 32),
        child: Semantics(
          key: _anclaKey,
          button: true,
          label: 'Compartir evento',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                'Compartir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
