/// Bottom sheets para explorar personas y squads por ciudad.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../core/ubicaciones_data.dart';
import '../models/social.dart';
import 'burbuja_estado.dart';
import 'filtro_ubicaciones_sheet.dart';
import 'social_ui.dart';

const int _kExplorarPagina = 27;

String arrobaExplorar(String u) {
  final t = u.trim();
  if (t.isEmpty) return '@usuario';
  return t.startsWith('@') ? t : '@$t';
}

/// Provincia + ciudades desde `perfiles_usuarios` (misma fuente que cartelera).
Future<({String provincia, Set<String> ciudades})?> leerUbicacionPerfilExplorar() async {
  final uid = ServicioSupabase().usuarioActual?.id;
  if (uid == null) return null;
  try {
    final resp = await ServicioSupabase().cliente
        .from('perfiles_usuarios')
        .select('provincia, provincia_usuario, ciudad, ciudades_preferidas')
        .eq('id', uid)
        .maybeSingle();
    if (resp == null) return null;

    final provincia = (resp['provincia'] as String?)?.trim() ??
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
  });

  final String titulo;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
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
    builder: (ctx) => _ExplorarPersonasSheet(onPerfil: onPerfil),
  );
}

Future<void> mostrarExplorarSquadsSheet(
  BuildContext context, {
  required void Function(SquadExplorarItem s) onSquad,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ExplorarSquadsSheet(onSquad: onSquad),
  );
}

class _ExplorarPersonasSheet extends StatefulWidget {
  final void Function(UsuarioBusqueda u) onPerfil;

  const _ExplorarPersonasSheet({required this.onPerfil});

  @override
  State<_ExplorarPersonasSheet> createState() => _ExplorarPersonasSheetState();
}

class _ExplorarPersonasSheetState extends State<_ExplorarPersonasSheet> {
  final ServicioAmigos _srv = ServicioAmigos();
  final ScrollController _scroll = ScrollController();
  String _provincia = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudades = {UbicacionesData.ciudadPorDefecto};
  String? _ciudadActiva;

  List<UsuarioBusqueda> _personas = [];
  String? _errorCarga;
  bool _cargando = false;
  bool _hayMas = false;
  bool _cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollFin);
    _inicializarUbicacion();
  }

  @override
  void dispose() {
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
    final ubi = await leerUbicacionPerfilExplorar();
    if (!mounted) return;
    setState(() {
      if (ubi != null) {
        _provincia = ubi.provincia;
        _ciudades = ubi.ciudades;
      }
      _ciudadActiva = _ciudades.length == 1 ? _ciudades.first : null;
    });
    if (_ciudadActiva != null) _cargar(inicial: true);
  }

  Future<void> _elegirCiudad() async {
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: _provincia,
      ciudadesActuales: _ciudades,
    );
    if (res == null || !mounted) return;
    setState(() {
      _provincia = res.provincia;
      _ciudades = res.ciudades.isEmpty
          ? UbicacionesData.ciudadesDe(res.provincia).toSet()
          : res.ciudades;
      _ciudadActiva = _ciudades.length == 1 ? _ciudades.first : null;
      _personas = [];
      _hayMas = false;
    });
    if (_ciudadActiva != null) _cargar(inicial: true);
  }

  void _seleccionarCiudadChip(String c) {
    setState(() {
      _ciudadActiva = c;
      _personas = [];
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  Future<void> _cargar({required bool inicial}) async {
    final ciudad = _ciudadActiva;
    if (ciudad == null) return;
    if (!inicial && (!_hayMas || _cargandoMas)) return;
    if (inicial) {
      setState(() => _cargando = true);
    } else {
      setState(() => _cargandoMas = true);
    }
    final pagina = await _srv.explorarCiudad(
      ciudad: ciudad,
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

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.9;
    final ciudad = _ciudadActiva;
    final ciudadesLista = _ciudades.toList()..sort();

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ColoresApp.textoSecundario.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          EncabezadoExplorarUbicacion(
            titulo: ciudad != null
                ? 'Personas de $ciudad'
                : 'Explorar personas',
            onEditar: _elegirCiudad,
          ),
          if (ciudadesLista.length > 1)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ciudadesLista.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = ciudadesLista[i];
                  final sel = c == ciudad;
                  return GestureDetector(
                    onTap: () => _seleccionarCiudadChip(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? ColoresApp.principalMarca
                            : ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ColoresApp.principalMarca
                              .withValues(alpha: sel ? 1 : 0.3),
                        ),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (ciudad == null)
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
            const Expanded(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_personas.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorCarga ??
                        'No hay personas públicas en $ciudad.\n'
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = _personas[i];
                          return _CeldaPersonaExplorar(
                            username: arrobaExplorar(p.username),
                            avatarUrl: p.avatarUrl ?? '',
                            estado: p.estado ?? '',
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onPerfil(p);
                            },
                          );
                        },
                        childCount: _personas.length,
                      ),
                    ),
                  ),
                  if (_cargandoMas)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColoresApp.principalMarca,
            ),
          ),
          const SizedBox(height: 6),
          AvatarSocialGlow(url: avatarUrl, size: 68),
          const SizedBox(height: 6),
          BurbujaEstado(
            texto: estado,
            fontSize: 9.5,
            maxWidth: 100,
            maxLines: 2,
            ajustarAnchoAlTexto: true,
            compacta: true,
          ),
        ],
      ),
    );
  }
}

