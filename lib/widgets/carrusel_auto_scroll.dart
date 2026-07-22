/// Carrusel horizontal con auto-scroll continuo y SUAVE (estilo marquee), pensado
/// para el carrusel TOP (eventos pagos) — aumenta su exposición sin saltos.
///
/// Liviano y smooth:
/// - Un solo Ticker que desplaza ~px/seg de forma continua (no salta de a páginas).
/// - Loop infinito sin "salto" visible (la lista se repite, el drift nunca corta).
/// - Pausa al tocar/arrastrar (no pelea con el dedo) y reanuda solo, suave.
/// - Pausa cuando la app va a background (no gasta batería).
/// - Pausa al salir del viewport (>90% fuera) y reanuda al entrar (>10% visible),
///   instantáneo — sin delay.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CarruselAutoScroll extends StatefulWidget {
  const CarruselAutoScroll({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.spacing = 12,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 6),
    this.velocidad = 20, // px por segundo (lento = smooth)
    this.pausaTrasInteraccion = const Duration(seconds: 3),
    this.invertir = false, // false = drift hacia un lado, true = al contrario
  });

  final int itemCount;
  final Widget Function(BuildContext context, int realIndex) itemBuilder;
  final double height;
  final double spacing;
  final EdgeInsets padding;
  final double velocidad;
  final Duration pausaTrasInteraccion;

  /// Sentido del desplazamiento. Internamente usamos `reverse` del ListView,
  /// así toda la lógica del loop (offset 0→max) queda idéntica; solo cambia
  /// hacia qué lado se ve correr el contenido. Permite intercalar carruseles.
  final bool invertir;

  @override
  State<CarruselAutoScroll> createState() => _CarruselAutoScrollState();
}

class _CarruselAutoScrollState extends State<CarruselAutoScroll>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _ctrl = ScrollController();
  final Key _visibilityKey = UniqueKey();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _pausadoTouch = false;
  bool _pausadoApp = false;
  /// Empieza pausado hasta que VisibilityDetector confirme ≥10% visible.
  bool _pausadoViewport = true;
  Timer? _resume;

  bool get _loop => widget.itemCount > 1;

  bool get _debeCorrer =>
      _loop && !_pausadoTouch && !_pausadoApp && !_pausadoViewport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _resume?.cancel();
    _ticker.dispose();
    _ctrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pausadoApp = state != AppLifecycleState.resumed;
    _syncTicker();
  }

  void _onVisibility(VisibilityInfo info) {
    // >90% fuera → pausa; ≥10% visible → reanuda. Instantáneo, sin delay.
    final fuera = info.visibleFraction < 0.1;
    if (fuera == _pausadoViewport) return;
    _pausadoViewport = fuera;
    _syncTicker();
  }

  void _syncTicker() {
    if (_debeCorrer) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    if (!_debeCorrer || !_ctrl.hasClients) {
      _last = elapsed;
      return;
    }
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Ignorar saltos grandes (resume de background, lag) para no "saltar".
    if (dt <= 0 || dt > 0.08) return;
    final pos = _ctrl.position;
    final next = _ctrl.offset + widget.velocidad * dt;
    if (next < pos.maxScrollExtent) {
      _ctrl.jumpTo(next);
    }
  }

  void _onDown(PointerDownEvent _) {
    _resume?.cancel();
    _pausadoTouch = true;
    _syncTicker();
  }

  void _onUp(PointerEvent _) {
    _resume?.cancel();
    _resume = Timer(widget.pausaTrasInteraccion, () {
      if (!mounted) return;
      _pausadoTouch = false;
      _syncTicker();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loop "infinito": repetimos la lista muchas veces (builder es lazy, así que
    // solo se construye lo visible). El drift nunca alcanza el final.
    final count = _loop ? widget.itemCount * 10000 : widget.itemCount;
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibility,
      child: SizedBox(
        height: widget.height,
        child: Listener(
          onPointerDown: _onDown,
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          child: ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            reverse: widget.invertir,
            padding: widget.padding,
            physics: const BouncingScrollPhysics(),
            cacheExtent: 700,
            itemCount: count,
            separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
            itemBuilder: (ctx, i) =>
                widget.itemBuilder(ctx, i % widget.itemCount),
          ),
        ),
      ),
    );
  }
}
