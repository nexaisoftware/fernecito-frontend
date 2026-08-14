/// Navegación desde notificaciones in-app (usa navigator raíz).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../PANTALLAS/pantalla_actividad.dart';
import '../PANTALLAS/pantalla_chat_plan.dart';
import '../PANTALLAS/pantalla_fernecito_match.dart';
import '../PANTALLAS/pantalla_match_chats.dart';
import '../PANTALLAS/pantalla_mis_squads.dart';
import '../PANTALLAS/pantalla_perfil_squads.dart';
import '../PANTALLAS/pantalla_perfil_usuarios.dart';
import '../PANTALLAS/pantalla_planes.dart';
import '../PANTALLAS/pantalla_rompehielo.dart' show TipoContraparte;
import '../PANTALLAS/pantalla_social.dart';
import '../PANTALLAS/pantalla_soporte.dart';
import '../PANTALLAS/pantalla_ver_plan.dart';
import 'servicio_planes.dart';
import '../models/notificacion.dart';
import 'app_navigator.dart';
import 'navegacion_evento_compartido.dart';
import 'rompehielo_navegacion.dart';
import 'servicio_amigos.dart';
import 'servicio_perfil_usuario.dart';
import 'servicio_rompehielo.dart';
import 'servicio_squads.dart';
import 'squad_helpers.dart';
import 'supabase_client.dart';

/// Cambia tab del home (0 actividad, 1 social, 2 cartelera, …).
typedef NotifIrATab = void Function(int tabIndex, {SocialVista? socialVista});

NavigatorState? get _nav => navigatorKey.currentState;

BuildContext? get _ctx => navigatorKey.currentContext;

Future<T?> _push<T>(Route<T> route) async => _nav?.push(route);

void _activarTab(
  NotifIrATab? onIrATab,
  int tab, {
  SocialVista? socialVista,
}) {
  if (onIrATab != null) {
    onIrATab(tab, socialVista: socialVista);
    return;
  }
  irATabHome(tab, socialVista: socialVista);
}

Future<bool> _irATabOFallback(
  int tab, {
  NotifIrATab? onIrATab,
  SocialVista? socialVista,
}) async {
  if (onIrATab != null || homeIrATabDisponible) {
    _activarTab(onIrATab, tab, socialVista: socialVista);
    return true;
  }

  switch (tab) {
    case 0:
      await _push(
        CupertinoPageRoute(builder: (_) => const PantallaActividad()),
      );
      return true;
    case 1:
      final tab = switch (socialVista) {
        SocialVista.amigos => 0,
        SocialVista.squads => 1,
        _ => null,
      };
      if (tab != null) {
        await _push(
          CupertinoPageRoute(
            builder: (_) => PantallaAmigosSquads(initialTab: tab),
          ),
        );
      } else {
        await _push(
          CupertinoPageRoute(
            builder: (_) => const PantallaSocial(
              vista: SocialVista.explorar,
              mostrarVolver: true,
            ),
          ),
        );
      }
      return true;
    case 2:
      return true; // abrir la app/cartelera alcanza para broadcasts o home.
    default:
      return false;
  }
}

/// Resuelve contraparte del rompehielo desde el payload de la notificación.
({String otroTipo, String otroId, String? idGrupoActor})?
resolverRompehieloNotif(Notificacion n) {
  final payload = n.payload;
  if (payload == null) return null;

  final otroTipo = payload['lado_otro_tipo']?.toString();
  final otroId = payload['lado_otro_id']?.toString();
  if (otroTipo == null || otroId == null || otroId.isEmpty) return null;

  final uid = ServicioSupabase().usuarioActual?.id;
  if (uid != null && otroTipo == 'usuario' && otroId == uid) {
    // Payload invertido: resolver contraparte desde el hilo.
    return null;
  }

  final idGrupo =
      payload['id_grupo']?.toString() ?? payload['id_grupo_actor']?.toString();
  return (otroTipo: otroTipo, otroId: otroId, idGrupoActor: idGrupo);
}

