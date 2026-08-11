/// Tokens de borde para avatares (personas y locales) en toda la app.
library;

import 'package:flutter/cupertino.dart';

import '../core/constants.dart';

class AvatarBordes {
  AvatarBordes._();

  /// Dorado Fernecito Pionero / Best Choice — siempre gana.
  static const doradoPionero = Color(0xFFE0B800);

  /// Blanco: contraste sobre fondos oscuros (perfil, stacks, chat).
  static const blanco = Color(0xFFFFFFFF);

  /// Color del tema activo (marca).
  static Color get tema => ColoresApp.principalMarca;

  /// Resuelve el color final. Pionero → dorado; si no, [preferido] o tema.
  static Color color({
    bool esPionero = false,
    Color? preferido,
  }) {
    if (esPionero) return doradoPionero;
    return preferido ?? tema;
  }

  static double ancho({
    bool esPionero = false,
    double? preferido,
  }) {
    if (preferido != null) return preferido;
    return esPionero ? 2.2 : 1.6;
  }
}
