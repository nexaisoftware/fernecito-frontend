/// Pantalla Social: Amigos y Squads, solicitudes, búsqueda. Datos reales.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_squads.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import 'pantalla_crear_squad.dart';
import 'pantalla_mis_squads.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';
import '../widgets/busqueda_social_expandible.dart';
import '../widgets/encabezado_amigos_social.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/social_explorar_sheets.dart';
import '../widgets/social_ui.dart';

String _arroba(String username) =>
    username.isEmpty ? '' : (username.startsWith('@') ? username : '@$username');

EstadoRelacionUsuario _estadoUsuarioDesde(String estadoAmistad) {
  switch (estadoAmistad) {
    case 'amigo':
      return EstadoRelacionUsuario.amigo;
    case 'enviada':
      return EstadoRelacionUsuario.solicitudEnviada;
    case 'recibida':
      return EstadoRelacionUsuario.solicitudRecibida;
    default:
      return EstadoRelacionUsuario.ninguno;
  }
}

EstadoRelacionSquad _estadoSquadDesde(
  String? miEstado, {
  bool esInvitacionRecibida = false,
}) {
  switch (miEstado) {
    case 'aceptado':
      return EstadoRelacionSquad.miembro;
    case 'pendiente':
      return esInvitacionRecibida
          ? EstadoRelacionSquad.solicitudPendiente
          : EstadoRelacionSquad.solicitudEnviada;
    default:
      return EstadoRelacionSquad.ninguno;
  }
}

Map<String, dynamic> _mapAmigo(Amigo a, {bool? esEnviada}) => {
      'id_usuario': a.idUsuario,
      'id_relacion': a.idRelacion,
      'nombre': a.nombre,
      'username': _arroba(a.username),
      'avatar': a.avatarUrl ?? '',
      'estado': a.miEstado ?? '',
      'instagram_url': a.instagramUrl ?? '',
      'tiktok_url': a.tiktokUrl ?? '',
      if (esEnviada != null) 'esEnviada': esEnviada,
      'perfil_publico': a.perfilPublico,
    };

Map<String, dynamic> _mapSquadResumen(SquadResumen s) => {
      'id_grupo': s.idGrupo,
      'id_squad': s.idGrupo,
      'nombre': s.nombre,
      'nombre_squad': s.nombre,
      'username': _arroba(s.username ?? ''),
      'descripcion': s.descripcion ?? '',
      'estado': s.vibe ?? s.estado ?? '',
      'estado_squad': s.vibe ?? s.estado ?? '',
      'vibe': s.vibe ?? '',
      'avatar': s.portadaUrl ?? '',
      'banner_url': s.portadaUrl,
      'es_publico': s.esPublico,
      'id_creador': s.idCreador,
      'id_lider': s.idCreador,
      'eresAdmin': s.soyLider,
      'soy_lider': s.soyLider,
      'mi_estado': 'aceptado',
      'mi_rol': s.miRol,
      'miembros': s.cantidadMiembros,
      'miembrosAvatares': s.avataresMiembros,
    };

Map<String, dynamic> _mapInvitacionSquad(SquadResumen s) {
  final map = _mapSquadResumen(s);
  map['mi_estado'] = 'pendiente';
  map['es_invitacion_recibida'] = true;
  return map;
}

class PantallaSocial extends StatefulWidget {
  final int initialTabIndex;