Future<bool> abrirRompehieloDesdeNotificacionUsuario(Notificacion n) async {
  final ctx = _ctx;
  if (ctx == null || !ctx.mounted) return false;

  final resuelto = resolverRompehieloNotif(n);
  if (resuelto == null) return false;

  final otroTipo = resuelto.otroTipo;
  final otroId = resuelto.otroId;
  var idGrupoActor = resuelto.idGrupoActor;

  final srv = ServicioRompehielo();
  final srvPerfil = ServicioPerfilUsuario();
  final srvSquads = ServicioSquads();

  final estado = await srv.estado(
    otroTipo: otroTipo,
    otroId: otroId,
    idGrupoActor: idGrupoActor,
  );
  if (!ctx.mounted) return false;

  idGrupoActor ??= estado.idGrupoActorMio;

  Map<String, dynamic> contraparte;
  TipoContraparte tipo;
  if (otroTipo == 'usuario') {
    tipo = TipoContraparte.usuario;
    final det = await srvPerfil.detalle(otroId);
    if (!ctx.mounted) return false;
    contraparte = {
      'id_usuario': otroId,
      'username': det?['username'] ?? '@usuario',
      'avatar': ServicioSupabase().urlAvatar(
        det?['foto_perfil_url']?.toString(),
      ),
    };
  } else {
    tipo = TipoContraparte.squad;
    final det = await srvSquads.detalle(otroId);
    if (!ctx.mounted) return false;
    if (det == null) return false;
    contraparte = mapNavegacionDesdeDetalle(det);
  }

  Map<String, dynamic>? squadActor;
  if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
    final detSquad = await srvSquads.detalle(idGrupoActor);
    if (detSquad != null) {
      squadActor = mapNavegacionDesdeDetalle(detSquad);
    }
  }

  if (!ctx.mounted) return false;
  await abrirRompehieloDesdeNotificacion(
    ctx,
    tipoContraparte: tipo,
    contraparte: contraparte,
    estadoInicial: estado,
    idGrupoActor: idGrupoActor,
    squadActor: squadActor,
  );
  return true;
}

Future<bool> abrirEventoDesdeNotificacion(Notificacion n) async {
  final ctx = _ctx;
  final idEvento = n.ctaIdRef?.trim();
  if (ctx == null || idEvento == null || idEvento.isEmpty) return false;
  await abrirEventoCompartidoPorId(ctx, idEvento);
  return true;
}

Future<bool> abrirPlanDesdeNotificacion(Notificacion n) async {
  final idPlan =
      n.ctaIdRef?.trim() ?? n.payload?['id_plan']?.toString().trim();
  final accion =
      n.payload?['accion']?.toString() ??
      (n.tipo == 'plan_aceptado' || n.tipo == 'plan_mencion'
          ? 'chat'
          : (n.tipo == 'plan_cancelado' || n.tipo == 'plan_eliminado'
                ? 'hub'
                : 'detalle'));

  // Cancelado / eliminado (o sin id): volver al hub de planes.
  if (accion == 'hub' || idPlan == null || idPlan.isEmpty) {
    await _push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PantallaPlanes(),
      ),
    );
    return true;
  }

  if (accion == 'chat') {
    final res = await ServicioPlanes().detalle(idPlan);
    final plan = res.detalle?.plan;
    if (plan != null && plan.chatDisponible) {
      await _push(
        CupertinoPageRoute(builder: (_) => PantallaChatPlan(plan: plan)),
      );
      return true;
    }
  }

  await _push(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => PantallaVerPlan(idPlan: idPlan),
    ),
  );
  return true;
}

Future<bool> abrirSquadDesdeNotificacion(Notificacion n) async {
  final idGrupo = n.ctaIdRef?.trim();
  if (idGrupo == null || idGrupo.isEmpty) {
    await _push(
      CupertinoPageRoute(
        builder: (_) => const PantallaAmigosSquads(initialTab: 1),
      ),
    );
    return true;
  }

  final det = await ServicioSquads().detalle(idGrupo);
  final ctx = _ctx;
  if (ctx == null || !ctx.mounted) return false;
  if (det == null) {
    await _push(
      CupertinoPageRoute(
        builder: (_) => const PantallaAmigosSquads(initialTab: 1),
      ),
    );
    return true;
  }

  final map = mapNavegacionDesdeDetalle(det);
  if (notifEsPedidoUnionSquad(n) &&
      det.puedeAdministrar(ServicioSupabase().usuarioActual?.id)) {
    await _push(
      CupertinoPageRoute(builder: (_) => PantallaMisSquads(squad: map)),
    );
    return true;
  }

  final estado = det.miEstado == 'pendiente'
      ? EstadoRelacionSquad.solicitudPendiente
      : (det.miEstado == 'aceptado'
            ? EstadoRelacionSquad.miembro
            : EstadoRelacionSquad.ninguno);
  await _push(
    CupertinoPageRoute(
      builder: (_) => PantallaPerfilSquads(squad: map, estadoRelacion: estado),
    ),
  );
  return true;
}

