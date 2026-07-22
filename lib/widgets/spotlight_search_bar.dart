/// Barra Spotlight (misma fila que siempre):
/// - Reposo: lupa circular + Plan + Cuándo
/// - Expandido: TextField + pill «Búsqueda IA»; los filtros se ocultan
/// - Demo suave cada ~10s (3s abierta) si está en viewport y sin focus
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/jerarquias_data.dart';
import '../core/tipos_evento_data.dart';

/// Dorado del pill IA + violeta oscuro (app locales) para contraste.
const kDoradoBusquedaIa = Color(0xFFE0B800);
const kVioletaOscuroIa = Color(0xFF4A1A8A);

class SpotlightSearchBar extends StatefulWidget {
  const SpotlightSearchBar({
    super.key,
    required this.queryActual,
    required this.onQueryChanged,
    required this.tiposSeleccionados,
    required this.onTiposChanged,
    required this.filtroTiempo,
    required this.onFiltroTiempoChanged,
    this.onBusquedaIa,
  });

  final String queryActual;
  final ValueChanged<String> onQueryChanged;
  final Set<String> tiposSeleccionados;
  final ValueChanged<Set<String>> onTiposChanged;
  final FiltroTiempo filtroTiempo;
  final ValueChanged<FiltroTiempo> onFiltroTiempoChanged;
  final ValueChanged<String>? onBusquedaIa;

  @override
  State<SpotlightSearchBar> createState() => _SpotlightSearchBarState();
}

