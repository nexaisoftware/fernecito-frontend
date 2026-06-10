/// Barra de búsqueda plegable estilo cartelera (lupa → campo expandido).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class BusquedaSocialExpandible extends StatefulWidget {
  const BusquedaSocialExpandible({
    super.key,
    required this.hint,
    this.onQueryChanged,
    this.debounceMs = 380,
    this.accionesColapsado = const [],
    /// Reparto del ancho en reposo: barra vs cada acción (suma ≈ 10).
    this.flexBarraColapsada = 6,
    this.flexPorAccionColapsada = 4,
  });

  final String hint;
  final ValueChanged<String>? onQueryChanged;
  final int debounceMs;
  final List<Widget> accionesColapsado;
  final int flexBarraColapsada;
  final int flexPorAccionColapsada;

  @override
  State<BusquedaSocialExpandible> createState() =>
      _BusquedaSocialExpandibleState();
}

class _BusquedaSocialExpandibleState extends State<BusquedaSocialExpandible>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final AnimationController _anim;
  Timer? _debounce;
  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _ctrl.text.isEmpty) _colapsar();
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
    if (_ctrl.text.isNotEmpty) {
      _ctrl.clear();
      widget.onQueryChanged?.call('');
    }
  }

  void _onTextChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
      widget.onQueryChanged?.call(v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_anim.value);
        return SizedBox(
          height: 36,
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                flex: _expandido ? 1 : widget.flexBarraColapsada,
                child: _expandido ? _campoExpandido(t) : _barraColapsada(),
              ),
              if (!_expandido)
                for (var i = 0; i < widget.accionesColapsado.length; i++) ...[
                  SizedBox(width: i == 0 ? 8 : 10),
                  Expanded(
                    flex: widget.flexPorAccionColapsada,
                    child: widget.accionesColapsado[i],
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  /// Píldora ancha (lupa + hint) hasta los botones de acción.
  Widget _barraColapsada() {
    return GestureDetector(
      onTap: _expandir,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Buscar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ColoresApp.textoSecundario.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoExpandido(double t) {
    return Material(
      color: ColoresApp.fondoSuperficie.withValues(alpha: 0.92),
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.28 * t),
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              size: 19,
              color: ColoresApp.textoPrincipal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onTextChanged,
                cursorColor: ColoresApp.principalMarca,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Buscar',
                  hintStyle: GoogleFonts.baloo2(
                    color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _colapsar,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 22,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón «Explora» (pin + texto) junto a la barra de búsqueda.
class BotonExplorarSocial extends StatelessWidget {
  final VoidCallback onTap;

  const BotonExplorarSocial({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.location_solid,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Explora',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón crear squad (Squad +).
class BotonSquadMasSocial extends StatelessWidget {
  final VoidCallback onTap;

  const BotonSquadMasSocial({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'Squad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
