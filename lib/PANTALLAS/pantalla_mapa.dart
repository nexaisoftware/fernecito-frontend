/// Mapa explorar — locales y eventos en mapa full-screen.
library;

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/coordenadas_ciudades.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_mapa_explorar.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/servicio_ubicacion_dispositivo.dart';
import '../core/ubicaciones_data.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/mapa_ui.dart';
import '../widgets/dialogo_fernecito.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_ver_evento.dart';

const _kHomeTabBarHeight = 66.0;

double _homeTabBarBottomInset(BuildContext context) {
  final safe = MediaQuery.paddingOf(context).bottom;
  if (safe <= 10) return safe;
  return (safe * 0.35).clamp(10.0, 14.0);
}

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({
    super.key,
    this.provinciaInicial,
    this.ciudadesIniciales,
    this.carteleraInteligenteInicial,
  });

  final String? provinciaInicial;
  final Set<String>? ciudadesIniciales;

  /// Mismo flag que la cartelera (GPS / «cerca tuyo»).
  final bool? carteleraInteligenteInicial;

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  AnimationController? _animMapa;

  int _modoIndice = 0; // 0 locales, 1 eventos
  bool _cargando = true;

  String _provinciaActiva = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudadesActivas = {UbicacionesData.ciudadPorDefecto};
  bool _filtroInteligente = false;

  List<MapaLocalItem> _locales = const [];
  List<MapaEventoItem> _eventos = const [];

  MapaLocalItem? _localSeleccionado;
  MapaEventoItem? _eventoSeleccionado;

  LatLng? _posicionUsuario;
  bool _ubicacionActiva = false;
  bool _obteniendoUbicacion = false;
  bool _ofrecioUbicacionAlEntrar = false;

  @override
  void initState() {
    super.initState();
    if (widget.provinciaInicial?.isNotEmpty == true) {
      _provinciaActiva = widget.provinciaInicial!;
    }
    if (widget.ciudadesIniciales != null &&
        widget.ciudadesIniciales!.isNotEmpty) {
      _ciudadesActivas = Set<String>.from(widget.ciudadesIniciales!);
    }
    _filtroInteligente =
        widget.carteleraInteligenteInicial ??
        PreferenciasCartelera.instancia.inteligenteActiva;
    _iniciar();
  }

  ResultadoFiltroUbicacion get _filtroActual => ResultadoFiltroUbicacion(
    provincia: _provinciaActiva,
    ciudades: _ciudadesActivas,
    ciudadPrincipal: PreferenciasCartelera.instancia.ciudadPrincipal,
    carteleraInteligente: _filtroInteligente,
  );

  void _volver() {
    Navigator.of(context).pop(_filtroActual);
  }

  @override
  void dispose() {
    _animMapa?.dispose();
    super.dispose();
  }

  void _animarHacia(LatLng destino, double zoom, {bool instantaneo = false}) {
    if (instantaneo) {
      _mapController.move(destino, zoom);
      return;
    }

    _animMapa?.stop();
    _animMapa?.dispose();

    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destino.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destino.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    _animMapa = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    final anim = CurvedAnimation(
      parent: _animMapa!,
      curve: Curves.easeInOutCubic,
    );

    void tick() {
      _mapController.move(
        LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
        zoomTween.evaluate(anim),
      );
    }

    _animMapa!.addListener(tick);
    _animMapa!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animMapa?.removeListener(tick);
      }
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _animMapa?.dispose();
        _animMapa = null;
      }
    });
    _animMapa!.forward();
  }

  double _zoomAlSeleccionar() {
    final z = _mapController.camera.zoom;
    return z < 14 ? 14.5 : z;
  }

  Future<void> _iniciar() async {
    await _cargarDatos();
    if (!mounted) return;
    _centrarEnArea();
    setState(() => _cargando = false);
    _ofrecerUbicacionAlEntrar();
  }

  Future<void> _ofrecerUbicacionAlEntrar() async {
    if (_ofrecioUbicacionAlEntrar || _ubicacionActiva) return;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted || _ubicacionActiva || _cargando) return;
    _ofrecioUbicacionAlEntrar = true;
    _mostrarDialogoSolicitudUbicacion(alEntrar: true);
  }

  Future<void> _cargarDatos() async {
    final localesFuture = ServicioMapaExplorar.instancia.cargarLocales(
      ciudades: _ciudadesActivas,
    );
    final eventosFuture = ServicioMapaExplorar.instancia.cargarEventos(
      ciudades: _ciudadesActivas,
    );
    final res = await Future.wait([localesFuture, eventosFuture]);
    if (!mounted) return;
    setState(() {
      _locales = res[0] as List<MapaLocalItem>;
      _eventos = res[1] as List<MapaEventoItem>;
      _localSeleccionado = null;
      _eventoSeleccionado = null;
    });
  }

  void _tapBotonUbicacion() {
    if (_obteniendoUbicacion) return;
    if (_ubicacionActiva && _posicionUsuario != null) {
      _centrarEnUsuario();
      return;
    }
    _mostrarDialogoSolicitudUbicacion();
  }

  void _mostrarDialogoSolicitudUbicacion({bool alEntrar = false}) {
    showFernecitoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogoFernecito(
        title: Text(alEntrar ? '¿Activar ubicación?' : 'Usar tu ubicación'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            alEntrar
                ? 'Esto te permitirá ver qué locales y eventos están cerca de ti '
                      'y las distancias en el mapa.\n\n'
                      'En el próximo paso, el sistema o el navegador te pedirán permiso.'
                : 'Fernecito necesita acceder a tu ubicación para mostrarte en el mapa '
                      'y centrarlo cerca tuyo.\n\n'
                      'En el próximo paso, el sistema o el navegador te pedirán permiso.',
          ),
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ahora no'),
          ),
          AccionDialogoFernecito(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _ejecutarSolicitudUbicacionDesdeGesto();
            },
            child: const Text('Permitir ubicación'),
          ),
        ],
      ),
    );
  }

  /// Arranca la lectura GPS en el mismo gesto del botón (requerido en PWA/web).
  void _ejecutarSolicitudUbicacionDesdeGesto() {
    if (_obteniendoUbicacion) return;
    setState(() => _obteniendoUbicacion = true);

    final futuro = ServicioUbicacionDispositivo.instancia
        .iniciarDesdeGestoUsuario();

    futuro
        .then((res) {
          if (!mounted) return;
          if (res.exito && res.latitud != null && res.longitud != null) {
            setState(() {
              _posicionUsuario = LatLng(res.latitud!, res.longitud!);
              _ubicacionActiva = true;
            });
            _centrarEnUsuario();
            return;
          }
          if (res.mensajeUsuario != null) {
            _mostrarAvisoUbicacion(
              res.mensajeUsuario!,
              ofrecerAjustes: res.ofrecerAjustes,
            );
          }
        })
        .whenComplete(() {
          if (mounted) setState(() => _obteniendoUbicacion = false);
        });
  }

  Future<void> _mostrarAvisoUbicacion(
    String mensaje, {
    bool ofrecerAjustes = false,
  }) async {
    if (!mounted) return;
    await showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Ubicación'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(mensaje),
        ),
        actions: [
          if (ofrecerAjustes)
            AccionDialogoFernecito(
              onPressed: () {
                Navigator.of(ctx).pop();
                ServicioUbicacionDispositivo.instancia.abrirAjustes();
              },
              child: const Text('Abrir ajustes'),
            ),
          AccionDialogoFernecito(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _centrarEnArea() {
    final centro = CoordenadasCiudades.centroDeCiudades(_ciudadesActivas);
    final zoom = CoordenadasCiudades.zoomParaCiudades(_ciudadesActivas);
    _animarHacia(centro, zoom, instantaneo: true);
  }

  void _centrarEnUsuario() {
    final p = _posicionUsuario;
    if (p == null) return;
    _animarHacia(p, 15);
  }

  Future<void> _abrirFiltroUbicacion() async {
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: _provinciaActiva,
      ciudadesActuales: _ciudadesActivas,
      carteleraInteligente: _filtroInteligente,
    );
    // Igual que cartelera: cerrar sin aplicar = no cambia nada.
    if (res == null || res.ciudades.isEmpty || !mounted) return;

    setState(() {
      _provinciaActiva = res.provincia;
      _ciudadesActivas = Set<String>.from(res.ciudades);
      _filtroInteligente = res.carteleraInteligente;
      _cargando = true;
      _localSeleccionado = null;
      _eventoSeleccionado = null;
    });

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

    await _cargarDatos();
    if (!mounted) return;
    _centrarEnArea();
    setState(() => _cargando = false);
  }

  void _seleccionarLocal(MapaLocalItem item) {
    setState(() {
      _localSeleccionado = item;
      _eventoSeleccionado = null;
    });
    _animarHacia(item.coordenadas, _zoomAlSeleccionar());
  }

  void _seleccionarEvento(MapaEventoItem item) {
    setState(() {
      _eventoSeleccionado = item;
      _localSeleccionado = null;
    });
    _animarHacia(item.coordenadas, _zoomAlSeleccionar());
  }

  void _verDetalleSeleccionado() {
    if (_modoIndice == 0 && _localSeleccionado != null) {
      final l = _localSeleccionado!;
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PantallaLocalPerfil(
            avatarUrl: l.avatarUrl ?? '',
            nombreLocal: l.nombre,
            idLocal: l.id,
          ),
        ),
      );
      return;
    }
    if (_modoIndice == 1 && _eventoSeleccionado != null) {
      final e = _eventoSeleccionado!;
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PantallaVerEvento(
            evento: {
              'id': e.id,
              'titulo': e.titulo,
              'flyer': e.flyerUrl ?? '',
              'nombreLocal': e.nombreLocal,
              'avatarLocal': e.avatarLocal ?? '',
              'idLocal': e.idLocal,
              'descripcion': e.descripcion ?? '',
              'fechaInicio': e.fechaInicio?.toIso8601String(),
              'ciudadEvento': e.ciudad,
              'provinciaEvento': e.provincia,
              'localEsPionero': e.localEsPionero,
              'tienePromo': e.tienePromo,
            },
          ),
        ),
      );
    }
  }

  String get _etiquetaCiudad {
    if (_filtroInteligente) return 'cerca tuyo';
    if (_ciudadesActivas.isEmpty) return 'Elegir ciudad';
    if (_ciudadesActivas.length == 1) return _ciudadesActivas.first;
    return '${_ciudadesActivas.length} ciudades';
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final cardTop = padding.top + 52;
    final switchBottom =
        _homeTabBarBottomInset(context) + _kHomeTabBarHeight + 14;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _volver();
      },
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: CoordenadasCiudades.centroDeCiudades(
                  _ciudadesActivas,
                ),
                initialZoom: CoordenadasCiudades.zoomParaCiudades(
                  _ciudadesActivas,
                ),
                minZoom: 8,
                maxZoom: 18,
                backgroundColor: const Color(0xFF0D0D0F),
                onTap: (_, __) {
                  setState(() {
                    _localSeleccionado = null;
                    _eventoSeleccionado = null;
                  });
                },
              ),
              children: [
                const CapaTilesMapaConTema(),
                if (_ubicacionActiva && _posicionUsuario != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _posicionUsuario!,
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        child: PinUbicacionUsuario(),
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),

            // Header: back + filtro ciudad
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _BotonGlass(
                    onTap: _volver,
                    child: const Icon(
                      CupertinoIcons.back,
                      color: ColoresApp.textoPrincipal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _abrirFiltroUbicacion,
                      child: _BotonGlass(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 16,
                              color: ColoresApp.principalMarca,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _etiquetaCiudad,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.baloo2(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: ColoresApp.textoPrincipal,
                                ),
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 14,
                              color: ColoresApp.textoSecundario,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card info flotante
            Positioned(
              top: cardTop,
              left: 16,
              right: 16,
              child: MapaCardInfoFlotante(
                visible:
                    _localSeleccionado != null || _eventoSeleccionado != null,
                local: _localSeleccionado,
                evento: _eventoSeleccionado,
                posicionUsuario: _ubicacionActiva ? _posicionUsuario : null,
                onVerDetalle: _verDetalleSeleccionado,
              ),
            ),

            // Switch Locales / Eventos
            Positioned(
              left: 0,
              right: 0,
              bottom: switchBottom,
              child: Center(
                child: MapaSwitchModo(
                  indice: _modoIndice,
                  onChanged: (i) => setState(() {
                    _modoIndice = i;
                    _localSeleccionado = null;
                    _eventoSeleccionado = null;
                  }),
                ),
              ),
            ),

            // Botón ubicación — arriba del switch, esquina inferior derecha
            Positioned(
              right: 16,
              bottom: switchBottom + 58,
              child: BotonUbicacionMapa(
                activo: _ubicacionActiva,
                cargando: _obteniendoUbicacion,
                onTap: _obteniendoUbicacion ? null : _tapBotonUbicacion,
              ),
            ),

            if (_cargando)
              ColoredBox(
                color: const Color(0x88000000),
                child: Center(child: LoaderMapaIconosAnimado(size: 40)),
              ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    if (_modoIndice == 0) {
      return _locales.map((l) {
        final sel = _localSeleccionado?.id == l.id;
        return Marker(
          point: l.coordenadas,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _seleccionarLocal(l),
            child: PinAvatarLocalMapa(
              imageUrl: l.avatarUrl,
              esPionero: l.esPionero,
              seleccionado: sel,
            ),
          ),
        );
      }).toList();
    }

    return _eventos.map((e) {
      final sel = _eventoSeleccionado?.id == e.id;
      return Marker(
        point: e.coordenadas,
        width: e.tienePromo ? 56 : 52,
        height: e.tienePromo ? 72 : 68,
        child: GestureDetector(
          onTap: () => _seleccionarEvento(e),
          child: PinFlyerEventoMapa(
            flyerUrl: e.flyerUrl,
            seleccionado: sel,
            tienePromo: e.tienePromo,
            ancho: 48,
            alto: 64,
          ),
        ),
      );
    }).toList();
  }
}

class _BotonGlass extends StatelessWidget {
  const _BotonGlass({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
