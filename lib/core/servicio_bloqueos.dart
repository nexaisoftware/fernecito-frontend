import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Bloqueo de cuentas iniciado por el usuario (usuarios y locales).
/// Backend: RPCs bloquear_cuenta / desbloquear_cuenta (security definer,
/// usan auth.uid() como bloqueador).
class ServicioBloqueos {
  SupabaseClient get _sb => ServicioSupabase().cliente;

  Future<Map<String, dynamic>> bloquearCuenta({
    required String targetTipo, // 'usuario' | 'local'
    required String targetId,
  }) async {
    try {
      final res = await _sb.rpc(
        'bloquear_cuenta',
        params: {'p_target_tipo': targetTipo, 'p_target_id': targetId},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'ok': false, 'error': 'Respuesta invalida'};
    } catch (e) {
      debugPrint('🚫 bloquear ✗ $e');
      rethrow;
    }
  }

  Future<void> desbloquearCuenta({
    required String targetTipo,
    required String targetId,
  }) async {
    try {
      await _sb.rpc(
        'desbloquear_cuenta',
        params: {'p_target_tipo': targetTipo, 'p_target_id': targetId},
      );
    } catch (e) {
      debugPrint('🚫 desbloquear ✗ $e');
    }
  }
}
