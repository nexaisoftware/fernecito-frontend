/// Navegación desde notificaciones in-app (usa navigator raíz).
library;

import 'package:flutter/cupertino.dart';

import '../PANTALLAS/pantalla_actividad.dart';
import '../PANTALLAS/pantalla_mis_squads.dart';
import '../PANTALLAS/pantalla_perfil_squads.dart';
import '../PANTALLAS/pantalla_perfil_usuarios.dart';
import '../PANTALLAS/pantalla_rompehielo.dart' show TipoContraparte;
import '../PANTALLAS/pantalla_social.dart';
import '../PANTALLAS/pantalla_soporte.dart';
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
typedef NotifIrATab = void Function(
  int tabIndex, {
  SocialVista? socialVista,
});

NavigatorState? get _nav => navigatorKey.currentState;

BuildContext? get _ctx => navigatorKey.currentContext;

Future<T?> _push<T>(Route<T> route) async => _nav?.push(route);

/// Resuelve contraparte del rompehielo desde el payload de la notificación.
({String otroTipo, String otroId, String? idGrupoActor})? resolverRompehieloNotif(
  Notificacion n,
) {
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

  final idGrupo = payload['id_grupo']?.toString() ??
      payload['id_grupo_actor']?.toString();
  return (otroTipo: otroTipo, otroId: otroId, idGrupoActor: idGrupo);
}

Future<void> abrirRompehieloDesdeNotificacionUsuario(Notificacion n) async {
  final ctx = _ctx;
  if (ctx == null || !ctx.mounted) return;

  final resuelto = resolverRompehieloNotif(n);
  if (resuelto == null) return;

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
  if (!ctx.mounted) return;

  idGrupoActor ??= estado.idGrupoActorMio;

  Map<String, dynamic> contraparte;
  TipoContraparte tipo;
  if (otroTipo == 'usuario') {
    tipo = TipoContraparte.usuario;
    final det = await srvPerfil.detalle(otroId);
    if (!ctx.mounted) return;
    contraparte = {
      'id_usuario': otroId,
      'username': det?['username'] ?? '@usuario',
      'avatar': ServicioSupabase().urlAvatar(det?['foto_perfil_url']?.toString()),
    };
  } else {
    tipo = TipoContraparte.squad;
    final det = await srvSquads.detalle(otroId);
    if (!ctx.mounted) return;
    if (det == null) return;
    contraparte = mapNavegacionDesdeDetalle(det);
  }

  Map<String, dynamic>? squadActor;
  if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
    final detSquad = await srvSquads.detalle(idGrupoActor);
    if (detSquad != null) {
      squadActor = mapNavegacionDesdeDetalle(detSquad);
    }
  }

  if (!ctx.mounted) return;
  await abrirRompehieloDesdeNotificacion(
    ctx,
    tipoContraparte: tipo,
    contraparte: contraparte,
    estadoInicial: estado,
    idGrupoActor: idGrupoActor,
    squadActor: squadActor,
  );
}

Future<void> abrirEventoDesdeNotificacion(Notificacion n) async {
  final ctx = _ctx;
  final idEvento = n.ctaIdRef?.trim();
  if (ctx == null || idEvento == null || idEvento.isEmpty) return;
  await abrirEventoCompartidoPorId(ctx, idEvento);
}

Future<void> abrirSquadDesdeNotificacion(Notificacion n) async {
  final idGrupo = n.ctaIdRef?.trim();
  if (idGrupo == null || idGrupo.isEmpty) {
    await _push(
      CupertinoPageRoute(
        builder: (_) => const PantallaSocial(
          vista: SocialVista.squads,
          mostrarVolver: true,
        ),
      ),
    );
    return;
  }

  final det = await ServicioSquads().detalle(idGrupo);
  final ctx = _ctx;
  if (ctx == null || !ctx.mounted) return;
  if (det == null) return;

  final map = mapNavegacionDesdeDetalle(det);
  if (notifEsPedidoUnionSquad(n) &&
      det.puedeAdministrar(ServicioSupabase().usuarioActual?.id)) {
    await _push(
      CupertinoPageRoute(builder: (_) => PantallaMisSquads(squad: map)),
    );
    return;
  }

  final estado = det.miEstado == 'pendiente'
      ? EstadoRelacionSquad.solicitudPendiente
      : (det.miEstado == 'aceptado'
          ? EstadoRelacionSquad.miembro
          : EstadoRelacionSquad.ninguno);
  await _push(
    CupertinoPageRoute(
      builder: (_) => PantallaPerfilSquads(
        squad: map,
        estadoRelacion: estado,
      ),
    ),
  );
}

