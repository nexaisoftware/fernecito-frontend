/// Modelos del sistema social (amigos / squads).
/// Mapean los jsonb que devuelven los RPCs de la migración social_fundacion.
library;

import '../core/supabase_client.dart';

class Amigo {
  final String? idRelacion;
  final String idUsuario;
  final String username;
  final String nombre;
  final String? fotoPerfilUrl;
  final String? miEstado;
  final String? instagramUrl;
  final String? tiktokUrl;
  final bool perfilPublico;

  const Amigo({
    this.idRelacion,
    required this.idUsuario,
    required this.username,
    required this.nombre,
    this.fotoPerfilUrl,
    this.miEstado,
    this.instagramUrl,
    this.tiktokUrl,
    this.perfilPublico = false,
  });

  factory Amigo.fromMap(Map<String, dynamic> m) => Amigo(
        idRelacion: m['id_relacion']?.toString(),
        idUsuario: m['id_usuario'].toString(),
        username: (m['username'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        fotoPerfilUrl: m['foto_perfil_url'] as String?,
        miEstado: m['mi_estado'] as String?,
        instagramUrl: m['instagram_url'] as String?,
        tiktokUrl: m['tiktok_url'] as String?,
        perfilPublico: m['perfil_publico'] == true,
      );

  /// URL pública del avatar (resuelta desde el path en bucket `avatars`).
  String? get avatarUrl => ServicioSupabase().urlAvatar(fotoPerfilUrl);
}

/// Resultado de `amistad_listar`: amigos + solicitudes recibidas/enviadas.
class AmistadesData {
  final List<Amigo> amigos;
  final List<Amigo> recibidas;
  final List<Amigo> enviadas;

  const AmistadesData({
    this.amigos = const [],
    this.recibidas = const [],
    this.enviadas = const [],
  });

  factory AmistadesData.fromMap(Map<String, dynamic> m) {
    List<Amigo> parse(dynamic v) => (v is List)
        ? v.map((e) => Amigo.fromMap(Map<String, dynamic>.from(e as Map))).toList()
        : const [];
    return AmistadesData(
      amigos: parse(m['amigos']),
      recibidas: parse(m['recibidas']),
      enviadas: parse(m['enviadas']),
    );
  }
}

/// Resultado de `squad_username_disponible`.
class UsernameSquadCheck {
  final bool disponible;
  final String? normalizado;

  /// 'formato_invalido' | 'tomado_squad' | 'tomado_usuario' |
  /// 'rate_limit' | 'no_auth' | 'error' | null
  final String? motivo;

  const UsernameSquadCheck({
    required this.disponible,
    this.normalizado,
    this.motivo,
  });

  /// Mensaje legible para mostrar al usuario según el motivo.
  String get mensaje {
    switch (motivo) {
      case 'tomado_squad':
        return 'Ese @username ya lo usa otro squad';
      case 'tomado_usuario':
        return 'Ese @username ya lo usa un usuario';
      case 'formato_invalido':
        return 'Usá 4-20 caracteres: letras, números o guion bajo';
      case 'rate_limit':
        return 'Demasiados intentos, esperá unos segundos';
      case 'no_auth':
        return 'Iniciá sesión para continuar';
      case 'error':
        return 'No se pudo validar, reintentá';
      default:
        return disponible ? '✓ Username disponible' : 'No disponible';
    }
  }
}

/// Resultado de `buscar_usuarios`.
class UsuarioBusqueda {
  final String idUsuario;
  final String username;
  final String nombre;
  final String? fotoPerfilUrl;

  /// Estado/vibe del usuario (mi_estado en perfiles_usuarios).
  final String? estado;
  final String? instagramUrl;
  final String? tiktokUrl;
  final bool perfilPublico;

  /// 'amigo' | 'enviada' | 'recibida' | 'ninguno'
  final String estadoAmistad;

  const UsuarioBusqueda({
    required this.idUsuario,
    required this.username,
    required this.nombre,
    this.fotoPerfilUrl,
    this.estado,
    this.instagramUrl,
    this.tiktokUrl,
    this.perfilPublico = false,
    this.estadoAmistad = 'ninguno',
  });

  factory UsuarioBusqueda.fromMap(Map<String, dynamic> m) => UsuarioBusqueda(
        idUsuario: m['id_usuario'].toString(),
        username: (m['username'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        fotoPerfilUrl: m['foto_perfil_url'] as String?,
        estado: m['mi_estado'] as String?,
        instagramUrl: m['instagram_url'] as String?,
        tiktokUrl: m['tiktok_url'] as String?,
        perfilPublico: m['perfil_publico'] == true,
        estadoAmistad: (m['estado_amistad'] as String?) ?? 'ninguno',
      );

  String? get avatarUrl => ServicioSupabase().urlAvatar(fotoPerfilUrl);
}

/// Página de `explorar_usuarios_ciudad`.
class ExplorarUsuariosPagina {
  final List<UsuarioBusqueda> items;
  final bool hayMas;
  final String? error;

  const ExplorarUsuariosPagina({
    this.items = const [],
    this.hayMas = false,
    this.error,
  });
}

/// Squad en exploración por ciudad (`explorar_squads_ciudad`).
class SquadExplorarItem {
  final String idGrupo;
  final String nombre;
  final String? urlPortada;
  final String? fechaActualizacion;
  final int cantidadMiembros;
  final String miEstado;
  final List<String?> fotosMiembros;

  const SquadExplorarItem({
    required this.idGrupo,
    required this.nombre,
    this.urlPortada,
    this.fechaActualizacion,
    this.cantidadMiembros = 0,
    this.miEstado = 'ninguno',
    this.fotosMiembros = const [],
  });

  factory SquadExplorarItem.fromMap(Map<String, dynamic> m) {
    final avatarsRaw = m['avatares_miembros'];
    final fotos = avatarsRaw is List
        ? avatarsRaw.map((e) => e?.toString()).toList()
        : const <String?>[];
    return SquadExplorarItem(
      idGrupo: m['id_grupo'].toString(),
      nombre: (m['nombre_grupo'] as String?) ?? 'Squad',
      urlPortada: m['url_portada'] as String?,
      fechaActualizacion: m['fecha_actualizacion']?.toString(),
      cantidadMiembros: (m['cantidad_miembros'] as num?)?.toInt() ?? 0,
      miEstado: (m['mi_estado'] as String?) ?? 'ninguno',
      fotosMiembros: fotos,
    );
  }

  List<String> get avataresResueltos => fotosMiembros
      .map((p) => ServicioSupabase().urlAvatar(p))
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .toList();

  String? get portadaUrl => ServicioSupabase().urlPortadaSquadDisplay(
        urlPortada,
        version: fechaActualizacion,
        fallbackSeed: urlPortada ?? idGrupo,
      );

  String? get portadaCacheKey => portadaUrl;

  int get miembrosExtra =>
      cantidadMiembros > 3 ? cantidadMiembros - 3 : 0;
}

class ExplorarSquadsPagina {
  final List<SquadExplorarItem> items;
  final bool hayMas;
  final String? error;

  const ExplorarSquadsPagina({
    this.items = const [],
    this.hayMas = false,
    this.error,
  });
}

/// Resultado de `buscar_squads`.
class SquadBusqueda {
  final String idGrupo;
  final String nombre;
  final String? descripcion;
  final String? urlPortada;
  final String? vibe;
  final bool esPublico;
  final String? idCreador;
  final int cantidadMiembros;

  /// 'aceptado' | 'pendiente' | 'rechazado' | 'ninguno'
  final String miEstado;

  const SquadBusqueda({
    required this.idGrupo,
    required this.nombre,
    this.descripcion,
    this.urlPortada,
    this.vibe,
    this.esPublico = true,
    this.idCreador,
    this.cantidadMiembros = 0,
    this.miEstado = 'ninguno',
  });

  factory SquadBusqueda.fromMap(Map<String, dynamic> m) => SquadBusqueda(
        idGrupo: m['id_grupo'].toString(),
        nombre: (m['nombre_grupo'] as String?) ?? 'Squad',
        descripcion: m['descripcion_grupo'] as String?,
        urlPortada: m['url_portada'] as String?,
        vibe: m['vibe_grupo'] as String?,
        esPublico: m['es_publico'] == true,
        idCreador: m['id_creador']?.toString(),
        cantidadMiembros: (m['cantidad_miembros'] as num?)?.toInt() ?? 0,
        miEstado: (m['mi_estado'] as String?) ?? 'ninguno',
      );
}

/// Squad en listados (mis squads / invitaciones).
class SquadResumen {
  final String idGrupo;
  final String nombre;
  final String? username;
  final String? descripcion;
  final String? urlPortada;
  final String? estado;
  final String? vibe;
  final bool esPublico;
  final String? idCreador;
  final String? miRol;
  final bool soyLider;
  final int cantidadMiembros;

  /// Paths (bucket avatars) de hasta 3 miembros para el stack de la card.
  final List<String?> fotosMiembros;

  const SquadResumen({
    required this.idGrupo,
    required this.nombre,
    this.username,
    this.descripcion,
    this.urlPortada,
    this.estado,
    this.vibe,
    this.esPublico = false,
    this.idCreador,
    this.miRol,
    this.soyLider = false,
    this.cantidadMiembros = 0,
    this.fotosMiembros = const [],
  });

  factory SquadResumen.fromMap(Map<String, dynamic> m) {
    final avatarsRaw = m['avatares_miembros'];
    final fotos = avatarsRaw is List
        ? avatarsRaw.map((e) => e?.toString()).toList()
        : const <String?>[];
    return SquadResumen(
      idGrupo: m['id_grupo'].toString(),
      nombre: (m['nombre_grupo'] as String?) ?? 'Squad',
      username: m['username'] as String?,
      descripcion: m['descripcion_grupo'] as String?,
      urlPortada: m['url_portada'] as String?,
      estado: m['estado_grupo'] as String?,
      vibe: m['vibe_grupo'] as String?,
      esPublico: m['es_publico'] == true,
      idCreador: m['id_creador']?.toString(),
      miRol: m['mi_rol'] as String?,
      soyLider: m['soy_lider'] == true,
      cantidadMiembros: (m['cantidad_miembros'] as num?)?.toInt() ?? 0,
      fotosMiembros: fotos,
    );
  }

  /// URLs públicas resueltas de los avatares de miembros (para el stack).
  List<String> get avataresMiembros => fotosMiembros
      .map((p) => ServicioSupabase().urlAvatar(p))
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .toList();

  /// Portada resuelta (soporta path o URL absoluta).
  String? get portadaUrl => ServicioSupabase().urlPortadaSquadDisplay(
        urlPortada,
        fallbackSeed: urlPortada ?? idGrupo,
      );

  /// Puede invitar gente (líder o admin del squad).
  bool get puedeInvitar =>
      soyLider || miRol == 'admin' || miRol == 'lider';
}

class MiembroSquad {
  final String idUsuario;
  final String username;
  final String nombre;
  final String? fotoPerfilUrl;
  final String rol; // 'lider' | 'admin' | 'miembro'

  /// Estado/vibe del miembro (mi_estado en perfiles_usuarios; null si perfil privado).
  final String? estado;
  final String? instagramUrl;
  final String? tiktokUrl;
  final bool perfilPublico;

  /// 'invitacion' (admin invitó) | 'solicitud' (pidió unirse) — solo si pendiente.
  final String? origenPendiente;

  const MiembroSquad({
    required this.idUsuario,
    required this.username,
    required this.nombre,
    this.fotoPerfilUrl,
    this.rol = 'miembro',
    this.estado,
    this.instagramUrl,
    this.tiktokUrl,
    this.perfilPublico = false,
    this.origenPendiente,
  });

  factory MiembroSquad.fromMap(Map<String, dynamic> m) => MiembroSquad(
        idUsuario: m['id_usuario'].toString(),
        username: (m['username'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        fotoPerfilUrl: m['foto_perfil_url'] as String?,
        rol: (m['rol_miembro'] as String?) ?? 'miembro',
        estado: m['mi_estado'] as String?,
        instagramUrl: m['instagram_url'] as String?,
        tiktokUrl: m['tiktok_url'] as String?,
        perfilPublico: m['perfil_publico'] == true,
        origenPendiente: m['origen_pendiente'] as String?,
      );

  bool get esPedidoUnion => origenPendiente == 'solicitud';
  bool get esInvitacionEnviada => origenPendiente == 'invitacion' || origenPendiente == null;

  bool get esLider => rol == 'lider';
  bool get esAdmin => rol == 'admin' || rol == 'lider';

  String? get avatarUrl => ServicioSupabase().urlAvatar(fotoPerfilUrl);
}

/// Detalle de un squad (de `squad_detalle`).
class SquadDetalle {
  final String idGrupo;
  final String nombre;
  final String? username;
  final String? descripcion;
  final String? urlPortada;
  final String? fechaActualizacion;
  final String? estado;
  final String? vibe;
  final bool esPublico;
  final String? idCreador;
  final bool soyLider;

  /// Mi relación con el squad: 'aceptado' | 'pendiente' | 'rechazado' | 'ninguno'.
  final String miEstado;
  final List<MiembroSquad> miembros;

  const SquadDetalle({
    required this.idGrupo,
    required this.nombre,
    this.username,
    this.descripcion,
    this.urlPortada,
    this.fechaActualizacion,
    this.estado,
    this.vibe,
    this.esPublico = false,
    this.idCreador,
    this.soyLider = false,
    this.miEstado = 'ninguno',
    this.miembros = const [],
  });

  factory SquadDetalle.fromMap(Map<String, dynamic> m) => SquadDetalle(
        idGrupo: m['id_grupo'].toString(),
        nombre: (m['nombre_grupo'] as String?) ?? 'Squad',
        username: m['username'] as String?,
        descripcion: m['descripcion_grupo'] as String?,
        urlPortada: m['url_portada'] as String?,
        fechaActualizacion: m['fecha_actualizacion']?.toString(),
        estado: m['estado_grupo'] as String?,
        vibe: m['vibe_grupo'] as String?,
        esPublico: m['es_publico'] == true,
        idCreador: m['id_creador']?.toString(),
        soyLider: m['soy_lider'] == true,
        miEstado: (m['mi_estado'] as String?) ?? 'ninguno',
        miembros: (m['miembros'] is List)
            ? (m['miembros'] as List)
                .map((e) => MiembroSquad.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
      );

  bool puedeAdministrar(String? uidUsuario) {
    if (uidUsuario == null) return soyLider;
    if (soyLider || idCreador == uidUsuario) return true;
    return miembros.any((m) => m.idUsuario == uidUsuario && m.esAdmin);
  }

  bool get soyMiembroAceptado => miEstado == 'aceptado';

  /// Portada resuelta con bust de caché (`?v=fecha_actualizacion`).
  String? get portadaUrl => ServicioSupabase().urlPortadaSquadDisplay(
        urlPortada,
        version: fechaActualizacion,
        fallbackSeed: urlPortada ?? idGrupo,
      );

  String? get portadaCacheKey => portadaUrl;

  /// URLs de avatar de miembros (hasta los que devuelve `squad_detalle`).
  List<String> get avataresMiembros => miembros
      .map((m) => m.avatarUrl)
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .toList();
}
