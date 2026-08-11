/// Bottom sheets para explorar personas y squads por ciudad.
library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/ubicaciones_data.dart';
import '../models/social.dart';
import 'burbuja_estado.dart';
import 'filtro_ubicaciones_sheet.dart';
import 'avatar_bordes.dart';
import 'fernecito_loader.dart';
import 'social_ui.dart';

const int _kExplorarPagina = 27;

/// Layout grilla personas en explorar.
abstract final class _LayoutGridPersonasExplorar {
  static const mainAxisSpacing = 14.0;
  static const crossAxisSpacing = 10.0;
  static const celdaAltura = 132.0;
  static const padding = EdgeInsets.fromLTRB(14, 8, 14, 0);
  static const delegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisExtent: celdaAltura,
  );
}

String arrobaExplorar(String u) {
  final t = u.trim();
  if (t.isEmpty) return '@usuario';
  return t.startsWith('@') ? t : '@$t';
}

/// Provincia + ciudades desde `perfiles_usuarios` (misma fuente que cartelera).
Future<({String provincia, Set<String> ciudades})?>
leerUbicacionPerfilExplorar() async {
  final uid = ServicioSupabase().usuarioActual?.id;
  if (uid == null) return null;
  try {
    final resp = await ServicioSupabase().cliente
        .from('perfiles_usuarios')
        .select('provincia, provincia_usuario, ciudad, ciudades_preferidas')
        .eq('id', uid)
        .maybeSingle();
    if (resp == null) return null;

    final provincia =
        (resp['provincia'] as String?)?.trim() ??
        (resp['provincia_usuario'] as String?)?.trim();
    final ciudad = (resp['ciudad'] as String?)?.trim();
    final prefsRaw = resp['ciudades_preferidas'];
    final prefs = <String>{};
    if (prefsRaw is List) {
      for (final e in prefsRaw) {
        final c = e?.toString().trim();
        if (c != null && c.isNotEmpty) prefs.add(c);
      }
    }

    final prov = (provincia != null && provincia.isNotEmpty)
        ? provincia
        : UbicacionesData.provinciaPorDefecto;

    final ciudades = <String>{};
    if (ciudad != null && ciudad.isNotEmpty) ciudades.add(ciudad);
    ciudades.addAll(prefs);
    if (ciudades.isEmpty) {
      ciudades.add(UbicacionesData.ciudadPorDefecto);
    }

    return (provincia: prov, ciudades: ciudades);
  } catch (_) {
    return null;
  }
}

/// Título + pin de ubicación + botón Editar (abre selector de ciudades).
class EncabezadoExplorarUbicacion extends StatelessWidget {
  const EncabezadoExplorarUbicacion({
    super.key,
    required this.titulo,
    required this.onEditar,
    this.compacto = false,
  });

