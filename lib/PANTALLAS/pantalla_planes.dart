library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/compartir_evento.dart' show origenCompartirDesdeContexto;
import '../core/compartir_plan.dart';
import '../core/constants.dart';
import '../core/flujo_reporte.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/ubicaciones_data.dart';
import '../core/servicio_planes.dart';
import '../widgets/card_plan_comunidad.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/social_ui.dart';
import '../widgets/dialogo_fernecito.dart';
import 'pantalla_administrar_planes.dart';
import 'pantalla_crear_plan.dart';
import 'pantalla_ver_plan.dart';

/// Cartelera de Planes: explorar juntadas + mis planes/historial.
class PantallaPlanes extends StatefulWidget {
  const PantallaPlanes({super.key});

  @override
  State<PantallaPlanes> createState() => _PantallaPlanesState();
}

class _PantallaPlanesState extends State<PantallaPlanes> {
  final _srv = ServicioPlanes();
  final _scroll = ScrollController();
  final _busquedaCtrl = TextEditingController();
  final _busquedaFocus = FocusNode();

  List<PlanComunidad> _planes = const [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String _tab = 'explorar';
  String? _uniendoId;
  String? _error;
  String _q = '';

  /// Descarta respuestas viejas si cambia la ciudad a mitad de un request.
  int _genUbicacion = 0;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(_onUbicacion);
    _scroll.addListener(_onScroll);
    _busquedaCtrl.addListener(_onBusquedaChanged);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(_onUbicacion);
    _busquedaCtrl.removeListener(_onBusquedaChanged);
    _busquedaCtrl.dispose();
    _busquedaFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onBusquedaChanged() {
    final next = _busquedaCtrl.text.trim();
    if (next == _q) return;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_busquedaCtrl.text.trim() != next) return;
      setState(() => _q = next);
      if (_tab == 'explorar') _cargar(reset: true);
    });
  }

  void _onUbicacion() {
    if (_tab == 'explorar') _cargar(reset: true);
  }

  void _onScroll() {
    if (!_hayMas || _cargandoMas || _cargando || !_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 280) {
      _cargar(reset: false);
    }
  }

  Future<void> _cargar({required bool reset}) async {
    final gen = reset ? ++_genUbicacion : _genUbicacion;
    if (reset) {
      // Limpiar al toque: si no, quedan cards de la ciudad anterior
      // mientras llega la query nueva.
      setState(() {
        _cargando = true;
        _error = null;
        _planes = const [];
        _hayMas = false;
      });
    } else {
      if (_cargandoMas) return;
      setState(() => _cargandoMas = true);
    }

    await PreferenciasCartelera.instancia.cargar();
    final prefs = PreferenciasCartelera.instancia;
    final offset = reset ? 0 : _planes.length;

    final res = await _srv.hub(
      ciudades: _tab == 'explorar' ? prefs.ciudadesActivas : const {},
      provincia: _tab == 'explorar' ? prefs.provinciaActiva : null,
      limit: _pageSize,
      offset: offset,
      modo: _tab == 'mis' ? 'mis' : 'explorar',
      q: _tab == 'explorar' ? _q : null,
    );

    // Sin fallback a “todas las ciudades”: la ubicación del local define el feed.

    if (!mounted || gen != _genUbicacion) return;
    setState(() {
      if (res.error != null && reset) {
        _error = res.error;
        _planes = const [];
        _hayMas = false;
      } else {
        _error = null;
        _planes = reset ? res.items : [..._planes, ...res.items];
        _hayMas = res.hayMas;
      }
      _cargando = false;
      _cargandoMas = false;
    });
  }

  Future<void> _cambiarTab(String tab) async {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _planes = const [];
      _hayMas = false;
    });
    await _cargar(reset: true);
  }

  Future<void> _crearPlan() async {
    final creado = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PantallaCrearPlan(),
      ),
    );
    if (creado == true) {
      await _cargar(reset: true);
    }
  }

  Future<void> _abrirPlan(PlanComunidad plan) async {
    if (plan.estaFinalizado && _tab == 'mis') return;
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => PantallaVerPlan(idPlan: plan.id, inicial: plan),
      ),
    );
    if (changed == true) await _cargar(reset: true);
  }

  Future<void> _administrarPlanes() async {
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PantallaAdministrarPlanes(),
      ),
    );
    if (changed == true) await _cargar(reset: true);
  }

  Future<void> _unirse(PlanComunidad plan) async {
    if (!plan.puedeUnirse) return;
    String? idSquad;
    if (plan.permiteSquads) {
      idSquad = await _elegirIdentidadUnion(plan);
      if (idSquad == '__cancel__') return;
    }
    setState(() => _uniendoId = plan.id);
    try {
      final res = await _srv.solicitarUnirse(
        plan.id,
        idSquad: idSquad?.isEmpty == true ? null : idSquad,
      );
      if (!mounted) return;
      if (res == null) {
        _toast('No se pudo sumar. Probá de nuevo.');
        return;
      }
      final estado = res.estado;
      setState(() {
        _planes = _planes
            .map(
              (p) => p.id == plan.id
                  ? p.copyWith(
                      miEstado: estado,
                      cupoUsados: estado == 'aceptado'
                          ? p.cupoUsados + res.cantidad
                          : p.cupoUsados,
                    )
                  : p,
            )
            .toList(growable: false);
      });
      _toast(
        estado == 'aceptado'
            ? '¡Adentro! Ya podés entrar al chat del plan.'
            : 'Pedido enviado. Te avisan si te aceptan.',
      );
    } catch (e) {
      _toast(_srv.mensajeError(e, accion: 'sumarte'));
    } finally {
      if (mounted) setState(() => _uniendoId = null);
    }
  }

  Future<void> _reportarPlan(PlanComunidad plan) async {
    await mostrarFlujoReporte(
      context: context,
      entidad: 'este plan',
      targetTipo: 'plan',
      targetId: plan.id,
    );
  }

  Future<String?> _elegirIdentidadUnion(PlanComunidad plan) async {
    final squads = await _srv.misSquads();
    if (!mounted) return '__cancel__';
    final accion = plan.modoLista == 'manual' ? 'solicitar' : 'unirte';
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.paddingOf(ctx).bottom + 12,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                plan.modoLista == 'manual'
                    ? '¿Cómo querés solicitar unirte?'
                    : '¿Cómo te sumás?',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 10),
              _OpcionUnion(
                titulo: plan.modoLista == 'manual'
                    ? 'Solicitar solo'
                    : 'Voy solo',
                subtitulo: 'Vas a $accion con tu perfil.',
                icono: CupertinoIcons.person_fill,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final s in squads)
                _OpcionUnion(
                  titulo: plan.modoLista == 'manual'
                      ? 'Solicitar con ${s.nombre}'
                      : 'Ir con ${s.nombre}',
                  subtitulo:
                      '$accion con ${s.cantidadMiembros} miembros del squad',
                  icono: CupertinoIcons.person_3_fill,
                  onTap: () => Navigator.pop(ctx, s.idGrupo),
                ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(ctx, '__cancel__'),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String texto) {
    showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        content: Text(texto),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  String _textoZona(PreferenciasCartelera prefs) {
    final ciudades = prefs.ciudadesActivas;
    if (prefs.inteligenteActiva) return 'Planes de la comunidad';
    if (ciudades.isEmpty) return 'Planes de la comunidad';
    if (ciudades.length == 1) return 'Planes en ${ciudades.first}';
    return 'Planes en ${ciudades.length} ciudades';
  }

  Future<void> _elegirUbicacion() async {
    await PreferenciasCartelera.instancia.cargar();
    if (!mounted) return;
    final prefs = PreferenciasCartelera.instancia;
    final provincia =
        prefs.provinciaActiva ?? UbicacionesData.provinciaPorDefecto;
    final ciudades = prefs.ciudadesActivas.isNotEmpty
        ? prefs.ciudadesActivas
        : {UbicacionesData.ciudadPorDefecto};
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: provincia,
      ciudadesActuales: ciudades,
      carteleraInteligente: prefs.inteligenteActiva,
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
    await _cargar(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferenciasCartelera.instancia;
    final zona = _textoZona(prefs);

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: ColoresApp.principalMarca,
              backgroundColor: const Color(0xFF1E1E1E),
              onRefresh: () => _cargar(reset: true),
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => Navigator.of(context).pop(),
                                child: Icon(
                                  CupertinoIcons.chevron_left,
                                  color: ColoresApp.principalMarca,
                                  size: 30,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Planes',
                                style: GoogleFonts.baloo2(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: ColoresApp.textoPrincipal,
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 30),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            zona,
                            style: GoogleFonts.baloo2(
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _UbicacionPlanesBadge(
                            texto: prefs.inteligenteActiva
                                ? 'Ubicación inteligente'
                                : (prefs.ciudadesActivas.length == 1
                                      ? prefs.ciudadesActivas.first
                                      : 'Elegir zona'),
                            onTap: _elegirUbicacion,
                          ),
                          if (_tab == 'explorar') ...[
                            const SizedBox(height: 10),
                            CupertinoTextField(
                              controller: _busquedaCtrl,
                              focusNode: _busquedaFocus,
                              placeholder: 'Buscar plan, local, persona…',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: Icon(
                                  CupertinoIcons.search,
                                  size: 18,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                              suffix: _q.isEmpty
                                  ? null
                                  : Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: GestureDetector(
                                        onTap: () {
                                          _busquedaCtrl.clear();
                                          setState(() => _q = '');
                                          _cargar(reset: true);
                                        },
                                        child: const Icon(
                                          CupertinoIcons.clear_circled_solid,
                                          size: 18,
                                          color: ColoresApp.textoSecundario,
                                        ),
                                      ),
                                    ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                color: ColoresApp.textoPrincipal,
                              ),
                              placeholderStyle: GoogleFonts.baloo2(
                                fontSize: 14,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _TabsPlanes(tab: _tab, onChanged: _cambiarTab),
                          if (_tab == 'mis') ...[
                            const SizedBox(height: 10),
                            _AdministrarPlanesButton(onTap: _administrarPlanes),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_cargando)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: FernecitoLoader.inline(size: 28)),
                    )
                  else if (_error != null && _planes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorPlanes(
                        mensaje: _error!,
                        onReintentar: () => _cargar(reset: true),
                      ),
                    )
                  else if (_planes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _VacioPlanes(
                        modo: _tab,
                        busqueda: _q,
                        onReintentar: () => _cargar(reset: true),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 150),
                      sliver: SliverList.separated(
                        itemCount: _planes.length + (_cargandoMas ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          if (i >= _planes.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: FernecitoLoader.inline(size: 22),
                              ),
                            );
                          }
                          final plan = _planes[i];
                          return CardPlanComunidad(
                            plan: plan,
                            uniendo: _uniendoId == plan.id,
                            onTap: () => _abrirPlan(plan),
                            onUnirse: () => _unirse(plan),
                            onReportar: () => _reportarPlan(plan),
                            onCompartir: () => compartirPlan(
                              idPlan: plan.id,
                              titulo: plan.titulo,
                              nombreLocal: plan.nombreLocal,
                              ciudad: plan.ciudad,
                              fechaInicio: plan.fechaInicio,
                              sharePositionOrigin: origenCompartirDesdeContexto(
                                context,
                              ),
                              feedbackContext: context,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0xCC000000),
                        Color(0xF2000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: Center(child: _CrearPlanFab(onTap: _crearPlan)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabsPlanes extends StatelessWidget {
  const _TabsPlanes({required this.tab, required this.onChanged});
  final String tab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ToggleSegmentadoSocial(
      opciones: const ['Ver planes', 'Mis planes'],
      indice: tab == 'mis' ? 1 : 0,
      onChanged: (i) => onChanged(i == 1 ? 'mis' : 'explorar'),
      anchoMaximo: 340,
      paddingVertical: 8,
      fontSize: 14,
      sinBorde: true,
    );
  }
}

class _UbicacionPlanesBadge extends StatelessWidget {
  const _UbicacionPlanesBadge({required this.texto, required this.onTap});
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.location_solid,
            size: 15,
            color: ColoresApp.principalMarca,
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Editar',
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ColoresApp.principalMarca,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdministrarPlanesButton extends StatelessWidget {
  const _AdministrarPlanesButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.slider_horizontal_3,
            size: 17,
            color: ColoresApp.principalMarca,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Administrar',
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColoresApp.principalMarca,
              boxShadow: [
                BoxShadow(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

class _CrearPlanFab extends StatelessWidget {
  const _CrearPlanFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ColoresApp.principalMarca.withValues(alpha: 0.36),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(
              'Crear plan',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionUnion extends StatelessWidget {
  const _OpcionUnion({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icono, color: ColoresApp.principalMarca),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
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
      ),
    );
  }
}

class _ErrorPlanes extends StatelessWidget {
  const _ErrorPlanes({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.wifi_exclamationmark,
            size: 42,
            color: ColoresApp.principalMarca.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            'No se pudieron cargar',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Probá de nuevo en un momento.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario,
            ),
          ),
          if (mensaje.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: ColoresApp.principalMarca.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            onPressed: onReintentar,
            child: Text(
              'Reintentar',
              style: GoogleFonts.baloo2(
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

class _VacioPlanes extends StatelessWidget {
  const _VacioPlanes({
    required this.modo,
    required this.onReintentar,
    this.busqueda = '',
  });
  final String modo;
  final String busqueda;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final hayQ = busqueda.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hayQ
                ? CupertinoIcons.search
                : modo == 'mis'
                ? CupertinoIcons.calendar
                : CupertinoIcons.calendar_badge_plus,
            size: 42,
            color: ColoresApp.principalMarca.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            hayQ
                ? 'No hay planes con esa búsqueda'
                : modo == 'mis'
                ? 'Todavía no tenés planes'
                : 'Todavía no hay planes por acá',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hayQ
                ? 'Probá con otra palabra o limpiá el buscador.'
                : modo == 'mis'
                ? 'Creá uno o sumate desde Explorar.'
                : 'Cuando haya juntadas en tu zona, van a aparecer acá.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 13.5,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: ColoresApp.principalMarca.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            onPressed: onReintentar,
            child: Text(
              'Reintentar',
              style: GoogleFonts.baloo2(
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
