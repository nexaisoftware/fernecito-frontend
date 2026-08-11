/// Punto ÚNICO para aplicar un cambio de ubicación del usuario.
///
/// - Guarda el set de ciudades (radio GPS / multi-manual) en [PreferenciasCartelera] (local).
/// - Sincroniza la CIUDAD PRINCIPAL a `perfiles_usuarios.ciudad/provincia` (fuente de
///   verdad server-side que leen el perfil, explorar y la app v1.1.0).
///
/// La principal = la más cercana por GPS (inteligente) o la elegida por el usuario
/// (manual, con la regla de "mantener si sigue en la selección").
library;

import 'package:flutter/foundation.dart';

import 'preferencias_cartelera.dart';
import 'supabase_client.dart';

class ServicioUbicacionGlobal {
  ServicioUbicacionGlobal._();

  /// Modo MANUAL: ciudades elegidas a mano. `principal` opcional; si no viene, la
  /// regla de [PreferenciasCartelera] decide (mantiene la actual si sigue elegida).
  static Future<void> aplicarManual({
    required String provincia,
    required Set<String> ciudades,
    String? principal,
  }) async {
    final prefs = PreferenciasCartelera.instancia;
    await prefs.setInteligente(false);
    await prefs.setFiltroPersonalizado(
      provincia: provincia,
      ciudades: ciudades,
      principal: principal,
    );
    await _sincronizarPerfil(prefs.ciudadPrincipal, prefs.provinciaPrincipal);
  }

  /// Modo INTELIGENTE ya resuelto por GPS: `principal` debe ser la ciudad más cercana.
  static Future<void> aplicarInteligente({
    required Set<String> ciudades,
    String? provincia,
    String? principal,
  }) async {
    final prefs = PreferenciasCartelera.instancia;
    await prefs.setInteligente(true);
    await prefs.setInteligenteResuelto(
      ciudades: ciudades,
      provincia: provincia,
      principal: principal,
    );
    await _sincronizarPerfil(prefs.ciudadPrincipal, prefs.provinciaPrincipal);
  }

  /// Escribe la ciudad principal en el perfil (fuente de verdad). No pisa con vacío.
  /// Match usa esta ciudad (antes que la del plan) para decidir dónde aparecen
  /// en las cards y para el filtro excluyente de ubicación.
  static Future<void> _sincronizarPerfil(String? ciudad, String? provincia) async {
    if (ciudad == null || ciudad.trim().isEmpty) return;
    final uid = ServicioSupabase().usuarioActual?.id;
    if (uid == null) return;
    try {
      final data = <String, dynamic>{'ciudad': ciudad};
      if (provincia != null && provincia.trim().isNotEmpty) {
        data['provincia'] = provincia;
      }
      await ServicioSupabase().cliente
          .from('perfiles_usuarios')
          .update(data)
          .eq('id', uid);
    } catch (e) {
      debugPrint('⚠️ sync ciudad principal al perfil: $e');
    }
  }
}
