library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/ubicaciones_data.dart';
import '../core/servicio_planes.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/fernecito_loader.dart';
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

  List<PlanComunidad> _planes = const [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String _tab = 'explorar';
  String? _uniendoId;
  String? _error;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(_onUbicacion);
    _scroll.addListener(_onScroll);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(_onUbicacion);
    _scroll.dispose();
    super.dispose();
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
    if (reset) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    } else {
      if (_cargandoMas) return;
      setState(() => _cargandoMas = true);
    }

    await PreferenciasCartelera.instancia.cargar();
    final prefs = PreferenciasCartelera.instancia;
    final offset = reset ? 0 : _planes.length;

    var res = await _srv.hub(
      ciudades: _tab == 'explorar' ? prefs.ciudadesActivas : const {},
      provincia: _tab == 'explorar' ? prefs.provinciaActiva : null,
      limit: _pageSize,
      offset: offset,
      modo: _tab == 'mis' ? 'mis' : 'explorar',
    );

    // Si en la zona exacta no hay nada, ampliamos a provincia / general
    // para que el hub no quede vacío por un mismatch de nombre de ciudad.
    if (reset &&
        _tab == 'explorar' &&
        res.error == null &&
        res.items.isEmpty &&
        prefs.ciudadesActivas.isNotEmpty) {
      res = await _srv.hub(
        ciudades: const {},
        provincia: prefs.provinciaActiva,
        limit: _pageSize,
        offset: 0,
        modo: 'explorar',
      );
      if (res.error == null && res.items.isEmpty) {
        res = await _srv.hub(
          ciudades: const {},
          provincia: null,
          limit: _pageSize,
          offset: 0,
          modo: 'explorar',
        );
      }
    }

    if (!mounted) return;
    setState(() {
      if (res.error != null && reset) {
        _error = res.error;
        if (_planes.isEmpty) _planes = const [];
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
      final estado = await _srv.solicitarUnirse(
        plan.id,
        idSquad: idSquad?.isEmpty == true ? null : idSquad,
      );
      if (!mounted) return;
      if (estado == null) {
        _toast('No se pudo sumar. Probá de nuevo.');
        return;
      }
      setState(() {
        _planes = _planes
            .map(
              (p) => p.id == plan.id
                  ? p.copyWith(
                      miEstado: estado,
                      cupoUsados: estado == 'aceptado'
                          ? p.cupoUsados + 1
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
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(texto),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  String _textoZona(PreferenciasCartelera prefs) {
    final ciudades = prefs.ciudadesActivas;
    if (prefs.inteligenteActiva) return 'Planes cerca tuyo';
    if (ciudades.isEmpty) return 'Planes cerca tuyo';
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
                            'Juntadas para salir',
                            style: GoogleFonts.baloo2(
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tab == 'mis'
                                ? 'Tus planes activos, pendientes e historial.'
                                : 'Sumate y conocé gente antes de salir.',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _UbicacionPlanesBadge(
                            texto: zona,
                            onTap: _elegirUbicacion,
                          ),
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
                          return _CardPlan(
                            plan: plan,
                            uniendo: _uniendoId == plan.id,
                            onTap: () => _abrirPlan(plan),
                            onUnirse: () => _unirse(plan),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Ver planes',
            active: tab == 'explorar',
            onTap: () => onChanged('explorar'),
          ),
          _TabPill(
            label: 'Mis planes',
            active: tab == 'mis',
            onTap: () => onChanged('mis'),
          ),
        ],
      ),
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
              'Administrar mis planes',
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.92),
              ),
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

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? ColoresApp.principalMarca : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : ColoresApp.textoSecundario,
            ),
          ),
        ),
      ),
    );
  }
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

class _CardPlan extends StatelessWidget {
  const _CardPlan({
    required this.plan,
    required this.onTap,
    required this.onUnirse,
    this.uniendo = false,
  });

  final PlanComunidad plan;
  final VoidCallback onTap;
  final VoidCallback onUnirse;
  final bool uniendo;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(plan.colorHex);
    final portada = plan.portadaUrl;
    final desactivada = plan.estaFinalizado;

