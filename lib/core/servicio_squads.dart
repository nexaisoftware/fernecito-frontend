library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social.dart';
import 'cache_memoria.dart';
import 'chat_paginacion.dart';
import 'comprimir_imagen_storage.dart';
import 'supabase_client.dart';

class SquadMensaje {
  const SquadMensaje({
    required this.id,
    required this.cuerpo,
    required this.creadoEn,
    this.idAutor,
  });

  final int id;
  final String? idAutor;
  final String cuerpo;
  final DateTime creadoEn;

  factory SquadMensaje.fromMap(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    return SquadMensaje(
      id: id,
      idAutor: m['id_autor']?.toString(),
      cuerpo: m['cuerpo']?.toString() ?? '',
      creadoEn:
          DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Servicio de squads (grupos_salidas). Usa los RPCs `squad_*` del backend.
class ServicioSquads {
  static final ServicioSquads _instancia = ServicioSquads._interno();
  factory ServicioSquads() => _instancia;
  ServicioSquads._interno();

  static const _bucketPortadas = 'squad-banners';
  static const _ttlSuave = Duration(seconds: 90);

  final _cacheMios = CacheMemoria<List<SquadResumen>>();
  final _cacheInvs = CacheMemoria<List<SquadResumen>>();
  final _cacheDetalle = CachePorClave<SquadDetalle>();

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  bool get tieneCacheListas => _cacheMios.tiene(_uid) && _cacheInvs.tiene(_uid);

  List<SquadResumen>? get misSquadsCache =>
      _cacheMios.tiene(_uid) ? _cacheMios.data : null;

  List<SquadResumen>? get invitacionesCache =>
      _cacheInvs.tiene(_uid) ? _cacheInvs.data : null;

  void invalidarListas() {
    _cacheMios.clear();
    _cacheInvs.clear();
  }

  void invalidarDetalle(String idGrupo) => _cacheDetalle.invalidate(idGrupo);

  /// Squads donde soy miembro aceptado.
  Future<List<SquadResumen>> misSquads({bool forzarCompleto = false}) async {
    final uid = _uid;
    if (uid == null) {
      _cacheMios.clear();
      return const [];
    }
    if (!forzarCompleto && _cacheMios.fresco(uid, _ttlSuave)) {
      return _cacheMios.data!;
    }
    try {
      final res = await ServicioSupabase().cliente.rpc('squad_listar_mios');
      final list = res is List
          ? res
                .map(
                  (e) =>
                      SquadResumen.fromMap(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const <SquadResumen>[];
      _cacheMios.set(uid, list);
      return list;
    } catch (e) {
      debugPrint('⚠️ squad_listar_mios: $e');
      return _cacheMios.tiene(uid) ? _cacheMios.data! : const [];
    }
  }

  /// Invitaciones recibidas + solicitudes enviadas pendientes para mí.
  Future<List<SquadResumen>> invitaciones({bool forzarCompleto = false}) async {
    final uid = _uid;
    if (uid == null) {
      _cacheInvs.clear();
      return const [];
    }
    if (!forzarCompleto && _cacheInvs.fresco(uid, _ttlSuave)) {
      return _cacheInvs.data!;
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_listar_pendientes_mios',
      );
      final list = res is List
          ? res
                .map(
                  (e) =>
                      SquadResumen.fromMap(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const <SquadResumen>[];
      _cacheInvs.set(uid, list);
      return list;
    } catch (e) {
      debugPrint('⚠️ squad_listar_invitaciones: $e');
      return _cacheInvs.tiene(uid) ? _cacheInvs.data! : const [];
    }
  }

  /// Detalle de un squad con miembros y mi relación.
  Future<SquadDetalle?> detalle(
    String idGrupo, {
    bool forzarCompleto = false,
  }) async {
    if (!forzarCompleto && _cacheDetalle.fresco(idGrupo, _ttlSuave)) {
      return _cacheDetalle.get(idGrupo);
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_detalle',
        params: {'p_grupo': idGrupo},
      );
      if (res is Map) {
        final d = SquadDetalle.fromMap(Map<String, dynamic>.from(res));
        _cacheDetalle.set(idGrupo, d);
        return d;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ squad_detalle: $e');
      return _cacheDetalle.get(idGrupo);
    }
  }

  /// Chequea disponibilidad global de un @username de squad.
  /// Devuelve (disponible, normalizado, motivo). motivo ∈
  /// 'formato_invalido' | 'tomado_squad' | 'tomado_usuario' | null.
  Future<UsernameSquadCheck> chequearUsername(String username) async {
    if (_uid == null) {
      return const UsernameSquadCheck(disponible: false, motivo: 'no_auth');
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_username_disponible',
        params: {'p_username': username},
      );
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        return UsernameSquadCheck(
          disponible: m['disponible'] == true,
          normalizado: m['normalizado'] as String?,
          motivo: m['motivo'] as String?,
        );
      }
      return const UsernameSquadCheck(disponible: false, motivo: 'error');
    } catch (e) {
      debugPrint('⚠️ squad_username_disponible: $e');
      final msg = e.toString();
      if (msg.contains('rate_limit_exceeded')) {
        return const UsernameSquadCheck(
          disponible: false,
          motivo: 'rate_limit',
        );
      }
      return const UsernameSquadCheck(disponible: false, motivo: 'error');
    }
  }

  /// Crea un squad y devuelve su id_grupo (o null si falló).
  Future<String?> crear({
    required String nombre,
    required String username,
    String? descripcion,
    String? urlPortada,
    bool esPublico = false,
    String? vibe,
  }) async {
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_crear',
        params: {
          'p_nombre': nombre,
          'p_username': username,
          'p_descripcion': descripcion,
          'p_url_portada': urlPortada,
          'p_es_publico': esPublico,
          'p_vibe': vibe,
        },
      );
      invalidarListas();
      final id = res?.toString();
      if (id == null || id.isEmpty || id == 'null') return null;
      return id;
    } catch (e) {
      debugPrint('⚠️ squad_crear: $e');
      rethrow;
    }
  }

  Future<bool> editar(
    String idGrupo, {
    String? nombre,
    String? descripcion,
    String? urlPortada,
    bool? esPublico,
    String? estado,
    String? vibe,
  }) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_editar',
        params: {
          'p_grupo': idGrupo,
          'p_nombre': nombre,
          'p_descripcion': descripcion,
          'p_url_portada': urlPortada,
          'p_es_publico': esPublico,
          'p_estado': estado,
          'p_vibe': vibe,
        },
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_editar: $e');
      return false;
    }
  }

