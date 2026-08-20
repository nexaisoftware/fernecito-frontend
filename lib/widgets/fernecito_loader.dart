/// Loader Fernecito: íconos rotativos (café, mapa, pin, comida, etc.).
///
/// Usar siempre [FernecitoLoader] / [FernecitoLoaderCentro] en lugar de
/// [CupertinoActivityIndicator] o [CircularProgressIndicator].
/// Sin cápsula: solo el ícono con aureola negra.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../core/tema_fernecito.dart';

/// Widget único de carga Fernecito (íconos que rotan).
///
/// - Pantalla / sheet: [FernecitoLoaderCentro]
/// - Default / botón / placeholder: solo ícono + aureola
class FernecitoLoader extends StatelessWidget {
  const FernecitoLoader({
    super.key,
    this.size = 28,
    this.compact = true,
    this.circular = true,
    this.bare = true,
    this.color,
    this.animar = true,
    this.shadows,
  });

  /// Solo ícono rotativo, sin cápsula (botones, avatares, filas).
  const FernecitoLoader.inline({
    super.key,
    this.size = 16,
    this.color,
    this.animar = true,
    this.shadows,
  })  : compact = true,
        circular = true,
        bare = true;

  final double size;
  final bool compact;
  final bool circular;

  /// Sin fondo/cápsula: solo el ícono. Se mantiene por compatibilidad.
  final bool bare;
  final Color? color;
  final bool animar;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return LoaderIconosAnimado(
      size: size,
      compact: compact,
      circular: circular,
      bare: true,
      color: color,
      animar: animar,
      shadows: shadows,
    );
  }
}

/// Loader centrado para pantallas, navegación y bottom sheets.
class FernecitoLoaderCentro extends StatelessWidget {
  const FernecitoLoaderCentro({
    super.key,
    this.size = 34,
    this.compact,
    this.circular = true,
  });

  final double size;
  final bool? compact;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final esCompacto = compact ?? size < 36;
    return Center(
      child: FernecitoLoader(
        size: size,
        compact: esCompacto,
        circular: circular,
        bare: true,
      ),
    );
  }
}

/// Íconos que rotan rápido (implementación del loader).
class LoaderIconosAnimado extends StatefulWidget {
  const LoaderIconosAnimado({
    super.key,
    this.size = 40,
    this.compact = false,
    this.circular = false,
    this.bare = true,
    this.color,
    this.animar = true,
    this.shadows,
  });

  final double size;
  final bool compact;
  final bool circular;
  final bool bare;
  final Color? color;
  final bool animar;
  final List<Shadow>? shadows;

  @override
  State<LoaderIconosAnimado> createState() => _LoaderIconosAnimadoState();
}

class _LoaderIconosAnimadoState extends State<LoaderIconosAnimado> {
  static const _iconos = <IconData>[
    Icons.local_cafe_rounded,
    Icons.restaurant_rounded,
    Icons.local_bar_rounded,
    Icons.nightlife_rounded,
    CupertinoIcons.music_note_2,
    CupertinoIcons.mic_fill,
    CupertinoIcons.ticket_fill,
    CupertinoIcons.heart_fill,
    Icons.icecream_outlined,
    CupertinoIcons.map_fill,
  ];

  int _indice = 0;
  bool _loopActivo = false;

  @override
  void initState() {
    super.initState();
    if (widget.animar) _arrancarLoop();
  }

  @override
  void didUpdateWidget(covariant LoaderIconosAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animar && !oldWidget.animar) {
      _arrancarLoop();
    } else if (!widget.animar && oldWidget.animar) {
      _loopActivo = false;
      if (_indice != 0) {
        setState(() => _indice = 0);
      }
    }
  }

  void _arrancarLoop() {
    if (_loopActivo || !widget.animar) return;
    _loopActivo = true;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || !widget.animar || !_loopActivo) {
        _loopActivo = false;
        return false;
      }
      setState(() => _indice = (_indice + 1) % _iconos.length);
      return true;
    });
  }

  Widget _iconoAnimado(Color colorIcono) {
    final aureola = widget.shadows ??
        [
          Shadow(
            color: const Color(0xF2000000),
            blurRadius: widget.size * 0.38,
          ),
          Shadow(
            color: const Color(0xCC000000),
            blurRadius: widget.size * 0.72,
          ),
          Shadow(
            color: const Color(0x88000000),
            blurRadius: widget.size * 1.15,
          ),
        ];
    final indice = widget.animar ? _indice : 0;
    final icono = Icon(
      widget.animar ? _iconos[indice] : _iconos[0],
      key: widget.animar ? ValueKey<int>(indice) : null,
      size: widget.size,
      color: colorIcono,
      shadows: aureola,
    );
    if (!widget.animar) return icono;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: icono,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget iconoConAureola(Color colorIcono) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xB3000000),
              blurRadius: widget.size * 0.7,
              spreadRadius: widget.size * 0.06,
            ),
          ],
        ),
        child: _iconoAnimado(colorIcono),
      );
    }

    if (widget.color != null) {
      return iconoConAureola(widget.color!);
    }
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, accent, _) => iconoConAureola(accent),
    );
  }
}