    return Opacity(
      opacity: desactivada ? 0.52 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: desactivada ? 0.08 : 0.22),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (portada != null && portada.isNotEmpty)
                _FondoPlan(path: portada, fallback: color),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.54),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _AutoresPlanLine(plan: plan)),
                        const SizedBox(width: 8),
                        _EstadoBadge(plan: plan),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      plan.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 21,
                        height: 0.98,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (plan.descripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        plan.descripcion.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 11.8,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _MiniBadge('${plan.personasAceptadas} van'),
                        _MiniBadge(_fmtFechaCorta(plan.fechaInicio)),
                        if (plan.fechaFin != null)
                          _MiniBadge('fin ${_fmtFechaCorta(plan.fechaFin!)}'),
                        _MiniBadge(
                          plan.modoLista == 'manual'
                              ? 'con aprobación'
                              : 'entrada libre',
                        ),
                        if (plan.cupoMax != null)
                          _MiniBadge(
                            '${plan.cupoUsados}/${plan.cupoMax} cupos',
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonGlass(texto: 'Ver más', onTap: onTap),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BotonPlan(
                            plan: plan,
                            uniendo: uniendo,
                            onTap: onUnirse,
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

class _FondoPlan extends StatelessWidget {
  const _FondoPlan({required this.path, required this.fallback});
  final String path;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: fallback),
      errorWidget: (_, _, _) => ColoredBox(color: fallback),
    );
  }
}

class _BotonPlan extends StatelessWidget {
  const _BotonPlan({
    required this.plan,
    required this.uniendo,
    required this.onTap,
  });
  final PlanComunidad plan;
  final bool uniendo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = plan.estaFinalizado
        ? 'Finalizado'
        : plan.soyMiembro
        ? 'Ya estás'
        : plan.soyPendiente
        ? 'Pendiente'
        : plan.cupoLleno
        ? 'Lleno'
        : plan.modoLista == 'manual'
        ? 'Solicitar'
        : 'Unirme';
    return GestureDetector(
      onTap: plan.puedeUnirse && !uniendo ? onTap : null,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: plan.puedeUnirse
              ? ColoresApp.principalMarca
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: uniendo
            ? const CupertinoActivityIndicator(radius: 7, color: Colors.white)
            : Text(
                texto,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _BotonGlass extends StatelessWidget {
  const _BotonGlass({required this.texto, required this.onTap});
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AutoresPlanLine extends StatelessWidget {
  const _AutoresPlanLine({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    if (plan.esPlanLocal) {
      return Row(
        children: [
          _AvatarMini(url: plan.fotoLocalUrl, fallback: plan.nombreLocal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plan del local · ${plan.nombreLocal}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 11.8,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _AvatarMini(
          url: plan.fotoOrganizadorUrl,
          fallback: plan.nombreOrganizador,
        ),
        const SizedBox(width: 6),
        _AvatarMini(url: plan.fotoLocalUrl, fallback: plan.nombreLocal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Plan de ${plan.nombreOrganizador} en ${plan.nombreLocal}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarMini extends StatelessWidget {
  const _AvatarMini({required this.url, required this.fallback});
  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF252525),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.4,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _fallback(ini),
            )
          : _fallback(ini),
    );
  }

  Widget _fallback(String ini) => Center(
    child: Text(
      ini,
      style: GoogleFonts.baloo2(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    final texto = plan.esPlanLocal
        ? 'Plan del local'
        : plan.estaFinalizado
        ? 'Finalizado'
        : plan.soyPendiente
        ? 'Pendiente'
        : plan.soyMiembro
        ? 'Voy'
        : 'Abierto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.9),
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
            'No pudimos cargar los planes',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
  const _VacioPlanes({required this.modo, required this.onReintentar});
  final String modo;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            modo == 'mis'
                ? CupertinoIcons.calendar
                : CupertinoIcons.calendar_badge_plus,
            size: 42,
            color: ColoresApp.principalMarca.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            modo == 'mis'
                ? 'Todavía no tenés planes'
                : 'No hay planes nuevos, crea el primero!!',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            modo == 'mis'
                ? 'Creá uno o sumate a alguna juntada de la comunidad.'
                : 'Sé anfitrión de la próxima juntada en un local de Fernecito.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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

Color _parseColor(String hex) {
  final limpio = hex.replaceAll('#', '').trim();
  if (limpio.length != 6) return ColoresApp.principalMarca;
  return Color(int.parse('FF$limpio', radix: 16));
}

String _fmtFechaCorta(DateTime d) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final local = d.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${meses[local.month - 1]} · $hh:$mm';
}