Future<bool> abrirPerfilAmistadDesdeNotificacion(
  Notificacion n, {
  EstadoRelacionUsuario estado = EstadoRelacionUsuario.solicitudRecibida,
}) async {
  final idEmisor = n.ctaIdRef?.trim();
  final ctx = _ctx;
  if (ctx == null) return false;

  if (idEmisor != null && idEmisor.isNotEmpty) {
    final det = await ServicioPerfilUsuario().detalle(idEmisor);
    if (!ctx.mounted) return false;
    await _push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': idEmisor,
            'perfil_publico': det?['perfil_publico'] == true,
            if (det?['foto_perfil_url'] != null)
              'avatar': ServicioSupabase().urlAvatar(
                det!['foto_perfil_url']?.toString(),
              ),
            'username': det?['username'],
          },
          estadoRelacion: estado,
        ),
      ),
    );
    return true;
  }

  await _push(
    CupertinoPageRoute(
      builder: (_) => const PantallaAmigosSquads(initialTab: 0),
    ),
  );
  return true;
}

Future<bool> navegarDesdeNotificacion(
  Notificacion n, {
  NotifIrATab? onIrATab,
}) async {
  switch (n.tipo) {
    case 'solicitud_amistad':
      _activarTab(onIrATab, 1, socialVista: SocialVista.amigos);
      return abrirPerfilAmistadDesdeNotificacion(n);
    case 'amistad_aceptada':
      _activarTab(onIrATab, 1, socialVista: SocialVista.amigos);
      final id = n.ctaIdRef?.trim();
      if (id != null && id.isNotEmpty) {
        final abierta = await abrirPerfilAmistadDesdeNotificacion(
          n,
          estado: EstadoRelacionUsuario.amigo,
        );
        if (abierta) return true;
      }
      return _irATabOFallback(
        1,
        onIrATab: onIrATab,
        socialVista: SocialVista.amigos,
      );
    case 'solicitud_squad':
      _activarTab(onIrATab, 1, socialVista: SocialVista.squads);
      return abrirSquadDesdeNotificacion(n);
    case 'squad_aceptada':
      _activarTab(onIrATab, 1, socialVista: SocialVista.squads);
      final abierta = await abrirSquadDesdeNotificacion(n);
      if (abierta) return true;
      return _irATabOFallback(
        1,
        onIrATab: onIrATab,
        socialVista: SocialVista.squads,
      );
    case 'match_plan':
    case 'match_mensaje':
      _activarTab(onIrATab, 1);
      final navMatch = _nav;
      if (navMatch == null) return false;
      final idMatch = n.ctaIdRef?.trim();
      unawaited(
        _push(
          CupertinoPageRoute(builder: (_) => const PantallaFernecitoMatch()),
        ),
      );
      unawaited(
        _push(
          CupertinoPageRoute(
            builder: (_) => PantallaMatchChats(idMatchInicial: idMatch),
          ),
        ),
      );
      return true;
    case 'match_interes':
    case 'match_recopa':
      _activarTab(onIrATab, 1);
      if (_nav == null) return false;
      unawaited(
        _push(
          CupertinoPageRoute(builder: (_) => const PantallaFernecitoMatch()),
        ),
      );
      return true;
    case 'plan_solicitud':
    case 'plan_aceptado':
    case 'plan_rechazado':
    case 'plan_cancelado':
    case 'plan_eliminado':
    case 'plan_pedido_local':
    case 'plan_pedido_respuesta':
    case 'plan_mencion':
    case 'plan_mensaje':
      return abrirPlanDesdeNotificacion(n);
    case 'rompehielo_recibido':
    case 'rompehielo_respondido':
    case 'rompehielo_replicado':
      _activarTab(onIrATab, 1);
      final abierta = await abrirRompehieloDesdeNotificacionUsuario(n);
      if (abierta) return true;
      return _irATabOFallback(1, onIrATab: onIrATab);
    case 'lista_aceptada':
    case 'recordatorio_evento':
      final idEvento = n.ctaIdRef?.trim();
      if (idEvento != null && idEvento.isNotEmpty) {
        final abierta = await abrirEventoDesdeNotificacion(n);
        if (abierta) return true;
      } else {
        return _irATabOFallback(0, onIrATab: onIrATab);
      }
      return _irATabOFallback(0, onIrATab: onIrATab);
    case 'pase_canjeado':
      return _irATabOFallback(0, onIrATab: onIrATab);
    case 'cuenta_pausada':
    case 'cuenta_reactivada':
      return true;
    default:
      final ruta = n.ctaRuta?.trim() ?? '';
      switch (ruta) {
        case '/rompehielo':
          _activarTab(onIrATab, 1);
          final abierta = await abrirRompehieloDesdeNotificacionUsuario(n);
          if (abierta) return true;
          return _irATabOFallback(1, onIrATab: onIrATab);
        case '/match_chats':
          _activarTab(onIrATab, 1);
          if (_nav == null) return false;
          unawaited(
            _push(
              CupertinoPageRoute(
                builder: (_) => const PantallaFernecitoMatch(),
              ),
            ),
          );
          unawaited(
            _push(
              CupertinoPageRoute(builder: (_) => const PantallaMatchChats()),
            ),
          );
          return true;
        case '/match':
          _activarTab(onIrATab, 1);
          if (_nav == null) return false;
          unawaited(
            _push(
              CupertinoPageRoute(
                builder: (_) => const PantallaFernecitoMatch(),
              ),
            ),
          );
          return true;
        case '/social':
          return _irATabOFallback(
            1,
            onIrATab: onIrATab,
            socialVista: SocialVista.amigos,
          );
        case 'planes':
        case '/planes':
          return abrirPlanDesdeNotificacion(n);
        case '/actividad':
          return _irATabOFallback(0, onIrATab: onIrATab);
        case '/home':
          return _irATabOFallback(2, onIrATab: onIrATab);
        case '/soporte':
          await _push(
            CupertinoPageRoute(builder: (_) => const PantallaSoporte()),
          );
          return true;
        default:
          if (n.ctaIdRef != null && n.ctaIdRef!.isNotEmpty) {
            final abierta = await abrirEventoDesdeNotificacion(n);
            if (abierta) return true;
          } else {
            return _irATabOFallback(0, onIrATab: onIrATab);
          }
          return _irATabOFallback(0, onIrATab: onIrATab);
      }
  }
}

