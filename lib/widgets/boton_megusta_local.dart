library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fernecito_loader.dart';

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

  String get _textoCantidad {
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

  @override
  Widget build(BuildContext context) {
    final colorActivo = const Color(0xFFE91E63);
    final fondo = activo
        ? colorActivo.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: habilitado && !cargando
          ? () {
              HapticFeedback.lightImpact();
              onTap?.call();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 12 : 16,
          vertical: compacto ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargando)
              SizedBox(
                width: compacto ? 16 : 18,
                height: compacto ? 16 : 18,
                child: FernecitoLoader.inline(
                  size: compacto ? 14 : 16,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                activo ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                size: compacto ? 17 : 19,
                color: activo ? colorActivo : Colors.white,
              ),
            const SizedBox(width: 8),
            Text(
              _textoCantidad,
              style: GoogleFonts.baloo2(
                fontSize: compacto ? 15 : 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (!compacto) ...[
              const SizedBox(width: 6),
              Text(
                activo ? 'Te gusta' : 'Me gusta',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Variante integrada al banner: sin cápsula visible, solo corazón + contador.
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

  String get _textoCantidad {
    final cantidad = widget.cantidad;
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

  String get _textoAccion => widget.activo ? 'Te gusta' : 'Me gusta';

  TextStyle _textoStyle({required double fontSize}) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.72),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFE91E63);
    final habilitado = widget.habilitado && !widget.cargando;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: habilitado
          ? () {
              HapticFeedback.lightImpact();
              _animarToque();
              widget.onTap?.call();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      size: 31,
                      color: widget.activo ? rojo : Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.cantidad > 0) ...[
                  const SizedBox(width: 6),
                  Text(_textoCantidad, style: _textoStyle(fontSize: 18)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(_textoAccion, style: _textoStyle(fontSize: 11.5)),
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
