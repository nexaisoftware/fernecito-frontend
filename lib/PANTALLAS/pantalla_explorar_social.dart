library;

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_ranking_usuarios.dart';
import '../core/servicio_squads.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../widgets/busqueda_social_expandible.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/social_explorar_sheets.dart';
import '../widgets/ranking_usuarios_explorar.dart';
import '../widgets/social_ui.dart';
import 'pantalla_mis_squads.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';

class PantallaExplorarSocial extends StatefulWidget {
  const PantallaExplorarSocial({
    super.key,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
  });

  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;
  final bool? carteleraInteligenteInicial;

  @override
  State<PantallaExplorarSocial> createState() => _PantallaExplorarSocialState();
}

class _PantallaExplorarSocialState extends State<PantallaExplorarSocial> {
  int _indice = 0;
  String _query = '';
  bool _buscando = false;
  int _busquedaToken = 0;
  List<UsuarioBusqueda> _personasEncontradas = const [];
  List<SquadBusqueda> _squadsEncontrados = const [];

  final ServicioAmigos _amigos = ServicioAmigos();
  final ServicioSquads _squads = ServicioSquads();
  final ServicioRankingUsuarios _rankingSrv = ServicioRankingUsuarios();

  /// Podio semanal de personas (cache de 15 min en el backend).
  List<UsuarioRanking> _ranking = const [];
  bool _cargandoRanking = true;

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(_onCambioUbicacion);
    _cargarRanking();
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(_onCambioUbicacion);
    super.dispose();
  }

  void _onCambioUbicacion() {
    _cargarRanking();
  }

  Future<void> _cargarRanking() async {
    await PreferenciasCartelera.instancia.cargar();
    if (!mounted) return;
    final prefs = PreferenciasCartelera.instancia;
    setState(() {
      _cargandoRanking = true;
    });
    final lista = await _rankingSrv.listar(
      ciudades: prefs.ciudadesActivas,
      provincia: prefs.provinciaActiva,
      limite: 10,
    );
    if (!mounted) return;
    setState(() {
      _ranking = lista;
      _cargandoRanking = false;
    });
  }

  String _arroba(String value) => value.isEmpty
      ? ''
      : value.startsWith('@')
      ? value
      : '@$value';

  EstadoRelacionUsuario _estadoUsuario(String estado) {
    switch (estado) {
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

  EstadoRelacionSquad _estadoSquad(String? estado) => estado == 'aceptado'
      ? EstadoRelacionSquad.miembro
      : estado == 'pendiente'
      ? EstadoRelacionSquad.solicitudEnviada
      : EstadoRelacionSquad.ninguno;

  void _abrirPersona(UsuarioBusqueda usuario) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': usuario.idUsuario,
            'nombre': usuario.nombre,
            'username': _arroba(usuario.username),
            'avatar': usuario.avatarUrl ?? '',
            'estado': usuario.estado ?? '',
            'instagram_url': usuario.instagramUrl ?? '',
            'tiktok_url': usuario.tiktokUrl ?? '',
            'estado_amistad': usuario.estadoAmistad,
            'perfil_publico': usuario.perfilPublico,
          },
          estadoRelacion: _estadoUsuario(usuario.estadoAmistad),
          rompehieloOrigen: RompehieloOrigen.explorar,
        ),
      ),
    );
  }

  void _abrirSquad(SquadExplorarItem squad) {
    final map = <String, dynamic>{
      'id_grupo': squad.idGrupo,
      'id_squad': squad.idGrupo,
      'nombre': squad.nombre,
      'nombre_squad': squad.nombre,
      'avatar': squad.portadaUrl ?? '',
      'banner_url': squad.portadaUrl,
      'url_portada': squad.urlPortada,
      'miembros': squad.cantidadMiembros,
      'es_publico': true,
      'mi_estado': squad.miEstado,
      'miembrosAvatares': squad.avataresResueltos,
    };
    final estado = _estadoSquad(squad.miEstado);
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => estado == EstadoRelacionSquad.miembro
            ? PantallaMisSquads(squad: map)
            : PantallaPerfilSquads(
                squad: map,
                estadoRelacion: estado,
                rompehieloOrigen: RompehieloOrigen.explorar,
              ),
      ),
    );
  }

  void _abrirSquadBusqueda(SquadBusqueda squad) {
    final map = <String, dynamic>{
      'id_grupo': squad.idGrupo,
      'id_squad': squad.idGrupo,
      'nombre': squad.nombre,
      'nombre_squad': squad.nombre,
      'descripcion': squad.descripcion ?? '',
      'avatar': squad.portadaUrl ?? '',
      'banner_url': squad.portadaUrl,
      'url_portada': squad.urlPortada,
      'miembros': squad.cantidadMiembros,
      'es_publico': squad.esPublico,
      'mi_estado': squad.miEstado,
    };
    final estado = _estadoSquad(squad.miEstado);
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => estado == EstadoRelacionSquad.miembro
            ? PantallaMisSquads(squad: map)
            : PantallaPerfilSquads(
                squad: map,
                estadoRelacion: estado,
                rompehieloOrigen: RompehieloOrigen.explorar,
              ),
      ),
    );
  }

  Future<void> _buscar(String value) async {
    final query = value.trim();
    final token = ++_busquedaToken;
    if (query.length < 2) {
      setState(() {
        _query = query;
        _buscando = false;
        _personasEncontradas = const [];
        _squadsEncontrados = const [];
      });
      return;
    }
    setState(() {
      _query = query;
      _buscando = true;
    });
    if (_indice == 0) {
      final items = await _amigos.buscar(query);
      if (!mounted || token != _busquedaToken) return;
      setState(() {
        _personasEncontradas = items;
        _buscando = false;
      });
    } else {
      final items = await _squads.buscar(query);
      if (!mounted || token != _busquedaToken) return;
      setState(() {
        _squadsEncontrados = items;
        _buscando = false;
      });
    }
  }

  void _cambiarIndice(int value) {
    setState(() {
      _indice = value;
      _query = '';
      _buscando = false;
      _personasEncontradas = const [];
      _squadsEncontrados = const [];
    });
  }

  Widget _controlesSuperiores() => Column(
    children: [
      SizedBox(height: MediaQuery.paddingOf(context).top + 46),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
        child: ToggleSegmentadoSocial(
          opciones: const ['Personas', 'Squads'],
          indice: _indice,
          onChanged: _cambiarIndice,
          anchoMaximo: 340,
          paddingVertical: 7,
          fontSize: 13.5,
          sinBorde: true,
          sinGlowActivo: true,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
        child: BusquedaSocialExpandible(
          key: ValueKey('buscar_explora_$_indice'),
          hint: _indice == 0 ? 'Buscar personas' : 'Buscar squads',
          onQueryChanged: _buscar,
          flexBarraColapsada: 10,
          flexPorAccionColapsada: 0,
        ),
      ),
      // Podio semanal de personas (solo en la pestaña Personas y sin búsqueda)
      if (_indice == 0 && _query.trim().isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          child: RankingUsuariosExplorar(
            usuarios: _ranking,
            cargando: _cargandoRanking,
            onTapUsuario: _abrirPersonaDesdeRanking,
          ),
        ),
    ],
  );

  /// Abre el perfil desde el podio (datos mínimos; la pantalla completa el resto).
  void _abrirPersonaDesdeRanking(UsuarioRanking u) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': u.idUsuario,
            'nombre': u.nombre,
            'username': _arroba(u.username ?? ''),
            'avatar': u.fotoUrl ?? '',
            'estado': u.estado ?? '',
            'perfil_publico': true,
          },
          estadoRelacion: EstadoRelacionUsuario.ninguno,
          rompehieloOrigen: RompehieloOrigen.explorar,
        ),
      ),
    );
  }

  Widget _resultadosBusqueda() {
    final cantidad = _indice == 0
        ? _personasEncontradas.length
        : _squadsEncontrados.length;
    return Column(
      children: [
        _controlesSuperiores(),
        Expanded(
          child: _buscando
              ? const FernecitoLoaderCentro(size: 26)
              : cantidad == 0
              ? Center(
                  child: Text(
                    'No encontramos resultados para “$_query”.',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: _indice == 0
                      ? _personasEncontradas
                            .map(
                              (persona) => _ResultadoBusquedaSocial(
                                titulo: persona.nombre,
                                subtitulo: _arroba(persona.username),
                                imagen: persona.avatarUrl,
                                onTap: () => _abrirPersona(persona),
                              ),
                            )
                            .toList()
                      : _squadsEncontrados
                            .map(
                              (squad) => _ResultadoBusquedaSocial(
                                titulo: squad.nombre,
                                subtitulo: '${squad.cantidadMiembros} miembros',
                                imagen: squad.portadaUrl,
                                onTap: () => _abrirSquadBusqueda(squad),
                              ),
                            )
                            .toList(),
                ),
        ),
      ],
    );
  }

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
          'Explora',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: _query.length >= 2
            ? _resultadosBusqueda()
            : IndexedStack(
                index: _indice,
                children: [
                  ExplorarPersonasContenido(
                    provinciaInicial: widget.provinciaInicial,
                    ciudadesIniciales: widget.ciudadesIniciales,
                    carteleraInteligenteInicial:
                        widget.carteleraInteligenteInicial,
                    encabezadoSuperior: _controlesSuperiores(),
                    paddingInferiorScroll:
                        MediaQuery.paddingOf(context).bottom + 24,
                    onPerfil: _abrirPersona,
                  ),
                  ExplorarSquadsContenido(
                    provinciaInicial: widget.provinciaInicial,
                    ciudadesIniciales: widget.ciudadesIniciales,
                    carteleraInteligenteInicial:
                        widget.carteleraInteligenteInicial,
                    encabezadoSuperior: _controlesSuperiores(),
                    paddingInferiorScroll:
                        MediaQuery.paddingOf(context).bottom + 24,
                    onSquad: _abrirSquad,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ResultadoBusquedaSocial extends StatelessWidget {
  const _ResultadoBusquedaSocial({
    required this.titulo,
    required this.subtitulo,
    required this.imagen,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final String? imagen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CardSuperficieSocial(
    onTap: onTap,
    child: Row(
      children: [
        AvatarSocial(url: imagen ?? '', size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              Text(
                subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
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
}