/// Alias histórico del loader del mapa.
typedef LoaderMapaIconosAnimado = LoaderIconosAnimado;

/// Scroll con pull-to-refresh: loader fijo bajo el safe area (no queda en el notch).
class FernecitoRefreshScrollView extends StatefulWidget {
  const FernecitoRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.physics,
    this.controller,
    this.triggerPullDistance = 72,
    this.indicatorExtent = 36,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final double triggerPullDistance;
  final double indicatorExtent;

  @override
  State<FernecitoRefreshScrollView> createState() =>
      _FernecitoRefreshScrollViewState();
}

class _FernecitoRefreshScrollViewState extends State<FernecitoRefreshScrollView> {
  double _pulledExtent = 0;
  RefreshIndicatorMode _mode = RefreshIndicatorMode.inactive;

  void _syncPull(double pulled, RefreshIndicatorMode mode) {
    if ((_pulledExtent - pulled).abs() < 0.5 && _mode == mode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if ((_pulledExtent - pulled).abs() < 0.5 && _mode == mode) return;
      setState(() {
        _pulledExtent = pulled;
        _mode = mode;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    final trigger = widget.triggerPullDistance;
    final enPuntoDulce =
        _mode == RefreshIndicatorMode.armed ||
        _mode == RefreshIndicatorMode.refresh;
    final refrescando = _mode == RefreshIndicatorMode.refresh;
    final progreso = enPuntoDulce
        ? 1.0
        : (_pulledExtent / trigger).clamp(0.0, 1.0);
    final visible =
        _mode != RefreshIndicatorMode.inactive &&
        _mode != RefreshIndicatorMode.done &&
        progreso > 0.03;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomScrollView(
          controller: widget.controller,
          physics:
              widget.physics ??
              const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: widget.onRefresh,
              refreshTriggerPullDistance: trigger,
              refreshIndicatorExtent: widget.indicatorExtent,
              builder:
                  (
                    BuildContext context,
                    RefreshIndicatorMode mode,
                    double pulledExtent,
                    double refreshTriggerPullDistance,
                    double refreshIndicatorExtent,
                  ) {
                    _syncPull(pulledExtent, mode);
                    final alto = mode == RefreshIndicatorMode.refresh
                        ? refreshIndicatorExtent
                        : pulledExtent.clamp(0.0, refreshTriggerPullDistance);
                    return SizedBox(height: alto);
                  },
            ),
            ...widget.slivers,
          ],
        ),
        if (visible)
          Positioned(
            top: topSafe,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: refrescando || enPuntoDulce
                      ? 1.0
                      : (progreso * 0.95).clamp(0.0, 0.95),
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: AnimatedScale(
                    scale: refrescando || enPuntoDulce
                        ? 1.0
                        : 0.8 + 0.2 * progreso,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: FernecitoLoader.inline(
                      size: 22,
                      animar: enPuntoDulce || refrescando,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// @deprecated Usar [FernecitoRefreshScrollView].
class FernecitoSliverRefreshControl extends StatelessWidget {
  const FernecitoSliverRefreshControl({
    super.key,
    required this.onRefresh,
    this.indicatorExtent = 36,
    this.triggerPullDistance = 72,
  });

  final RefreshCallback onRefresh;
  final double indicatorExtent;
  final double triggerPullDistance;

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: onRefresh,
      refreshTriggerPullDistance: triggerPullDistance,
      refreshIndicatorExtent: indicatorExtent,
      builder: (_, __, pulled, ___, extent) {
        final alto = pulled.clamp(0.0, extent);
        return SizedBox(height: alto);
      },
    );
  }
}

/// Lista con pull-to-refresh Fernecito.
class FernecitoRefreshableList extends StatelessWidget {
  const FernecitoRefreshableList({
    super.key,
    required this.onRefresh,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return FernecitoRefreshScrollView(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildListDelegate(children),
          ),
        ),
      ],
    );
  }
}
