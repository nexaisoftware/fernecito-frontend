library;

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import 'fernecito_loader.dart';

const _rojoMegusta = Color(0xFFE91E63);
const _navBlurSigma = 18.0;
const _navGlassTop = Color(0xFF1E1E22);
const _navGlassBottom = Color(0xFF111114);

String _formatearCantidadMegusta(int cantidad) {
  if (cantidad >= 1000000) {
    final m = cantidad / 1000000;
    return m >= 10
        ? '${m.round()}M'
        : '${m.toStringAsFixed(1).replaceAll('.0', '')}M';
  }
  if (cantidad >= 1000) {
    final k = cantidad / 1000;
    return k >= 10
        ? '${k.round()}K'
        : '${k.toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return '$cantidad';
}

class _PillGlassMegusta extends StatelessWidget {
  const _PillGlassMegusta({
    required this.activo,
    required this.child,
    this.compacto = false,
  });

  final bool activo;
  final Widget child;
  final bool compacto;

  BoxDecoration _decoracionPill(bool activo) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: activo
            ? [
                _rojoMegusta.withValues(alpha: 0.34),
                _rojoMegusta.withValues(alpha: 0.48),
              ]
            : [
                _navGlassTop.withValues(alpha: 0.62),
                _navGlassBottom.withValues(alpha: 0.82),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _navBlurSigma,
          sigmaY: _navBlurSigma,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? 10 : 12,
            vertical: compacto ? 6 : 7,
          ),
          decoration: _decoracionPill(activo),
          child: child,
        ),
      ),
    );
  }
}

Color _colorContenidoMegusta({required bool activo, required bool esIcono}) {
  if (activo) {
    return esIcono ? _rojoMegusta : Colors.white;
  }
  return ColoresApp.textoSecundario;
}

TextStyle _estiloTextoMegusta({
  required bool activo,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w800,
}) {
  return GoogleFonts.baloo2(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: _colorContenidoMegusta(activo: activo, esIcono: false),
    height: 1,
  );
}

/// Botón de me gusta + contador para perfil de local.
class BotonMegustaLocal extends StatelessWidget {
  const BotonMegustaLocal({
    super.key,
    required this.cantidad,
    required this.activo,
    required this.habilitado,
    required this.cargando,
    required this.onTap,
    this.compacto = false,
  });

  final int cantidad;
  final bool activo;
  final bool habilitado;
  final bool cargando;
  final VoidCallback? onTap;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final iconSize = compacto ? 15.0 : 17.0;
    final textoCantidad = _formatearCantidadMegusta(cantidad);
    final textoAccion = activo ? 'Te gusta' : 'Me gusta';
    final colorContenido = _colorContenidoMegusta(activo: activo, esIcono: false);

    return GestureDetector(
      onTap: habilitado && !cargando
          ? () {
              HapticFeedback.lightImpact();
              onTap?.call();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: _PillGlassMegusta(
        activo: activo,
        compacto: compacto,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargando)
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: FernecitoLoader.inline(
                  size: compacto ? 13 : 14,
                  color: colorContenido,
                ),
              )
            else
              Icon(
                activo ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                size: iconSize,
                color: _colorContenidoMegusta(activo: activo, esIcono: true),
              ),
            if (cantidad > 0) ...[
              const SizedBox(width: 3),
              Text(
                textoCantidad,
                style: _estiloTextoMegusta(
                  activo: activo,
                  fontSize: compacto ? 13.5 : 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              textoAccion,
              style: _estiloTextoMegusta(
                activo: activo,
                fontSize: compacto ? 11.5 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Variante integrada al banner: pill glass, corazón + contador + texto en una fila.
class BotonMegustaLocalHero extends StatefulWidget {
  const BotonMegustaLocalHero({
    super.key,
    required this.cantidad,
    required this.activo,
    required this.habilitado,
    required this.cargando,
    required this.onTap,
  });

  final int cantidad;
  final bool activo;
  final bool habilitado;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  State<BotonMegustaLocalHero> createState() => _BotonMegustaLocalHeroState();
}

class _BotonMegustaLocalHeroState extends State<BotonMegustaLocalHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _pulsoArmado = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1, end: 1.22), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.92), weight: 24),
        TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.12), weight: 22),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 24),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarPulso());
  }

  Future<void> _iniciarPulso() async {
    if (_pulsoArmado) return;
    _pulsoArmado = true;
    while (mounted) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted || _controller.isAnimating) continue;
      await _controller.forward(from: 0);
    }
  }

  void _animarToque() {
    if (_controller.isAnimating) _controller.stop();
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BotonMegustaLocalHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activo != widget.activo ||
        oldWidget.cantidad != widget.cantidad) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.habilitado && !widget.cargando;
    final textoCantidad = _formatearCantidadMegusta(widget.cantidad);
    final textoAccion = widget.activo ? 'Te gusta' : 'Me gusta';
    final colorContenido =
        _colorContenidoMegusta(activo: widget.activo, esIcono: false);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: habilitado
          ? () {
              HapticFeedback.lightImpact();
              _animarToque();
              widget.onTap?.call();
            }
          : null,
      child: _PillGlassMegusta(
        activo: widget.activo,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.cargando)
              SizedBox(
                width: 19,
                height: 19,
                child: FernecitoLoader.inline(
                  size: 15,
                  color: colorContenido,
                ),
              )
            else
              ScaleTransition(
                scale: _scale,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    widget.activo
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    key: ValueKey(widget.activo),
                    size: 19,
                    color: _colorContenidoMegusta(
                      activo: widget.activo,
                      esIcono: true,
                    ),
                  ),
                ),
              ),
            if (widget.cantidad > 0) ...[
              const SizedBox(width: 3),
              Text(
                textoCantidad,
                style: _estiloTextoMegusta(
                  activo: widget.activo,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              textoAccion,
              style: _estiloTextoMegusta(
                activo: widget.activo,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solo lectura (app locales / vista sin login).
class BadgeMegustaLocalLectura extends StatelessWidget {
  const BadgeMegustaLocalLectura({
    super.key,
    required this.cantidad,
    this.compacto = false,
  });

  final int cantidad;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return BotonMegustaLocal(
      cantidad: cantidad,
      activo: false,
      habilitado: false,
      cargando: false,
      onTap: null,
      compacto: compacto,
    );
  }
}
