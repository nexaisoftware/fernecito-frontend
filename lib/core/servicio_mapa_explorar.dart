/// Carga de locales y eventos para el mapa explorar.
library;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache_memoria.dart';
import 'coordenadas_ciudades.dart';
import 'servicio_geocodificacion.dart';
import 'supabase_client.dart';

class MapaLocalItem {
  MapaLocalItem({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.provincia,
    required this.coordenadas,
    this.avatarUrl,
    this.descripcion,
    bool esPionero = false,
  }) : _esPionero = esPionero;

  final String id;
  final String nombre;
  final String ciudad;
  final String provincia;
  final LatLng coordenadas;
  final String? avatarUrl;
  final String? descripcion;
  final bool? _esPionero;

  bool get esPionero => _esPionero ?? false;
}

class MapaEventoItem {
  MapaEventoItem({
    required this.id,
    required this.titulo,
    required this.nombreLocal,
    required this.ciudad,
    required this.provincia,
    required this.coordenadas,
    required this.idLocal,
    this.descripcion,
    this.flyerUrl,
    this.avatarLocal,
    this.fechaInicio,
    bool localEsPionero = false,
    bool tienePromo = false,
  })  : _localEsPionero = localEsPionero,
        _tienePromo = tienePromo;

  final String id;
  final String titulo;
  final String nombreLocal;
  final String ciudad;
  final String provincia;
  final LatLng coordenadas;
  final String idLocal;
  final String? descripcion;
  final String? flyerUrl;
  final String? avatarLocal;
  final DateTime? fechaInicio;
  final bool? _localEsPionero;
  final bool? _tienePromo;

  bool get localEsPionero => _localEsPionero ?? false;
  bool get tienePromo => _tienePromo ?? false;
}

class ServicioMapaExplorar {
  ServicioMapaExplorar._();
  static final instancia = ServicioMapaExplorar._();

  static const _ttl = Duration(seconds: 120);
  final _cacheLocales = CachePorClave<List<MapaLocalItem>>();
  final _cacheEventos = CachePorClave<List<MapaEventoItem>>();

  String _claveCiudades(Set<String> ciudades) {
    final list = ciudades.toList()..sort();
    return list.join('|');
  }

  void invalidar() {
    _cacheLocales.clear();
    _cacheEventos.clear();
  }

  String _resolverAvatar(SupabaseClient sb, String? path) {
    final p = path?.trim() ?? '';
    if (p.isEmpty) return '';
    if (p.startsWith('http') || p.startsWith('assets/')) return p;
    return sb.storage.from('avatars_locales').getPublicUrl(p);
  }

  bool _coincideCiudad(String? ciudad, Set<String> ciudades) {
    if (ciudades.isEmpty) return false;
    final c = ciudad?.trim() ?? '';
    return c.isNotEmpty && ciudades.contains(c);
  }

  Future<List<MapaLocalItem>> cargarLocales({
    required Set<String> ciudades,
    bool forzarCompleto = false,
  }) async {
    final key = _claveCiudades(ciudades);
    if (!forzarCompleto && _cacheLocales.fresco(key, _ttl)) {
      return _cacheLocales.get(key) ?? const [];
    }
    final sb = ServicioSupabase().cliente;
    try {
      final rows = await sb
          .from('perfiles_locales')
          .select(
            'id, nombre_local, local_username, foto_perfil_url, ciudad, '
            'provincia, direccion, url_maps, descripcion_local, es_pionero',
          )
          .eq('estado_cuenta', 'activa')
          .limit(100);

      final filtrados = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => _coincideCiudad(m['ciudad']?.toString(), ciudades))
          .toList();

      final resultado = <MapaLocalItem>[];
      for (final m in filtrados) {
        final id = m['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final nombre = (m['nombre_local'] ?? m['local_username'] ?? 'Local')
            .toString()
            .trim();
        final ciudad = m['ciudad']?.toString() ?? '';
        final provincia = m['provincia']?.toString() ?? '';
        final coord = await ServicioGeocodificacion.instancia.resolver(
          id: id,
          direccion: m['direccion']?.toString(),
          ciudad: ciudad,
          provincia: provincia,
          urlMaps: m['url_maps']?.toString(),
          nombreFallback: nombre,
        );
        if (coord == null) continue;
        resultado.add(
          MapaLocalItem(
            id: id,
            nombre: nombre.isNotEmpty ? nombre : 'Local',
            ciudad: ciudad,
            provincia: provincia,
            esPionero: _parseBool(m['es_pionero']),
            coordenadas: coord,
            avatarUrl: _resolverAvatar(sb, m['foto_perfil_url']?.toString()),
            descripcion: m['descripcion_local']?.toString(),
          ),
        );
      }
      _cacheLocales.set(key, resultado);
      return resultado;
    } catch (e) {
      debugPrint('[MapaExplorar] locales: $e');
      return _cacheLocales.get(key) ?? const [];
    }
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 't';
  }

