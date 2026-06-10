library;

import 'package:flutter/foundation.dart';

import '../models/rompehielo.dart';
import 'supabase_client.dart';

/// Rompehielo ping-pong (usuario↔usuario, squad↔squad, usuario↔squad).
class ServicioRompehielo {
  static final ServicioRompehielo _instancia = ServicioRompehielo._interno();
  factory ServicioRompehielo() => _instancia;
  ServicioRompehielo._interno();

  Future<RompehieloEstado> estado({
    required String otroTipo,
    required String otroId,
    String? idGrupoActor,
  }) async {
    if (otroId.isEmpty) {
      return RompehieloEstado.vacio(otroTipo: otroTipo, otroId: otroId);
    }
    try {
      final params = <String, dynamic>{
        'p_otro_tipo': otroTipo,
        'p_otro_id': otroId,
      };
      if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
        params['p_id_grupo_actor'] = idGrupoActor;
      }
      final res = await ServicioSupabase().cliente.rpc('rompehielo_estado', params: params);
      if (res is Map) {
        return RompehieloEstado.fromMap(Map<String, dynamic>.from(res));
      }
      return RompehieloEstado.vacio(otroTipo: otroTipo, otroId: otroId);
    } catch (e) {
      debugPrint('⚠️ rompehielo_estado: $e');
      return RompehieloEstado.vacio(otroTipo: otroTipo, otroId: otroId);
    }
  }

  Future<({RompehieloEstado? estado, String? error})> actuar({
    required String otroTipo,
    required String otroId,
    required String mensaje,
    String? idGrupoActor,
    String? idEvento,
    RompehieloOrigen origen = RompehieloOrigen.perfil,
    String? nombreEvento,
  }) async {
    if (otroId.isEmpty) return (estado: null, error: 'destino_invalido');
    try {
      final params = <String, dynamic>{
        'p_otro_tipo': otroTipo,
        'p_otro_id': otroId,
        'p_mensaje': mensaje.trim(),
        'p_origen': origen.name,
      };
      if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
        params['p_id_grupo_actor'] = idGrupoActor;
      }
      if (idEvento != null && idEvento.isNotEmpty) {
        params['p_id_evento'] = idEvento;
      }
      if (nombreEvento != null && nombreEvento.isNotEmpty) {
        params['p_nombre_evento'] = nombreEvento;
      }
      final res = await ServicioSupabase().cliente.rpc('rompehielo_actuar', params: params);
      if (res is Map) {
        return (
          estado: RompehieloEstado.fromMap(Map<String, dynamic>.from(res)),
          error: null,
        );
      }
      return (estado: null, error: 'respuesta_invalida');
    } catch (e) {
      debugPrint('⚠️ rompehielo_actuar: $e');
      final msg = e.toString();
      if (msg.contains('no_es_tu_turno')) {
        return (estado: null, error: 'no_es_tu_turno');
      }
      if (msg.contains('rate_limit_exceeded')) {
        return (estado: null, error: 'rate_limit');
      }
      if (msg.contains('mensaje_invalido')) {
        return (estado: null, error: 'mensaje_invalido');
      }
      return (estado: null, error: 'error');
    }
  }

  /// Ignora el rompehielo: congela la conversación y deja claro que no querés
  /// seguir. Cualquier participante puede ignorar.
  Future<({RompehieloEstado? estado, String? error})> ignorar({
    required String otroTipo,
    required String otroId,
    String? idGrupoActor,
  }) async {
    if (otroId.isEmpty) return (estado: null, error: 'destino_invalido');
    try {
      final params = <String, dynamic>{
        'p_otro_tipo': otroTipo,
        'p_otro_id': otroId,
      };
      if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
        params['p_id_grupo_actor'] = idGrupoActor;
      }
      final res =
          await ServicioSupabase().cliente.rpc('rompehielo_ignorar', params: params);
      if (res is Map) {
        return (
          estado: RompehieloEstado.fromMap(Map<String, dynamic>.from(res)),
          error: null,
        );
      }
      return (estado: null, error: 'respuesta_invalida');
    } catch (e) {
      debugPrint('⚠️ rompehielo_ignorar: $e');
      return (estado: null, error: 'error');
    }
  }
}