Future<bool> aceptarAmistadDesdeNotificacion(Notificacion n) async {
  final idEmisor = n.ctaIdRef?.trim();
  if (idEmisor == null || idEmisor.isEmpty) {
    await navegarDesdeNotificacion(n);
    return false;
  }

  final srv = ServicioAmigos();
  var ok = false;
  final data = await srv.listar();
  final recibida = data.recibidas
      .where((a) => a.idUsuario == idEmisor)
      .toList();
  if (recibida.isNotEmpty) {
    final rel = recibida.first.idRelacion?.toString();
    if (rel != null && rel.isNotEmpty) {
      ok = await srv.responder(rel, aceptar: true);
    }
  }
  if (!ok) {
    final estado = await srv.solicitar(idEmisor);
    ok = estado == 'aceptada' || estado == 'aceptado';
  }

  final ctx = _ctx;
  if (!ok || ctx == null || !ctx.mounted) return ok;

  await _push(
    CupertinoPageRoute(
      builder: (_) => PantallaPerfilUsuarios(
        usuario: {'id_usuario': idEmisor, 'perfil_publico': false},
        estadoRelacion: EstadoRelacionUsuario.amigo,
      ),
    ),
  );
  return ok;
}

Future<bool> aceptarInvitacionSquadDesdeNotificacion(Notificacion n) async {
  final idGrupo = n.ctaIdRef?.trim();
  if (idGrupo == null || idGrupo.isEmpty) {
    await navegarDesdeNotificacion(n);
    return false;
  }
  final ok = await ServicioSquads().responderInvitacion(idGrupo, aceptar: true);
  if (!ok) {
    await abrirSquadDesdeNotificacion(n);
  }
  return ok;
}
