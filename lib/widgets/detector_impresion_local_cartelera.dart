library;

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/secciones_impresion.dart';
import '../core/servicio_impresiones.dart';

/// Cuenta exposición de la card de local (no visita real al perfil).
class DetectorImpresionLocalCartelera extends StatefulWidget {
  const DetectorImpresionLocalCartelera({
    super.key,
    required this.idLocal,
    required this.child,
  });

  final String idLocal;
  final Widget child;

  @override
  State<DetectorImpresionLocalCartelera> createState() =>
      _DetectorImpresionLocalCarteleraState();
}

class _DetectorImpresionLocalCarteleraState
    extends State<DetectorImpresionLocalCartelera> {
  final Key _visibilityKey = UniqueKey();
  bool _visibleRegistrada = false;

  void _onVisibility(VisibilityInfo info) {
    if (info.visibleFraction >= 0.1 && !_visibleRegistrada) {
      _visibleRegistrada = true;
      ServicioImpresiones.instancia.registrar(
        idLocal: widget.idLocal,
        seccion: SeccionesImpresion.cardLocal,
      );
      return;
    }
    if (info.visibleFraction <= 0.01) {
      _visibleRegistrada = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibility,
      child: widget.child,
    );
  }
}
