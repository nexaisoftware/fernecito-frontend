library;

import 'package:flutter/foundation.dart';

import 'cache_memoria.dart';
import 'supabase_client.dart';

class LocalMegustaItem {
  const LocalMegustaItem({
    required this.idLocal,
    required this.nombreLocal,
    this.localUsername,
    this.fotoPerfilUrl,
    this.verificado = false,
    this.esPionero = false,
  });

  final String idLocal;
  final String nombreLocal;
  final String? localUsername;
  final String? fotoPerfilUrl;
  final bool verificado;
  final bool esPionero;

  LocalMegustaItem copyWith({bool? verificado, bool? esPionero}) {
    return LocalMegustaItem(
      idLocal: idLocal,
      nombreLocal: nombreLocal,
      localUsername: localUsername,
      fotoPerfilUrl: fotoPerfilUrl,
      verificado: verificado ?? this.verificado,
      esPionero: esPionero ?? this.esPionero,
    );
  }

  factory LocalMegustaItem.fromJson(Map<String, dynamic> json) {
    final esPionero =
        json['local_es_pionero'] == true || json['es_pionero'] == true;
    return LocalMegustaItem(
      idLocal: json['id_local']?.toString() ?? '',
      nombreLocal: json['nombre_local']?.toString().trim() ?? 'Local',
      localUsername: json['local_username']?.toString(),
      fotoPerfilUrl: json['foto_perfil_url']?.toString(),
      verificado: json['local_verificado'] == true || esPionero,
      esPionero: esPionero,
    );
  }
}

class EstadoMegustaLocal {
  const EstadoMegustaLocal({required this.cantidad, required this.yoMegusta});

  final int cantidad;
  final bool yoMegusta;
}

/// Me gusta a locales vía RPC (escritura segura, rate limit en backend).
class ServicioLocalesMegusta {
  ServicioLocalesMegusta._();
  static final ServicioLocalesMegusta instancia = ServicioLocalesMegusta._();

  Future<EstadoMegustaLocal> estado(String idLocal) async {
    if (idLocal.isEmpty) {
      return const EstadoMegustaLocal(cantidad: 0, yoMegusta: false);
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'local_megusta_estado',
        params: {'p_id_local': idLocal},
      );
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        return EstadoMegustaLocal(
          cantidad: _entero(map['cantidad']),
          yoMegusta: map['yo_megusta'] == true,
        );
      }
    } catch (e) {
      debugPrint('⚠️ local_megusta_estado: $e');
    }
    return const EstadoMegustaLocal(cantidad: 0, yoMegusta: false);
  }

  Future<EstadoMegustaLocal?> toggle(String idLocal) async {
    if (idLocal.isEmpty) return null;
    if (ServicioSupabase().usuarioActual == null) return null;
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'local_megusta_toggle',
        params: {'p_id_local': idLocal},
      );
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['ok'] != true) return null;
        invalidarLista();
        return EstadoMegustaLocal(
          cantidad: _entero(map['cantidad']),
          yoMegusta: map['megusta'] == true,
        );
      }
    } catch (e) {
      debugPrint('⚠️ local_megusta_toggle: $e');
      rethrow;
    }
    return null;
  }

  final _cacheListas = CachePorClave<List<LocalMegustaItem>>();
  static const _ttlLista = Duration(seconds: 90);

  void invalidarLista({String? idUsuario}) {
    final key = idUsuario ?? '_yo';
    _cacheListas.invalidate(key);
  }

  Future<List<LocalMegustaItem>> listar({
    String? idUsuario,
    bool forzarCompleto = false,
  }) async {
    final key = idUsuario ?? '_yo';
    if (!forzarCompleto && _cacheListas.fresco(key, _ttlLista)) {
      return _cacheListas.get(key) ?? const [];
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'locales_megusta_listar',
        params: {if (idUsuario != null) 'p_id_usuario': idUsuario},
      );
      if (res is! Map) return const [];
      final map = Map<String, dynamic>.from(res);
      final raw = map['items'];
      if (raw is! List) return const [];
      final items = raw
          .whereType<Map>()
          .map((e) => LocalMegustaItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.idLocal.isNotEmpty)
          .toList();
      final listos = await _completarPioneros(items);
      _cacheListas.set(key, listos);
      return listos;
    } catch (e) {
      debugPrint('⚠️ locales_megusta_listar: $e');
      return _cacheListas.get(key) ?? const [];
    }
  }

  Future<List<LocalMegustaItem>> _completarPioneros(
    List<LocalMegustaItem> items,
  ) async {
    if (items.isEmpty) return items;
    final ids = items.map((e) => e.idLocal).toSet().toList();
    try {
      final rows = await ServicioSupabase().cliente
          .from('perfiles_locales')
          .select('id, local_verificado, es_pionero')
          .inFilter('id', ids);
      final porId = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString();
        if (id != null && id.isNotEmpty) porId[id] = map;
      }
      return items.map((item) {
        final extra = porId[item.idLocal];
        if (extra == null) return item;
        final esPionero = extra['es_pionero'] == true;
        final verificado = extra['local_verificado'] == true || esPionero;
        return item.copyWith(verificado: verificado, esPionero: esPionero);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ completar pioneros en me gusta: $e');
      return items;
    }
  }

  int _entero(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