class _SpotlightSearchBarState extends State<SpotlightSearchBar>
    with TickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final AnimationController _anim;
  late final Animation<double> _curva;
  late final AnimationController _shimmerIa;
  bool _expandido = false;
  bool _focusUsuario = false;
  bool _bloquearColapsoPorIa = false;
  bool _demoEnCurso = false;
  Timer? _cicloTimer;
  Timer? _colapsoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.queryActual);
    _focus = FocusNode()..addListener(_onFocusChange);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      reverseDuration: const Duration(milliseconds: 540),
    );
    _curva = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _shimmerIa = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arrancarCicloDemo();
    });
  }

  @override
  void didUpdateWidget(covariant SpotlightSearchBar old) {
    super.didUpdateWidget(old);
    if (widget.queryActual != _ctrl.text) {
      _ctrl.text = widget.queryActual;
    }
  }

  @override
  void dispose() {
    _cicloTimer?.cancel();
    _colapsoTimer?.cancel();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    _anim.dispose();
    _shimmerIa.dispose();
    super.dispose();
  }

  bool _estaEnViewport() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return false;
    final pos = ro.localToGlobal(Offset.zero);
    final h = ro.size.height;
    final screenH = MediaQuery.sizeOf(context).height;
    return pos.dy + h > 40 && pos.dy < screenH - 90;
  }

  void _arrancarCicloDemo() {
    _cicloTimer?.cancel();
    _cicloTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _focusUsuario || _focus.hasFocus || _demoEnCurso) return;
      if (!_estaEnViewport()) return;
      _demoExpandirYColapsar();
    });
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _focusUsuario || _focus.hasFocus) return;
      if (_estaEnViewport()) _demoExpandirYColapsar();
    });
  }

  Future<void> _demoExpandirYColapsar() async {
    if (_focusUsuario || _focus.hasFocus || _demoEnCurso) return;
    if (_anim.value > 0.01) return;
    _demoEnCurso = true;
    setState(() => _expandido = true);
    await _anim.forward();
    if (!mounted || _focusUsuario || _focus.hasFocus) {
      _demoEnCurso = false;
      return;
    }
    _colapsoTimer?.cancel();
    _colapsoTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || _focusUsuario || _focus.hasFocus) {
        _demoEnCurso = false;
        return;
      }
      await _colapsarSuave();
      _demoEnCurso = false;
    });
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _focusUsuario = true;
      _demoEnCurso = false;
      _colapsoTimer?.cancel();
      return;
    }
    if (_bloquearColapsoPorIa) return;
    if (_focusUsuario) {
      _focusUsuario = false;
      if (_ctrl.text.trim().isEmpty) {
        Future<void>.delayed(const Duration(milliseconds: 140), () {
          if (!mounted || _focus.hasFocus || _bloquearColapsoPorIa) return;
          _colapsarSuave();
        });
      }
    }
  }

  void _expandir() {
    _colapsoTimer?.cancel();
    _demoEnCurso = false;
    _focusUsuario = true;
    setState(() => _expandido = true);
    _anim.forward();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _colapsarSuave() async {
    if (_anim.value <= 0 && !_expandido) return;
    _colapsoTimer?.cancel();
    _focus.unfocus();
    await _anim.reverse();
    if (!mounted) return;
    if (_focus.hasFocus || _focusUsuario) return;
    setState(() => _expandido = false);
  }

  void _colapsar() {
    _colapsarSuave();
  }

  void _abrirBusquedaIa() {
    final onIa = widget.onBusquedaIa;
    if (onIa == null) return;
    _bloquearColapsoPorIa = true;
    _colapsoTimer?.cancel();
    final texto = _ctrl.text.trim();
    onIa(texto);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusUsuario = false;
      _focus.unfocus();
      _colapsar();
      _bloquearColapsoPorIa = false;
    });
  }

  double _posicionBrillo(double t) {
    const ventana = 0.38;
    if (t > ventana) return -0.4;
    return Curves.easeInOutCubic.transform(t / ventana);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_curva, _shimmerIa]),
      builder: (context, _) {
        final t = _curva.value;
        // Flex interpolado: evita el “salto” de layout.
        final flexSearch = (18 + (82 * t)).round().clamp(18, 100);
        final flexFilters = (82 * (1.0 - t)).round().clamp(0, 82);
        final mostrarCampo = t > 0.04;
        final mostrarFiltros = t < 0.96 && flexFilters > 0;

        return SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(
                flex: flexSearch,
                child: mostrarCampo
                    ? _buildTextFieldExpandido(t)
                    : _buildBotonLupaCircular(),
              ),
              if (mostrarFiltros) ...[
                SizedBox(width: 10 * (1.0 - t)),
                Expanded(
                  flex: flexFilters < 1 ? 1 : flexFilters,
                  child: Opacity(
                    opacity: Curves.easeOut.transform((1.0 - t).clamp(0.0, 1.0)),
                    child: IgnorePointer(
                      ignoring: t > 0.12,
                      child: Row(
                        children: [
                          Expanded(child: _buildDropdownPlan()),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDropdownTiempo()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBotonLupaCircular() {
    return GestureDetector(
      onTap: _expandir,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.search,
          color: ColoresApp.textoPrincipal,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTextFieldExpandido(double t) {
    final fadeIn = Curves.easeOut.transform(t.clamp(0.0, 1.0));
    return Opacity(
      opacity: fadeIn,
      child: Transform.scale(
        scale: 0.96 + (0.04 * fadeIn),
        alignment: Alignment.centerLeft,
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22 * fadeIn),
                blurRadius: 12 * fadeIn,
                offset: Offset(0, 3 * fadeIn),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _colapsar,
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  CupertinoIcons.search,
                  color: ColoresApp.textoPrincipal,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: widget.onQueryChanged,
                  onTap: () {
                    _focusUsuario = true;
                    _colapsoTimer?.cancel();
                    _demoEnCurso = false;
                  },
                  cursorColor: ColoresApp.principalMarca,
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: '¿Qué buscás?',
                    hintStyle: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
              if (widget.onBusquedaIa != null) ...[
                const SizedBox(width: 6),
                Opacity(
                  opacity: Curves.easeOut.transform(
                    ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                  ),
                  child: Listener(
                    onPointerDown: (_) => _bloquearColapsoPorIa = true,
                    child: GestureDetector(
                      onTap: _abrirBusquedaIa,
                      behavior: HitTestBehavior.opaque,
                      child: _PillBusquedaIa(
                        shimmer: _shimmerIa,
                        posicionBrillo: _posicionBrillo,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownPlan() {
    final activos = widget.tiposSeleccionados;
    final hayFiltro = activos.isNotEmpty;
    final label = hayFiltro
        ? (activos.length == 1
            ? (TiposEventoData.desdeSlug(activos.first)?.label ?? 'Plan')
            : '${activos.length} planes')
        : 'Plan';
    return _Pildora(
      icono: CupertinoIcons.ticket_fill,
      label: label,
      activo: hayFiltro,
      onTap: _abrirSheetPlanes,
    );
  }

  Widget _buildDropdownTiempo() {
    final activo = widget.filtroTiempo != FiltroTiempo.todos;
    return _Pildora(
      icono: CupertinoIcons.calendar,
      label: activo ? widget.filtroTiempo.label : 'Cuándo',
      activo: activo,
      onTap: _abrirSheetTiempo,
    );
  }

  static const double _kAlturaNavbarUI = 58.0;

  Future<void> _abrirSheetPlanes() async {
    final Set<String> tmp = {...widget.tiposSeleccionados};
    final marginNavbar =
        _kAlturaNavbarUI + MediaQuery.of(context).padding.bottom + 8;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: marginNavbar),
            child: Container(
              decoration: SuperficiesApp.bottomSheet(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HandleSheet(),
                  const SizedBox(height: 10),
                  Text(
                    'Tipo de plan',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elegí uno o varios. Vacío = todos.',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final t in TiposEventoData.todos)
                        _ChipPlan(
                          label: t.label,
                          icono: t.icono,
                          seleccionado: tmp.contains(t.slug),
                          onTap: () {
                            setSheet(() {
                              if (tmp.contains(t.slug)) {
                                tmp.remove(t.slug);
                              } else {
                                tmp.add(t.slug);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setSheet(tmp.clear),
                          child: Text(
                            'Limpiar',
                            style: GoogleFonts.baloo2(
                              color: ColoresApp.textoSecundario,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ColoresApp.principalMarca,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            widget.onTiposChanged({...tmp});
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Aplicar',
                            style: GoogleFonts.baloo2(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirSheetTiempo() async {
    final marginNavbar =
        _kAlturaNavbarUI + MediaQuery.of(context).padding.bottom + 8;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: marginNavbar),
          child: Container(
            decoration: SuperficiesApp.bottomSheet(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HandleSheet(),
                const SizedBox(height: 10),
                Text(
                  '¿Para cuándo buscás?',
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (final f in FiltroTiempo.values)
                  _OpcionTiempo(
                    filtro: f,
                    seleccionado: widget.filtroTiempo == f,
                    onTap: () {
                      widget.onFiltroTiempoChanged(f);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PillBusquedaIa extends StatelessWidget {
  const _PillBusquedaIa({
    required this.shimmer,
    required this.posicionBrillo,
  });

  final Animation<double> shimmer;
  final double Function(double) posicionBrillo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: ColoredBox(color: kDoradoBusquedaIa)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: kVioletaOscuroIa,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Búsqueda IA',
                    style: GoogleFonts.baloo2(
                      color: kVioletaOscuroIa,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, size) {
                    final ancho = size.maxWidth;
                    final alto = size.maxHeight;
                    final p = posicionBrillo(shimmer.value);
                    final x = -ancho * 0.45 + p * (ancho * 1.85);
                    return Transform.translate(
                      offset: Offset(x, 0),
                      child: Transform.rotate(
                        angle: -0.42,
                        child: Container(
                          width: ancho * 0.28,
                          height: alto * 2.4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.65),
                                Colors.white.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.48, 0.52, 1.0],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.icono,
    required this.label,
    required this.activo,
    required this.onTap,
  });
  final IconData icono;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        activo ? ColoresApp.principalMarca : ColoresApp.textoSecundario;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 13,
              color: ColoresApp.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }
}

class _HandleSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: ColoresApp.textoSecundario.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ChipPlan extends StatelessWidget {
  const _ChipPlan({
    required this.label,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });
  final String label;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: seleccionado
              ? ColoresApp.principalMarca.withValues(alpha: 0.18)
              : ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15, color: ColoresApp.textoPrincipal),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionTiempo extends StatelessWidget {
  const _OpcionTiempo({
    required this.filtro,
    required this.seleccionado,
    required this.onTap,
  });
  final FiltroTiempo filtro;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: seleccionado
              ? ColoresApp.principalMarca.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              seleccionado
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: seleccionado
                  ? ColoresApp.principalMarca
                  : ColoresApp.textoSecundario,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              filtro.label,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
