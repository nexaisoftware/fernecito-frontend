library;

import 'package:flutter/foundation.dart';
import 'cache_memoria.dart';
import 'supabase_client.dart';

/// Detalle y métricas de un perfil ajeno vía RPC `perfil_usuario_detalle`.
class ServicioPerfilUsuario {
  static final ServicioPerfilUsuario _instancia = ServicioPerfilUsuario._interno();
  factory ServicioPerfilUsuario() => _instancia;
  ServicioPerfilUsuario._interno();

  static const _ttl = Duration(seconds: 90);
  final _cacheDetalle = CachePorClave<Map<String, dynamic>>();
  final _cacheActividad = CachePorClave<List<Map<String, dynamic>>>();

  /// URL del avatar propio para el navbar (con cache-bust).
  /// Solo se actualiza al subir/quitar foto en Mi perfil.
  final ValueNotifier<String?> avatarNavbarUrl = ValueNotifier<String?>(null);

  void publicarAvatarNavbar(String? url) {
    avatarNavbarUrl.value = url;
  }

  void invalidarUsuario(String idUsuario) {
    _cacheDetalle.invalidate(idUsuario);
    for (final t in PerfilActividadTipo.values) {
      _cacheActividad.invalidate('$idUsuario:${t.valorRpc}');
    }
  }

  Future<Map<String, dynamic>?> detalle(
    String idUsuario, {
    bool forzarCompleto = false,
  }) async {
    if (idUsuario.isEmpty) return null;
    if (!forzarCompleto && _cacheDetalle.fresco(idUsuario, _ttl)) {
      return _cacheDetalle.get(idUsuario);
    }
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('perfil_usuario_detalle', params: {'p_id': idUsuario});
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        _cacheDetalle.set(idUsuario, map);
        return map;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ perfil_usuario_detalle: $e');
      return _cacheDetalle.get(idUsuario);
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

  /// Listado de actividad del perfil (`amigos` | `eventos` | `locales`).
  Future<List<Map<String, dynamic>>> listarActividad({
    required String idUsuario,
    required PerfilActividadTipo tipo,
    bool forzarCompleto = false,
  }) async {
    if (idUsuario.isEmpty) return const [];
    final key = '$idUsuario:${tipo.valorRpc}';
    if (!forzarCompleto && _cacheActividad.fresco(key, _ttl)) {
      return _cacheActividad.get(key) ?? const [];
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'perfil_usuario_actividad_listar',
        params: {
          'p_id_usuario': idUsuario,
          'p_tipo': tipo.valorRpc,
        },
      );
      final items = _parseItemsRpc(res);
      _cacheActividad.set(key, items);
      return items;
    } catch (e) {
      debugPrint('⚠️ perfil_usuario_actividad_listar: $e');
      return _cacheActividad.get(key) ?? const [];
    }
  }

  static List<Map<String, dynamic>> _parseItemsRpc(dynamic res) {
    if (res is! Map) return const [];
    final map = Map<String, dynamic>.from(res);
    if (map['ok'] != true) return const [];
    final items = map['items'];
    if (items is List) {
      return items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    return const [];
  }
}

enum PerfilActividadTipo {
  amigos('amigos'),
  squads('squads'),
  eventos('eventos'),
  locales('locales');

  const PerfilActividadTipo(this.valorRpc);
  final String valorRpc;
}