class _ExplorarSquadsSheet extends StatefulWidget {
  final void Function(SquadExplorarItem s) onSquad;

  const _ExplorarSquadsSheet({required this.onSquad});

  @override
  State<_ExplorarSquadsSheet> createState() => _ExplorarSquadsSheetState();
}

class _ExplorarSquadsSheetState extends State<_ExplorarSquadsSheet> {
  final ServicioSquads _srv = ServicioSquads();
  String _provincia = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudades = {UbicacionesData.ciudadPorDefecto};
  String? _ciudadActiva;

  List<SquadExplorarItem> _squads = [];
  String? _errorCarga;
  bool _cargando = false;
  bool _hayMas = false;
  bool _cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
  }

  Future<void> _inicializarUbicacion() async {
    final ubi = await leerUbicacionPerfilExplorar();
    if (!mounted) return;
    setState(() {
      if (ubi != null) {
        _provincia = ubi.provincia;
        _ciudades = ubi.ciudades;
      }
      _ciudadActiva = _ciudades.length == 1 ? _ciudades.first : null;
    });
    if (_ciudadActiva != null) _cargar(inicial: true);
  }

  Future<void> _elegirCiudad() async {
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: _provincia,
      ciudadesActuales: _ciudades,
    );
    if (res == null || !mounted) return;
    setState(() {
      _provincia = res.provincia;
      _ciudades = res.ciudades.isEmpty
          ? UbicacionesData.ciudadesDe(res.provincia).toSet()
          : res.ciudades;
      _ciudadActiva = _ciudades.length == 1 ? _ciudades.first : null;
      _squads = [];
      _hayMas = false;
    });
    if (_ciudadActiva != null) _cargar(inicial: true);
  }

  void _seleccionarCiudadChip(String c) {
    setState(() {
      _ciudadActiva = c;
      _squads = [];
      _hayMas = false;
    });
    _cargar(inicial: true);
  }

  Future<void> _cargar({required bool inicial}) async {
    final ciudad = _ciudadActiva;
    if (ciudad == null) return;
    setState(() => inicial ? _cargando = true : _cargandoMas = true);
    final pagina = await _srv.explorarCiudad(
      ciudad: ciudad,
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

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.9;
    final ciudad = _ciudadActiva;
    final ciudadesLista = _ciudades.toList()..sort();

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ColoresApp.textoSecundario.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          EncabezadoExplorarUbicacion(
            titulo: ciudad != null ? 'Squads en $ciudad' : 'Explorar squads',
            onEditar: _elegirCiudad,
          ),
          if (ciudadesLista.length > 1)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ciudadesLista.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = ciudadesLista[i];
                  final sel = c == ciudad;
                  return GestureDetector(
                    onTap: () => _seleccionarCiudadChip(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? ColoresApp.principalMarca
                            : ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ColoresApp.principalMarca
                              .withValues(alpha: sel ? 1 : 0.3),
                        ),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (ciudad == null)
            const Expanded(
              child: Center(
                child: Text('Elegí una ciudad'),
              ),
            )
          else if (_cargando)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))
          else if (_squads.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorCarga ??
                        'No hay squads públicos con miembros en $ciudad.\n'
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
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final s = _squads[i];
                          return _CeldaSquadExplorar(
                            nombre: s.nombre,
                            avatares: s.avataresResueltos,
                            portada: s.portadaUrl,
                            portadaCacheKey: s.portadaCacheKey,
                            total: s.cantidadMiembros,
                            extra: s.miembrosExtra,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSquad(s);
                            },
                          );
                        },
                        childCount: _squads.length,
                      ),
                    ),
                  ),
                  if (_hayMas)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        child: CupertinoButton(
                          color: ColoresApp.fondoSuperficie,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _cargandoMas
                              ? null
                              : () => _cargar(inicial: false),
                          child: _cargandoMas
                              ? const CupertinoActivityIndicator()
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
      ),
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
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.45, 1.0],
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
    return ColoredBox(
      color: ColoresApp.fondoSuperficie,
      child: Center(
        child: Icon(
          CupertinoIcons.person_3_fill,
          size: 36,
          color: ColoresApp.principalMarca.withValues(alpha: 0.28),
        ),
      ),
    );
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
                  border: Border.all(
                    color: bordeClaro
                        ? Colors.white
                        : ColoresApp.principalMarca.withValues(alpha: 0.5),
                    width: bordeClaro ? 2 : 1,
                  ),
                ),
                child: Text(
                  '+$extra',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: bordeClaro ? Colors.white : ColoresApp.principalMarca,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String url, double size, {bool bordeClaro = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: bordeClaro ? Colors.white : ColoresApp.fondoPrincipal,
          width: bordeClaro ? 2 : 2,
        ),
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
