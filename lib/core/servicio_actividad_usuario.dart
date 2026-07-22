/// Cache + carga de Mi Actividad (tokens de asistencia y promos).
library;

import 'package:flutter/foundation.dart';

import 'cache_memoria.dart';
import 'supabase_client.dart';

class SnapshotTokenPromoCache {
  const SnapshotTokenPromoCache({
    required this.codigo,
    required this.estadoToken,
  });

  final String codigo;
  final String estadoToken;
}

class ActividadSnapshot {
  const ActividadSnapshot({
    required this.tokens,
    required this.promosPorId,
  });

  final List<Map<String, dynamic>> tokens;
  final Map<String, SnapshotTokenPromoCache> promosPorId;
}

class ServicioActividadUsuario {
  ServicioActividadUsuario._();
  static final instancia = ServicioActividadUsuario._();

  static const _ttlSuave = Duration(seconds: 90);
  static const _estadosPromo = [
    'activo',
    'canjeado',
    'reservado',
  ];

  final _cache = CacheMemoria<ActividadSnapshot>();

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  bool get tieneCache => _cache.tiene(_uid);

  ActividadSnapshot? get cache =>
      _cache.tiene(_uid) ? _cache.data : null;

  void invalidar() => _cache.clear();

  /// [forzarCompleto] = pull-to-refresh (siempre red).
  /// Sin forzar: si el cache está fresco, no llama a Supabase.
  Future<ActividadSnapshot> sincronizar({bool forzarCompleto = false}) async {
    final uid = _uid;
    if (uid == null) {
      _cache.clear();
      return const ActividadSnapshot(tokens: [], promosPorId: {});
    }

    if (!forzarCompleto && _cache.fresco(uid, _ttlSuave)) {
      return _cache.data!;
    }

    final snap = await _fetch(uid);
    _cache.set(uid, snap);
    return snap;
  }

