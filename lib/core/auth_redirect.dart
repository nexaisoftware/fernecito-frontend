/// URL de redirect para OAuth, confirmación de email y recovery — Fernecito Usuarios.
library;

import 'package:flutter/foundation.dart';

/// Producción PWA (Vercel). Usado si [Uri.base.origin] no es https en builds web.
const String kAuthRedirectWebProduccion = 'https://appusuarios.fernecitoapp.com/';

/// URL a la que Supabase redirige tras Google OAuth / email / recovery.
/// Web: mismo origen del sitio (HTTPS). App: deep link nativo.
String get authRedirectUrlUsuarios {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http://') || origin.startsWith('https://')) {
      return origin.endsWith('/') ? origin : '$origin/';
    }
    return kAuthRedirectWebProduccion;
  }
  return 'fernecito://auth-callback';
}
