/// Fondo con degradado de color de tema (fijo, no se mueve con scroll).
/// - corto: degradado solo en la parte superior (pantallas secundarias).
/// - largo: degradado como home/pools.
library;

import 'package:flutter/material.dart';
import '../core/tema_fernecito.dart';

/// Coloca el degradado fijo detrás del [child].
class FondoGradienteFernecito extends StatelessWidget {
  const FondoGradienteFernecito({
    super.key,
    required this.child,
    this.corto = false,
  });

  final Widget child;
  /// true = degradado corto (top), false = degradado largo (como home/pools).
  final bool corto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<Color>(
            valueListenable: TemaFernecito.instancia.colorActual,
            builder: (context, color, _) => IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: corto
                        ? [
                            color.withValues(alpha: 0.35),
                            color.withValues(alpha: 0.12),
                            Colors.transparent,
                          ]
                        : [
                            color.withValues(alpha: 0.45),
                            color.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                    stops: corto ? const [0.0, 0.25, 0.5] : const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