  const PantallaSocial({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<PantallaSocial> createState() => _PantallaSocialState();
}

class _PantallaSocialState extends State<PantallaSocial> {
  late int _tabIndex;

  final ServicioAmigos _srvAmigos = ServicioAmigos();
  final ServicioSquads _srvSquads = ServicioSquads();

  AmistadesData _amistades = const AmistadesData();
  List<SquadResumen> _misSquads = const [];
  List<SquadResumen> _invitaciones = const [];

  bool _cargandoAmigos = true;
  bool _cargandoSquads = true;
  String? _solicitudProcesandoKey;
  String? _squadProcesandoId;

  String _claveSolicitud(Map<String, dynamic> s) =>
      s['id_relacion']?.toString() ?? s['id_usuario']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
    _cargarAmigos();
    _cargarSquads();
  }

  Future<void> _cargarAmigos({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargandoAmigos = true);
    final data = await _srvAmigos.listar();
    if (mounted) {
      setState(() {
        _amistades = data;
        _cargandoAmigos = false;
      });
    }
  }

  void _quitarSolicitudLocal(String idUsuario) {
    setState(() {
      _amistades = AmistadesData(
        amigos: _amistades.amigos,
        recibidas: _amistades.recibidas
            .where((a) => a.idUsuario != idUsuario)
            .toList(),
        enviadas: _amistades.enviadas
            .where((a) => a.idUsuario != idUsuario)
            .toList(),
      );
    });
  }

  Future<void> _cargarSquads() async {
    if (mounted) setState(() => _cargandoSquads = true);
    final mios = await _srvSquads.misSquads();
    final invs = await _srvSquads.invitaciones();
    if (mounted) {
      setState(() {
        _misSquads = mios;
        _invitaciones = invs;
        _cargandoSquads = false;
      });
    }
  }

  // —— Acciones amigos ——

  Future<void> _aceptarAmigo(Map<String, dynamic> solicitud) async {
    final clave = _claveSolicitud(solicitud);
    if (clave.isEmpty || _solicitudProcesandoKey != null) return;

    setState(() => _solicitudProcesandoKey = clave);
    var ok = false;

    try {
      final idRelacion = solicitud['id_relacion']?.toString();
      if (idRelacion != null && idRelacion.isNotEmpty) {
        ok = await _srvAmigos.responder(idRelacion, aceptar: true);
      }

      if (!ok) {
        final idUsuario = solicitud['id_usuario']?.toString();
        if (idUsuario != null && idUsuario.isNotEmpty) {
          final estado = await _srvAmigos.solicitar(idUsuario);
          ok = estado == 'aceptada' || estado == 'aceptado';
        }
      }

      if (!ok) {
        if (mounted) {
          _mostrarError('No se pudo aceptar la solicitud. Intentá de nuevo.');
        }
        return;
      }

      final idUsuario = solicitud['id_usuario']?.toString();
      if (idUsuario != null && idUsuario.isNotEmpty) {
        _quitarSolicitudLocal(idUsuario);
      }
      await _cargarAmigos(silencioso: true);
    } finally {
      if (mounted) setState(() => _solicitudProcesandoKey = null);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _rechazarAmigo(String? idRelacion, {String? idUsuario}) async {
    if (idRelacion == null || idRelacion.isEmpty) return;
    final clave = idRelacion;
    if (_solicitudProcesandoKey != null) return;

    setState(() => _solicitudProcesandoKey = clave);
    try {
      final ok = await _srvAmigos.responder(idRelacion, aceptar: false);
      if (ok) {
        if (idUsuario != null && idUsuario.isNotEmpty) {
          _quitarSolicitudLocal(idUsuario);
        }
        await _cargarAmigos(silencioso: true);
      }
    } finally {
      if (mounted) setState(() => _solicitudProcesandoKey = null);
    }
  }

  Future<void> _cancelarSolicitudAmigo(String idUsuario) async {
    if (_solicitudProcesandoKey != null) return;
    setState(() => _solicitudProcesandoKey = idUsuario);
    try {
      final ok = await _srvAmigos.eliminar(idUsuario);
      if (ok) {
        _quitarSolicitudLocal(idUsuario);
        await _cargarAmigos(silencioso: true);
      }
    } finally {
      if (mounted) setState(() => _solicitudProcesandoKey = null);
    }
  }

  // —— Acciones squads ——

  void _quitarInvitacionLocal(String idGrupo) {
    setState(() {
      _invitaciones =
          _invitaciones.where((s) => s.idGrupo != idGrupo).toList();
    });
  }

  Future<void> _responderInvitacion(String idGrupo, {required bool aceptar}) async {
    if (_squadProcesandoId != null) return;
    setState(() => _squadProcesandoId = idGrupo);
    try {
      final ok =
          await _srvSquads.responderInvitacion(idGrupo, aceptar: aceptar);
      if (!ok) {
        if (mounted) {
          _mostrarError('No se pudo ${aceptar ? 'aceptar' : 'rechazar'} la invitación.');
        }
        return;
      }
      _quitarInvitacionLocal(idGrupo);
      await _cargarSquads();
    } finally {
      if (mounted) setState(() => _squadProcesandoId = null);
    }
  }

  Map<String, dynamic> _mapUsuarioBusqueda(UsuarioBusqueda u) => {
        'id_usuario': u.idUsuario,
        'nombre': u.nombre,
        'username': _arroba(u.username),
        'avatar': u.avatarUrl ?? '',
        'estado': u.estado ?? '',
        'instagram_url': u.instagramUrl ?? '',
        'tiktok_url': u.tiktokUrl ?? '',
        'estado_amistad': u.estadoAmistad,
        'perfil_publico': u.perfilPublico,
      };

  Map<String, dynamic> _mapSquadExplorar(SquadExplorarItem s) => {
        'id_grupo': s.idGrupo,
        'id_squad': s.idGrupo,
        'nombre': s.nombre,
        'nombre_squad': s.nombre,
        'avatar': s.portadaUrl ?? '',
        'banner_url': s.portadaUrl,
        'miembros': s.cantidadMiembros,
        'es_publico': true,
        'mi_estado': s.miEstado,
        'miembrosAvatares': s.avataresResueltos,
      };

  void _abrirCrearSquad(BuildContext context) {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const PantallaCrearSquad()))
        .then((_) => _cargarSquads());
  }

  void _abrirPerfilUsuario(
    BuildContext context,
    Map<String, dynamic> usuario, {
    required EstadoRelacionUsuario estadoRelacion,
  }) {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(
            builder: (_) => PantallaPerfilUsuarios(
              usuario: usuario,
              estadoRelacion: estadoRelacion,
              rompehieloOrigen: RompehieloOrigen.explorar,
            ),
          ),
        )
        .then((_) => _cargarAmigos(silencioso: true));
  }

