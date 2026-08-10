/// Planes (comunidad) — cartelera de juntadas en locales + chat grupal realtime.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'comprimir_imagen_storage.dart';
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
    this.expiraEn,
    this.cupoMax,
    this.idSquad,
    this.nombreSquad,
    this.fotoLocal,
    this.fotoOrganizador,
    this.miEstado = 'ninguno',
    this.estado = 'abierto',
    this.creadorTipo = 'usuario',
    this.idCreadorLocal,
    this.portadaPath,
    this.colorHex = '#C084FC',
    this.permiteSquads = true,
    this.edadMinima,
    this.contactoAnfitrion,
    this.beneficioLocal,
    this.beneficioEstado = 'ninguno',
    this.beneficioContraoferta,
    this.pedidoBeneficio,
    this.pedidoVotos = 0,
    this.soyModerador = false,
    this.esPlanLocal = false,
    this.personasAceptadas = 0,
    this.ingresoAbierto = true,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String ciudad;
  final String? provincia;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final DateTime? expiraEn;
  final String modoLista; // auto | manual
  final int? cupoMax;
  final int cupoUsados;
  final String idLocal;
  final String nombreLocal;
  final String? fotoLocal;
  final String idOrganizador;
  final String? idCreadorLocal;
  final String nombreOrganizador;
  final String? fotoOrganizador;
  final String tipoOrganizador; // usuario | squad | local
  final String creadorTipo; // usuario | local
  final String? idSquad;
  final String? nombreSquad;
  final String miEstado; // ninguno | pendiente | aceptado | local | cancelado
  final String estado; // abierto | cancelado | finalizado | eliminado
  final String? portadaPath;
  final String colorHex;
  final bool permiteSquads;
  final int? edadMinima;
  final String? contactoAnfitrion;
  final String? beneficioLocal;
  final String beneficioEstado;
  final String? beneficioContraoferta;
  final String? pedidoBeneficio;
  final int pedidoVotos;
  final bool soyModerador;
  final bool esPlanLocal;
  final int personasAceptadas;
  final bool ingresoAbierto;

  String? get fotoLocalUrl => ServicioSupabase().urlAvatar(fotoLocal);
  String? get fotoOrganizadorUrl =>
      ServicioSupabase().urlAvatar(fotoOrganizador);
  String? get portadaUrl => ServicioSupabase().urlPortadaPlan(portadaPath);

  bool get soyMiembro => miEstado == 'aceptado' || miEstado == 'local';
  bool get soyPendiente => miEstado == 'pendiente';
  bool get estaAbierto => estado == 'abierto';
  bool get estaFinalizado =>
      estado == 'cancelado' ||
      estado == 'finalizado' ||
      estado == 'eliminado';
  bool get cupoLleno => cupoMax != null && cupoUsados >= cupoMax!;
  bool get puedeUnirse =>
      estaAbierto &&
      ingresoAbierto &&
      !soyMiembro &&
      !soyPendiente &&
      !cupoLleno;
  bool get chatDisponible => soyMiembro && estaAbierto;

  PlanComunidad copyWith({
    String? miEstado,
    int? cupoUsados,
    String? estado,
    bool? ingresoAbierto,
    String? beneficioContraoferta,
    String? beneficioEstado,
    String? pedidoBeneficio,
    int? pedidoVotos,
  }) =>
      PlanComunidad(
        id: id,
        titulo: titulo,
        descripcion: descripcion,
        ciudad: ciudad,
        fechaInicio: fechaInicio,
        modoLista: modoLista,
        cupoUsados: cupoUsados ?? this.cupoUsados,
        idLocal: idLocal,
        nombreLocal: nombreLocal,
        idOrganizador: idOrganizador,
        nombreOrganizador: nombreOrganizador,
        tipoOrganizador: tipoOrganizador,
        provincia: provincia,
        fechaFin: fechaFin,
        expiraEn: expiraEn,
        cupoMax: cupoMax,
        idSquad: idSquad,
        nombreSquad: nombreSquad,
        fotoLocal: fotoLocal,
        fotoOrganizador: fotoOrganizador,
        miEstado: miEstado ?? this.miEstado,
        estado: estado ?? this.estado,
        creadorTipo: creadorTipo,
        idCreadorLocal: idCreadorLocal,
        portadaPath: portadaPath,
        colorHex: colorHex,
        permiteSquads: permiteSquads,
        edadMinima: edadMinima,
        contactoAnfitrion: contactoAnfitrion,
        beneficioLocal: beneficioLocal,
        beneficioEstado: beneficioEstado ?? this.beneficioEstado,
        beneficioContraoferta:
            beneficioContraoferta ?? this.beneficioContraoferta,
        pedidoBeneficio: pedidoBeneficio ?? this.pedidoBeneficio,
        pedidoVotos: pedidoVotos ?? this.pedidoVotos,
        soyModerador: soyModerador,
        esPlanLocal: esPlanLocal,
        personasAceptadas: personasAceptadas,
        ingresoAbierto: ingresoAbierto ?? this.ingresoAbierto,
      );

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
      expiraEn: dt(m['expira_en']),
      modoLista: m['modo_lista']?.toString() ?? 'auto',
      cupoMax: n(m['cupo_max']),
      cupoUsados: n(m['cupo_usados']) ?? n(m['personas_aceptadas']) ?? 0,
      idLocal: m['id_local']?.toString() ?? '',
      nombreLocal: m['nombre_local']?.toString() ?? 'Local',
      fotoLocal: m['foto_local']?.toString(),
      idOrganizador: m['id_organizador']?.toString() ?? '',
      idCreadorLocal: m['id_creador_local']?.toString(),
      nombreOrganizador: m['nombre_organizador']?.toString() ?? 'Alguien',
      fotoOrganizador: m['foto_organizador']?.toString(),
      tipoOrganizador: m['tipo_organizador']?.toString() ?? 'usuario',
      creadorTipo: m['creador_tipo']?.toString() ?? 'usuario',
      idSquad: m['id_squad']?.toString(),
      nombreSquad: m['nombre_squad']?.toString(),
      miEstado: m['mi_estado']?.toString() ?? 'ninguno',
      estado: m['estado']?.toString() ?? 'abierto',
      portadaPath: m['portada_path']?.toString(),
      colorHex: m['color_hex']?.toString() ?? '#C084FC',
      permiteSquads: m['permite_squads'] != false,
      edadMinima: n(m['edad_minima']),
      contactoAnfitrion: m['contacto_anfitrion']?.toString(),
      beneficioLocal: m['beneficio_local']?.toString(),
      beneficioEstado: m['beneficio_estado']?.toString() ?? 'ninguno',
      beneficioContraoferta: m['beneficio_contraoferta']?.toString(),
      pedidoBeneficio: m['pedido_beneficio']?.toString(),
      pedidoVotos: n(m['pedido_votos']) ?? 0,
      soyModerador: m['soy_moderador'] == true,
      esPlanLocal: m['es_plan_local'] == true || m['creador_tipo'] == 'local',
      personasAceptadas: n(m['personas_aceptadas']) ?? n(m['cupo_usados']) ?? 0,
      ingresoAbierto: m['ingreso_abierto'] != false,
    );
  }
}

