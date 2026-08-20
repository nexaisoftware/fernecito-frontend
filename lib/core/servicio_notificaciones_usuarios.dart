library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/notificacion.dart';
import 'supabase_client.dart';

/// Servicio singleton para leer / marcar / borrar notificaciones del usuario.
///
/// Mantiene un cache en memoria: la primera carga trae el feed completo;
/// las siguientes solo piden **nuevas** (`fecha_creacion` más reciente) y
/// sincronizan el estado **leída** con un query liviano de ids no leídos.
class ServicioNotificacionesUsuarios {
  static final ServicioNotificacionesUsuarios _instancia =
      ServicioNotificacionesUsuarios._interno();
  factory ServicioNotificacionesUsuarios() => _instancia;
  ServicioNotificacionesUsuarios._interno();

  static const int _limitFeed = 50;

  /// Total de notificaciones no leídas del usuario actual (para badge).
  final ValueNotifier<int> contadorNoLeidas = ValueNotifier<int>(0);

  List<Notificacion> _cache = const [];
  String? _cacheUid;
  DateTime? _ultimoContadorAt;
  static const _ttlContador = Duration(seconds: 45);

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  /// Snapshot del cache (más recientes primero). Vacío si no hay datos aún.
  List<Notificacion> get cache => List<Notificacion>.unmodifiable(_cache);

  bool get tieneCache => _cache.isNotEmpty && _cacheUid == _uid;

  void limpiarCache() {
    _cache = const [];
    _cacheUid = null;
  }

  void _asegurarUsuario() {
    final uid = _uid;
    if (uid == null) {
      limpiarCache();
      contadorNoLeidas.value = 0;
      return;
    }
    if (_cacheUid != null && _cacheUid != uid) {
      limpiarCache();
      contadorNoLeidas.value = 0;
    }
  }

