/// Navegación al rompehielo: modal de identidad solo al iniciar fila nueva.
library;

import 'package:flutter/cupertino.dart';

import '../models/rompehielo.dart';
import '../models/social.dart';
import '../PANTALLAS/pantalla_rompehielo.dart';
import '../widgets/modal_identidad_rompehielo.dart';
import 'servicio_rompehielo.dart';
import 'servicio_squads.dart';
import 'supabase_client.dart';

/// Involucramiento en una fila (yo o un squad propio).
class RompehieloInvolucramiento {
  final String? idGrupoActor;
  final String etiqueta;
  final RompehieloEstado estado;

  const RompehieloInvolucramiento({
    required this.idGrupoActor,
    required this.etiqueta,
    required this.estado,
  });
}

/// Lista filas existentes con esta contraparte (yo + cada squad propio).
Future<List<RompehieloInvolucramiento>> listarInvolucramientosRompehielo({
  required String otroTipo,
  required String otroId,
}) async {
  if (otroId.isEmpty) return const [];
  final srv = ServicioRompehielo();
  final squads = await ServicioSquads().misSquads();
  final out = <RompehieloInvolucramiento>[];

  final estYo = await srv.estado(otroTipo: otroTipo, otroId: otroId);
  if (estYo.existe) {
    out.add(RompehieloInvolucramiento(
      idGrupoActor: null,
      etiqueta: 'Yo',
      estado: estYo,
    ));
  }

  for (final s in squads) {
    final est = await srv.estado(
      otroTipo: otroTipo,
      otroId: otroId,
      idGrupoActor: s.idGrupo,
    );
    if (est.existe) {
      out.add(RompehieloInvolucramiento(
        idGrupoActor: s.idGrupo,
        etiqueta: s.nombre,
        estado: est,
      ));
    }
  }
  return out;
}

/// Mejor fila para el botón del perfil (responder > replicar > cualquier activa).
RompehieloInvolucramiento? mejorInvolucramiento(
  List<RompehieloInvolucramiento> lista,
) {
  if (lista.isEmpty) return null;
  RompehieloInvolucramiento? pick(bool Function(RompehieloEstado) test) {
    for (final i in lista) {
      if (test(i.estado)) return i;
    }
    return null;
  }
  return pick((e) => e.debeResponder) ??
      pick((e) => e.debeReplicar) ??
      lista.first;
}

Map<String, dynamic> _squadMapDesdeResumen(SquadResumen s) {
  final user = s.username ?? '';
  return {
    'id_grupo': s.idGrupo,
    'nombre': s.nombre,
    'username': user.startsWith('@') ? user : '@$user',
    'avatar': s.portadaUrl ?? '',
    'miembrosAvatares': s.avataresMiembros,
    'miembrosTotal': s.cantidadMiembros,
  };
}

Future<RompehieloModalContexto> _contextoModal() async {
  final sb = ServicioSupabase();
  var miAvatar = '';
  var miUsername = '@yo';
  final uid = sb.usuarioActual?.id;
  if (uid != null) {
    try {
      final perfil = await sb.cliente
          .from('perfiles_usuarios')
          .select('username, foto_perfil_url')
          .eq('id', uid)
          .maybeSingle();
      if (perfil != null) {
        final u = (perfil['username'] as String?)?.trim() ?? '';
        if (u.isNotEmpty) {
          miUsername = u.startsWith('@') ? u : '@$u';
        }
        miAvatar = sb.urlAvatar(perfil['foto_perfil_url']?.toString()) ?? '';
      }
    } catch (_) {}
  }
  return RompehieloModalContexto(
    miAvatar: miAvatar,
    miUsername: miUsername,
  );
}

