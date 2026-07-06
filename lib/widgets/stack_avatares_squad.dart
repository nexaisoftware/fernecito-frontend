/// Stack horizontal de avatares de miembros (rompehielo, perfiles).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import 'avatar_usuario.dart';

/// Tres avatares semi-apilados del mismo tamaño que un avatar solo + badge +n.
class StackAvataresSquad extends StatelessWidget {
  const StackAvataresSquad({
    super.key,
    required this.avatares,
    this.totalExtra = 0,
    this.size = 76,
    this.paddingExterno = _kPadExterno,
  });

  final List<String> avatares;
  final int totalExtra;
  final double size;
  final double paddingExterno;

  /// Separación horizontal entre centros visuales (mismo criterio que perfil squad).
  double get _overlap => size * 0.34;

  @override
  Widget build(BuildContext context) {
    final urls = avatares.where((u) => u.trim().isNotEmpty).toList();
    final total = totalExtra > 0 ? totalExtra : urls.length;
    final visibles = urls.take(3).toList();
    final extra = total - visibles.length;
    final n = visibles.length;

    if (n == 0) {
      return Padding(
        padding: const EdgeInsets.all(_kPadExterno),
        child: AvatarBordeBlanco(avatar: '', size: size),
      );
    }

    final step = size - _overlap;
    final badgeSize = size * 0.36;
    final badgeLeft = (n - 1) * step + size - badgeSize * 0.78;
    final contentW = extra > 0 ? badgeLeft + badgeSize : size + (n - 1) * step;

    return Padding(
      padding: EdgeInsets.all(paddingExterno),
      child: SizedBox(
        width: contentW,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: i * step,
                top: 0,
                child: AvatarBordeBlanco(avatar: visibles[i], size: size),
              ),
            if (extra > 0)
              Positioned(
                left: badgeLeft,
                top: (size - badgeSize) / 2,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ColoresApp.principalMarca,
                                        boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '+$extra',
                    style: GoogleFonts.baloo2(
                      fontSize: size * 0.14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Margen para sombras/bordes; evita que el padre recorte el stack.
const double _kPadExterno = 6;
