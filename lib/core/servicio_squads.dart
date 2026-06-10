library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social.dart';
import 'comprimir_imagen_storage.dart';
import 'supabase_client.dart';

/// Servicio de squads (grupos_salidas). Usa los RPCs `squad_*` del backend.
class ServicioSquads {
  static final ServicioSquads _instancia = ServicioSquads._interno();
  factory ServicioSquads() => _instancia;
  ServicioSquads._interno();

  static const _bucketPortadas = 'squad-banners';

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  /// Squads donde soy miembro aceptado.
  Future<List<SquadResumen>> misSquads() async {
    if (_uid == null) return const [];
    try {
      final res = await ServicioSupabase().cliente.rpc('squad_listar_mios');
      if (res is List) {
        return res
            .map((e) => SquadResumen.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ squad_listar_mios: $e');
      return const [];
    }
  }

  /// Invitaciones a squads pendientes para mí.
  Future<List<SquadResumen>> invitaciones() async {
    if (_uid == null) return const [];
    try {
      final res = await ServicioSupabase().cliente.rpc('squad_listar_invitaciones');
      if (res is List) {
        return res
            .map((e) => SquadResumen.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ squad_listar_invitaciones: $e');
      return const [];
    }
  }

  /// Detalle de un squad con miembros y mi relación.
  Future<SquadDetalle?> detalle(String idGrupo) async {
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('squad_detalle', params: {'p_grupo': idGrupo});
      if (res is Map) return SquadDetalle.fromMap(Map<String, dynamic>.from(res));
      return null;
    } catch (e) {
      debugPrint('⚠️ squad_detalle: $e');
      return null;
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
        return const UsernameSquadCheck(disponible: false, motivo: 'rate_limit');
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
      final res = await ServicioSupabase().cliente.rpc('squad_crear', params: {
        'p_nombre': nombre,
        'p_username': username,
        'p_descripcion': descripcion,
        'p_url_portada': urlPortada,
        'p_es_publico': esPublico,
        'p_vibe': vibe,
      });
      return res?.toString();
    } catch (e) {
      debugPrint('⚠️ squad_crear: $e');
      return null;
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
      await ServicioSupabase().cliente.rpc('squad_editar', params: {
        'p_grupo': idGrupo,
        'p_nombre': nombre,
        'p_descripcion': descripcion,
        'p_url_portada': urlPortada,
        'p_es_publico': esPublico,
        'p_estado': estado,
        'p_vibe': vibe,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_editar: $e');
      return false;
    }
  }

  Future<bool> eliminar(String idGrupo) async {
    try {
      await ServicioSupabase()
          .cliente
          .rpc('squad_eliminar', params: {'p_grupo': idGrupo});
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_eliminar: $e');
      return false;
    }
  }

  Future<bool> invitar(String idGrupo, String idUsuario) async {
    try {
      await ServicioSupabase().cliente.rpc('squad_invitar', params: {
        'p_grupo': idGrupo,
        'p_usuario': idUsuario,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_invitar: $e');
      return false;
    }
  }

  Future<bool> responderInvitacion(String idGrupo, {required bool aceptar}) async {
    try {
      await ServicioSupabase().cliente.rpc('squad_responder_invitacion', params: {
        'p_grupo': idGrupo,
        'p_aceptar': aceptar,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_responder_invitacion: $e');
      return false;
    }
  }

  Future<bool> salir(String idGrupo) async {
    try {
      await ServicioSupabase()
          .cliente
          .rpc('squad_salir', params: {'p_grupo': idGrupo});
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_salir: $e');
      return false;
    }
  }

  Future<bool> expulsar(String idGrupo, String idUsuario) async {
    try {
      await ServicioSupabase().cliente.rpc('squad_expulsar', params: {
        'p_grupo': idGrupo,
        'p_usuario': idUsuario,
      });
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
      final res = await ServicioSupabase()
          .cliente
          .rpc('buscar_squads', params: {'p_query': query});
      if (res is List) {
        return res
            .map((e) =>
                SquadBusqueda.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ buscar_squads: $e');
      return const [];
    }
  }

  /// Squads públicos con al menos un miembro en la ciudad indicada.
  Future<ExplorarSquadsPagina> explorarCiudad({
    required String ciudad,
    String? provincia,
    int offset = 0,
    int limit = 40,
  }) async {
    if (_uid == null || ciudad.trim().isEmpty) {
      return const ExplorarSquadsPagina();
    }
    try {
      final res = await ServicioSupabase().cliente.rpc(
        'explorar_squads_ciudad',
        params: {
          'p_ciudad': ciudad.trim(),
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
      final lista = itemsRaw is List
          ? itemsRaw
              .map((e) =>
                  SquadExplorarItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <SquadExplorarItem>[];
      return ExplorarSquadsPagina(
        items: lista,
        hayMas: map['hay_mas'] == true,
      );
    } catch (e) {
      debugPrint('⚠️ explorar_squads_ciudad: $e');
      return ExplorarSquadsPagina(
        error: 'No se pudo cargar squads ($e)',
      );
    }
  }

  /// Pide unirse a un squad público. Devuelve el estado resultante
  /// ('pendiente' | 'aceptado') o null si falló.
  Future<String?> solicitarUnirse(String idGrupo) async {
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('squad_solicitar_unirse', params: {'p_grupo': idGrupo});
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
      final res = await ServicioSupabase()
          .cliente
          .rpc('squad_listar_pendientes', params: {'p_grupo': idGrupo});
      if (res is List) {
        return res
            .map((e) => MiembroSquad.fromMap(Map<String, dynamic>.from(e as Map)))
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
  Future<bool> aprobarMiembro(String idGrupo, String idUsuario,
      {required bool aceptar}) async {
    try {
      await ServicioSupabase().cliente.rpc('squad_aprobar_miembro', params: {
        'p_grupo': idGrupo,
        'p_usuario': idUsuario,
        'p_aceptar': aceptar,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ squad_aprobar_miembro: $e');
      return false;
    }
  }

  /// Sube la portada al bucket. Devuelve el **path** en storage (para guardar en DB).
  Future<String?> subirPortada(String idGrupo, Uint8List bytes,
      {String ext = 'jpg'}) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      // Path fijo .jpg para que upsert y la URL pública no cambien de extensión.
      final path = '$uid/$idGrupo.jpg';
      await ServicioSupabase().cliente.storage.from(_bucketPortadas).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentTypeDesdeExtension(ext == 'webp' ? 'jpg' : ext),
            ),
          );
      return path;
    } catch (e) {
      debugPrint('⚠️ subirPortada squad: $e');
      return null;
    }
  }
}