Future<void> abrirPerfilAmistadDesdeNotificacion(Notificacion n) async {
  final idEmisor = n.ctaIdRef?.trim();
  final ctx = _ctx;
  if (ctx == null) return;

  if (idEmisor != null && idEmisor.isNotEmpty) {
    final det = await ServicioPerfilUsuario().detalle(idEmisor);
    if (!ctx.mounted) return;
    await _push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': idEmisor,
            'perfil_publico': det?['perfil_publico'] == true,
            if (det?['foto_perfil_url'] != null)
              'avatar': ServicioSupabase()
                  .urlAvatar(det!['foto_perfil_url']?.toString()),
            'username': det?['username'],
          },
          estadoRelacion: EstadoRelacionUsuario.solicitudRecibida,
        ),
      ),
    );
    return;
  }

  await _push(
    CupertinoPageRoute(
      builder: (_) => const PantallaSocial(
        vista: SocialVista.amigos,
        mostrarVolver: true,
      ),
    ),
  );
}

Future<void> navegarDesdeNotificacion(
  Notificacion n, {
  NotifIrATab? onIrATab,
}) async {
  switch (n.tipo) {
    case 'solicitud_amistad':
      await abrirPerfilAmistadDesdeNotificacion(n);
      break;
    case 'amistad_aceptada':
      onIrATab?.call(1, socialVista: SocialVista.amigos);
      break;
    case 'solicitud_squad':
      await abrirSquadDesdeNotificacion(n);
      break;
    case 'squad_aceptada':
      onIrATab?.call(1, socialVista: SocialVista.squads);
      break;
    case 'rompehielo_recibido':
    case 'rompehielo_respondido':
    case 'rompehielo_replicado':
      await abrirRompehieloDesdeNotificacionUsuario(n);
      break;
    case 'lista_aceptada':
    case 'recordatorio_evento':
      final idEvento = n.ctaIdRef?.trim();
      if (idEvento != null && idEvento.isNotEmpty) {
        await abrirEventoDesdeNotificacion(n);
      } else {
        onIrATab?.call(0);
      }
      break;
    case 'pase_canjeado':
      onIrATab?.call(0);
      break;
    case 'cuenta_pausada':
    case 'cuenta_reactivada':
      break;
    default:
      final ruta = n.ctaRuta?.trim() ?? '';
      switch (ruta) {
        case '/rompehielo':
          await abrirRompehieloDesdeNotificacionUsuario(n);
          break;
        case '/social':
          onIrATab?.call(1, socialVista: SocialVista.amigos);
          break;
        case '/actividad':
          onIrATab?.call(0);
          break;
        case '/home':
          onIrATab?.call(2);
          break;
        case '/soporte':
          await _push(
            CupertinoPageRoute(builder: (_) => const PantallaSoporte()),
          );
          break;
        default:
          if (n.ctaIdRef != null && n.ctaIdRef!.isNotEmpty) {
            await abrirEventoDesdeNotificacion(n);
          } else {
            onIrATab?.call(0);
            await _push(
              CupertinoPageRoute(builder: (_) => const PantallaActividad()),
            );
          }
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
  final recibida = data.recibidas.where((a) => a.idUsuario == idEmisor).toList();
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
        usuario: {
          'id_usuario': idEmisor,
          'perfil_publico': false,
        },
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