/// Abre rompehielo: fila existente directo; fila nueva → modal de identidad.
Future<void> abrirRompehielo(
  BuildContext context, {
  required TipoContraparte tipoContraparte,
  required Map<String, dynamic> contraparte,
  RompehieloOrigen origen = RompehieloOrigen.perfil,
  String? idEvento,
  String? nombreEvento,
}) async {
  final otroTipo =
      tipoContraparte == TipoContraparte.usuario ? 'usuario' : 'squad';
  final otroId = tipoContraparte == TipoContraparte.usuario
      ? contraparte['id_usuario']?.toString() ?? ''
      : contraparte['id_grupo']?.toString() ??
          contraparte['id_squad']?.toString() ??
          '';
  if (otroId.isEmpty) return;

  final srv = ServicioRompehielo();
  final misSquads = await ServicioSquads().misSquads();
  final activos = await listarInvolucramientosRompehielo(
    otroTipo: otroTipo,
    otroId: otroId,
  );
  if (!context.mounted) return;

  String? idGrupoActor;
  Map<String, dynamic>? squadActor;
  RompehieloEstado? estadoInicial;
  var identidadFijada = false;

  final idsConFila =
      activos.map((a) => a.idGrupoActor ?? '__yo__').toSet();
  final squadsNuevos =
      misSquads.where((s) => !idsConFila.contains(s.idGrupo)).toList();
  final puedeNuevoYo = !idsConFila.contains('__yo__');
  final hayOpcionesNuevas = puedeNuevoYo || squadsNuevos.isNotEmpty;

  if (activos.length == 1 && !hayOpcionesNuevas) {
    final u = activos.first;
    idGrupoActor = u.idGrupoActor;
    estadoInicial = u.estado;
    identidadFijada = true;
    if (idGrupoActor != null) {
      final s = misSquads.where((x) => x.idGrupo == idGrupoActor).firstOrNull;
      if (s != null) squadActor = _squadMapDesdeResumen(s);
    }
  } else if (activos.isNotEmpty) {
    final modalCtx = await _contextoModal();
    if (!context.mounted) return;
    final res = await mostrarModalOpcionesRompehielo(
      context,
      contexto: modalCtx,
      hilosActivos: activos,
      misSquads: misSquads,
      squadsNuevos: squadsNuevos,
      puedeNuevoYo: puedeNuevoYo,
    );
    if (res == null || !context.mounted) return;
    if (res.esContinuar) {
      idGrupoActor = res.involucramiento!.idGrupoActor;
      estadoInicial = res.involucramiento!.estado;
      identidadFijada = true;
      if (idGrupoActor != null) {
        final s = misSquads.where((x) => x.idGrupo == idGrupoActor).firstOrNull;
        if (s != null) squadActor = _squadMapDesdeResumen(s);
      }
    } else {
      idGrupoActor = res.idGrupoActor;
      squadActor = res.squadMap;
      estadoInicial = await srv.estado(
        otroTipo: otroTipo,
        otroId: otroId,
        idGrupoActor: idGrupoActor,
      );
      identidadFijada = true;
    }
  } else {
    // Sin fila: iniciar nueva → modal de identidad (si hay squads).
    if (misSquads.isEmpty) {
      idGrupoActor = null;
      estadoInicial = await srv.estado(otroTipo: otroTipo, otroId: otroId);
      identidadFijada = true;
    } else {
      final modalCtx = await _contextoModal();
      if (!context.mounted) return;
      final eleccion = await mostrarModalIdentidadRompehielo(
        context,
        contexto: modalCtx,
        squads: misSquads,
      );
      if (eleccion == null || !context.mounted) return;
      idGrupoActor = eleccion.idGrupoActor;
      squadActor = eleccion.squadMap;
      estadoInicial = await srv.estado(
        otroTipo: otroTipo,
        otroId: otroId,
        idGrupoActor: idGrupoActor,
      );
      identidadFijada = true;
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => PantallaRompehielo(
        data: RompehieloData(
          tipoContraparte: tipoContraparte,
          contraparte: contraparte,
          estadoInicial: estadoInicial,
          origen: origen,
          idEvento: idEvento,
          nombreEvento: nombreEvento,
          idGrupoActorInicial: idGrupoActor,
          squadActorInicial: squadActor,
          identidadFijada: identidadFijada,
        ),
      ),
    ),
  );
}

/// Desde notificación: identidad ya definida en la fila, sin modal.
Future<void> abrirRompehieloDesdeNotificacion(
  BuildContext context, {
  required TipoContraparte tipoContraparte,
  required Map<String, dynamic> contraparte,
  required RompehieloEstado estadoInicial,
  String? idGrupoActor,
  Map<String, dynamic>? squadActor,
}) async {
  await Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => PantallaRompehielo(
        data: RompehieloData(
          tipoContraparte: tipoContraparte,
          contraparte: contraparte,
          estadoInicial: estadoInicial,
          idGrupoActorInicial: idGrupoActor,
          squadActorInicial: squadActor,
          identidadFijada: true,
        ),
      ),
    ),
  );
}
