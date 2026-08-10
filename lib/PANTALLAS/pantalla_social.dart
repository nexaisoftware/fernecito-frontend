/// Pantalla Social: Amigos y Squads, solicitudes, búsqueda. Datos reales.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/servicio_squads.dart';
import '../core/servicio_tendencias_social.dart';
import '../core/preferencias_cartelera.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../models/tendencia_social.dart';
import 'pantalla_crear_squad.dart';
import 'pantalla_explorar_social.dart';
import 'pantalla_fernecito_match.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_mis_squads.dart';
import 'pantalla_planes.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';
import '../widgets/busqueda_social_expandible.dart';
import '../widgets/encabezado_amigos_social.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/social_explorar_sheets.dart';
import '../widgets/social_ui.dart';

String _arroba(String username) => username.isEmpty
    ? ''
    : (username.startsWith('@') ? username : '@$username');

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
  'origen_pendiente': s.origenPendiente,
  'miembros': s.cantidadMiembros,
  'miembrosAvatares': s.avataresMiembros,
};

Map<String, dynamic> _mapInvitacionSquad(SquadResumen s) {
  final map = _mapSquadResumen(s);
  final esSolicitudEnviada = s.origenPendiente == 'solicitud';
  map['mi_estado'] = 'pendiente';
  map['es_invitacion_recibida'] = !esSolicitudEnviada;
  map['es_solicitud_enviada'] = esSolicitudEnviada;
  return map;
}

enum SocialVista { explorar, amigos, squads }

class PantallaSocial extends StatefulWidget {
  final SocialVista vista;
  final bool mostrarVolver;
  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;
  final bool? carteleraInteligenteInicial;

