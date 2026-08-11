import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:google_fonts/google_fonts.dart';

import '../core/compartir_evento.dart' show origenCompartirDesdeContexto;
import '../core/compartir_plan.dart';
import '../core/constants.dart';

/// Acción liviana para compartir un plan con preview rica (OG + mensaje).
/// Espejo de [BotonCompartirEvento].
class BotonCompartirPlan extends StatefulWidget {
  const BotonCompartirPlan({
    super.key,
    required this.idPlan,
    required this.titulo,
    this.nombreLocal,
    this.ciudad,
    this.fechaInicio,
    this.compacto = false,
    this.etiqueta = 'Compartir plan',
  });

  final String idPlan;
  final String titulo;
  final String? nombreLocal;
  final String? ciudad;
  final DateTime? fechaInicio;
  final bool compacto;
  final String etiqueta;

  @override
  State<BotonCompartirPlan> createState() => _BotonCompartirPlanState();
}

class _BotonCompartirPlanState extends State<BotonCompartirPlan> {
  final GlobalKey _anclaKey = GlobalKey();

  Future<void> _onTap() async {
    Rect? origin;
    final ctx = _anclaKey.currentContext;
    if (ctx != null) {
      origin = origenCompartirDesdeContexto(ctx);
    } else if (mounted) {
      origin = origenCompartirDesdeContexto(context);
    }

    await compartirPlan(
      idPlan: widget.idPlan,
      titulo: widget.titulo,
      nombreLocal: widget.nombreLocal,
      ciudad: widget.ciudad,
      fechaInicio: widget.fechaInicio,
      sharePositionOrigin: origin,
      feedbackContext: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deshabilitado = widget.idPlan.trim().isEmpty;

    final color = deshabilitado
        ? ColoresApp.textoSecundario.withValues(alpha: 0.45)
        : ColoresApp.principalMarca;

    if (widget.compacto) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: deshabilitado ? null : _onTap,
        minimumSize: const Size(48, 40),
        child: Semantics(
          key: _anclaKey,
          button: true,
          label: widget.etiqueta,
          child: Container(
            width: 50,
            decoration: BoxDecoration(
              color: ColoresApp.fondoSuperficie.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Icon(Icons.share, size: 17, color: color),
          ),
        ),
      );
    }

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: deshabilitado ? null : _onTap,
      minimumSize: const Size(32, 32),
      child: Semantics(
        key: _anclaKey,
        button: true,
        label: widget.etiqueta,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.share, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                widget.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
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
