/// Helpers de permisos y mapeo para squads (alineado con RPCs `es_admin_grupo`).
library;

import '../models/notificacion.dart';
import '../models/social.dart';
import 'supabase_client.dart';

/// Líder del grupo o rol `admin`/`lider` en miembros_grupos.
bool squadPuedeInvitar(SquadResumen s) =>
    s.soyLider || s.miRol == 'admin' || s.miRol == 'lider';

bool squadDetallePuedeAdministrar(SquadDetalle d) {
  final uid = ServicioSupabase().usuarioActual?.id;
  if (uid == null) return false;
  if (d.soyLider || d.idCreador == uid) return true;
  for (final m in d.miembros) {
    if (m.idUsuario == uid && m.esAdmin) return true;
  }
  return false;
}

bool squadDetalleSoyMiembroAceptado(SquadDetalle d) => d.miEstado == 'aceptado';

/// Invitación recibida (tab invitaciones / notif) vs pedido enviado por el usuario.
bool notifEsInvitacionSquad(Notificacion n) =>
    n.titulo.contains('Invitación') || n.ctaTexto == 'Ver invitación';

bool notifEsPedidoUnionSquad(Notificacion n) =>
    n.titulo.contains('Pedido') || n.ctaTexto == 'Ver squad';

Map<String, dynamic> mapNavegacionDesdeResumen(
  SquadResumen s, {
  String? miEstado,
}) {
  return {
    'id_grupo': s.idGrupo,
    'id_squad': s.idGrupo,
    'nombre': s.nombre,
    'nombre_squad': s.nombre,
    'username': s.username,
    'descripcion': s.descripcion ?? '',
    'vibe': s.vibe ?? '',
    'avatar': s.portadaUrl ?? '',
    'banner_url': s.portadaUrl,
    'es_publico': s.esPublico,
    'id_creador': s.idCreador,
    'soy_lider': s.soyLider,
    'mi_rol': s.miRol,
    'mi_estado': miEstado,
    'miembros': s.cantidadMiembros,
    'miembrosTotal': s.cantidadMiembros,
    'miembrosAvatares': s.avataresMiembros,
  };
}

Map<String, dynamic> mapNavegacionDesdeDetalle(SquadDetalle d) {
  return {
    'id_grupo': d.idGrupo,
    'id_squad': d.idGrupo,
    'nombre': d.nombre,
    'nombre_squad': d.nombre,
    'username': d.username,
    'descripcion': d.descripcion ?? '',
    'vibe': d.vibe ?? '',
    'avatar': d.portadaUrl ?? '',
    'banner_url': d.portadaUrl,
    'es_publico': d.esPublico,
    'id_creador': d.idCreador,
    'soy_lider': d.soyLider,
    'mi_estado': d.miEstado,
    'miembros': d.miembros.length,
    'miembrosTotal': d.miembros.length,
    'miembrosAvatares': d.avataresMiembros,
  };
}
