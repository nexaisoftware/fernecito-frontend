library;

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/servicio_impresiones.dart';

/// Cuenta una impresión cada vez que la card entra al viewport (~10% visible).
class DetectorImpresionCartelera extends StatefulWidget {
  const DetectorImpresionCartelera({
    super.key,
    required this.idLocal,
    required this.idEvento,
    required this.seccion,
    required this.child,
  });

  final String idLocal;
  final String idEvento;
  final String seccion;
  final Widget child;

  @override
  State<DetectorImpresionCartelera> createState() =>
      _DetectorImpresionCarteleraState();
}

class _DetectorImpresionCarteleraState
    extends State<DetectorImpresionCartelera> {
  final Key _visibilityKey = UniqueKey();
  bool _visibleRegistrada = false;

  void _onVisibility(VisibilityInfo info) {
    if (info.visibleFraction >= 0.1 && !_visibleRegistrada) {
      _visibleRegistrada = true;
      ServicioImpresiones.instancia.registrarCartelera(
        idLocal: widget.idLocal,
        idEvento: widget.idEvento,
        seccion: widget.seccion,
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
