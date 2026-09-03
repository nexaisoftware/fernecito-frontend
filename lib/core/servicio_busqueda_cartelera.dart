/// Búsqueda de cartelera: DB + [BusquedaNatural] (typos, incompletas, sinónimos).
///
/// Orden:
/// - Lugares: nombre → rubro / ciudad
/// - Eventos: título/contenido → local publicador (+ boost promo)
/// - Planes: título/nombre → lugar (ciudad / local)
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'busqueda_natural.dart';
import 'servicio_cartelera_locales.dart';
import 'supabase_client.dart';

class ResultadoBusquedaCartelera {
  const ResultadoBusquedaCartelera({
    required this.lugares,
    required this.eventos,
  });

  final List<Map<String, dynamic>> lugares;
  final List<Map<String, dynamic>> eventos;
}

class ServicioBusquedaCartelera {
  ServicioBusquedaCartelera._();
  static final instancia = ServicioBusquedaCartelera._();

  static const _selLocal =
      'id, nombre_local, local_username, local_verificado, es_pionero, foto_perfil_url, '
      'url_foto_banner, foto_local_1, foto_local_2, foto_local_3, rubro, ciudad, provincia, fecha_creacion';

  static const _selEvento =
      'id_evento, titulo_evento, descripcion_evento, url_flyer, fecha_inicio, fecha_fin, '
      'fecha_fin_publicacion, jerarquia, tipo_evento, tiene_promo, cupo_lista_max, cupo_lista_usados, modo_lista, '
      'id_local, ciudad_evento, provincia_evento, dia_semana, '
      'perfiles_locales!eventos_id_local_fkey!inner('
      'nombre_local, local_username, local_verificado, es_pionero, foto_perfil_url, '
      'url_foto_banner, foto_local_1, foto_local_2, foto_local_3, rubro, ciudad, estado_cuenta'
      ')';

  /// Tokens útiles para armar candidatos ILIKE en DB (mín. 2 chars).
  static List<String> tokensConsulta(String q) {
    final n = BusquedaNatural.normalizar(q);
    if (n.isEmpty) return const [];
    return n
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .take(4)
        .toList(growable: false);
  }

  static String patronIlikeSeguro(String raw) {
    return raw
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', ' ')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('\\', '')
        .trim();
  }

  Future<ResultadoBusquedaCartelera> buscar({
    required String query,
    required Set<String> ciudadesActivas,
    required Map<String, dynamic> Function(
      SupabaseClient sb,
      Map<String, dynamic> local, {
      bool esNuevo,
    }) empacarLocal,
    required Map<String, dynamic> Function(
      SupabaseClient sb,
      Map<String, dynamic> row,
    ) empacarEvento,
    Map<String, dynamic>? Function(dynamic row)? perfilEmbedded,
    List<Map<String, dynamic>> memoriaLocales = const [],
    List<Map<String, dynamic>> memoriaEventos = const [],
  }) async {
    final q = query.trim();
    if (q.length < 2) {
      return const ResultadoBusquedaCartelera(lugares: [], eventos: []);
    }

    final sb = ServicioSupabase().cliente;
    final ciudades = ServicioCarteleraLocales.expandirCiudadesQuery(
      ciudadesActivas,
    );

    // 1) RPC (ya con GRANT). Si falla, seguimos con queries.
    final lugaresExtra = <Map<String, dynamic>>[];
    final eventosExtra = <Map<String, dynamic>>[];
    try {
      final rpc = await _viaRpc(sb, q, ciudades);
      if (rpc != null) {
        lugaresExtra.addAll(rpc.lugares);
        eventosExtra.addAll(rpc.eventos);
      }
    } catch (e) {
      debugPrint('⚠️ busqueda rpc: $e');
    }

    // 2) Queries directas + memoria (fuzzy BusquedaNatural).
    final tokens = tokensConsulta(q);
    final likePrincipal = patronIlikeSeguro(
      tokens.isNotEmpty ? tokens.first : q,
    );
    final idsPromo = await _idsEventosConPromo(sb);
    final lugaresDb = await _localesCandidatos(
      sb,
      likePrincipal,
      tokens,
      ciudades,
    );
    final eventosDb = await _eventosCandidatos(
      sb,
      likePrincipal,
      tokens,
      ciudades,
      idsPromo,
    );

    final lugares = _rankearLocales(q, [
      for (final raw in [...lugaresExtra, ...lugaresDb]) empacarLocal(sb, raw),
      ...memoriaLocales,
    ]);

    final eventosRaw = <Map<String, dynamic>>[];
    for (final raw in [...eventosExtra, ...eventosDb]) {
      final perfil = perfilEmbedded?.call(raw) ?? const <String, dynamic>{};
      final mapped = empacarEvento(sb, {...raw, ...perfil});
      final id = mapped['id']?.toString() ?? '';
      if (id.isNotEmpty && idsPromo.contains(id)) {
        mapped['tienePromo'] = true;
      }
      eventosRaw.add(mapped);
    }
    for (final e in memoriaEventos) {
      eventosRaw.add(Map<String, dynamic>.from(e));
    }

    return ResultadoBusquedaCartelera(
      lugares: lugares,
      eventos: _rankearEventos(q, eventosRaw),
    );
  }