  /// Compatibilidad: 0 → amigos, 1 → squads (desde notificaciones antiguas).
  const PantallaSocial({
    super.key,
    this.vista = SocialVista.explorar,
    this.mostrarVolver = false,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
    @Deprecated('Usar vista') this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<PantallaSocial> createState() => _PantallaSocialHubState();
}

class _PantallaSocialHubState extends State<PantallaSocial>
    with SingleTickerProviderStateMixin {
  final ServicioAmigos _amigos = ServicioAmigos();
  final ServicioSquads _squads = ServicioSquads();
  final ServicioTendenciasSocial _tendencias = ServicioTendenciasSocial();

  late final AnimationController _fuegoController;
  List<LocalTendenciaSocial> _locales = const [];
  int _novedadesSociales = 0;
  bool _cargandoTendencias = true;

  @override
  void initState() {
    super.initState();
    _fuegoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
    if (widget.vista == SocialVista.explorar && !widget.mostrarVolver) {
      _cargarHub();
    }
  }

  @override
  void dispose() {
    _fuegoController.dispose();
    super.dispose();
  }

  Future<void> _cargarHub() async {
    await PreferenciasCartelera.instancia.cargar();
    final prefs = PreferenciasCartelera.instancia;
    try {
      final resultados = await Future.wait<dynamic>([
        _amigos.listar(),
        _squads.invitaciones(),
        _tendencias.listarLocales(
          ciudades: prefs.ciudadesActivas,
          provincia: prefs.provinciaActiva,
          dias: 7,
          limite: 6,
        ),
      ]);
      if (!mounted) return;
      final amistades = resultados[0] as AmistadesData;
      final invitaciones = resultados[1] as List<SquadResumen>;
      setState(() {
        _novedadesSociales =
            amistades.recibidas.length +
            invitaciones
                .where((item) => item.origenPendiente != 'solicitud')
                .length;
        _locales = resultados[2] as List<LocalTendenciaSocial>;
        _cargandoTendencias = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoTendencias = false);
    }
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => pantalla))
        .then((_) => _cargarHub());
  }

  @override
  Widget build(BuildContext context) {
    // Conserva los deep-links existentes de notificaciones y perfiles.
    if (widget.vista == SocialVista.explorar && widget.mostrarVolver) {
      return PantallaExplorarSocial(
        provinciaInicial: widget.provinciaInicial,
        ciudadesIniciales: widget.ciudadesIniciales,
        carteleraInteligenteInicial: widget.carteleraInteligenteInicial,
      );
    }
    if (widget.vista != SocialVista.explorar) {
      return PantallaSocialLegacy(
        vista: widget.vista,
        mostrarVolver: widget.mostrarVolver,
        provinciaInicial: widget.provinciaInicial,
        ciudadesIniciales: widget.ciudadesIniciales,
        carteleraInteligenteInicial: widget.carteleraInteligenteInicial,
      );
    }

    final bottom = reservaInferiorSocialEmbebido(context);
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 14,
                16,
                bottom,
              ),
              sliver: SliverList.list(
                children: [
                  _encabezadoHub(),
                  const SizedBox(height: 12),
                  _seccionTendencias(),
                  const SizedBox(height: 14),
                  _CardDestinoSocial(
                    titulo: 'Explora 🧭',
                    descripcion: 'Personas, rompehielos y squads cerca tuyo.',
                    asset: 'assets/imagenes/social_hub/explora.webp',
                    onTap: () => _abrir(
                      PantallaExplorarSocial(
                        provinciaInicial: widget.provinciaInicial,
                        ciudadesIniciales: widget.ciudadesIniciales,
                        carteleraInteligenteInicial:
                            widget.carteleraInteligenteInicial,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardDestinoSocial(
                    titulo: 'Planes 🍸',
                    descripcion: 'Juntadas de la comunidad para conocer gente.',
                    asset: 'assets/imagenes/social_hub/planes.webp',
                    etiqueta: 'Nuevo',
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .push(
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const PantallaPlanes(),
                          ),
                        )
                        .then((_) => _cargarHub()),
                  ),
                  const SizedBox(height: 12),
                  _CardDestinoSocial(
                    titulo: 'Fernecito Match 💜',
                    descripcion: 'Conectá con personas o squads para salir.',
                    asset: 'assets/imagenes/social_hub/match.webp',
                    etiqueta: 'Nuevo',
                    // Root navigator: escapa del shell de tabs para que la
                    // glass tab bar no tape el deck de cards.
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .push(
                          CupertinoPageRoute(
                            builder: (_) => const PantallaFernecitoMatch(),
                          ),
                        )
                        .then((_) => _cargarHub()),
                  ),
                  const SizedBox(height: 12),
                  _CardDestinoSocial(
                    titulo: 'Mis amigos & squads 👥',
                    descripcion: 'Tus amistades, invitaciones y squads.',
                    asset: 'assets/imagenes/social_hub/amigos_squads.webp',
                    novedades: _novedadesSociales,
                    onTap: () => _abrir(const PantallaAmigosSquads()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezadoHub() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Social',
                style: GoogleFonts.baloo2(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Conectá, armá planes y salí.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionTendencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tendencias',
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(width: 7),
            AnimatedBuilder(
              animation: _fuegoController,
              builder: (_, child) => Transform.scale(
                scale: 0.94 + (_fuegoController.value * 0.12),
                child: Opacity(
                  opacity: 0.76 + (_fuegoController.value * 0.24),
                  child: child,
                ),
              ),
              child: const Text('🔥', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        Text(
          'Los locales más populares de los últimos 7 días',
          style: GoogleFonts.baloo2(
            fontSize: 13,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 78,
          child: _cargandoTendencias
              ? const Center(child: FernecitoLoader.inline(size: 22))
              : _locales.isEmpty
              ? _TendenciasVacias(onReintentar: _cargarHub)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 2, right: 8),
                  itemCount: _locales.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, index) => _LocalTendenciaItem(
                    posicion: index + 1,
                    local: _locales[index],
                    onTap: () => _abrir(
                      PantallaLocalPerfil(
                        idLocal: _locales[index].idLocal,
                        nombreLocal: _locales[index].nombre,
                        avatarUrl: _locales[index].fotoUrl ?? '',
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class PantallaAmigosSquads extends StatefulWidget {
  const PantallaAmigosSquads({super.key});

  @override
  State<PantallaAmigosSquads> createState() => _PantallaAmigosSquadsState();
}

class _PantallaAmigosSquadsState extends State<PantallaAmigosSquads> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: ColoresApp.fondoPrincipal.withValues(alpha: 0.92),
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Text(
          'Amigos & squads',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 46),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
              child: ToggleSegmentadoSocial(
                opciones: const ['Amigos', 'Squads'],
                indice: _indice,
                onChanged: (value) => setState(() => _indice = value),
                anchoMaximo: 340,
                paddingVertical: 8,
                fontSize: 13.5,
                sinBorde: true,
                sinGlowActivo: true,
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _indice,
                children: const [
                  PantallaSocialLegacy(
                    vista: SocialVista.amigos,
                    ocultarCabeceraEmbebida: true,
                  ),
                  PantallaSocialLegacy(
                    vista: SocialVista.squads,
                    ocultarCabeceraEmbebida: true,
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

class _CardDestinoSocial extends StatelessWidget {
  const _CardDestinoSocial({
    required this.titulo,
    required this.descripcion,
    required this.asset,
    required this.onTap,
    this.novedades = 0,
    this.etiqueta,
  });

  final String titulo;
  final String descripcion;
  final String asset;
  final VoidCallback onTap;
  final int novedades;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$titulo. $descripcion',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 104,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: ColoresApp.principalMarca.withValues(alpha: 0.13),
                blurRadius: 11,
                spreadRadius: 0.2,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.58),
                      Colors.black.withValues(alpha: 0.12),
                    ],
                    stops: const [0, 0.54, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (etiqueta != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ColoresApp.principalMarca.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                etiqueta!,
                                style: GoogleFonts.baloo2(
                                  fontSize: 10.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.baloo2(
                              fontSize: 18.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              height: 1.12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        if (novedades > 0)
                          Positioned(
                            right: -6,
                            top: -8,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 23),
                              height: 23,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4D5D),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                novedades > 99 ? '99+' : '$novedades',
                                style: GoogleFonts.baloo2(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalTendenciaItem extends StatelessWidget {
  const _LocalTendenciaItem({
    required this.posicion,
    required this.local,
    required this.onTap,
  });

  static const _oro = Color(0xFFFFD54A);
  static const _plata = Color(0xFFC9CED6);
  static const _bronce = Color(0xFFD08A45);

  final int posicion;
  final LocalTendenciaSocial local;
  final VoidCallback onTap;

  Color get _acentoMedalla {
    switch (posicion) {
      case 1:
        return _oro;
      case 2:
        return _plata;
      case 3:
        return _bronce;
      default:
        return ColoresApp.principalMarca;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = local.fotoUrl;
    final acento = _acentoMedalla;
    final esPodio = posicion <= 3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            SizedBox(
              height: 53,
              width: 65,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 13,
                    top: 1,
                    child: Container(
                      width: 52,
                      height: 52,
                      padding: EdgeInsets.all(esPodio ? 2.5 : 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: acento,
                        boxShadow: [
                          BoxShadow(
                            color: acento.withValues(
                              alpha: esPodio ? 0.36 : 0.24,
                            ),
                            blurRadius: esPodio ? 9 : 7,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: ColoresApp.fondoSuperficie,
                          child: foto != null && foto.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: foto,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _iconoLocal(),
                                  placeholder: (_, _) => _iconoLocal(),
                                )
                              : _iconoLocal(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '$posicion',
                      style: GoogleFonts.baloo2(
                        fontSize: 28,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        color: esPodio ? acento : Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 7),
                          Shadow(color: Colors.black, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              local.nombre,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoLocal() => Icon(
    CupertinoIcons.building_2_fill,
    size: 28,
    color: ColoresApp.textoSecundario,
  );
}

class _TendenciasVacias extends StatelessWidget {
  const _TendenciasVacias({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onReintentar,
    child: Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Las tendencias aparecerán cuando haya actividad esta semana.',
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
          fontSize: 13,
          color: ColoresApp.textoSecundario,
        ),
      ),
    ),
  );
}

class PantallaSocialLegacy extends StatefulWidget {
  final SocialVista vista;
  final bool mostrarVolver;
  final bool ocultarCabeceraEmbebida;
  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;
  final bool? carteleraInteligenteInicial;

  const PantallaSocialLegacy({
    super.key,
    this.vista = SocialVista.explorar,
    this.mostrarVolver = false,
    this.ocultarCabeceraEmbebida = false,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
    @Deprecated('Usar vista') this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<PantallaSocialLegacy> createState() => _PantallaSocialLegacyState();
}

class _PantallaSocialLegacyState extends State<PantallaSocialLegacy> {
  late SocialVista _vista;
  int _explorarIndice = 0;

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
    _vista = widget.vista;
    _cargarAmigos();
    _cargarSquads();
  }

  Future<void> _cargarAmigos({
    bool silencioso = false,
    bool forzarCompleto = false,
  }) async {
    if (!silencioso && !forzarCompleto && _srvAmigos.tieneCache && mounted) {
      setState(() {
        _amistades = _srvAmigos.cache!;
        _cargandoAmigos = false;
      });
    } else if (!silencioso && mounted) {
      setState(() => _cargandoAmigos = true);
    }
    final data = await _srvAmigos.listar(forzarCompleto: forzarCompleto);
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

  Future<void> _cargarSquads({bool forzarCompleto = false}) async {
    if (!forzarCompleto && _srvSquads.tieneCacheListas && mounted) {
      setState(() {
        _misSquads = _srvSquads.misSquadsCache ?? _misSquads;
        _invitaciones = _srvSquads.invitacionesCache ?? _invitaciones;
        _cargandoSquads = false;
      });
    } else if (mounted) {
      setState(() => _cargandoSquads = true);
    }
    final mios = await _srvSquads.misSquads(forzarCompleto: forzarCompleto);
    final invs = await _srvSquads.invitaciones(forzarCompleto: forzarCompleto);
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
        ServicioPerfilUsuario().invalidarUsuario(idUsuario);
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
          ServicioPerfilUsuario().invalidarUsuario(idUsuario);
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
        ServicioPerfilUsuario().invalidarUsuario(idUsuario);
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
      _invitaciones = _invitaciones.where((s) => s.idGrupo != idGrupo).toList();
    });
  }

  Future<void> _resolverPendienteSquad(
    Map<String, dynamic> squad, {
    required bool aceptar,
  }) async {
    final idGrupo = squad['id_grupo']?.toString() ?? '';
    if (idGrupo.isEmpty) return;
    if (_squadProcesandoId != null) return;
    setState(() => _squadProcesandoId = idGrupo);
    try {
      final esSolicitudEnviada = squad['es_solicitud_enviada'] == true;
      final ok = esSolicitudEnviada
          ? await _srvSquads.salir(idGrupo)
          : await _srvSquads.responderInvitacion(idGrupo, aceptar: aceptar);
      if (!ok) {
        if (mounted) {
          _mostrarError(
            esSolicitudEnviada
                ? 'No se pudo cancelar la solicitud.'
                : 'No se pudo ${aceptar ? 'aceptar' : 'rechazar'} la invitación.',
          );
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
    'url_portada': s.urlPortada,
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
    if (estado == EstadoRelacionSquad.miembro ||
        squad['mi_estado']?.toString() == 'aceptado') {
      _abrirMisSquad(context, squad);
      return;
    }
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
        .push(
          CupertinoPageRoute(builder: (_) => PantallaMisSquads(squad: squad)),
        )
        .then((_) => _cargarSquads());
  }

  void _abrirMisAmigos() {
    setState(() => _vista = SocialVista.amigos);
  }

  void _abrirMisSquads() {
    setState(() => _vista = SocialVista.squads);
  }

  void _volverAExplorar() {
    setState(() => _vista = SocialVista.explorar);
  }

  Widget _switchExplorarSuperior() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: ToggleSegmentadoSocial(
        opciones: const ['Personas', 'Squads'],
        indice: _explorarIndice,
        onChanged: (i) => setState(() => _explorarIndice = i),
        anchoMaximo: 320,
        paddingVertical: 7,
        fontSize: 13.5,
        sinBorde: true,
        sinGlowActivo: true,
      ),
    );
  }

  Widget _barraVolverEmbebida({required String titulo}) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top + 4, 16, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(36, 36),
            onPressed: _volverAExplorar,
            child: Icon(
              CupertinoIcons.chevron_back,
              color: ColoresApp.principalMarca,
              size: 26,
            ),
          ),
          Expanded(
            child: Text(
              titulo,
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAccesoSocial({
    required String titulo,
    required IconData icono,
    required VoidCallback onTap,
    int novedades = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: ColoresApp.fondoSuperficie,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 16, color: ColoresApp.principalMarca),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 7,
            right: 10,
            child: IgnorePointer(
              child: IndicadorNovedadesSocial(cantidad: novedades),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fondoSocial = ColoresApp.fondoPrincipal;

    final idsAmigos = _amistades.amigos.map((a) => a.idUsuario).toSet();
    final solicitudesAmigos = <Map<String, dynamic>>[
      ..._amistades.recibidas
          .where((a) => !idsAmigos.contains(a.idUsuario))
          .map((a) => _mapAmigo(a, esEnviada: false)),
      ..._amistades.enviadas.map((a) => _mapAmigo(a, esEnviada: true)),
    ];
    final amigos = _amistades.amigos.map((a) => _mapAmigo(a)).toList();

    final solicitudesSquads = _invitaciones.map(_mapInvitacionSquad).toList();
    final misGrupos = _misSquads.map((s) => _mapSquadResumen(s)).toList();
    final novedadesAmigos = _amistades.recibidas
        .where((a) => !idsAmigos.contains(a.idUsuario))
        .length;
    final novedadesSquads = _invitaciones.length;

    if (_vista == SocialVista.amigos) {
      return CupertinoPageScaffold(
        backgroundColor: fondoSocial,
        navigationBar: widget.mostrarVolver
            ? CupertinoNavigationBar(
                backgroundColor: Colors.transparent,
                border: null,
                leading: CupertinoNavigationBarBackButton(
                  color: ColoresApp.principalMarca,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                middle: Text(
                  'Mis amigos',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              )
            : null,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.mostrarVolver && !widget.ocultarCabeceraEmbebida)
                _barraVolverEmbebida(titulo: 'Mis amigos'),
              Expanded(
                child: _TabAmigos(
                  pantallaDedicada: widget.mostrarVolver,
                  solicitudes: solicitudesAmigos,
                  amigos: amigos,
                  cargando: _cargandoAmigos,
                  solicitudProcesandoKey: _solicitudProcesandoKey,
                  srvAmigos: _srvAmigos,
                  onRefresh: () =>
                      _cargarAmigos(silencioso: true, forzarCompleto: true),
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
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_vista == SocialVista.squads) {
      return CupertinoPageScaffold(
        backgroundColor: fondoSocial,
        navigationBar: widget.mostrarVolver
            ? CupertinoNavigationBar(
                backgroundColor: Colors.transparent,
                border: null,
                leading: CupertinoNavigationBarBackButton(
                  color: ColoresApp.principalMarca,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                middle: Text(
                  'Mis squads',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              )
            : null,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.mostrarVolver && !widget.ocultarCabeceraEmbebida)
                _barraVolverEmbebida(titulo: 'Mis squads'),
              Expanded(
                child: _TabSquads(
                  pantallaDedicada: widget.mostrarVolver,
                  solicitudes: solicitudesSquads,
                  misGrupos: misGrupos,
                  cargando: _cargandoSquads,
                  srvSquads: _srvSquads,
                  onRefresh: () => _cargarSquads(forzarCompleto: true),
                  onCrearSquad: () => _abrirCrearSquad(context),
                  squadProcesandoId: _squadProcesandoId,
                  onAbrirPerfilSquad: (s) => _abrirPerfilSquad(
                    context,
                    s,
                    estado: _estadoSquadDesde(
                      s['mi_estado'] as String?,
                      esInvitacionRecibida: s['es_invitacion_recibida'] == true,
                    ),
                  ),
                  onAceptarInvitacion: (s) =>
                      _resolverPendienteSquad(s, aceptar: true),
                  onRechazarInvitacion: (s) =>
                      _resolverPendienteSquad(s, aceptar: false),
                  onAbrirMisSquad: (s) => _abrirMisSquad(context, s),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final topSafe = MediaQuery.paddingOf(context).top;

    return CupertinoPageScaffold(
      backgroundColor: fondoSocial,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, topSafe + 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _botonAccesoSocial(
                      titulo: 'Mis amigos',
                      icono: CupertinoIcons.person_2_fill,
                      onTap: _abrirMisAmigos,
                      novedades: novedadesAmigos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _botonAccesoSocial(
                      titulo: 'Mis squads',
                      icono: CupertinoIcons.person_3_fill,
                      onTap: _abrirMisSquads,
                      novedades: novedadesSquads,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _explorarIndice,
                children: [
                  ExplorarPersonasContenido(
                    provinciaInicial: widget.provinciaInicial,
                    ciudadesIniciales: widget.ciudadesIniciales,
                    carteleraInteligenteInicial:
                        widget.carteleraInteligenteInicial,
                    encabezadoSuperior: _switchExplorarSuperior(),
                    paddingInferiorScroll: reservaInferiorSocialEmbebido(
                      context,
                    ),
                    onPerfil: (u) => _abrirPerfilUsuario(
                      context,
                      _mapUsuarioBusqueda(u),
                      estadoRelacion: _estadoUsuarioDesde(u.estadoAmistad),
                    ),
                  ),
                  ExplorarSquadsContenido(
                    provinciaInicial: widget.provinciaInicial,
                    ciudadesIniciales: widget.ciudadesIniciales,
                    carteleraInteligenteInicial:
                        widget.carteleraInteligenteInicial,
                    encabezadoSuperior: _switchExplorarSuperior(),
                    paddingInferiorScroll: reservaInferiorSocialEmbebido(
                      context,
                    ),
                    onSquad: (s) => _abrirPerfilSquad(
                      context,
                      _mapSquadExplorar(s),
                      estado: _estadoSquadDesde(s.miEstado),
                    ),
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
  final bool pantallaDedicada;
  final List<Map<String, dynamic>> solicitudes;
  final List<Map<String, dynamic>> amigos;
  final bool cargando;
  final String? solicitudProcesandoKey;
  final ServicioAmigos srvAmigos;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onAceptar;
  final void Function(Map<String, dynamic>) onCancelarRechazar;
  final void Function(Map<String, dynamic>, EstadoRelacionUsuario)
  onAbrirPerfil;

  const _TabAmigos({
    this.pantallaDedicada = false,
    required this.solicitudes,
    required this.amigos,
    required this.cargando,
    this.solicitudProcesandoKey,
    required this.srvAmigos,
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
    final bottomPad = MediaQuery.paddingOf(context).bottom + 100;
    final contenido = _contenidoLista(mostrandoBusqueda);

    final lista = FernecitoRefreshableList(
      onRefresh: widget.onRefresh,
      padding: EdgeInsets.fromLTRB(
        20,
        widget.pantallaDedicada ? 12 : 6,
        20,
        bottomPad,
      ),
      children: contenido,
    );

    if (widget.pantallaDedicada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _barraBusqueda(),
          ),
          Expanded(child: lista),
        ],
      );
    }

    return FernecitoRefreshableList(
      onRefresh: widget.onRefresh,
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPad),
      children: [_barraBusqueda(), ...contenido],
    );
  }

  Widget _barraBusqueda() {
    return BusquedaSocialExpandible(
      hint: widget.pantallaDedicada ? 'Buscar amigos' : 'Buscar',
      onQueryChanged: _onBuscar,
      flexBarraColapsada: 10,
      flexPorAccionColapsada: 3,
    );
  }

  List<Widget> _contenidoLista(bool mostrandoBusqueda) {
    return [
      if (!mostrandoBusqueda && !widget.pantallaDedicada)
        const SizedBox(height: 12),
      if (_buscando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: FernecitoLoaderCentro(size: 26),
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
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: ColoresApp.textoSecundario,
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
      if (!mostrandoBusqueda && widget.cargando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: FernecitoLoaderCentro(size: 26),
        )
      else if (!mostrandoBusqueda) ...[
        if (widget.solicitudes.isNotEmpty) ...[
          const EncabezadoSeccionSocial(
            titulo: 'Solicitudes',
            subtitulo: 'Pendientes de respuesta',
          ),
          ...widget.solicitudes.map((s) {
            final clave =
                s['id_relacion']?.toString() ??
                s['id_usuario']?.toString() ??
                '';
            final esEnviada = s['esEnviada'] as bool? ?? false;
            final yaAceptado =
                !esEnviada &&
                widget.amigos.any((a) => a['id_usuario'] == s['id_usuario']);
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
          }),
          const SizedBox(height: 20),
        ] else if (widget.pantallaDedicada) ...[
          const EncabezadoSeccionSocial(
            titulo: 'Solicitudes',
            subtitulo: 'Sin pendientes por ahora',
          ),
          const SizedBox(height: 8),
        ],
        if (widget.amigos.isNotEmpty || widget.pantallaDedicada)
          EncabezadoAmigosCentrado(cantidad: widget.amigos.length),
        if (widget.amigos.isEmpty)
          const _PanelVacioAmigosSocial()
        else
          ...widget.amigos.map(
            (a) => _CardAmigo(
              amigo: a,
              onTap: () => widget.onAbrirPerfil(a, EstadoRelacionUsuario.amigo),
            ),
          ),
      ],
    ];
  }
}

class _PanelVacioAmigosSocial extends StatelessWidget {
  const _PanelVacioAmigosSocial();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Todavía no tenés amigos. Buscá por nombre arriba o explorá desde la pestaña Social.',
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
          fontSize: 14,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}

class _PanelVacioSquadsSocial extends StatelessWidget {
  final VoidCallback onCrear;

  const _PanelVacioSquadsSocial({required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'Todavía no tenés squads. Creá uno propio o explorá desde la pestaña Social.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          BotonSquadMasSocial(onTap: onCrear),
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
    final esPrivadaRecibida = PrivacidadPerfil.solicitudRecibidaPrivada(
      solicitud,
    );

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: ColoresApp.fondoPrincipal,
                borderRadius: BorderRadius.circular(50),
                onPressed: procesando ? null : onCancelar,
                child: procesando
                    ? const FernecitoLoader.inline(size: 16)
                    : Text(
                        'Cancelar',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
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
                      horizontal: 8,
                      vertical: 7,
                    ),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(50),
                    onPressed: procesando ? null : onAceptar,
                    child: procesando
                        ? const FernecitoLoader.inline(
                            size: 16,
                            color: Colors.white,
                          )
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
                      horizontal: 8,
                      vertical: 7,
                    ),
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
        decoration: BoxDecoration(),
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
  final bool pantallaDedicada;
  final List<Map<String, dynamic>> solicitudes;
  final List<Map<String, dynamic>> misGrupos;
  final bool cargando;
  final ServicioSquads srvSquads;
  final VoidCallback onCrearSquad;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onAbrirPerfilSquad;
  final void Function(Map<String, dynamic>) onAceptarInvitacion;
  final void Function(Map<String, dynamic>) onRechazarInvitacion;
  final void Function(Map<String, dynamic>) onAbrirMisSquad;
  final String? squadProcesandoId;

  const _TabSquads({
    this.pantallaDedicada = false,
    required this.solicitudes,
    required this.misGrupos,
    this.cargando = false,
    required this.srvSquads,
    required this.onCrearSquad,
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
    final bottomPad = MediaQuery.paddingOf(context).bottom + 100;
    final contenido = _contenidoLista(mostrandoBusqueda);

    final lista = FernecitoRefreshableList(
      onRefresh: widget.onRefresh,
      padding: EdgeInsets.fromLTRB(
        20,
        widget.pantallaDedicada ? 12 : 6,
        20,
        bottomPad,
      ),
      children: contenido,
    );

    if (widget.pantallaDedicada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _barraBusqueda(),
          ),
          Expanded(child: lista),
        ],
      );
    }

    return FernecitoRefreshableList(
      onRefresh: widget.onRefresh,
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPad),
      children: [_barraBusqueda(), ...contenido],
    );
  }

  Widget _barraBusqueda() {
    return BusquedaSocialExpandible(
      hint: 'Nombre del squad',
      onQueryChanged: _onBuscar,
      flexBarraColapsada: 4,
      flexPorAccionColapsada: 3,
      accionesColapsado: [BotonSquadMasSocial(onTap: widget.onCrearSquad)],
    );
  }

  List<Widget> _contenidoLista(bool mostrandoBusqueda) {
    return [
      if (!mostrandoBusqueda && !widget.pantallaDedicada)
        const SizedBox(height: 12),
      if (_buscando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: FernecitoLoaderCentro(size: 26),
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
          final portada = s.portadaUrl;
          final raw = {
            'id_grupo': s.idGrupo,
            'id_squad': s.idGrupo,
            'nombre': s.nombre,
            'descripcion': s.descripcion ?? '',
            'vibe': s.vibe ?? '',
            'avatar': portada ?? '',
            'banner_url': portada,
            'url_portada': s.urlPortada,
            'miembros': s.cantidadMiembros,
            'es_publico': s.esPublico,
            'id_creador': s.idCreador,
            'mi_estado': s.miEstado,
            'miembrosAvatares': const <String>[],
          };
          return CardSuperficieSocial(
            onTap: () => widget.onAbrirPerfilSquad(raw),
            child: Row(
              children: [
                AvatarSocial(url: portada ?? '', size: 48),
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
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: ColoresApp.textoSecundario,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
      if (!mostrandoBusqueda && widget.cargando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: FernecitoLoaderCentro(size: 26),
        )
      else if (!mostrandoBusqueda) ...[
        if (widget.solicitudes.isNotEmpty) ...[
          const EncabezadoSeccionSocial(
            titulo: 'Solicitudes',
            subtitulo: 'Invitaciones y pedidos enviados',
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
        ] else if (widget.pantallaDedicada) ...[
          const EncabezadoSeccionSocial(
            titulo: 'Solicitudes',
            subtitulo: 'Sin pendientes por ahora',
          ),
          const SizedBox(height: 8),
        ],
        if (widget.misGrupos.isNotEmpty || widget.pantallaDedicada)
          EncabezadoSquadsCentrado(cantidad: widget.misGrupos.length),
        if (widget.misGrupos.isEmpty)
          _PanelVacioSquadsSocial(onCrear: widget.onCrearSquad)
        else
          ...widget.misGrupos.map(
            (g) =>
                _CardMiGrupo(grupo: g, onTap: () => widget.onAbrirMisSquad(g)),
          ),
      ],
    ];
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
    final esSolicitudEnviada = squad['es_solicitud_enviada'] == true;
    return GestureDetector(
      onTap: onVerGrupo,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18).copyWith(),
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
            if (esSolicitudEnviada) ...[
              const SizedBox(height: 2),
              Text(
                'Solicitud enviada',
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  color: ColoresApp.textoSecundario,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _StackAvataresMiembros(
                  avatares: List<String>.from(
                    squad['miembrosAvatares'] as List? ?? [],
                  ),
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
                      horizontal: 12,
                      vertical: 10,
                    ),
                    color: ColoresApp.fondoPrincipal,
                    borderRadius: BorderRadius.circular(50),
                    onPressed: procesando ? null : onRechazar,
                    child: Text(
                      esSolicitudEnviada ? 'Cancelar solicitud' : 'Rechazar',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!esSolicitudEnviada)
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      color: ColoresApp.principalMarca,
                      borderRadius: BorderRadius.circular(50),
                      onPressed: procesando ? null : onUnirse,
                      child: procesando
                          ? const FernecitoLoader.inline(
                              size: 16,
                              color: Colors.white,
                            )
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
    final overflow = totalMiembros > visibles ? totalMiembros - visibles : 0;

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
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatares[i],
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Icon(
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
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18).copyWith(),
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.promoMarca.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'Sos líder',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.promoMarca,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StackAvataresMiembros(
                  avatares: List<String>.from(
                    grupo['miembrosAvatares'] as List? ?? [],
                  ),
                  totalMiembros: grupo['miembros'] as int? ?? 0,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    estado.isEmpty
                        ? '${grupo['miembros']} miembros'
                        : '$estado • ${grupo['miembros']} miembros',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: ColoresApp.textoSecundario,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