  final String titulo;
  final VoidCallback onEditar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compacto ? 6 : 16, 12, compacto ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ),
          Icon(
            CupertinoIcons.location_solid,
            size: 22,
            color: ColoresApp.principalMarca,
          ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            onPressed: onEditar,
            child: Text(
              'Editar',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColoresApp.principalMarca,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> mostrarExplorarPersonasSheet(
  BuildContext context, {
  required void Function(UsuarioBusqueda u) onPerfil,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ExplorarPersonasContenido(
      onPerfil: (u) {
        Navigator.of(ctx).pop();
        onPerfil(u);
      },
      embebido: false,
    ),
  );
}

class ExplorarPersonasContenido extends StatefulWidget {
  const ExplorarPersonasContenido({
    super.key,
    required this.onPerfil,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
    this.encabezadoSuperior,
    this.embebido = true,
    this.paddingInferiorScroll = 0,
  });

  final void Function(UsuarioBusqueda u) onPerfil;
  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;
  final bool? carteleraInteligenteInicial;
  final Widget? encabezadoSuperior;
  final bool embebido;
  final double paddingInferiorScroll;

  @override
  State<ExplorarPersonasContenido> createState() =>
      _ExplorarPersonasContenidoState();
}

class _ExplorarPersonasContenidoState extends State<ExplorarPersonasContenido> {
  final ServicioAmigos _srv = ServicioAmigos();
  final ScrollController _scroll = ScrollController();
  String _provincia = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudades = {UbicacionesData.ciudadPorDefecto};

  List<UsuarioBusqueda> _personas = [];
  String? _errorCarga;
  bool _cargando = false;
  bool _hayMas = false;
  bool _cargandoMas = false;
  bool _syncPreferenciasProgramado = false;

  Set<String>? get _ciudadesDesdeWidget {
    final ciudades = widget.ciudadesIniciales;
    if (ciudades == null || ciudades.isEmpty) return null;
    return Set<String>.from(ciudades);
  }

  String _tituloExplorar(String tipo, List<String> ciudades) {
    if (ciudades.length == 1) return 'Explorar ${ciudades.first}';
    if (ciudades.length > 1) {
      final inteligente =
          widget.carteleraInteligenteInicial ??
          PreferenciasCartelera.instancia.inteligenteActiva;
      return inteligente
          ? 'Explorar $tipo cerca tuyo'
          : 'Explorar $tipo en ${ciudades.length} ciudades';
    }
    return 'Explorar $tipo';
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollFin);
    PreferenciasCartelera.instancia.cambios.addListener(
      _sincronizarPreferenciasAhora,
    );
    _inicializarUbicacion();
  }

  @override
  void didUpdateWidget(covariant ExplorarPersonasContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevas = _ciudadesDesdeWidget;
    if (nuevas == null) return;
    final provincia = widget.provinciaInicial ?? _provincia;
    if (provincia == _provincia && setEquals(nuevas, _ciudades)) return;
    setState(() {
      _provincia = provincia;
      _ciudades = nuevas;
      _personas = [];
      _errorCarga = null;
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(
      _sincronizarPreferenciasAhora,
    );
    _scroll.removeListener(_onScrollFin);
    _scroll.dispose();
    super.dispose();
  }

  void _onScrollFin() {
    if (!_hayMas || _cargandoMas || _cargando) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      _cargar(inicial: false);
    }
  }

  Future<void> _inicializarUbicacion() async {
    final iniciales = _ciudadesDesdeWidget;
    if (iniciales != null) {
      if (!mounted) return;
      setState(() {
        _provincia = widget.provinciaInicial ?? _provincia;
        _ciudades = iniciales;
      });
      _cargar(inicial: true);
      return;
    }
    // Unificado: hereda la ubicación de la cartelera (misma fuente). Fallback: perfil.
    await PreferenciasCartelera.instancia.cargar();
    final activas = PreferenciasCartelera.instancia.ciudadesActivas;
    if (activas.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _provincia =
            PreferenciasCartelera.instancia.provinciaActiva ?? _provincia;
        _ciudades = {...activas};
      });
      _cargar(inicial: true);
      return;
    }
    final ubi = await leerUbicacionPerfilExplorar();
    if (!mounted) return;
    setState(() {
      if (ubi != null) {
        _provincia = ubi.provincia;
        _ciudades = ubi.ciudades;
      }
    });
    if (_ciudades.isNotEmpty) _cargar(inicial: true);
  }

  void _programarSyncPreferencias() {
    if (_syncPreferenciasProgramado || _cargando || _cargandoMas) return;
    _syncPreferenciasProgramado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPreferenciasProgramado = false;
      if (!mounted || _cargando || _cargandoMas) return;
      final prefs = PreferenciasCartelera.instancia;
      final activas = _ciudadesDesdeWidget ?? prefs.ciudadesActivas;
      if (activas.isEmpty) return;
      final provincia =
          widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
      if (provincia == _provincia && setEquals(activas, _ciudades)) return;
      setState(() {
        _provincia = provincia;
        _ciudades = {...activas};
        _personas = [];
        _errorCarga = null;
        _hayMas = false;
      });
      _cargar(inicial: true);
    });
  }

  void _sincronizarPreferenciasAhora() {
    if (!mounted) return;
    if (_cargando || _cargandoMas) {
      _programarSyncPreferencias();
      return;
    }
    final prefs = PreferenciasCartelera.instancia;
    final activas = _ciudadesDesdeWidget ?? prefs.ciudadesActivas;
    if (activas.isEmpty) return;
    final provincia =
        widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
    if (provincia == _provincia && setEquals(activas, _ciudades)) return;
    setState(() {
      _provincia = provincia;
      _ciudades = {...activas};
      _personas = [];
      _errorCarga = null;
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  Future<void> _elegirCiudad() async {
    await PreferenciasCartelera.instancia.cargar();
    if (!mounted) return;
    final prefs = PreferenciasCartelera.instancia;
    final ciudadesWidget = _ciudadesDesdeWidget;
    final ciudadesActuales = ciudadesWidget != null
        ? ciudadesWidget
        : prefs.ciudadesActivas.isNotEmpty
        ? prefs.ciudadesActivas
        : _ciudades;
    final provinciaActual =
        widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: provinciaActual,
      ciudadesActuales: ciudadesActuales,
      // Arrastra el estado real del modo inteligente (antes quedaba en false → el
      // switch aparecía apagado cada vez que se abría el sheet desde explorar).
      carteleraInteligente:
          widget.carteleraInteligenteInicial ?? prefs.inteligenteActiva,
    );
    if (res == null || !mounted) return;
    if (res.carteleraInteligente) {
      await ServicioUbicacionGlobal.aplicarInteligente(
        ciudades: res.ciudades,
        provincia: res.provincia,
        principal: res.ciudadPrincipal,
      );
    } else {
      await ServicioUbicacionGlobal.aplicarManual(
        provincia: res.provincia,
        ciudades: res.ciudades,
        principal: res.ciudadPrincipal,
      );
    }
    if (!mounted) return;
    setState(() {
      _provincia = res.provincia;
      _ciudades = res.ciudades.isEmpty
          ? UbicacionesData.ciudadesDe(res.provincia).toSet()
          : res.ciudades;
      _personas = [];
      _hayMas = false;
    });
    if (_ciudades.isNotEmpty) _cargar(inicial: true);
  }

  Future<void> _cargar({required bool inicial}) async {
    if (_ciudades.isEmpty) return;
    if (!inicial && (!_hayMas || _cargandoMas)) return;
    if (inicial) {
      setState(() => _cargando = true);
    } else {
      setState(() => _cargandoMas = true);
    }
    final pagina = await _srv.explorarCiudades(
      ciudades: _ciudades,
      provincia: _provincia,
      offset: inicial ? 0 : _personas.length,
      limit: _kExplorarPagina,
    );
    if (!mounted) return;
    setState(() {
      if (inicial) {
        _personas = pagina.items;
        _errorCarga = pagina.error;
      } else {
        _personas = [..._personas, ...pagina.items];
      }
      _hayMas = pagina.hayMas;
      _cargando = false;
      _cargandoMas = false;
    });
  }

  Widget _buildEmbebido(
    BuildContext context,
    bool tieneCiudades,
    List<String> ciudadesLista,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.encabezadoSuperior != null) widget.encabezadoSuperior!,
        EncabezadoExplorarUbicacion(
          titulo: _tituloExplorar('personas', ciudadesLista),
          onEditar: _elegirCiudad,
        ),
        if (!tieneCiudades)
          Expanded(
            child: Center(
              child: Text(
                'Elegí una ciudad para ver personas',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
          )
        else if (_cargando)
          const Expanded(child: FernecitoLoaderCentro(size: 28))
        else if (_personas.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorCarga ??
                      'No hay personas públicas en estas ciudades.\n'
                          'Solo aparecen quienes tienen ciudad en el perfil (cartelera) y perfil público.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: _errorCarga != null
                        ? ColoresApp.principalMarca
                        : ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: _LayoutGridPersonasExplorar.padding,
                  sliver: SliverGrid(
                    gridDelegate: _LayoutGridPersonasExplorar.delegate,
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final p = _personas[i];
                      return _CeldaPersonaExplorar(
                        username: arrobaExplorar(p.username),
                        avatarUrl: p.avatarUrl ?? '',
                        estado: p.estado ?? '',
                        onTap: () => widget.onPerfil(p),
                      );
                    }, childCount: _personas.length),
                  ),
                ),
                if (_cargandoMas)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: FernecitoLoaderCentro(size: 28),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: widget.paddingInferiorScroll),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _programarSyncPreferencias();
    final h = MediaQuery.sizeOf(context).height * 0.9;
    final ciudadesLista = _ciudades.toList()..sort();
    final tieneCiudades = ciudadesLista.isNotEmpty;

    if (widget.embebido) {
      return _buildEmbebido(context, tieneCiudades, ciudadesLista);
    }

    final cuerpo = Column(
      children: [
        if (!widget.embebido) ...[
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ColoresApp.textoSecundario.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        EncabezadoExplorarUbicacion(
          titulo: _tituloExplorar('personas', ciudadesLista),
          onEditar: _elegirCiudad,
        ),
        if (!tieneCiudades)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Elegí una ciudad para ver personas',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ),
          )
        else if (_cargando)
          const Expanded(child: FernecitoLoaderCentro(size: 28))
        else if (_personas.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorCarga ??
                      'No hay personas públicas en estas ciudades.\n'
                          'Solo aparecen quienes tienen ciudad en el perfil (cartelera) y perfil público.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: _errorCarga != null
                        ? ColoresApp.principalMarca
                        : ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: _LayoutGridPersonasExplorar.padding,
                  sliver: SliverGrid(
                    gridDelegate: _LayoutGridPersonasExplorar.delegate,
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final p = _personas[i];
                      return _CeldaPersonaExplorar(
                        username: arrobaExplorar(p.username),
                        avatarUrl: p.avatarUrl ?? '',
                        estado: p.estado ?? '',
                        onTap: () => widget.onPerfil(p),
                      );
                    }, childCount: _personas.length),
                  ),
                ),
                if (_cargandoMas)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: FernecitoLoaderCentro(size: 28),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: widget.embebido
                        ? 24
                        : MediaQuery.paddingOf(context).bottom + 16,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (widget.embebido) {
      return cuerpo;
    }

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: cuerpo,
    );
  }
}

