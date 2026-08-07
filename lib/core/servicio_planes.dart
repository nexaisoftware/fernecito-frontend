/// Planes (comunidad) — hub de juntadas en locales + chat grupal realtime.
///
/// Backend: RPCs `planes_*` (JWT + rate limit). Chat: SELECT historial en
/// `planes_mensajes` (RLS miembros) + `postgres_changes`. Creación asistida
/// vía edge `asistente_plan_comunidad` (no escribe DB; el alta es `planes_crear`).
///
/// Independiente de Fernecito Match.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class PlanComunidad {
  const PlanComunidad({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.ciudad,
    required this.fechaInicio,
    required this.modoLista,
    required this.cupoUsados,
    required this.idLocal,
    required this.nombreLocal,
    required this.idOrganizador,
    required this.nombreOrganizador,
    required this.tipoOrganizador,
    this.provincia,
    this.fechaFin,
    this.cupoMax,
    this.idSquad,
    this.nombreSquad,
    this.fotoLocal,
    this.fotoOrganizador,
    this.miEstado = 'ninguno',
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String ciudad;
  final String? provincia;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String modoLista; // auto | manual
  final int? cupoMax;
  final int cupoUsados;
  final String idLocal;
  final String nombreLocal;
  final String? fotoLocal;
  final String idOrganizador;
  final String nombreOrganizador;
  final String? fotoOrganizador;
  final String tipoOrganizador; // usuario | squad
  final String? idSquad;
  final String? nombreSquad;
  final String miEstado; // ninguno | pendiente | aceptado | …

  factory PlanComunidad.fromMap(Map<String, dynamic> m) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    int? n(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

    return PlanComunidad(
      id: m['id']?.toString() ?? '',
      titulo: m['titulo']?.toString() ?? '',
      descripcion: m['descripcion']?.toString() ?? '',
      ciudad: m['ciudad']?.toString() ?? '',
      provincia: m['provincia']?.toString(),
      fechaInicio: dt(m['fecha_inicio']) ?? DateTime.now(),
      fechaFin: dt(m['fecha_fin']),
      modoLista: m['modo_lista']?.toString() ?? 'auto',
      cupoMax: n(m['cupo_max']),
      cupoUsados: n(m['cupo_usados']) ?? 0,
      idLocal: m['id_local']?.toString() ?? '',
      nombreLocal: m['nombre_local']?.toString() ?? 'Local',
      fotoLocal: m['foto_local']?.toString(),
      idOrganizador: m['id_organizador']?.toString() ?? '',
      nombreOrganizador: m['nombre_organizador']?.toString() ?? 'Alguien',
      fotoOrganizador: m['foto_organizador']?.toString(),
      tipoOrganizador: m['tipo_organizador']?.toString() ?? 'usuario',
      idSquad: m['id_squad']?.toString(),
      nombreSquad: m['nombre_squad']?.toString(),
      miEstado: m['mi_estado']?.toString() ?? 'ninguno',
    );
  }
}

class PlanMensaje {
  const PlanMensaje({
    required this.id,
    required this.idAutor,
    required this.cuerpo,
    required this.creadoEn,
  });

  final int id;
  final String idAutor;
  final String cuerpo;
  final DateTime creadoEn;

  factory PlanMensaje.fromMap(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    return PlanMensaje(
      id: id,
      idAutor: m['id_autor']?.toString() ?? '',
      cuerpo: m['cuerpo']?.toString() ?? '',
      creadoEn: DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class ServicioPlanes {
  SupabaseClient get _c => ServicioSupabase().cliente;
  String? get miUid => _c.auth.currentUser?.id;

  Future<List<PlanComunidad>> hub({
    Set<String> ciudades = const {},
    String? provincia,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _c.rpc(
        'planes_hub',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (res is! Map) return const [];
      final items = res['items'];
      if (items is! List) return const [];
      return items
          .map((e) => PlanComunidad.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('⚠️ planes_hub: $e');
      return const [];
    }
  }

  Future<String?> crear({
    required String titulo,
    required String descripcion,
    required String idLocal,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    String modoLista = 'auto',
    int? cupoMax,
    String tipoOrganizador = 'usuario',
    String? idSquad,
  }) async {
    final res = await _c.rpc(
      'planes_crear',
      params: {
        'p_titulo': titulo,
        'p_descripcion': descripcion,
        'p_id_local': idLocal,
        'p_fecha_inicio': fechaInicio.toUtc().toIso8601String(),
        'p_fecha_fin': fechaFin?.toUtc().toIso8601String(),
        'p_modo_lista': modoLista,
        'p_cupo_max': cupoMax,
        'p_tipo_organizador': tipoOrganizador,
        if (idSquad != null) 'p_id_squad': idSquad,
      },
    );
    if (res is Map && res['ok'] == true) return res['id']?.toString();
    return null;
  }

  Future<String?> solicitarUnirse(String idPlan) async {
    final res = await _c.rpc(
      'planes_solicitar_unirse',
      params: {'p_id_plan': idPlan},
    );
    if (res is Map) return res['estado']?.toString();
    return null;
  }

  Future<bool> gestionarMiembro({
    required String idPlan,
    required String idUsuario,
    required String accion, // aceptar | rechazar | expulsar
  }) async {
    final res = await _c.rpc(
      'planes_gestionar_miembro',
      params: {
        'p_id_plan': idPlan,
        'p_id_usuario': idUsuario,
        'p_accion': accion,
      },
    );
    return res is Map && res['ok'] == true;
  }

  Future<bool> cancelar(String idPlan) async {
    final res = await _c.rpc('planes_cancelar', params: {'p_id_plan': idPlan});
    return res is Map && res['ok'] == true;
  }

  Future<List<PlanMensaje>> historial(String idPlan) async {
    final rows = await _c
        .from('planes_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_plan', idPlan)
        .order('id', ascending: true)
        .limit(300);
    return (rows as List)
        .map((e) => PlanMensaje.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int?> enviarMensaje(String idPlan, String cuerpo) async {
    final res = await _c.rpc(
      'planes_enviar_mensaje',
      params: {'p_id_plan': idPlan, 'p_cuerpo': cuerpo},
    );
    if (res is Map && res['id'] != null) {
      final id = res['id'];
      return id is num ? id.toInt() : int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> marcarLeido(String idPlan) async {
    try {
      await _c.rpc('planes_marcar_leido', params: {'p_id_plan': idPlan});
    } catch (e) {
      debugPrint('⚠️ planes_marcar_leido: $e');
    }
  }

  RealtimeChannel suscribirMensajes(
    String idPlan,
    void Function(PlanMensaje) onMensaje,
  ) {
    return _c
        .channel('plan_chat_$idPlan')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'planes_mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_plan',
            value: idPlan,
          ),
          callback: (payload) {
            onMensaje(
              PlanMensaje.fromMap(Map<String, dynamic>.from(payload.newRecord)),
            );
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⚠️ planes realtime: $status $error');
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
    await _c.removeChannel(canal);
  }

  /// Orquesta el chatbot de creación (edge). No persiste.
  Future<Map<String, dynamic>?> asistenteSiguientePaso(
    Map<String, dynamic> borrador,
  ) async {
    try {
      final res = await _c.functions.invoke(
        'asistente_plan_comunidad',
        body: {'intent': 'siguiente_paso', 'borrador': borrador},
      );
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (e) {
      debugPrint('⚠️ asistente_plan_comunidad: $e');
      return null;
    }
  }
}
