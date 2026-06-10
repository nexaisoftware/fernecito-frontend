library;

import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

/// Detalle y métricas de un perfil ajeno vía RPC `perfil_usuario_detalle`.
class ServicioPerfilUsuario {
  static final ServicioPerfilUsuario _instancia = ServicioPerfilUsuario._interno();
  factory ServicioPerfilUsuario() => _instancia;
  ServicioPerfilUsuario._interno();

  Future<Map<String, dynamic>?> detalle(String idUsuario) async {
    if (idUsuario.isEmpty) return null;
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('perfil_usuario_detalle', params: {'p_id': idUsuario});
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      debugPrint('⚠️ perfil_usuario_detalle: $e');
      return null;
    }
  }

  /// Entero seguro desde jsonb del RPC (`cantidad_amigos`, métricas, etc.).
  static int enteroDeDetalle(Map<String, dynamic>? det, String clave,
      {int porDefecto = 0}) {
    if (det == null) return porDefecto;
    final v = det[clave];
    if (v == null) return porDefecto;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? porDefecto;
    return porDefecto;
  }
}