Future<void> mostrarExplorarSquadsSheet(
  BuildContext context, {
  required void Function(SquadExplorarItem s) onSquad,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ExplorarSquadsContenido(
      onSquad: (s) {
        Navigator.of(ctx).pop();
        onSquad(s);
      },
      embebido: false,
    ),
  );
}

class _CeldaPersonaExplorar extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final String estado;
  final VoidCallback onTap;

  const _CeldaPersonaExplorar({
    required this.username,
    required this.avatarUrl,
    required this.estado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: AvatarSocial(
                    url: avatarUrl,
                    size: 60,
                    borderColor: Colors.white.withValues(alpha: 0.14),
                    borderWidth: 1,
                  ),
                ),
                _PillUsernameGlass(username: username),
              ],
            ),
            const SizedBox(height: 5),
            BurbujaEstado(
              texto: estado,
              fontSize: 10.5,
              maxWidth: 102,
              maxLines: 2,
              ajustarAnchoAlTexto: true,
              compacta: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PillUsernameGlass extends StatelessWidget {
  const _PillUsernameGlass({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 108),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoPrincipal.withValues(alpha: 0.92),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class ExplorarSquadsContenido extends StatefulWidget {
  const ExplorarSquadsContenido({
    super.key,
    required this.onSquad,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
    this.encabezadoSuperior,
    this.embebido = true,
    this.paddingInferiorScroll = 0,
  });

  final void Function(SquadExplorarItem s) onSquad;
  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;
  final bool? carteleraInteligenteInicial;
  final Widget? encabezadoSuperior;
  final bool embebido;
  final double paddingInferiorScroll;

  @override
  State<ExplorarSquadsContenido> createState() =>
      _ExplorarSquadsContenidoState();
}

class _ExplorarSquadsContenidoState extends State<ExplorarSquadsContenido> {
  final ServicioSquads _srv = ServicioSquads();
  String _provincia = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudades = {UbicacionesData.ciudadPorDefecto};

  List<SquadExplorarItem> _squads = [];
  String? _errorCarga;
  bool _cargando = false;
  bool _hayMas = false;
  bool _cargandoMas = false;
  bool _syncPreferenciasProgramado = false;

  Set<String>? get _ciudadesDesdeWidget {
    final ciudades = widget.ciudadesIniciales;
    if (ciudades == null || ciudades.isEmpty) return null;
    return Set<String>.from(ciudades);
  }

  String _tituloExplorar(List<String> ciudades) {
    if (ciudades.length == 1) return 'Explorar ${ciudades.first}';
    if (ciudades.length > 1) {
      final inteligente =
          widget.carteleraInteligenteInicial ??
          PreferenciasCartelera.instancia.inteligenteActiva;
      return inteligente
          ? 'Explorar squads cerca tuyo'
          : 'Explorar squads en ${ciudades.length} ciudades';
    }
    return 'Explorar squads';
  }

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(
      _sincronizarPreferenciasAhora,
    );
    _inicializarUbicacion();
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(
      _sincronizarPreferenciasAhora,
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExplorarSquadsContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevas = _ciudadesDesdeWidget;
    if (nuevas == null) return;
    final provincia = widget.provinciaInicial ?? _provincia;
    if (provincia == _provincia && setEquals(nuevas, _ciudades)) return;
    setState(() {
      _provincia = provincia;
      _ciudades = nuevas;
      _squads = [];
      _errorCarga = null;
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  Future<void> _inicializarUbicacion() async {
    final iniciales = _ciudadesDesdeWidget;
    if (iniciales != null) {
      if (!mounted) return;
      setState(() {
        _provincia = widget.provinciaInicial ?? _provincia;
        _ciudades = iniciales;
      });
      _cargar(inicial: true);
      return;
    }
    // Unificado: hereda la ubicación de la cartelera (misma fuente). Fallback: perfil.
    await PreferenciasCartelera.instancia.cargar();
    final activas = PreferenciasCartelera.instancia.ciudadesActivas;
    if (activas.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _provincia =
            PreferenciasCartelera.instancia.provinciaActiva ?? _provincia;
        _ciudades = {...activas};
      });
      _cargar(inicial: true);
      return;
    }
    final ubi = await leerUbicacionPerfilExplorar();
    if (!mounted) return;
    setState(() {
      if (ubi != null) {
        _provincia = ubi.provincia;
        _ciudades = ubi.ciudades;
      }
    });
    if (_ciudades.isNotEmpty) _cargar(inicial: true);
  }

  void _programarSyncPreferencias() {
    if (_syncPreferenciasProgramado || _cargando || _cargandoMas) return;
    _syncPreferenciasProgramado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPreferenciasProgramado = false;
      if (!mounted || _cargando || _cargandoMas) return;
      final prefs = PreferenciasCartelera.instancia;
      final activas = _ciudadesDesdeWidget ?? prefs.ciudadesActivas;
      if (activas.isEmpty) return;
      final provincia =
          widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
      if (provincia == _provincia && setEquals(activas, _ciudades)) return;
      setState(() {
        _provincia = provincia;
        _ciudades = {...activas};
        _squads = [];
        _errorCarga = null;
        _hayMas = false;
      });
      _cargar(inicial: true);
    });
  }

  void _sincronizarPreferenciasAhora() {
    if (!mounted) return;
    if (_cargando || _cargandoMas) {
      _programarSyncPreferencias();
      return;
    }
    final prefs = PreferenciasCartelera.instancia;
    final activas = _ciudadesDesdeWidget ?? prefs.ciudadesActivas;
    if (activas.isEmpty) return;
    final provincia =
        widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
    if (provincia == _provincia && setEquals(activas, _ciudades)) return;
    setState(() {
      _provincia = provincia;
      _ciudades = {...activas};
      _squads = [];
      _errorCarga = null;
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  Future<void> _elegirCiudad() async {
    await PreferenciasCartelera.instancia.cargar();
    if (!mounted) return;
    final prefs = PreferenciasCartelera.instancia;
    final ciudadesWidget = _ciudadesDesdeWidget;
    final ciudadesActuales = ciudadesWidget != null
        ? ciudadesWidget
        : prefs.ciudadesActivas.isNotEmpty
        ? prefs.ciudadesActivas
        : _ciudades;
    final provinciaActual =
        widget.provinciaInicial ?? prefs.provinciaActiva ?? _provincia;
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: provinciaActual,
      ciudadesActuales: ciudadesActuales,
      carteleraInteligente:
          widget.carteleraInteligenteInicial ?? prefs.inteligenteActiva,
    );
    if (res == null || !mounted) return;
    if (res.carteleraInteligente) {
      await ServicioUbicacionGlobal.aplicarInteligente(
        ciudades: res.ciudades,
        provincia: res.provincia,
        principal: res.ciudadPrincipal,
      );
    } else {
      await ServicioUbicacionGlobal.aplicarManual(
        provincia: res.provincia,
        ciudades: res.ciudades,
        principal: res.ciudadPrincipal,
      );
    }
    if (!mounted) return;
    setState(() {
      _provincia = res.provincia;
      _ciudades = res.ciudades.isEmpty
          ? UbicacionesData.ciudadesDe(res.provincia).toSet()
          : res.ciudades;
      _squads = [];
      _hayMas = false;
    });
    if (_ciudades.isNotEmpty) _cargar(inicial: true);
  }

  Future<void> _cargar({required bool inicial}) async {
    if (_ciudades.isEmpty) return;
    setState(() => inicial ? _cargando = true : _cargandoMas = true);
    final pagina = await _srv.explorarCiudades(
      ciudades: _ciudades,
      provincia: _provincia,
      offset: inicial ? 0 : _squads.length,
      limit: inicial ? 40 : 20,
    );
    if (!mounted) return;
    setState(() {
      if (inicial) {
        _squads = pagina.items;
        _errorCarga = pagina.error;
      } else {
        _squads = [..._squads, ...pagina.items];
      }
      _hayMas = pagina.hayMas;
      _cargando = false;
      _cargandoMas = false;
    });
  }

  Widget _buildSquadsEmbebido(
    BuildContext context,
    bool tieneCiudades,
    List<String> ciudadesLista,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.encabezadoSuperior != null) widget.encabezadoSuperior!,
        EncabezadoExplorarUbicacion(
          titulo: _tituloExplorar(ciudadesLista),
          onEditar: _elegirCiudad,
        ),
        if (!tieneCiudades)
          const Expanded(child: Center(child: Text('Elegí una ciudad')))
        else if (_cargando)
          const Expanded(child: FernecitoLoaderCentro(size: 28))
        else if (_squads.isEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _errorCarga ??
                      'No hay squads públicos en estas ciudades.\n'
                          'En la base no hay miembros aceptados en squads todavía.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: _errorCarga != null
                        ? ColoresApp.principalMarca
                        : ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.88,
                        ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final s = _squads[i];
                      return _CeldaSquadExplorar(
                        nombre: s.nombre,
                        avatares: s.avataresResueltos,
                        portada: s.portadaUrl,
                        portadaCacheKey: s.portadaCacheKey,
                        total: s.cantidadMiembros,
                        extra: s.miembrosExtra,
                        onTap: () => widget.onSquad(s),
                      );
                    }, childCount: _squads.length),
                  ),
                ),
                if (_hayMas)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: CupertinoButton(
                        color: ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: _cargandoMas
                            ? null
                            : () => _cargar(inicial: false),
                        child: _cargandoMas
                            ? const FernecitoLoader.inline(size: 16)
                            : Text(
                                'Ver más squads',
                                style: GoogleFonts.baloo2(
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.principalMarca,
                                ),
                              ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: widget.paddingInferiorScroll),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _programarSyncPreferencias();
    final h = MediaQuery.sizeOf(context).height * 0.9;
    final ciudadesLista = _ciudades.toList()..sort();
    final tieneCiudades = ciudadesLista.isNotEmpty;

    if (widget.embebido) {
      return _buildSquadsEmbebido(context, tieneCiudades, ciudadesLista);
    }

    final cuerpo = Column(
      children: [
        if (!widget.embebido) ...[
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ColoresApp.textoSecundario.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        EncabezadoExplorarUbicacion(
          titulo: _tituloExplorar(ciudadesLista),
          onEditar: _elegirCiudad,
          compacto: widget.embebido,
        ),
        if (!tieneCiudades)
          const Expanded(child: Center(child: Text('Elegí una ciudad')))
        else if (_cargando)
          const Expanded(child: FernecitoLoaderCentro(size: 28))
        else if (_squads.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorCarga ??
                      'No hay squads públicos en estas ciudades.\n'
                          'En la base no hay miembros aceptados en squads todavía.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: _errorCarga != null
                        ? ColoresApp.principalMarca
                        : ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final s = _squads[i];
                      return _CeldaSquadExplorar(
                        nombre: s.nombre,
                        avatares: s.avataresResueltos,
                        portada: s.portadaUrl,
                        portadaCacheKey: s.portadaCacheKey,
                        total: s.cantidadMiembros,
                        extra: s.miembrosExtra,
                        onTap: () => widget.onSquad(s),
                      );
                    }, childCount: _squads.length),
                  ),
                ),
                if (_hayMas)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        widget.embebido
                            ? 24
                            : MediaQuery.paddingOf(context).bottom + 16,
                      ),
                      child: CupertinoButton(
                        color: ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: _cargandoMas
                            ? null
                            : () => _cargar(inicial: false),
                        child: _cargandoMas
                            ? const FernecitoLoader.inline(size: 16)
                            : Text(
                                'Ver más squads',
                                style: GoogleFonts.baloo2(
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.principalMarca,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    if (widget.embebido) {
      return cuerpo;
    }

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: cuerpo,
    );
  }
}

class _CeldaSquadExplorar extends StatelessWidget {
  final String nombre;
  final List<String> avatares;
  final String? portada;
  final String? portadaCacheKey;
  final int total;
  final int extra;
  final VoidCallback onTap;

  const _CeldaSquadExplorar({
    required this.nombre,
    required this.avatares,
    this.portada,
    this.portadaCacheKey,
    required this.total,
    required this.extra,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final banner = portada?.trim() ?? '';
    final tieneBanner = banner.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tieneBanner)
              CachedNetworkImage(
                imageUrl: banner,
                cacheKey: portadaCacheKey ?? banner,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => _fondoFallback(),
                errorWidget: (_, __, ___) => _fondoFallback(),
              )
            else
              _fondoFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.48, 0.72, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _StackAvataresExplorar(
                    avatares: avatares,
                    extra: extra,
                    bordeClaro: tieneBanner,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$total miembro${total == 1 ? '' : 's'}',
                    style: GoogleFonts.baloo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
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

  Widget _fondoFallback() {
    return const ColoredBox(color: ColoresApp.fondoPrincipal);
  }
}

class _StackAvataresExplorar extends StatelessWidget {
  final List<String> avatares;
  final int extra;
  final bool bordeClaro;

  const _StackAvataresExplorar({
    required this.avatares,
    required this.extra,
    this.bordeClaro = false,
  });

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const overlap = 22.0;
    final urls = avatares.take(3).toList();
    final count = urls.length + (extra > 0 ? 1 : 0);
    if (count <= 0) {
      return SizedBox(
        height: size,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            CupertinoIcons.person_3,
            size: 22,
            color: bordeClaro
                ? Colors.white.withValues(alpha: 0.55)
                : ColoresApp.textoSecundario,
          ),
        ),
      );
    }
    final width = size + overlap * (count - 1);

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length; i++)
            Positioned(
              left: i * overlap,
              child: _avatarCircle(urls[i], size, bordeClaro: bordeClaro),
            ),
          if (extra > 0)
            Positioned(
              left: urls.length * overlap,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bordeClaro
                      ? ColoresApp.principalMarca.withValues(alpha: 0.85)
                      : ColoresApp.principalMarca.withValues(alpha: 0.2),
                ),
                child: Text(
                  '+$extra',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: bordeClaro
                        ? Colors.white
                        : ColoresApp.principalMarca,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String url, double size, {bool bordeClaro = false}) {
    final borde = bordeClaro ? AvatarBordes.blanco : AvatarBordes.tema;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borde, width: AvatarBordes.ancho()),
        boxShadow: bordeClaro
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: url.isEmpty
            ? ColoredBox(
                color: ColoresApp.fondoSuperficie,
                child: Icon(
                  CupertinoIcons.person_3_fill,
                  size: size * 0.45,
                  color: ColoresApp.textoSecundario,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  CupertinoIcons.person_fill,
                  color: ColoresApp.textoSecundario,
                  size: size * 0.4,
                ),
              ),
      ),
    );
  }
}
