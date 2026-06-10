library;

import 'package:flutter/foundation.dart';
import '../models/social.dart';
import 'supabase_client.dart';

/// Servicio de amistades. Usa los RPCs `amistad_*` (SECURITY DEFINER) del backend.
class ServicioAmigos {
  static final ServicioAmigos _instancia = ServicioAmigos._interno();
  factory ServicioAmigos() => _instancia;
  ServicioAmigos._interno();

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  /// Trae amigos + solicitudes recibidas + enviadas en una sola llamada.
  Future<AmistadesData> listar() async {
    if (_uid == null) return const AmistadesData();
    try {
      final res = await ServicioSupabase().cliente.rpc('amistad_listar');
      if (res is Map) return AmistadesData.fromMap(Map<String, dynamic>.from(res));
      return const AmistadesData();
    } catch (e) {
      debugPrint('⚠️ amistad_listar: $e');
      return const AmistadesData();
    }
  }

  /// Envía solicitud de amistad. Devuelve el estado resultante
  /// ('pendiente' | 'aceptada' | ...) o null si falló.
  Future<String?> solicitar(String idDestino) async {
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('amistad_solicitar', params: {'p_destino': idDestino});
      if (res is Map) return res['estado']?.toString();
      return 'pendiente';
    } catch (e) {
      debugPrint('⚠️ amistad_solicitar: $e');
      if (e.toString().contains('rate_limit_exceeded')) {
        debugPrint('⚠️ Límite de solicitudes alcanzado. Intentá más tarde.');
      }
      return null;
    }
  }

  /// Acepta o rechaza una solicitud recibida (por id_relacion).
  Future<bool> responder(String idRelacion, {required bool aceptar}) async {
    try {
      await ServicioSupabase().cliente.rpc('amistad_responder', params: {
        'p_relacion': idRelacion,
        'p_aceptar': aceptar,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ amistad_responder: $e');
      return false;
    }
  }

  /// Elimina amistad o cancela solicitud (cualquier dirección) con [idOtro].
  Future<bool> eliminar(String idOtro) async {
    try {
      await ServicioSupabase()
          .cliente
          .rpc('amistad_eliminar', params: {'p_otro': idOtro});
      return true;
    } catch (e) {
      debugPrint('⚠️ amistad_eliminar: $e');
      return false;
    }
  }

  /// Busca usuarios por username o nombre. Devuelve perfiles con
  /// `estado_amistad` ('amigo' | 'enviada' | 'recibida' | 'ninguno').
  Future<List<UsuarioBusqueda>> buscar(String query) async {
    if (_uid == null) return const [];
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('buscar_usuarios', params: {'p_query': query});
      if (res is List) {
        return res
            .map((e) =>
                UsuarioBusqueda.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ buscar_usuarios: $e');
      return const [];
    }
  }

  /// Personas públicas en una ciudad (paginado).
  Future<ExplorarUsuariosPagina> explorarCiudad({
    required String ciudad,
    String? provincia,
    int offset = 0,
    int limit = 40,
  }) async {
    if (_uid == null || ciudad.trim().isEmpty) {
      return const ExplorarUsuariosPagina();
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'explorar_usuarios_ciudad',
        params: {
          'p_ciudad': ciudad.trim(),
          'p_provincia': (provincia == null || provincia.trim().isEmpty)
              ? null
              : provincia.trim(),
          'p_offset': offset,
          'p_limit': limit,
        },
      );
      if (res is! Map) return const ExplorarUsuariosPagina();
      final map = Map<String, dynamic>.from(res);
      final itemsRaw = map['items'];
      final lista = itemsRaw is List
          ? itemsRaw
              .map((e) =>
                  UsuarioBusqueda.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <UsuarioBusqueda>[];
      return ExplorarUsuariosPagina(
        items: lista,
        hayMas: map['hay_mas'] == true,
      );
    } catch (e) {
      debugPrint('⚠️ explorar_usuarios_ciudad: $e');
      return ExplorarUsuariosPagina(
        error: 'No se pudo cargar personas ($e)',
      );
    }
  }
}