  Future<ActividadSnapshot> _fetch(String userId) async {
    final sb = ServicioSupabase().cliente;

    final rows = await sb
        .from('tokens_asistencia')
        .select(
          'id_token, codigo_puerta, estado_token, fecha_expiracion, '
          'snapshot_squad, id_reserva_grupal, '
          'eventos!tokens_asistencia_id_evento_fkey('
          'id_evento, titulo_evento, descripcion_evento, url_flyer, '
          'fecha_inicio, fecha_fin, id_local'
          ')',
        )
        .eq('id_usuario', userId)
        .inFilter('estado_token', ['pendiente', 'aceptada', 'canjeada'])
        .order('fecha_creacion', ascending: false);

    if (kDebugMode) {
      debugPrint(
        '[Actividad] userId=$userId tokens: ${(rows as List).length}',
      );
    }

    final idsLocales = <String>{};
    for (final r in (rows as List)) {
      final ev = r['eventos'];
      if (ev is Map) {
        final idL = ev['id_local']?.toString().trim() ?? '';
        if (idL.isNotEmpty) idsLocales.add(idL);
      }
    }

    final perfilesPorId = <String, Map<String, dynamic>>{};
    if (idsLocales.isNotEmpty) {
      try {
        final perfilesRows = await sb
            .from('perfiles_locales')
            .select(
              'id, nombre_local, foto_perfil_url, url_maps, direccion, '
              'ciudad, provincia, es_pionero',
            )
            .inFilter('id', idsLocales.toList());
        for (final p in (perfilesRows as List)) {
          final id = p['id']?.toString().toLowerCase() ?? '';
          if (id.isNotEmpty) {
            perfilesPorId[id] = Map<String, dynamic>.from(p as Map);
          }
        }
      } catch (_) {}
    }

    final reservadoresIds = <String>{};
    for (final r in (rows as List)) {
      final snap = r['snapshot_squad'];
      if (snap is Map) {
        final rp = snap['reservado_por']?.toString().trim() ?? '';
        if (rp.isNotEmpty) reservadoresIds.add(rp);
      }
    }
    final reservadoresPorId = <String, Map<String, dynamic>>{};
    if (reservadoresIds.isNotEmpty) {
      try {
        final resRows = await sb
            .from('perfiles_usuarios')
            .select('id, nombre, username')
            .inFilter('id', reservadoresIds.toList());
        for (final p in (resRows as List)) {
          final id = p['id']?.toString().toLowerCase() ?? '';
          if (id.isNotEmpty) {
            reservadoresPorId[id] = Map<String, dynamic>.from(p as Map);
          }
        }
      } catch (_) {}
    }

    final tokens = rows.map<Map<String, dynamic>>((r) {
      final ev = r['eventos'] as Map<String, dynamic>? ?? {};
      final idLocal = ev['id_local']?.toString().trim() ?? '';
      final perfil = perfilesPorId[idLocal.toLowerCase()];
      final snapRaw = r['snapshot_squad'];
      Map<String, dynamic>? snap;
      if (snapRaw is Map) snap = Map<String, dynamic>.from(snapRaw);

      String? nombreSquad;
      int? indiceSquad;
      int? totalSquad;
      String? reservadoPorId;
      String? reservadoPorNombre;
      String? reservadoPorUsername;
      var esSquad = false;

      if (snap != null) {
        nombreSquad = snap['nombre_grupo']?.toString().trim();
        if (nombreSquad != null && nombreSquad.isEmpty) nombreSquad = null;
        final indRaw = snap['indice'];
        indiceSquad = indRaw is int
            ? indRaw
            : (indRaw is num ? indRaw.toInt() : int.tryParse('$indRaw'));
        final totalRaw = snap['cantidad_total'] ?? snap['cantidad'];
        totalSquad = totalRaw is int
            ? totalRaw
            : (totalRaw is num
                ? totalRaw.toInt()
                : int.tryParse('$totalRaw'));
        reservadoPorId = snap['reservado_por']?.toString().trim();
        if (reservadoPorId != null && reservadoPorId.isEmpty) {
          reservadoPorId = null;
        }
        esSquad = indiceSquad != null ||
            (totalSquad != null && totalSquad > 1) ||
            snap['id_grupo'] != null;
        if (reservadoPorId != null) {
          final rp = reservadoresPorId[reservadoPorId.toLowerCase()];
          if (rp != null) {
            reservadoPorNombre = rp['nombre']?.toString().trim();
            reservadoPorUsername = rp['username']?.toString().trim();
          }
        }
      }

      return {
        'id_token': r['id_token'],
        'codigo_puerta': r['codigo_puerta'] ?? '',
        'estado_token': r['estado_token'] ?? 'pendiente',
        'id_reserva_grupal': r['id_reserva_grupal'],
        'es_squad': esSquad,
        'nombre_squad': nombreSquad,
        'indice_squad': indiceSquad,
        'total_squad': totalSquad,
        'reservado_por_id': reservadoPorId,
        'reservado_por_nombre': reservadoPorNombre,
        'reservado_por_username': reservadoPorUsername,
        'titulo': ev['titulo_evento'] ?? 'Evento',
        'descripcion': ev['descripcion_evento'] ?? '',
        'flyer': ev['url_flyer'] ?? '',
        'fechaInicio': ev['fecha_inicio'],
        'fechaFin': ev['fecha_fin'],
        'nombreLocal': perfil?['nombre_local']?.toString().trim().isNotEmpty ==
                true
            ? perfil!['nombre_local'].toString()
            : 'Local',
        'avatarLocal': _resolverAvatarLocal(perfil?['foto_perfil_url']),
        'localEsPionero': perfil?['es_pionero'] == true,
        'idLocal': idLocal.isNotEmpty ? idLocal : null,
        'urlMaps': perfil?['url_maps']?.toString().trim() ?? '',
        'direccion': perfil?['direccion']?.toString().trim() ?? '',
        'ciudad': perfil?['ciudad']?.toString().trim() ?? '',
        'provincia': perfil?['provincia']?.toString().trim() ?? '',
        'id_evento': ev['id_evento'],
      };
    }).toList();

    final promoPorId = <String, SnapshotTokenPromoCache>{};
    try {
      final promoRows = await sb
          .from('tokens_promociones')
          .select('id_promocion, token_codigo, estado_token')
          .eq('id_usuario', userId)
          .inFilter('estado_token', _estadosPromo);
      for (final t in (promoRows as List)) {
        final idP = t['id_promocion']?.toString() ?? '';
        final codigo = t['token_codigo']?.toString() ?? '';
        final est = t['estado_token']?.toString().toLowerCase() ?? 'activo';
        if (idP.isNotEmpty && codigo.isNotEmpty) {
          promoPorId[idP] =
              SnapshotTokenPromoCache(codigo: codigo, estadoToken: est);
        }
      }
    } catch (e, st) {
      debugPrint('[Actividad] tokens_promociones: $e\n$st');
    }

    return ActividadSnapshot(tokens: tokens, promosPorId: promoPorId);
  }

  String _resolverAvatarLocal(dynamic avatarRaw) {
    final avatar = avatarRaw?.toString() ?? '';
    if (avatar.isEmpty || avatar.startsWith('http')) return avatar;
    return ServicioSupabase()
        .cliente
        .storage
        .from('perfiles-locales')
        .getPublicUrl(avatar);
  }
}