  /// Ranking inmediato sin red (lo que ya está en cartelera / explora).
  static ResultadoBusquedaCartelera rankearDesdeMemoria({
    required String query,
    required List<Map<String, dynamic>> locales,
    required List<Map<String, dynamic>> eventos,
  }) {
    final svc = ServicioBusquedaCartelera.instancia;
    return ResultadoBusquedaCartelera(
      lugares: svc._rankearLocales(query, locales),
      eventos: svc._rankearEventos(query, eventos),
    );
  }

  Future<({List<Map<String, dynamic>> lugares, List<Map<String, dynamic>> eventos})?>
  _viaRpc(
    SupabaseClient sb,
    String q,
    List<String> ciudades,
  ) async {
    Future<Map?> call(List<String>? cities) async {
      final res = await sb.rpc(
        'cartelera_buscar',
        params: {
          'p_q': q,
          'p_ciudades': cities,
          'p_limite_locales': 40,
          'p_limite_eventos': 50,
        },
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    }

    try {
      var res = await call(ciudades.isEmpty ? null : ciudades);
      if (res == null) return null;

      List<Map<String, dynamic>> parseList(dynamic raw) {
        if (raw is! List) return const [];
        return [
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }

      var lugares = parseList(res['locales']);
      var eventos = parseList(res['eventos']);

      if (lugares.isEmpty && ciudades.isNotEmpty) {
        final r2 = await call(null);
        if (r2 != null) lugares = parseList(r2['locales']);
      }
      if (eventos.isEmpty && ciudades.isNotEmpty) {
        final r2 = await call(null);
        if (r2 != null) eventos = parseList(r2['eventos']);
      }

      return (lugares: lugares, eventos: eventos);
    } on PostgrestException {
      return null;
    }
  }

  Future<Set<String>> _idsEventosConPromo(SupabaseClient sb) async {
    try {
      final rows = await sb
          .from('promociones')
          .select('id_evento')
          .eq('estado_promocion', 'activa')
          .limit(200);
      return {
        for (final r in (rows as List))
          if ((r['id_evento']?.toString() ?? '').isNotEmpty)
            r['id_evento'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _localesCandidatos(
    SupabaseClient sb,
    String likePrincipal,
    List<String> tokens,
    List<String> ciudades,
  ) async {
    final out = <String, Map<String, dynamic>>{};

    Future<void> pull({required bool filtrarCiudad, String? like}) async {
      try {
        var q = sb
            .from('perfiles_locales')
            .select(_selLocal)
            .eq('estado_cuenta', 'activa');
        if (filtrarCiudad && ciudades.isNotEmpty) {
          q = q.inFilter('ciudad', ciudades);
        }
        if (like != null && like.isNotEmpty) {
          q = q.or(
            'nombre_local.ilike.%$like%,local_username.ilike.%$like%',
          );
        }
        final rows = await q.limit(like == null ? 120 : 60);
        for (final raw in (rows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) out[id] = m;
        }
      } catch (e) {
        debugPrint('⚠️ busqueda locales pull: $e');
      }
    }

    // Candidatos por ILIKE (tokens) + muestra de zona para fuzzy/sinónimos.
    if (likePrincipal.isNotEmpty) {
      await pull(filtrarCiudad: true, like: likePrincipal);
    }
    for (final t in tokens.skip(1).take(2)) {
      final like = patronIlikeSeguro(t);
      if (like.length >= 2) await pull(filtrarCiudad: true, like: like);
    }
    await pull(filtrarCiudad: true, like: null);

    if (out.length < 8 && ciudades.isNotEmpty) {
      if (likePrincipal.isNotEmpty) {
        await pull(filtrarCiudad: false, like: likePrincipal);
      }
      await pull(filtrarCiudad: false, like: null);
    }

    return out.values.toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _eventosCandidatos(
    SupabaseClient sb,
    String likePrincipal,
    List<String> tokens,
    List<String> ciudades,
    Set<String> idsPromo,
  ) async {
    final out = <String, Map<String, dynamic>>{};
    final now = DateTime.now().toUtc();

    bool vigente(Map<String, dynamic> m) {
      final fin = m['fecha_fin_publicacion']?.toString();
      if (fin == null || fin.isEmpty) return true;
      final dt = DateTime.tryParse(fin);
      if (dt == null) return true;
      return dt.isAfter(now);
    }

    Future<void> pull({required bool filtrarCiudad, String? like}) async {
      try {
        var q = sb
            .from('eventos')
            .select(_selEvento)
            .eq('estado_publicacion', 'publicado')
            .eq('perfiles_locales.estado_cuenta', 'activa');
        if (filtrarCiudad && ciudades.isNotEmpty) {
          q = q.inFilter('ciudad_evento', ciudades);
        }
        if (like != null && like.isNotEmpty) {
          q = q.or(
            'titulo_evento.ilike.%$like%,'
            'descripcion_evento.ilike.%$like%,'
            'tipo_evento.ilike.%$like%',
          );
        }
        final rows = await q.limit(like == null ? 120 : 60);
        for (final raw in (rows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          if (!vigente(m)) continue;
          final id = m['id_evento']?.toString() ?? '';
          if (id.isNotEmpty) out[id] = m;
        }
      } catch (e) {
        debugPrint('⚠️ busqueda eventos pull: $e');
      }
    }

    if (likePrincipal.isNotEmpty) {
      await pull(filtrarCiudad: true, like: likePrincipal);
    }
    for (final t in tokens.skip(1).take(2)) {
      final like = patronIlikeSeguro(t);
      if (like.length >= 2) await pull(filtrarCiudad: true, like: like);
    }
    await pull(filtrarCiudad: true, like: null);

    // Promos activas: traer esos eventos (para "promo" / 2x1 / descuento).
    if (idsPromo.isNotEmpty) {
      try {
        final ids = idsPromo.take(40).toList();
        var q = sb
            .from('eventos')
            .select(_selEvento)
            .eq('estado_publicacion', 'publicado')
            .eq('perfiles_locales.estado_cuenta', 'activa')
            .inFilter('id_evento', ids);
        if (ciudades.isNotEmpty) {
          q = q.inFilter('ciudad_evento', ciudades);
        }
        final rows = await q.limit(40);
        for (final raw in (rows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          if (!vigente(m)) continue;
          final id = m['id_evento']?.toString() ?? '';
          if (id.isNotEmpty) out[id] = m;
        }
      } catch (e) {
        debugPrint('⚠️ busqueda promos: $e');
      }
    }

    if (out.length < 8 && ciudades.isNotEmpty) {
      if (likePrincipal.isNotEmpty) {
        await pull(filtrarCiudad: false, like: likePrincipal);
      }
      await pull(filtrarCiudad: false, like: null);
    }

    return out.values.toList(growable: false);
  }

  List<Map<String, dynamic>> _rankearLocales(
    String q,
    List<Map<String, dynamic>> candidatos,
  ) {
    final vistos = <String>{};
    final scored = <({int score, Map<String, dynamic> item})>[];

    for (final raw in candidatos) {
      final local = Map<String, dynamic>.from(raw);
      final id = (local['idLocal'] ?? local['id'])?.toString() ?? '';
      if (id.isEmpty || !vistos.add(id)) continue;

      final nombre = local['nombre'] ?? local['nombre_local'];
      final rubro = local['rubro'];
      final ciudad = local['ciudad'];
      final provincia = local['provincia'];

      if (!BusquedaNatural.coincide(q, [nombre, rubro, ciudad, provincia])) {
        continue;
      }

      var score = 0;
      if (BusquedaNatural.coincide(q, [nombre])) score += 100;
      if (BusquedaNatural.coincide(q, [rubro])) score += 40;
      if (BusquedaNatural.coincide(q, [ciudad, provincia])) score += 15;
      scored.add((score: score, item: local));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return [
      for (final s in scored.take(30)) s.item,
    ];
  }

  List<Map<String, dynamic>> _rankearEventos(
    String q,
    List<Map<String, dynamic>> candidatos,
  ) {
    final vistos = <String>{};
    final scored = <({int score, Map<String, dynamic> item})>[];

    for (final raw in candidatos) {
      final e = Map<String, dynamic>.from(raw);
      final id = e['id']?.toString() ?? '';
      if (id.isEmpty || !vistos.add(id)) continue;

      final titulo = e['titulo'];
      final desc = e['descripcion'];
      final tipo = e['tipoEvento'] ?? e['tipo_evento'];
      final dia = e['diaSemana'] ?? e['dia_semana'];
      final ciudad = e['ciudadEvento'] ?? e['ciudad_evento'];
      final nombreLocal = e['nombreLocal'] ?? e['nombre_local'];
      final promo = e['tienePromo'] == true || e['tiene_promo'] == true;

      final matchContenido = BusquedaNatural.coincide(q, [
        titulo,
        desc,
        tipo,
        dia,
        ciudad,
        if (promo) 'promo promocion descuento oferta 2x1',
      ]);
      final matchLocal = BusquedaNatural.coincide(q, [nombreLocal]);

      if (!matchContenido && !matchLocal) continue;

      var score = 0;
      // Primero coincidencia por nombre/contenido del evento; luego por local.
      if (BusquedaNatural.coincide(q, [titulo])) score += 100;
      if (matchContenido) score += 50;
      if (matchLocal) score += 30;
      if (promo && BusquedaNatural.coincide(q, ['promo promocion descuento'])) {
        score += 20;
      }
      // Preferir match solo-contenido sobre solo-local en el sort:
      if (matchContenido && !matchLocal) score += 5;
      if (!matchContenido && matchLocal) score -= 5;

      scored.add((score: score, item: e));
    }

    // Contenido primero, después por local (score ya lo ordena).
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [
      for (final s in scored.take(40)) s.item,
    ];
  }

  /// Reordena planes: nombre/título primero, luego lugar.
  static List<T> rankearPlanes<T>(
    String q,
    List<T> items, {
    required String? Function(T) titulo,
    required String? Function(T) lugar,
    String? Function(T)? extraNombre,
  }) {
    if (q.trim().isEmpty || items.isEmpty) return items;
    final scored = <({int score, T item})>[];
    for (final p in items) {
      final nom = titulo(p);
      final extra = extraNombre?.call(p);
      final ubi = lugar(p);
      final matchNombre = BusquedaNatural.coincide(q, [nom, extra]);
      final matchLugar = BusquedaNatural.coincide(q, [ubi]);
      if (!matchNombre && !matchLugar) {
        // El hub ya filtró; conservar al final.
        scored.add((score: 0, item: p));
        continue;
      }
      var score = 0;
      if (matchNombre) score += 100;
      if (matchLugar) score += 40;
      scored.add((score: score, item: p));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final s in scored) s.item];
  }
}