class PlanSquadGrupo {
  const PlanSquadGrupo({
    required this.idSquad,
    required this.nombreSquad,
    required this.estado,
    this.portadaPath,
    this.cantidadMiembros = 0,
  });

  final String idSquad;
  final String nombreSquad;
  final String? portadaPath;
  final String estado;
  final int cantidadMiembros;

  String? get portadaUrl =>
      ServicioSupabase().urlPortadaSquadDisplay(portadaPath);

  factory PlanSquadGrupo.fromMap(Map<String, dynamic> m) => PlanSquadGrupo(
    idSquad: m['id_squad']?.toString() ?? '',
    nombreSquad: m['nombre_squad']?.toString() ?? 'Squad',
    portadaPath: m['url_portada']?.toString() ?? m['portada_path']?.toString(),
    estado: m['estado']?.toString() ?? 'aceptado',
    cantidadMiembros: m['cantidad_miembros'] is num
        ? (m['cantidad_miembros'] as num).toInt()
        : int.tryParse(m['cantidad_miembros']?.toString() ?? '') ?? 0,
  );
}

class PlanMiembro {
  const PlanMiembro({
    required this.idUsuario,
    required this.nombre,
    required this.estado,
    this.username,
    this.fotoPath,
    this.rol = 'miembro',
    this.idSquad,
    this.nombreSquad,
  });

  final String idUsuario;
  final String nombre;
  final String? username;
  final String? fotoPath;
  final String rol;
  final String estado;
  final String? idSquad;
  final String? nombreSquad;

  String? get fotoUrl => ServicioSupabase().urlAvatar(fotoPath);

  factory PlanMiembro.fromMap(Map<String, dynamic> m) => PlanMiembro(
    idUsuario: m['id_usuario']?.toString() ?? '',
    nombre: m['nombre']?.toString() ?? 'Alguien',
    username: m['username']?.toString(),
    fotoPath: m['foto_perfil_url']?.toString(),
    rol: m['rol']?.toString() ?? 'miembro',
    estado: m['estado']?.toString() ?? 'aceptado',
    idSquad: m['id_squad']?.toString(),
    nombreSquad: m['nombre_squad']?.toString(),
  );
}

