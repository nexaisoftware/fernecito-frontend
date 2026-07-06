/// Fondo sólido gris (mismo tono que cartelera). Sin degradé.
library;

import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Envuelve [child] con el fondo principal sólido de la app.
class FondoGradienteFernecito extends StatelessWidget {
  const FondoGradienteFernecito({
    super.key,
    required this.child,
    this.corto = false,
  });

  final Widget child;

  /// Conservado por compatibilidad; ya no altera el fondo.
  final bool corto;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColoresApp.fondoPrincipal,
      child: child,
    );
  }
}