  Future<List<dynamic>> _consultarEventosMapa(SupabaseClient sb, String ahora) async {
    const embed =
        'perfiles_locales!inner(id, nombre_local, local_username, '
        'foto_perfil_url, ciudad, provincia, direccion, url_maps, es_pionero)';
    const base =
        'id_evento, titulo_evento, descripcion_evento, url_flyer, '
        'fecha_inicio, ciudad_evento, provincia_evento, id_local, $embed';
    const conPromo = 'tiene_promo, $base';

    try {
      return await sb
          .from('eventos')
          .select(conPromo)
          .eq('estado_publicacion', 'publicado')
          .eq('perfiles_locales.estado_cuenta', 'activa')
          .or('fecha_fin_publicacion.gt.$ahora,fecha_fin_publicacion.is.null')
          .order('fecha_inicio', ascending: true)
          .limit(120);
    } catch (e) {
      debugPrint('[MapaExplorar] query con tiene_promo falló, reintento: $e');
      return await sb
          .from('eventos')
          .select(base)
          .eq('estado_publicacion', 'publicado')
          .eq('perfiles_locales.estado_cuenta', 'activa')
          .or('fecha_fin_publicacion.gt.$ahora,fecha_fin_publicacion.is.null')
          .order('fecha_inicio', ascending: true)
          .limit(120);
    }
  }

  Future<List<MapaEventoItem>> cargarEventos({
    required Set<String> ciudades,
    bool forzarCompleto = false,
  }) async {
    final key = _claveCiudades(ciudades);
    if (!forzarCompleto && _cacheEventos.fresco(key, _ttl)) {
      return _cacheEventos.get(key) ?? const [];
    }
    final sb = ServicioSupabase().cliente;
    final ahora = DateTime.now().toUtc().toIso8601String();

    Set<String> idsConPromo = {};
    try {
      final promos = await sb
          .from('promociones')
          .select('id_evento')
          .eq('estado_promocion', 'activa');
      idsConPromo = (promos as List)
          .map((e) => (e as Map)['id_evento']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('[MapaExplorar] promos: $e');
    }

    try {
      final rows = await _consultarEventosMapa(sb, ahora);

      final filtrados = (rows)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where(
            (m) => _coincideCiudad(m['ciudad_evento']?.toString(), ciudades),
          )
          .toList();

      final coordsLocales = <String, LatLng>{};
      final resultado = <MapaEventoItem>[];

      for (final m in filtrados) {
        final id = m['id_evento']?.toString() ?? '';
        if (id.isEmpty) continue;
        final perfil = m['perfiles_locales'] is Map
            ? Map<String, dynamic>.from(m['perfiles_locales'] as Map)
            : null;
        final idLocal = m['id_local']?.toString() ?? perfil?['id']?.toString() ?? '';
        final ciudad = m['ciudad_evento']?.toString() ?? '';
        final provincia = m['provincia_evento']?.toString() ?? '';
        final titulo = m['titulo_evento']?.toString() ?? 'Evento';
        final nombreLocal = (perfil?['nombre_local'] ?? perfil?['local_username'] ?? 'Local')
            .toString();

        LatLng? coord;
        if (idLocal.isNotEmpty) {
          coord = coordsLocales[idLocal];
          if (coord == null) {
            coord = await ServicioGeocodificacion.instancia.resolver(
              id: idLocal,
              direccion: perfil?['direccion']?.toString(),
              ciudad: perfil?['ciudad']?.toString() ?? ciudad,
              provincia: perfil?['provincia']?.toString() ?? provincia,
              urlMaps: perfil?['url_maps']?.toString(),
              nombreFallback: nombreLocal,
            );
            if (coord != null) coordsLocales[idLocal] = coord;
          }
        }
        coord ??= CoordenadasCiudades.deCiudad(ciudad);
        if (coord == null) continue;

        final conJitter = CoordenadasCiudades.conJitter(coord, id);
        final fechaRaw = m['fecha_inicio']?.toString();
        final promoFlag =
            _parseBool(m['tiene_promo']) || idsConPromo.contains(id);
        resultado.add(
          MapaEventoItem(
            id: id,
            titulo: titulo,
            nombreLocal: nombreLocal,
            ciudad: ciudad,
            provincia: provincia,
            coordenadas: conJitter,
            idLocal: idLocal,
            descripcion: m['descripcion_evento']?.toString(),
            flyerUrl: m['url_flyer']?.toString(),
            avatarLocal: _resolverAvatar(sb, perfil?['foto_perfil_url']?.toString()),
            fechaInicio: fechaRaw != null ? DateTime.tryParse(fechaRaw) : null,
            localEsPionero: _parseBool(perfil?['es_pionero']),
            tienePromo: promoFlag,
          ),
        );
      }
      _cacheEventos.set(key, resultado);
      return resultado;
    } catch (e) {
      debugPrint('[MapaExplorar] eventos: $e');
      return _cacheEventos.get(key) ?? const [];
    }
  }
}