  /// Ubicación propia del squad (cualquier miembro puede editarla).
  Future<bool> setUbicacion(
    String idGrupo, {
    required String ciudad,
    String? provincia,
  }) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_set_ubicacion',
        params: {
          'p_grupo': idGrupo,
          'p_ciudad': ciudad,
          'p_provincia': provincia,
        },
      );
      invalidarDetalle(idGrupo);
      invalidarListas();
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_set_ubicacion: $e');
      return false;
    }
  }

  Future<bool> eliminar(String idGrupo) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_eliminar',
        params: {'p_grupo': idGrupo},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_eliminar: $e');
      return false;
    }
  }

  Future<bool> invitar(String idGrupo, String idUsuario) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_invitar',
        params: {'p_grupo': idGrupo, 'p_usuario': idUsuario},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_invitar: $e');
      return false;
    }
  }

  Future<bool> responderInvitacion(
    String idGrupo, {
    required bool aceptar,
  }) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_responder_invitacion',
        params: {'p_grupo': idGrupo, 'p_aceptar': aceptar},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_responder_invitacion: $e');
      return false;
    }
  }

  Future<bool> salir(String idGrupo) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_salir',
        params: {'p_grupo': idGrupo},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_salir: $e');
      return false;
    }
  }

  Future<bool> expulsar(String idGrupo, String idUsuario) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_expulsar',
        params: {'p_grupo': idGrupo, 'p_usuario': idUsuario},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_expulsar: $e');
      return false;
    }
  }

  /// Busca squads públicos por nombre. Devuelve `mi_estado` por cada uno.
  Future<List<SquadBusqueda>> buscar(String query) async {
    if (_uid == null) return const [];
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'buscar_squads',
        params: {'p_query': query},
      );
      if (res is List) {
        return res
            .map(
              (e) => SquadBusqueda.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ buscar_squads: $e');
      return const [];
    }
  }

  /// Squads públicos de las ciudades indicadas (usa la ciudad propia del squad).
  Future<ExplorarSquadsPagina> explorarCiudades({
    required Set<String> ciudades,
    String? provincia,
    int offset = 0,
    int limit = 40,
  }) async {
    final ciudadesLista = ciudades
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (_uid == null || ciudadesLista.isEmpty) {
      return const ExplorarSquadsPagina();
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'explorar_squads_ciudad',
        params: {
          'p_ciudad': ciudadesLista.first,
          'p_ciudades': ciudadesLista,
          'p_provincia': (provincia == null || provincia.trim().isEmpty)
              ? null
              : provincia.trim(),
          'p_offset': offset,
          'p_limit': limit,
        },
      );
      if (res is! Map) return const ExplorarSquadsPagina();
      final map = Map<String, dynamic>.from(res);
      final itemsRaw = map['items'];
      final squads = itemsRaw is List
          ? itemsRaw
                .map(
                  (e) => SquadExplorarItem.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : <SquadExplorarItem>[];
      return ExplorarSquadsPagina(
        items: squads,
        hayMas: map['hay_mas'] == true,
      );
    } catch (e) {
      debugPrint('⚠️ explorar_squads_ciudad: $e');
      return ExplorarSquadsPagina(error: 'No se pudo cargar squads ($e)');
    }
  }

  /// Pide unirse a un squad público. Devuelve el estado resultante
  /// ('pendiente' | 'aceptado') o null si falló.
  Future<String?> solicitarUnirse(String idGrupo) async {
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_solicitar_unirse',
        params: {'p_grupo': idGrupo},
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      if (res is Map) return res['estado']?.toString();
      return 'pendiente';
    } catch (e) {
      debugPrint('⚠️ squad_solicitar_unirse: $e');
      return null;
    }
  }

  /// Pendientes del squad (invitaciones enviadas + pedidos de unión).
  /// Cada ítem trae [MiembroSquad.origenPendiente]: 'invitacion' | 'solicitud'.
  Future<List<MiembroSquad>> listarPendientes(String idGrupo) async {
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'squad_listar_pendientes',
        params: {'p_grupo': idGrupo},
      );
      if (res is List) {
        return res
            .map(
              (e) => MiembroSquad.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ squad_listar_pendientes: $e');
      return const [];
    }
  }

  /// Líder/admin aprueba o rechaza un pedido de unión (origen 'solicitud').
  /// No aplica a invitaciones enviadas: esas las responde el invitado.
  Future<bool> aprobarMiembro(
    String idGrupo,
    String idUsuario, {
    required bool aceptar,
  }) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squad_aprobar_miembro',
        params: {
          'p_grupo': idGrupo,
          'p_usuario': idUsuario,
          'p_aceptar': aceptar,
        },
      );
      invalidarListas();
      invalidarDetalle(idGrupo);
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_aprobar_miembro: $e');
      return false;
    }
  }

  /// Sube la portada al bucket. Devuelve el **path** en storage (para guardar en DB).
  Future<String?> subirPortada(
    String idGrupo,
    Uint8List bytes, {
    String ext = 'jpg',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      // Path fijo .jpg para que upsert y la URL pública no cambien de extensión.
      final path = '$uid/$idGrupo.jpg';
      await ServicioSupabase().cliente.storage
          .from(_bucketPortadas)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentTypeDesdeExtension(
                ext == 'webp' ? 'jpg' : ext,
              ),
            ),
          );
      return path;
    } catch (e) {
      debugPrint('⚠️ subirPortada squad: $e');
      return null;
    }
  }

  Future<PaginaChatMensajes<SquadMensaje>> historialChat(String idGrupo) async {
    final limite = kChatMensajesPorPagina;
    final rows = await ServicioSupabase().cliente
        .from('squads_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_grupo', idGrupo)
        .order('id', ascending: false)
        .limit(limite + 1);
    final parsed = (rows as List)
        .map((e) => SquadMensaje.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return armarPaginaAsc(parsed, limite);
  }

  Future<PaginaChatMensajes<SquadMensaje>> historialChatAntesDe(
    String idGrupo,
    int antesDeId,
  ) async {
    final limite = kChatMensajesPorPagina;
    final rows = await ServicioSupabase().cliente
        .from('squads_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_grupo', idGrupo)
        .lt('id', antesDeId)
        .order('id', ascending: false)
        .limit(limite + 1);
    final parsed = (rows as List)
        .map((e) => SquadMensaje.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return armarPaginaAsc(parsed, limite);
  }

  Future<int?> enviarMensajeChat(String idGrupo, String cuerpo) async {
    final res = await ServicioSupabase().cliente.rpc(
      'squads_enviar_mensaje',
      params: {'p_id_grupo': idGrupo, 'p_cuerpo': cuerpo},
    );
    if (res is Map && res['id'] != null) {
      final id = res['id'];
      return id is num ? id.toInt() : int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> marcarChatLeido(String idGrupo) async {
    try {
      await ServicioSupabase().cliente.rpc(
        'squads_marcar_leido',
        params: {'p_id_grupo': idGrupo},
      );
    } catch (e) {
      debugPrint('⚠️ squads_marcar_leido: $e');
    }
  }

  RealtimeChannel suscribirChat(
    String idGrupo,
    void Function(SquadMensaje) onMensaje,
  ) {
    return ServicioSupabase().cliente
        .channel('squad_chat_$idGrupo')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'squads_mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_grupo',
            value: idGrupo,
          ),
          callback: (payload) {
            onMensaje(
              SquadMensaje.fromMap(
                Map<String, dynamic>.from(payload.newRecord),
              ),
            );
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⚠️ squads realtime: $status $error');
            unawaited(
              Supabase.instance.client.auth.refreshSession().then(
                (_) {},
                onError: (_) {},
              ),
            );
          }
        });
  }

  Future<void> cerrarCanal(RealtimeChannel canal) async {
    await ServicioSupabase().cliente.removeChannel(canal);
  }

  String mensajeErrorChat(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('no_auth') || msg.contains('jwt')) {
      return 'Tu sesión expiró. Cerrá sesión y volvé a entrar.';
    }
    if (msg.contains('rate')) {
      return 'Estás mandando muy seguido. Esperá un toque.';
    }
    if (msg.contains('no_participante')) {
      return 'Ya no formás parte de este squad.';
    }
    if (msg.contains('mensaje_invalido')) {
      return 'El mensaje tiene que tener entre 1 y 700 caracteres.';
    }
    return 'No pude enviar el mensaje. Probá de nuevo.';
  }
}