  void _abrirPerfilSquad(
    BuildContext context,
    Map<String, dynamic> squad, {
    required EstadoRelacionSquad estado,
  }) {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(
            builder: (_) => PantallaPerfilSquads(
              squad: squad,
              estadoRelacion: estado,
              rompehieloOrigen: RompehieloOrigen.explorar,
            ),
          ),
        )
        .then((_) => _cargarSquads());
  }

  void _abrirMisSquad(BuildContext context, Map<String, dynamic> squad) {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => PantallaMisSquads(squad: squad)))
        .then((_) => _cargarSquads());
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    final idsAmigos =
        _amistades.amigos.map((a) => a.idUsuario).toSet();
    final solicitudesAmigos = <Map<String, dynamic>>[
      ..._amistades.recibidas
          .where((a) => !idsAmigos.contains(a.idUsuario))
          .map((a) => _mapAmigo(a, esEnviada: false)),
      ..._amistades.enviadas.map((a) => _mapAmigo(a, esEnviada: true)),
    ];
    final amigos = _amistades.amigos.map((a) => _mapAmigo(a)).toList();

    final solicitudesSquads =
        _invitaciones.map(_mapInvitacionSquad).toList();
    final misGrupos = _misSquads.map((s) => _mapSquadResumen(s)).toList();

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, padding.top + 14, 20, 0),
              child: ToggleSegmentadoSocial(
                opciones: const ['Amigos', 'Squads'],
                indice: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _TabAmigos(
                    solicitudes: solicitudesAmigos,
                    amigos: amigos,
                    cargando: _cargandoAmigos,
                    solicitudProcesandoKey: _solicitudProcesandoKey,
                    srvAmigos: _srvAmigos,
                    onRefresh: () => _cargarAmigos(silencioso: true),
                    onAceptar: _aceptarAmigo,
                    onCancelarRechazar: (s) {
                      final esEnviada = s['esEnviada'] as bool? ?? false;
                      if (esEnviada) {
                        _cancelarSolicitudAmigo(s['id_usuario'] as String);
                      } else {
                        _rechazarAmigo(
                          s['id_relacion']?.toString(),
                          idUsuario: s['id_usuario']?.toString(),
                        );
                      }
                    },
                    onAbrirPerfil: (s, estado) =>
                        _abrirPerfilUsuario(context, s, estadoRelacion: estado),
                    onExplorar: () => mostrarExplorarPersonasSheet(
                      context,
                      onPerfil: (u) => _abrirPerfilUsuario(
                        context,
                        _mapUsuarioBusqueda(u),
                        estadoRelacion:
                            _estadoUsuarioDesde(u.estadoAmistad),
                      ),
                    ),
                  ),
                  _TabSquads(
                    solicitudes: solicitudesSquads,
                    misGrupos: misGrupos,
                    cargando: _cargandoSquads,
                    srvSquads: _srvSquads,
                    onRefresh: _cargarSquads,
                    onCrearSquad: () => _abrirCrearSquad(context),
                    onExplorar: () => mostrarExplorarSquadsSheet(
                      context,
                      onSquad: (s) => _abrirPerfilSquad(
                        context,
                        _mapSquadExplorar(s),
                        estado: _estadoSquadDesde(s.miEstado),
                      ),
                    ),
                    squadProcesandoId: _squadProcesandoId,
                    onAbrirPerfilSquad: (s) => _abrirPerfilSquad(
                      context,
                      s,
                      estado: _estadoSquadDesde(
                        s['mi_estado'] as String?,
                        esInvitacionRecibida:
                            s['es_invitacion_recibida'] == true,
                      ),
                    ),
                    onAceptarInvitacion: (s) => _responderInvitacion(
                        s['id_grupo'] as String,
                        aceptar: true),
                    onRechazarInvitacion: (s) => _responderInvitacion(
                        s['id_grupo'] as String,
                        aceptar: false),
                    onAbrirMisSquad: (s) => _abrirMisSquad(context, s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabAmigos extends StatefulWidget {
  final List<Map<String, dynamic>> solicitudes;
  final List<Map<String, dynamic>> amigos;
  final bool cargando;
  final String? solicitudProcesandoKey;
  final ServicioAmigos srvAmigos;
  final VoidCallback onExplorar;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onAceptar;
  final void Function(Map<String, dynamic>) onCancelarRechazar;
  final void Function(Map<String, dynamic>, EstadoRelacionUsuario) onAbrirPerfil;

  const _TabAmigos({
    required this.solicitudes,
    required this.amigos,
    required this.cargando,
    this.solicitudProcesandoKey,
    required this.srvAmigos,
    required this.onExplorar,
    required this.onRefresh,
    required this.onAceptar,
    required this.onCancelarRechazar,
    required this.onAbrirPerfil,
  });

  @override
  State<_TabAmigos> createState() => _TabAmigosState();
}

class _TabAmigosState extends State<_TabAmigos> {
  List<UsuarioBusqueda> _resultados = [];
  bool _buscando = false;
  String _ultimaQuery = '';

  Future<void> _onBuscar(String q) async {
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _resultados = [];
          _ultimaQuery = '';
          _buscando = false;
        });
      }
      return;
    }
    if (q == _ultimaQuery && _resultados.isNotEmpty) return;
    setState(() {
      _buscando = true;
      _ultimaQuery = q;
    });
    final res = await widget.srvAmigos.buscar(q);
    if (!mounted || _ultimaQuery != q) return;
    setState(() {
      _resultados = res;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrandoBusqueda = _ultimaQuery.length >= 2;

    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      color: ColoresApp.principalMarca,
      backgroundColor: ColoresApp.fondoSuperficie,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        children: [
        BusquedaSocialExpandible(
          hint: 'Buscar',
          onQueryChanged: _onBuscar,
          flexBarraColapsada: 5,
          flexPorAccionColapsada: 3,
          accionesColapsado: [
            BotonExplorarSocial(onTap: widget.onExplorar),
          ],
        ),
        if (!mostrandoBusqueda) const SizedBox(height: 12),
        if (_buscando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (mostrandoBusqueda) ...[
          const SizedBox(height: 12),
          EncabezadoSeccionSocial(
            titulo: 'Resultados',
            subtitulo: _resultados.isEmpty
                ? 'Sin coincidencias — probá otro nombre'
                : '${_resultados.length} encontrados',
          ),
          if (_resultados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No encontramos a nadie con "$_ultimaQuery"',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            )
          else
            ..._resultados.map((u) {
              final raw = {
                'id_usuario': u.idUsuario,
                'nombre': u.nombre,
                'username': _arroba(u.username),
                'avatar': u.avatarUrl ?? '',
                'estado': u.estado ?? '',
                'instagram_url': u.instagramUrl ?? '',
                'tiktok_url': u.tiktokUrl ?? '',
                'estado_amistad': u.estadoAmistad,
                'perfil_publico': u.perfilPublico,
              };
              final candado = PrivacidadPerfil.mostrarCandadoEnBusqueda(
                perfilPublico: u.perfilPublico,
              );
              return CardSuperficieSocial(
                onTap: () => widget.onAbrirPerfil(
                  raw,
                  _estadoUsuarioDesde(u.estadoAmistad),
                ),
                child: Row(
                  children: [
                    AvatarSocialPrivacidad(
                      url: u.avatarUrl ?? '',
                      size: 48,
                      mostrarCandado: candado,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PrivacidadPerfil.nombreEnBusqueda(
                              perfilPublico: u.perfilPublico,
                              nombre: u.nombre,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ChipSocial(texto: _arroba(u.username)),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 16, color: ColoresApp.textoSecundario),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
        if (!mostrandoBusqueda && widget.cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (!mostrandoBusqueda) ...[
          if (widget.solicitudes.isNotEmpty) ...[
            const EncabezadoSeccionSocial(
              titulo: 'Solicitudes',
              subtitulo: 'Pendientes de respuesta',
            ),
            ...widget.solicitudes.map(
              (s) {
                final clave = s['id_relacion']?.toString() ??
                    s['id_usuario']?.toString() ??
                    '';
                final esEnviada = s['esEnviada'] as bool? ?? false;
                final yaAceptado = !esEnviada &&
                    widget.amigos.any(
                      (a) => a['id_usuario'] == s['id_usuario'],
                    );
                return _CardSolicitudAmigo(
                  solicitud: s,
                  procesando: widget.solicitudProcesandoKey == clave,
                  yaAceptado: yaAceptado,
                  onAceptar: () => widget.onAceptar(s),
                  onCancelar: () => widget.onCancelarRechazar(s),
                  onVerPerfil: () => widget.onAbrirPerfil(
                    s,
                    esEnviada
                        ? EstadoRelacionUsuario.solicitudEnviada
                        : EstadoRelacionUsuario.solicitudRecibida,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          if (widget.amigos.isNotEmpty)
            EncabezadoAmigosCentrado(cantidad: widget.amigos.length),
          if (widget.amigos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Todavía no tenés amigos. Explorá por ciudad o buscá por nombre.',
                style: GoogleFonts.baloo2(
                    fontSize: 14, color: ColoresApp.textoSecundario),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...widget.amigos.map((a) => _CardAmigo(
                  amigo: a,
                  onTap: () =>
                      widget.onAbrirPerfil(a, EstadoRelacionUsuario.amigo),
                )),
        ],
      ],
      ),
    );
  }
}

class _CardSolicitudAmigo extends StatelessWidget {
  final Map<String, dynamic> solicitud;
  final bool procesando;
  final bool yaAceptado;
  final VoidCallback onAceptar;
  final VoidCallback onCancelar;
  final VoidCallback onVerPerfil;

  const _CardSolicitudAmigo({
    required this.solicitud,
    this.procesando = false,
    this.yaAceptado = false,
    required this.onAceptar,
    required this.onCancelar,
    required this.onVerPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final esEnviada = solicitud['esEnviada'] as bool? ?? false;
    final esPrivadaRecibida = PrivacidadPerfil.solicitudRecibidaPrivada(solicitud);

    return CardSuperficieSocial(
      onTap: onVerPerfil,
      destacada: !esEnviada && !yaAceptado,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AvatarSocialPrivacidad(
              url: solicitud['avatar'] as String? ?? '',
              size: 44,
              mostrarCandado: esPrivadaRecibida,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esPrivadaRecibida
                        ? PrivacidadPerfil.tituloPerfilPrivado
                        : (solicitud['nombre'] as String? ?? 'Usuario'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    esPrivadaRecibida
                        ? (solicitud['username'] as String? ?? '@usuario')
                        : (solicitud['username'] as String? ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            if (esEnviada)
              SizedBox(
                width: 86,
                child: CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: ColoresApp.fondoPrincipal,
                  borderRadius: BorderRadius.circular(50),
                  onPressed: procesando ? null : onCancelar,
                  child: procesando
                      ? const CupertinoActivityIndicator(radius: 8)
                      : Text('Cancelar',
                          style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.textoPrincipal)),
                ),
              )
            else if (yaAceptado)
              SizedBox(
                width: 88,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(50),
                  onPressed: null,
                  child: Text(
                    'Aceptaste',
                    style: GoogleFonts.baloo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 82,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      color: ColoresApp.principalMarca,
                      borderRadius: BorderRadius.circular(50),
                      onPressed: procesando ? null : onAceptar,
                      child: procesando
                          ? const CupertinoActivityIndicator(
                              radius: 7, color: Colors.white)
                          : Text(
                              'Aceptar',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 82,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      onPressed: procesando ? null : onCancelar,
                      child: Text(
                        'Rechazar',
                        style: GoogleFonts.baloo2(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
    );
  }
}

class _CardAmigo extends StatelessWidget {
  final Map<String, dynamic> amigo;
  final VoidCallback onTap;

  const _CardAmigo({required this.amigo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ColoresApp.textoSecundario.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: Row(
          children: [
            AvatarSocial(url: amigo['avatar'] as String? ?? '', size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amigo['nombre'] as String? ?? 'Usuario',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    amigo['username'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

// —— Tab Squads ——

class _TabSquads extends StatefulWidget {
  final List<Map<String, dynamic>> solicitudes;
  final List<Map<String, dynamic>> misGrupos;
  final bool cargando;
  final ServicioSquads srvSquads;
  final VoidCallback onCrearSquad;
  final VoidCallback onExplorar;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onAbrirPerfilSquad;
  final void Function(Map<String, dynamic>) onAceptarInvitacion;
  final void Function(Map<String, dynamic>) onRechazarInvitacion;
  final void Function(Map<String, dynamic>) onAbrirMisSquad;
  final String? squadProcesandoId;

  const _TabSquads({
    required this.solicitudes,
    required this.misGrupos,
    this.cargando = false,
    required this.srvSquads,
    required this.onCrearSquad,
    required this.onExplorar,
    required this.onRefresh,
    required this.onAbrirPerfilSquad,
    required this.onAceptarInvitacion,
    required this.onRechazarInvitacion,
    required this.onAbrirMisSquad,
    this.squadProcesandoId,
  });

  @override
  State<_TabSquads> createState() => _TabSquadsState();
}

class _TabSquadsState extends State<_TabSquads> {
  List<SquadBusqueda> _resultados = [];
  bool _buscando = false;
  String _ultimaQuery = '';

  Future<void> _onBuscar(String q) async {
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _resultados = [];
          _ultimaQuery = '';
          _buscando = false;
        });
      }
      return;
    }
    if (q == _ultimaQuery && _resultados.isNotEmpty) return;
    setState(() {
      _buscando = true;
      _ultimaQuery = q;
    });
    final res = await widget.srvSquads.buscar(q);
    if (!mounted || _ultimaQuery != q) return;
    setState(() {
      _resultados = res;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrandoBusqueda = _ultimaQuery.length >= 2;

    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      color: ColoresApp.principalMarca,
      backgroundColor: ColoresApp.fondoSuperficie,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(20, 6, 20, MediaQuery.paddingOf(context).bottom + 100),
      children: [
        BusquedaSocialExpandible(
          hint: 'Nombre del squad',
          onQueryChanged: _onBuscar,
          flexBarraColapsada: 4,
          flexPorAccionColapsada: 3,
          accionesColapsado: [
            BotonSquadMasSocial(onTap: widget.onCrearSquad),
            BotonExplorarSocial(onTap: widget.onExplorar),
          ],
        ),
        if (!mostrandoBusqueda) const SizedBox(height: 12),
        if (_buscando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (mostrandoBusqueda) ...[
          const SizedBox(height: 12),
          EncabezadoSeccionSocial(
            titulo: 'Resultados',
            subtitulo: _resultados.isEmpty
                ? 'Sin coincidencias'
                : '${_resultados.length} squads',
          ),
          ..._resultados.map((s) {
            final raw = {
              'id_grupo': s.idGrupo,
              'id_squad': s.idGrupo,
              'nombre': s.nombre,
              'descripcion': s.descripcion ?? '',
              'vibe': s.vibe ?? '',
              'avatar': s.urlPortada ?? '',
              'miembros': s.cantidadMiembros,
              'es_publico': s.esPublico,
              'id_creador': s.idCreador,
              'mi_estado': s.miEstado,
              'miembrosAvatares': const <String>[],
            };
            return CardSuperficieSocial(
              onTap: () => widget.onAbrirPerfilSquad(
                raw,
              ),
              child: Row(
                children: [
                  AvatarSocial(url: s.urlPortada ?? '', size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.nombre,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        Text(
                          '${s.cantidadMiembros} miembros',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 16, color: ColoresApp.textoSecundario),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (!mostrandoBusqueda && widget.cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (!mostrandoBusqueda) ...[
          if (widget.solicitudes.isNotEmpty) ...[
            const EncabezadoSeccionSocial(
              titulo: 'Invitaciones',
              subtitulo: 'Te invitaron a unirte',
            ),
            ...widget.solicitudes.map((s) {
              final idGrupo = s['id_grupo']?.toString() ?? '';
              final procesando = widget.squadProcesandoId == idGrupo;
              return _CardSolicitudSquad(
                squad: s,
                procesando: procesando,
                onVerGrupo: () => widget.onAbrirPerfilSquad(s),
                onRechazar: () => widget.onRechazarInvitacion(s),
                onUnirse: () => widget.onAceptarInvitacion(s),
              );
            }),
            const SizedBox(height: 20),
          ],
          if (widget.misGrupos.isNotEmpty)
            EncabezadoSquadsCentrado(cantidad: widget.misGrupos.length),
          if (widget.misGrupos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Todavía no tenés squads. Creá uno o explorá por ciudad.',
                style: GoogleFonts.baloo2(
                    fontSize: 14, color: ColoresApp.textoSecundario),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...widget.misGrupos.map((g) => _CardMiGrupo(
                  grupo: g,
                  onTap: () => widget.onAbrirMisSquad(g),
                )),
        ],
      ],
      ),
    );
  }
}

class _CardSolicitudSquad extends StatelessWidget {
  final Map<String, dynamic> squad;
  final bool procesando;
  final VoidCallback onVerGrupo;
  final VoidCallback onRechazar;
  final VoidCallback onUnirse;

  const _CardSolicitudSquad({
    required this.squad,
    this.procesando = false,
    required this.onVerGrupo,
    required this.onRechazar,
    required this.onUnirse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onVerGrupo,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18).copyWith(
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              squad['nombre'] as String? ?? 'Grupo',
              style: GoogleFonts.baloo2(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _StackAvataresMiembros(
                  avatares:
                      List<String>.from(squad['miembrosAvatares'] as List? ?? []),
                  totalMiembros: squad['miembros'] as int? ?? 0,
                ),
                const SizedBox(width: 10),
                Text(
                  '${squad['miembros']} miembros',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: ColoresApp.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    color: ColoresApp.fondoPrincipal,
                    borderRadius: BorderRadius.circular(50),
                    onPressed: procesando ? null : onRechazar,
                    child: Text(
                      'Rechazar',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(50),
                    onPressed: procesando ? null : onUnirse,
                    child: procesando
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(
                            'Unirse',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StackAvataresMiembros extends StatelessWidget {
  final List<String> avatares;
  final int totalMiembros;

  const _StackAvataresMiembros({
    required this.avatares,
    required this.totalMiembros,
  });

  @override
  Widget build(BuildContext context) {
    const mostrar = 3;
    final visibles = avatares.length >= mostrar ? mostrar : avatares.length;
    final overflow =
        totalMiembros > visibles ? totalMiembros - visibles : 0;

    return SizedBox(
      width: 90,
      height: 28,
      child: Stack(
        children: List.generate(visibles + (overflow > 0 ? 1 : 0), (i) {
          final left = i * 20.0;
          if (i < visibles) {
            return Positioned(
              left: left,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: ColoresApp.fondoSuperficie, width: 2),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatares[i],
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      CupertinoIcons.person_fill,
                      size: 14,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
              ),
            );
          }
          return Positioned(
            left: left,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.principalMarca,
                border: Border.all(color: ColoresApp.fondoSuperficie, width: 2),
              ),
              child: Text(
                '+$overflow',
                style: GoogleFonts.baloo2(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CardMiGrupo extends StatelessWidget {
  final Map<String, dynamic> grupo;
  final VoidCallback onTap;

  const _CardMiGrupo({required this.grupo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esAdmin = grupo['eresAdmin'] as bool? ?? false;
    final estado = (grupo['estado'] as String? ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18).copyWith(
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    grupo['nombre'] as String? ?? 'Grupo',
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                ),
                if (esAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ColoresApp.promoMarca.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'Sos líder',
                      style: GoogleFonts.baloo2(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.promoMarca),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StackAvataresMiembros(
                  avatares:
                      List<String>.from(grupo['miembrosAvatares'] as List? ?? []),
                  totalMiembros: grupo['miembros'] as int? ?? 0,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    estado.isEmpty
                        ? '${grupo['miembros']} miembros'
                        : '$estado • ${grupo['miembros']} miembros',
                    style: GoogleFonts.baloo2(
                        fontSize: 13, color: ColoresApp.textoSecundario),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right,
                    size: 18, color: ColoresApp.textoSecundario),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
