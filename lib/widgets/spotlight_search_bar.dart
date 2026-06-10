/// Barra de búsqueda estilo Spotlight (macOS).
///
/// Comportamiento:
/// - En reposo: muestra un círculo con icono de lupa + 2 dropdowns (filtros).
/// - Al tocar la lupa: el círculo se transforma en un `TextField` ancho con
///   animación de expansión; los dropdowns se ocultan con fade.
/// - Al perder foco (o tocar "X"): vuelve al estado de reposo.
///
/// Diseño minimalista, dark, alineado con el tema Fernecito.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/jerarquias_data.dart';
import '../core/tipos_evento_data.dart';

class SpotlightSearchBar extends StatefulWidget {
  const SpotlightSearchBar({
    super.key,
    required this.queryActual,
    required this.onQueryChanged,
    required this.tiposSeleccionados,
    required this.onTiposChanged,
    required this.filtroTiempo,
    required this.onFiltroTiempoChanged,
  });

  final String queryActual;
  final ValueChanged<String> onQueryChanged;

  /// Tipos de evento marcados (boliche, fiesta, sunset, etc.). Vacío = "todos".
  final Set<String> tiposSeleccionados;
  final ValueChanged<Set<String>> onTiposChanged;

  final FiltroTiempo filtroTiempo;
  final ValueChanged<FiltroTiempo> onFiltroTiempoChanged;

  @override
  State<SpotlightSearchBar> createState() => _SpotlightSearchBarState();
}

class _SpotlightSearchBarState extends State<SpotlightSearchBar>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final AnimationController _anim;
  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.queryActual);
    _focus = FocusNode();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _focus.addListener(_onFocusChange);
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
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _ctrl.text.isEmpty) {
      _colapsar();
    }
  }

  void _expandir() {
    setState(() => _expandido = true);
    _anim.forward();
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _focus.requestFocus();
    });
  }

  void _colapsar() {
    _focus.unfocus();
    _anim.reverse();
    setState(() => _expandido = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_anim.value);
        return SizedBox(
          height: 44,
          child: Row(
            children: [
              // === Lupa / TextField expandible ===
              Expanded(
                flex: _expandido ? 100 : 18,
                child: _expandido
                    ? _buildTextFieldExpandido(t)
                    : _buildBotonLupaCircular(),
              ),
              if (!_expandido) const SizedBox(width: 10),
              // === Filtros (se desvanecen al expandir) ===
              if (!_expandido)
                Expanded(
                  flex: 82,
                  child: Opacity(
                    opacity: 1 - t,
                    child: IgnorePointer(
                      ignoring: _expandido,
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
          ),
        );
      },
    );
  }

  Widget _buildBotonLupaCircular() {
    return GestureDetector(
      onTap: _expandir,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: ColoresApp.principalMarca.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.search,
          color: ColoresApp.textoPrincipal,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTextFieldExpandido(double t) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ColoresApp.principalMarca.withOpacity(0.45 * t),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3 * t),
            blurRadius: 14 * t,
            offset: Offset(0, 4 * t),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search,
              color: ColoresApp.textoPrincipal, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: widget.onQueryChanged,
              cursorColor: ColoresApp.principalMarca,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Buscar evento, local, promo…',
                hintStyle: GoogleFonts.baloo2(
                  color: ColoresApp.textoSecundario,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              widget.onQueryChanged('');
              _colapsar();
            },
            child: const Icon(
              CupertinoIcons.clear_circled_solid,
              color: ColoresApp.textoSecundario,
              size: 18,
            ),
          ),
        ],
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
        : 'Cuál es tu plan';
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
      label: widget.filtroTiempo.label,
      activo: activo,
      onTap: _abrirSheetTiempo,
    );
  }

  // Altura aproximada de la navbar global, sumada al safearea inferior.
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
    final color = activo ? ColoresApp.principalMarca : ColoresApp.textoSecundario;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withOpacity(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(activo ? 0.55 : 0.18),
            width: 1,
          ),
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
            Icon(CupertinoIcons.chevron_down,
                size: 13, color: ColoresApp.textoSecundario),
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
          color: ColoresApp.textoSecundario.withOpacity(0.35),
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
              ? ColoresApp.principalMarca.withOpacity(0.18)
              : ColoresApp.fondoSuperficie.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionado
                ? ColoresApp.principalMarca
                : ColoresApp.textoSecundario.withOpacity(0.22),
            width: 1.2,
          ),
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
              ? ColoresApp.principalMarca.withOpacity(0.12)
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
