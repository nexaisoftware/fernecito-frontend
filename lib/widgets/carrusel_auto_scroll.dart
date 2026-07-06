/// Carrusel horizontal con auto-scroll continuo y SUAVE (estilo marquee), pensado
/// para el carrusel TOP (eventos pagos) — aumenta su exposición sin saltos.
///
/// Liviano y smooth:
/// - Un solo Ticker que desplaza ~px/seg de forma continua (no salta de a páginas).
/// - Loop infinito sin "salto" visible (la lista se repite, el drift nunca corta).
/// - Pausa al tocar/arrastrar (no pelea con el dedo) y reanuda solo, suave.
/// - Pausa cuando la app va a background (no gasta batería).
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _pausadoTouch = false;
  bool _pausadoApp = false;
  Timer? _resume;

  bool get _loop => widget.itemCount > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    if (_loop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ticker.start();
      });
    }
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
  }

  void _tick(Duration elapsed) {
    if (_pausadoTouch || _pausadoApp || !_ctrl.hasClients) {
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
  }

  void _onUp(PointerEvent _) {
    _resume?.cancel();
    _resume = Timer(widget.pausaTrasInteraccion, () {
      if (mounted) _pausadoTouch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loop "infinito": repetimos la lista muchas veces (builder es lazy, así que
    // solo se construye lo visible). El drift nunca alcanza el final.
    final count = _loop ? widget.itemCount * 10000 : widget.itemCount;
    return SizedBox(
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
    );
  }
}
