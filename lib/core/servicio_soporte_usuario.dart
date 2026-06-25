import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Soporte del usuario: abrir una solicitud (no se cierra desde la app) y leer
/// su estado. El código anti-estafa lo genera el backend.
class ServicioSoporteUsuario {
  SupabaseClient get _sb => ServicioSupabase().cliente;

  /// Devuelve el ticket vigente del usuario, o null si no tiene ninguno.
  Future<Map<String, dynamic>?> estado() async {
    final res = await _sb.rpc('usuario_soporte_estado');
    if (res is Map && res['ok'] == true) {
      final s = res['soporte'];
      return s is Map ? Map<String, dynamic>.from(s) : null;
    }
    return null;
  }

  /// Abre (o devuelve la abierta) una solicitud de soporte.
  Future<Map<String, dynamic>> abrir({
    required String mensaje,
    String? telefono,
    String via = 'email',
  }) async {
    final res = await _sb.rpc('usuario_soporte_abrir', params: {
      'p_mensaje': mensaje,
      'p_telefono': telefono,
      'p_via': via,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'ok': false, 'error': 'Respuesta inválida'};
  }
}