class PlanDetalle {
  const PlanDetalle({
    required this.plan,
    required this.miembros,
    this.squads = const [],
    this.yaVotePedido = false,
  });
  final PlanComunidad plan;
  final List<PlanMiembro> miembros;
  final List<PlanSquadGrupo> squads;
  final bool yaVotePedido;
}

class PlanMensaje {
  const PlanMensaje({
    required this.id,
    required this.cuerpo,
    required this.creadoEn,
    this.idAutor,
    this.idAutorLocal,
    this.autorTipo = 'usuario',
    this.tipo = 'mensaje',
  });

  final int id;
  final String? idAutor;
  final String? idAutorLocal;
  final String autorTipo; // usuario | local | sistema
  final String tipo; // mensaje | sistema | beneficio
  final String cuerpo;
  final DateTime creadoEn;

  bool get esSistema => autorTipo == 'sistema' || tipo == 'sistema';
  bool get esLocal => autorTipo == 'local';

  factory PlanMensaje.fromMap(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    return PlanMensaje(
      id: id,
      idAutor: m['id_autor']?.toString(),
      idAutorLocal: m['id_autor_local']?.toString(),
      autorTipo: m['autor_tipo']?.toString() ?? 'usuario',
      tipo: m['tipo']?.toString() ?? 'mensaje',
      cuerpo: m['cuerpo']?.toString() ?? '',
      creadoEn:
          DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class PlanSquadOpcion {
  const PlanSquadOpcion({
    required this.idGrupo,
    required this.nombre,
    this.portadaPath,
    this.cantidadMiembros = 0,
    this.puedeOrganizar = false,
  });

  final String idGrupo;
  final String nombre;
  final String? portadaPath;
  final int cantidadMiembros;
  final bool puedeOrganizar;

  String? get portadaUrl =>
      ServicioSupabase().urlPortadaSquadDisplay(portadaPath);

  factory PlanSquadOpcion.fromMap(Map<String, dynamic> m) => PlanSquadOpcion(
    idGrupo: m['id_grupo']?.toString() ?? '',
    nombre: m['nombre_grupo']?.toString() ?? 'Squad',
    portadaPath: m['url_portada']?.toString(),
    cantidadMiembros: m['cantidad_miembros'] is num
        ? (m['cantidad_miembros'] as num).toInt()
        : int.tryParse(m['cantidad_miembros']?.toString() ?? '') ?? 0,
    puedeOrganizar: m['puede_organizar'] == true,
  );
}

class ServicioPlanes {
  static const _bucketPortadas = 'planes-portadas';

  SupabaseClient get _c => ServicioSupabase().cliente;
  String? get miUid => _c.auth.currentUser?.id;

  Future<({List<PlanComunidad> items, bool hayMas, String? error})> hub({
    Set<String> ciudades = const {},
    String? provincia,
    int limit = 20,
    int offset = 0,
    String modo = 'explorar',
  }) async {
    try {
      final res = await _c.rpc(
        'planes_hub',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limit': limit,
          'p_offset': offset,
          'p_modo': modo,
        },
      );
      if (res is! Map) {
        return (
          items: const <PlanComunidad>[],
          hayMas: false,
          error: 'No se pudo cargar la cartelera.',
        );
      }
      final raw = res['items'];
      if (raw is! List) {
        return (items: const <PlanComunidad>[], hayMas: false, error: null);
      }
      final items = raw
          .map(
            (e) => PlanComunidad.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);
      return (items: items, hayMas: res['hay_mas'] == true, error: null);
    } catch (e) {
      debugPrint('⚠️ planes_hub: $e');
      return (
        items: const <PlanComunidad>[],
        hayMas: false,
        error: mensajeError(e, accion: 'cargar los planes'),
      );
    }
  }

  Future<({PlanDetalle? detalle, String? error})> detalle(String idPlan) async {
    try {
      final res = await _c.rpc('planes_detalle', params: {'p_id_plan': idPlan});
      if (res is! Map) {
        return (detalle: null, error: 'No se pudo abrir el plan.');
      }
      final planRaw = res['plan'];
      if (planRaw is! Map) {
        return (detalle: null, error: 'Este plan ya no está disponible.');
      }
      final miembrosRaw = res['miembros'] as List? ?? const [];
      final squadsRaw = res['squads'] as List? ?? const [];
      return (
        detalle: PlanDetalle(
          plan: PlanComunidad.fromMap(Map<String, dynamic>.from(planRaw)),
          miembros: miembrosRaw
              .map(
                (e) => PlanMiembro.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(growable: false),
          squads: squadsRaw
              .map(
                (e) =>
                    PlanSquadGrupo.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .where((s) => s.idSquad.isNotEmpty)
              .toList(growable: false),
          yaVotePedido: res['ya_vote_pedido'] == true,
        ),
        error: null,
      );
    } catch (e) {
      debugPrint('⚠️ planes_detalle: $e');
      return (
        detalle: null,
        error: mensajeError(e, accion: 'abrir el plan'),
      );
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
    String? contactoAnfitrion,
    String? portadaPath,
    String colorHex = '#C084FC',
    bool permiteSquads = true,
    int? edadMinima,
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
        'p_contacto_anfitrion': contactoAnfitrion,
        'p_portada_path': portadaPath,
        'p_color_hex': colorHex,
        'p_permite_squads': permiteSquads,
        'p_edad_minima': edadMinima,
      },
    );
    if (res is Map && res['ok'] == true) return res['id']?.toString();
    return null;
  }

  Future<({String estado, int cantidad})?> solicitarUnirse(
    String idPlan, {
    String? idSquad,
  }) async {
    final res = await _c.rpc(
      'planes_solicitar_unirse',
      params: {'p_id_plan': idPlan, 'p_id_squad': idSquad},
    );
    if (res is! Map) return null;
    final estado = res['estado']?.toString();
    if (estado == null || estado.isEmpty) return null;
    final cantidadRaw = res['cantidad'];
    final cantidad = cantidadRaw is num
        ? cantidadRaw.toInt()
        : int.tryParse(cantidadRaw?.toString() ?? '') ?? 0;
    return (estado: estado, cantidad: cantidad);
  }

  String mensajeError(Object error, {String accion = 'procesar el plan'}) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('no_auth') || msg.contains('jwt')) {
      return 'Tu sesión expiró. Cerrá sesión y volvé a entrar.';
    }
    if (msg.contains('rate') || msg.contains('demasiad')) {
      return 'Estás haciendo muchas acciones seguidas. Esperá un ratito y probá de nuevo.';
    }
    if (msg.contains('cupo_lleno')) return 'Se llenó el cupo.';
    if (msg.contains('ingreso_cerrado')) {
      return 'Este plan ya no acepta más gente.';
    }
    if (msg.contains('nadie_elegible')) {
      return 'No hay nadie elegible del squad para sumarse.';
    }
    if (msg.contains('pedido_invalido')) {
      return 'El pedido al local tiene que tener entre 3 y 120 caracteres.';
    }
    if (msg.contains('beneficio_ya_aceptado')) {
      return 'El local ya aceptó un beneficio para este plan.';
    }
    if (msg.contains('organizador_no_sale')) {
      return 'El organizador no puede salir del plan. Cancelalo o transferí.';
    }
    if (msg.contains('plan_eliminado')) {
      return 'Este plan fue eliminado.';
    }
    if (msg.contains('squads_no_permitidos')) {
      return 'Este plan no acepta squads.';
    }
    if (msg.contains('no_miembro_squad')) {
      return 'No figurás como miembro aceptado de ese squad.';
    }
    if (msg.contains('plan_cerrado') ||
        msg.contains('plan_finalizado') ||
        msg.contains('plan_inexistente')) {
      return 'Este plan ya no está disponible.';
    }
    if (msg.contains('bloqueado')) {
      return 'No podés interactuar con este plan por configuración de privacidad.';
    }
    if (msg.contains('local_inactivo') || msg.contains('local_inexistente')) {
      return 'El local elegido ya no está disponible.';
    }
    if (msg.contains('titulo_invalido')) {
      return 'El título tiene que tener entre 3 y 80 caracteres.';
    }
    if (msg.contains('descripcion_invalida')) {
      return 'La descripción es demasiado larga.';
    }
    if (msg.contains('fecha_fin_invalida')) {
      return 'La fecha de fin no puede ser antes del inicio.';
    }
    if (msg.contains('fecha_fuera_ventana')) {
      return 'La fecha del plan está fuera de la ventana permitida.';
    }
    if (msg.contains('edad_insuficiente')) {
      return 'No cumplís la edad mínima para este plan.';
    }
    if (msg.contains('expulsado')) {
      return 'Te expulsaron de este plan y no podés volver a sumarte.';
    }
    if (msg.contains('no_admin_squad')) {
      return 'Solo un admin del squad puede publicar o gestionar esto.';
    }
    if (msg.contains('squad_requerido')) {
      return 'Tenés que elegir un squad para continuar.';
    }
    if (msg.contains('cupo_menor_usados')) {
      return 'El cupo no puede ser menor a la gente que ya está adentro.';
    }
    if (msg.contains('estado_invalido')) {
      return 'El estado del plan no permite esta acción.';
    }
    if (msg.contains('mensaje_invalido')) {
      return 'El mensaje está vacío o es demasiado largo.';
    }
    if (msg.contains('no_participante')) {
      return 'Solo pueden chatear los aceptados en el plan.';
    }
    return 'No se pudo $accion. Revisá conexión y probá de nuevo.';
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

  Future<bool> eliminar(String idPlan) async {
    final res = await _c.rpc('planes_eliminar', params: {'p_id_plan': idPlan});
    return res is Map && res['ok'] == true;
  }

  Future<bool> salir(String idPlan) async {
    final res = await _c.rpc('planes_salir', params: {'p_id_plan': idPlan});
    return res is Map && res['ok'] == true;
  }

  Future<bool> localQuitarse(String idPlan) async {
    final res = await _c.rpc(
      'planes_local_quitarse',
      params: {'p_id_plan': idPlan},
    );
    return res is Map && res['ok'] == true;
  }

  Future<bool> pedidoLocal(String idPlan, String pedido) async {
    final res = await _c.rpc(
      'planes_pedido_local',
      params: {'p_id_plan': idPlan, 'p_pedido': pedido},
    );
    return res is Map && res['ok'] == true;
  }

  Future<bool> pedidoResponder({
    required String idPlan,
    required String accion,
    String? contraoferta,
  }) async {
    final res = await _c.rpc(
      'planes_pedido_responder',
      params: {
        'p_id_plan': idPlan,
        'p_accion': accion,
        'p_contraoferta': contraoferta,
      },
    );
    return res is Map && res['ok'] == true;
  }

  Future<({bool ok, int votos, bool yaVote})> pedidoVotar(String idPlan) async {
    final res = await _c.rpc(
      'planes_pedido_votar',
      params: {'p_id_plan': idPlan},
    );
    if (res is! Map) return (ok: false, votos: 0, yaVote: false);
    final votosRaw = res['votos'];
    final votos = votosRaw is num
        ? votosRaw.toInt()
        : int.tryParse(votosRaw?.toString() ?? '') ?? 0;
    return (
      ok: res['ok'] == true,
      votos: votos,
      yaVote: res['ya_vote'] == true,
    );
  }

  Future<List<PlanMensaje>> historial(String idPlan) async {
    final rows = await _c
        .from('planes_mensajes')
        .select(
          'id, id_autor, id_autor_local, autor_tipo, tipo, cuerpo, creado_en',
        )
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

  Future<List<PlanSquadOpcion>> misSquads() async {
    try {
      final res = await _c.rpc('planes_mis_squads');
      if (res is! Map) return const [];
      final raw = res['items'] as List? ?? const [];
      return raw
          .map(
            (e) => PlanSquadOpcion.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .where((s) => s.idGrupo.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('⚠️ planes_mis_squads: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> buscarLocales(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final rows = await _c
          .from('perfiles_locales')
          .select('id, nombre_local, ciudad, provincia, foto_perfil_url')
          .ilike('nombre_local', '%$q%')
          .eq('estado_cuenta', 'activa')
          .limit(12);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (e) {
      debugPrint('⚠️ buscarLocales planes: $e');
      return const [];
    }
  }

  Future<bool> actualizarBasico({
    required String idPlan,
    String? titulo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? cupoMax,
    bool sinCupo = false,
    bool? ingresoAbierto,
  }) async {
    final res = await _c.rpc(
      'planes_actualizar_basico',
      params: {
        'p_id_plan': idPlan,
        'p_titulo': titulo,
        'p_fecha_inicio': fechaInicio?.toUtc().toIso8601String(),
        'p_fecha_fin': fechaFin?.toUtc().toIso8601String(),
        'p_cupo_max': cupoMax,
        'p_sin_cupo': sinCupo,
        'p_ingreso_abierto': ingresoAbierto,
      },
    );
    return res is Map && res['ok'] == true;
  }

  Future<String?> subirPortada({
    required String idTemporal,
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    final uid = miUid;
    if (uid == null) return null;
    try {
      final path = '$uid/$idTemporal.jpg';
      await _c.storage
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
      debugPrint('⚠️ subirPortada plan: $e');
      return null;
    }
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