  /// Lista completa (sin usar cache). Preferir [sincronizar].
  Future<List<Notificacion>> listar({int limit = _limitFeed}) async {
    final uid = _uid;
    if (uid == null) return const [];

    try {
      final data = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .select()
          .eq('id_usuario', uid)
          .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String())
          .order('fecha_creacion', ascending: false)
          .limit(limit);

      return agruparHilosChat(
        (data as List)
            .cast<Map<String, dynamic>>()
            .map(Notificacion.fromMap)
            .toList(),
      );
    } catch (e) {
      debugPrint('⚠️ listar notificaciones usuario: $e');
      return const [];
    }
  }

  /// Un hilo de Match/Planes/Squad/conversación = una card (la más reciente).
  static List<Notificacion> agruparHilosChat(List<Notificacion> lista) {
    const hilos = {
      'match_mensaje',
      'plan_mencion',
      'squad_mensaje',
      'squad_mencion',
      'conversacion_mensaje',
    };
    final seen = <String>{};
    final out = <Notificacion>[];
    for (final n in lista) {
      if (hilos.contains(n.tipo) && (n.ctaIdRef ?? '').isNotEmpty) {
        final k = (n.tipo == 'squad_mensaje' || n.tipo == 'squad_mencion')
            ? 'squad:${n.ctaIdRef}'
            : '${n.tipo}:${n.ctaIdRef}';
        if (!seen.add(k)) continue;
      }
      out.add(n);
    }
    return out;
  }

  /// Sincroniza el feed: cache + solo nuevas + estado leída.
  ///
  /// [forzarCompleto] recarga las 50 más recientes (pull-to-refresh largo / error).
  Future<List<Notificacion>> sincronizar({bool forzarCompleto = false}) async {
    _asegurarUsuario();
    final uid = _uid;
    if (uid == null) return const [];

    if (forzarCompleto || !tieneCache) {
      final lista = agruparHilosChat(await listar());
      _cache = lista;
      _cacheUid = uid;
      sincronizarDesdeLista(_cache);
      return cache;
    }

    try {
      final desde = _cache
          .map((n) => n.fechaCreacion)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final resultados = await Future.wait<dynamic>([
        _fetchNuevas(uid, desde),
        _fetchIdsNoLeidas(uid),
      ]);

      final nuevas = resultados[0] as List<Notificacion>;
      final idsNoLeidas = resultados[1] as Set<String>;
      final ahora = DateTime.now().toUtc();

      final porId = <String, Notificacion>{for (final n in _cache) n.id: n};
      for (final n in nuevas) {
        porId[n.id] = n;
      }

      final fusionadas =
          porId.values
              .map((n) {
                final noLeidaEnServer = idsNoLeidas.contains(n.id);
                if (n.leida == !noLeidaEnServer) return n;
                if (noLeidaEnServer) {
                  return n.copyWith(leida: false);
                }
                return n.copyWith(
                  leida: true,
                  fechaLectura: n.fechaLectura ?? ahora,
                );
              })
              .where((n) {
                final exp = n.fechaExpiracion;
                if (exp == null) return true;
                return !exp.isBefore(ahora);
              })
              .toList()
            ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

      if (fusionadas.length > _limitFeed) {
        _cache = agruparHilosChat(fusionadas.sublist(0, _limitFeed));
      } else {
        _cache = agruparHilosChat(fusionadas);
      }
      _cacheUid = uid;
      // Contador desde server (incluye no leídas fuera del limit del feed).
      contadorNoLeidas.value = idsNoLeidas.length;
      _ultimoContadorAt = DateTime.now();
      return cache;
    } catch (e) {
      debugPrint('⚠️ sincronizar notificaciones: $e — fallback completo');
      final lista = agruparHilosChat(await listar());
      _cache = lista;
      _cacheUid = uid;
      sincronizarDesdeLista(_cache);
      return cache;
    }
  }

  Future<List<Notificacion>> _fetchNuevas(String uid, DateTime desde) async {
    final data = await ServicioSupabase().cliente
        .from('notificaciones_usuarios')
        .select()
        .eq('id_usuario', uid)
        .gt('fecha_creacion', desde.toUtc().toIso8601String())
        .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String())
        .order('fecha_creacion', ascending: false)
        .limit(_limitFeed);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Notificacion.fromMap)
        .toList();
  }

  Future<Set<String>> _fetchIdsNoLeidas(String uid) async {
    final rows = await ServicioSupabase().cliente
        .from('notificaciones_usuarios')
        .select('id')
        .eq('id_usuario', uid)
        .eq('leida', false)
        .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String());
    return {
      for (final r in (rows as List))
        if (r is Map && r['id'] != null) r['id'].toString(),
    };
  }

  /// Sincroniza el badge con una lista ya cargada.
  void sincronizarDesdeLista(List<Notificacion> lista) {
    if (_cacheUid == _uid || _cacheUid == null) {
      _cache = List<Notificacion>.from(lista);
      _cacheUid = _uid;
    }
    contadorNoLeidas.value = lista.where((n) => !n.leida).length;
  }

  /// Refresca el contador de no leídas (consulta puntual liviana).
  /// [forzar] ignora el debounce (entrar a notificaciones / pull).
  Future<int> refrescarContador({bool forzar = false}) async {
    final uid = _uid;
    if (uid == null) {
      contadorNoLeidas.value = 0;
      return 0;
    }
    if (!forzar &&
        _ultimoContadorAt != null &&
        DateTime.now().difference(_ultimoContadorAt!) < _ttlContador) {
      return contadorNoLeidas.value;
    }
    try {
      final ids = await _fetchIdsNoLeidas(uid);
      contadorNoLeidas.value = ids.length;
      _ultimoContadorAt = DateTime.now();
      // Alinea leídas del cache sin traer el feed completo.
      if (tieneCache) {
        final ahora = DateTime.now().toUtc();
        _cache = _cache.map((n) {
          final noLeida = ids.contains(n.id);
          if (n.leida == !noLeida) return n;
          if (noLeida) return n.copyWith(leida: false);
          return n.copyWith(leida: true, fechaLectura: n.fechaLectura ?? ahora);
        }).toList();
      }
      return ids.length;
    } catch (e) {
      debugPrint('⚠️ refrescarContador usuario: $e');
      return contadorNoLeidas.value;
    }
  }

  /// Marca una notificación específica como leída (idempotente).
  Future<bool> marcarLeida(String idNotif) async {
    final uid = _uid;
    if (uid == null) return false;

    _aplicarLeidaEnCache(idNotif);
    try {
      final res = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .update({
            'leida': true,
            'fecha_lectura': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', idNotif)
          .eq('id_usuario', uid)
          .select('id')
          .maybeSingle();
      if (res == null) {
        // Ya estaba leída en server o no existe: mantener cache local.
        debugPrint('ℹ️ marcarLeida: sin filas (id=$idNotif)');
      }
      _ultimoContadorAt = null;
      unawaited(refrescarContador(forzar: true));
      return true;
    } catch (e) {
      debugPrint('⚠️ marcarLeida usuario: $e');
      return false;
    }
  }

  /// Busca una notificación puntual. Se usa al abrir una push del sistema:
  /// si existe la in-app, reutilizamos su payload completo para navegar.
  Future<Notificacion?> obtenerPorId(String idNotif) async {
    final uid = _uid;
    final id = idNotif.trim();
    if (uid == null || id.isEmpty) return null;

    final cacheHit = _cache.where((n) => n.id == id).toList();
    if (cacheHit.isNotEmpty) return cacheHit.first;

    try {
      final row = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .select()
          .eq('id', id)
          .eq('id_usuario', uid)
          .maybeSingle();
      if (row == null) return null;
      final notif = Notificacion.fromMap(Map<String, dynamic>.from(row as Map));
      final porId = <String, Notificacion>{
        for (final n in _cache) n.id: n,
        notif.id: notif,
      };
      _cache = porId.values.toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      _cacheUid = uid;
      sincronizarDesdeLista(_cache);
      return notif;
    } catch (e) {
      debugPrint('⚠️ obtener notif usuario: $e');
      return null;
    }
  }

  void _aplicarLeidaEnCache(String idNotif) {
    final idx = _cache.indexWhere((n) => n.id == idNotif);
    if (idx < 0) {
      if (contadorNoLeidas.value > 0) {
        contadorNoLeidas.value = contadorNoLeidas.value - 1;
      }
      return;
    }
    final n = _cache[idx];
    if (n.leida) return;
    final copia = List<Notificacion>.from(_cache);
    copia[idx] = n.copyWith(leida: true, fechaLectura: DateTime.now().toUtc());
    _cache = copia;
    sincronizarDesdeLista(_cache);
  }

  /// Marca todas las no-leídas del usuario como leídas.
  Future<bool> marcarTodasLeidas() async {
    final uid = _uid;
    if (uid == null) return false;
    _cache = _cache
        .map(
          (n) => n.leida
              ? n
              : n.copyWith(leida: true, fechaLectura: DateTime.now().toUtc()),
        )
        .toList();
    contadorNoLeidas.value = 0;
    try {
      await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .update({
            'leida': true,
            'fecha_lectura': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_usuario', uid)
          .eq('leida', false);
      return true;
    } catch (e) {
      debugPrint('⚠️ marcarTodasLeidas usuario: $e');
      return false;
    }
  }

  /// Borra una notificación (deja al usuario "limpiar" su feed).
  Future<bool> borrar(String idNotif) async {
    Notificacion? previa;
    for (final n in _cache) {
      if (n.id == idNotif) {
        previa = n;
        break;
      }
    }
    _cache = _cache.where((n) => n.id != idNotif).toList();
    if (previa != null && !previa.leida && contadorNoLeidas.value > 0) {
      contadorNoLeidas.value = contadorNoLeidas.value - 1;
    }
    try {
      await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .delete()
          .eq('id', idNotif);
      return true;
    } catch (e) {
      debugPrint('⚠️ borrar notif usuario: $e');
      return false;
    }
  }

  /// Conteos de no leídas por destino del hub Social.
  Future<ConteosNovedadesSocial> conteosDestinosSocial() async {
    final uid = _uid;
    if (uid == null) return const ConteosNovedadesSocial();
    try {
      final data = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .select('tipo')
          .eq('id_usuario', uid)
          .eq('leida', false)
          .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String());
      var explora = 0;
      var planes = 0;
      var match = 0;
      var amigos = 0;
      for (final row in data as List) {
        final tipo = (row as Map)['tipo']?.toString() ?? '';
        switch (ConteosNovedadesSocial.destinoDe(tipo)) {
          case 'explora':
            explora++;
          case 'planes':
            planes++;
          case 'match':
            match++;
          case 'amigos':
            amigos++;
        }
      }
      return ConteosNovedadesSocial(
        explora: explora,
        planes: planes,
        match: match,
        amigos: amigos,
      );
    } catch (e) {
      debugPrint('⚠️ conteosDestinosSocial: $e');
      return const ConteosNovedadesSocial();
    }
  }
}

class ConteosNovedadesSocial {
  const ConteosNovedadesSocial({
    this.explora = 0,
    this.planes = 0,
    this.match = 0,
    this.amigos = 0,
  });

  final int explora;
  final int planes;
  final int match;
  final int amigos;

  static String destinoDe(String tipo) {
    if (tipo.startsWith('rompehielo_') || tipo.startsWith('ranking_top')) {
      return 'explora';
    }
    if (tipo.startsWith('plan_')) return 'planes';
    if (tipo.startsWith('match_')) return 'match';
    if (tipo == 'solicitud_amistad' ||
        tipo == 'amistad_aceptada' ||
        tipo == 'solicitud_squad' ||
        tipo == 'squad_aceptada') {
      return 'amigos';
    }
    return '';
  }
}
