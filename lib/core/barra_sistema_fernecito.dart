import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'barra_sistema_stub.dart'
    if (dart.library.js_interop) 'barra_sistema_web.dart' as barra_pwa;

/// Barra de estado / theme-color PWA (app usuarios siempre oscura).
class BarraSistemaFernecito {
  BarraSistemaFernecito._();

  static const colorFondo = '#121212';

  static SystemUiOverlayStyle get estilo => const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF121212),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF121212),
        systemNavigationBarIconBrightness: Brightness.light,
      );

  static void aplicar() {
    if (kIsWeb) {
      barra_pwa.actualizarThemeColorPwa(true);
    }
    SystemChrome.setSystemUIOverlayStyle(estilo);
  }
}
