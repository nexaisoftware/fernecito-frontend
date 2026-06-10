/// Visor fullscreen de "stories" para eventos con jerarquía `top_ultra`.
///
/// Se abre como ruta fullscreen sobre la cartelera cuando hay top_ultra activos.
/// Estética minimalista Apple:
///  - Fondo oscuro sólido con viñeta suave.
///  - Flyer centrado con bordes redondeados y glow del color del tema.
///  - Barra de progreso tipo stories + botón X para cerrar.
///  - Auto-avance cada 5s; tap izq/der retrocede/avanza; mantener pausa.
///  - Footer con local, título y botón "Ver evento".
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/tema_fernecito.dart';

class EventoTopUltra {
  const EventoTopUltra({
    required this.idEvento,
    required this.tituloEvento,
    required this.urlFlyer,
    required this.nombreLocal,
    this.avatarLocal,
    this.fechaTexto,
  });
  final String idEvento;
  final String tituloEvento;
  final String urlFlyer;
  final String nombreLocal;
  final String? avatarLocal;
  final String? fechaTexto;
}

/// Muestra el visor fullscreen si la lista no está vacía.
Future<void> mostrarTopUltraStoriesOverlay(
  BuildContext context, {
  required List<EventoTopUltra> eventos,
  required void Function(String idEvento) onVerEvento,
}) {
  if (eventos.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _TopUltraStories(
        eventos: eventos,
        onVerEvento: onVerEvento,
      ),
      transitionsBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Badge compacto con destello para reabrir Top Ultra desde la cartelera.
class TopUltraBadgeCartelera extends StatefulWidget {
  const TopUltraBadgeCartelera({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<TopUltraBadgeCartelera> createState() => _TopUltraBadgeCarteleraState();
}

class _TopUltraBadgeCarteleraState extends State<TopUltraBadgeCartelera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  /// Brillo rápido izq→der; el resto del ciclo queda en pausa.
  double _posicionBrillo(double t) {
    const ventana = 0.38;
    if (t > ventana) return -0.4;
    return Curves.easeInOutCubic.transform(t / ventana);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: IntrinsicWidth(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.hardEdge,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorTema.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorTema.withValues(alpha: 0.38)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.flame_fill, color: colorTema, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Top Ultra',
                            style: GoogleFonts.baloo2(
                              color: ColoresApp.textoPrincipal,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 12,
                            color: ColoresApp.textoSecundario.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, size) {
                          final ancho = size.maxWidth;
                          final alto = size.maxHeight;
                          return AnimatedBuilder(
                            animation: _shimmer,
                            builder: (context, _) {
                              final p = _posicionBrillo(_shimmer.value);
                              final x = -ancho * 0.45 + p * (ancho * 1.85);
                              return Transform.translate(
                                offset: Offset(x, 0),
                                child: Transform.rotate(
                                  angle: -0.42,
                                  child: Container(
                                    width: ancho * 0.22,
                                    height: alto * 2.4,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
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
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopUltraStories extends StatefulWidget {
  const _TopUltraStories({required this.eventos, required this.onVerEvento});
  final List<EventoTopUltra> eventos;
  final void Function(String idEvento) onVerEvento;

  @override
  State<_TopUltraStories> createState() => _TopUltraStoriesState();
}

class _TopUltraStoriesState extends State<_TopUltraStories>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progreso;
  int _indice = 0;
  bool _pausado = false;
  static const Duration _duracionStory = Duration(seconds: 5);
  static const double _flyerRadius = 18;

  @override
  void initState() {
    super.initState();
    _progreso = AnimationController(vsync: this, duration: _duracionStory)
      ..addStatusListener(_onStatus);
    _iniciar();
  }

  @override
  void dispose() {
    _progreso.removeStatusListener(_onStatus);
    _progreso.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _siguiente();
  }

  void _iniciar() {
    _progreso
      ..stop()
      ..value = 0
      ..forward();
  }

  void _cerrar() => Navigator.of(context).maybePop();

  void _siguiente() {
    if (_indice >= widget.eventos.length - 1) {
      _cerrar();
      return;
    }
    setState(() => _indice++);
    _iniciar();
  }

  void _anterior() {
    if (_indice == 0) {
      _iniciar();
      return;
    }
    setState(() => _indice--);
    _iniciar();
  }

  void _onTapUp(TapUpDetails d, double ancho) {
    if (d.localPosition.dx < ancho * 0.32) {
      _anterior();
    } else {
      _siguiente();
    }
  }

  void _setPausa(bool v) {
    setState(() => _pausado = v);
    if (v) {
      _progreso.stop();
    } else {
      _progreso.forward();
    }
  }

  void _verEvento() {
    final id = widget.eventos[_indice].idEvento;
    _cerrar();
    widget.onVerEvento(id);
  }

  @override
  Widget build(BuildContext context) {
    final evento = widget.eventos[_indice];

    return Material(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (ctx, cons) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _FondoOscuro(),

              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTapUp(d, cons.maxWidth),
                  onLongPressStart: (_) => _setPausa(true),
                  onLongPressEnd: (_) => _setPausa(false),
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 64,
                      bottom: 168,
                      left: 16,
                      right: 16,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      child: _FlyerConGlow(
                        key: ValueKey<String>(evento.idEvento),
                        url: evento.urlFlyer,
                        borderRadius: _flyerRadius,
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Column(
                      children: [
                        _BarrasProgreso(
                          cantidad: widget.eventos.length,
                          indiceActual: _indice,
                          progreso: _progreso,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const _BadgeTopUltraHeader(),
                            const Spacer(),
                            _BotonCerrar(onTap: _cerrar),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Footer(
                  evento: evento,
                  onVerEvento: _verEvento,
                ),
              ),

              if (_pausado)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 82,
                  right: 22,
                  child: Icon(
                    CupertinoIcons.pause_circle_fill,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 28,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FondoOscuro extends StatelessWidget {
  const _FondoOscuro();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.1,
          colors: [
            const Color(0xFF1A1A1E),
            Colors.black,
          ],
        ),
      ),
    );
  }
}

class _FlyerConGlow extends StatelessWidget {
  const _FlyerConGlow({
    super.key,
    required this.url,
    required this.borderRadius,
  });

  final String url;
  final double borderRadius;

  static Size _tamanoContain(Size imagen, Size maximo) {
    if (imagen.width <= 0 || imagen.height <= 0) return maximo;
    final escala = math.min(
      maximo.width / imagen.width,
      maximo.height / imagen.height,
    );
    return Size(imagen.width * escala, imagen.height * escala);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maximo = Size(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: CachedNetworkImage(
                imageUrl: url,
                imageBuilder: (context, imageProvider) {
                  return _FlyerRecortado(
                    imageProvider: imageProvider,
                    maximo: maximo,
                    borderRadius: borderRadius,
                    colorTema: colorTema,
                  );
                },
                placeholder: (_, __) => SizedBox(
                  height: math.min(maximo.height, 280),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      color: colorTema.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => SizedBox(
                  height: math.min(maximo.height, 280),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Clip al tamaño real renderizado (contain) para que 9:16 también redondee esquinas.
class _FlyerRecortado extends StatefulWidget {
  const _FlyerRecortado({
    required this.imageProvider,
    required this.maximo,
    required this.borderRadius,
    required this.colorTema,
  });

  final ImageProvider imageProvider;
  final Size maximo;
  final double borderRadius;
  final Color colorTema;

  @override
  State<_FlyerRecortado> createState() => _FlyerRecortadoState();
}

class _FlyerRecortadoState extends State<_FlyerRecortado> {
  Size? _tamanoImagen;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolverTamano();
  }

  @override
  void didUpdateWidget(covariant _FlyerRecortado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _quitarListener();
      _tamanoImagen = null;
      _resolverTamano();
    }
  }

  void _quitarListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolverTamano() {
    if (_stream != null) return;
    _stream = widget.imageProvider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      setState(() => _tamanoImagen = Size(w, h));
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _quitarListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tamanoImagen == null) {
      return SizedBox(
        height: math.min(widget.maximo.height, 280),
        child: Center(
          child: CupertinoActivityIndicator(
            color: widget.colorTema.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    final display = _FlyerConGlow._tamanoContain(_tamanoImagen!, widget.maximo);

    return SizedBox(
      width: display.width,
      height: display.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius + 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.colorTema.withValues(alpha: 0.5),
                      blurRadius: 44,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: widget.colorTema.withValues(alpha: 0.2),
                      blurRadius: 72,
                      spreadRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: display.width,
              height: display.height,
              child: Image(
                image: widget.imageProvider,
                fit: BoxFit.cover,
                width: display.width,
                height: display.height,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarrasProgreso extends StatelessWidget {
  const _BarrasProgreso({
    required this.cantidad,
    required this.indiceActual,
    required this.progreso,
  });
  final int cantidad;
  final int indiceActual;
  final AnimationController progreso;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(cantidad, (i) {
        final double? v =
            i < indiceActual ? 1.0 : (i == indiceActual ? null : 0.0);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == cantidad - 1 ? 0 : 5),
            child: SizedBox(
              height: 2.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: v == null
                    ? AnimatedBuilder(
                        animation: progreso,
                        builder: (_, __) => _barra(progreso.value),
                      )
                    : _barra(v),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _barra(double value) => LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white.withValues(alpha: 0.22),
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.white.withValues(alpha: 0.95),
        ),
      );
}

class _BadgeTopUltraHeader extends StatelessWidget {
  const _BadgeTopUltraHeader();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.flame_fill, color: colorTema, size: 14),
              const SizedBox(width: 5),
              Text(
                'Top Ultra',
                style: GoogleFonts.baloo2(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BotonCerrar extends StatelessWidget {
  const _BotonCerrar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.xmark,
          color: Colors.white.withValues(alpha: 0.92),
          size: 16,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.evento,
    required this.onVerEvento,
  });
  final EventoTopUltra evento;
  final VoidCallback onVerEvento;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: ColoresApp.fondoSuperficie,
                    backgroundImage: (evento.avatarLocal != null &&
                            evento.avatarLocal!.isNotEmpty)
                        ? CachedNetworkImageProvider(evento.avatarLocal!)
                        : null,
                    child: (evento.avatarLocal == null ||
                            evento.avatarLocal!.isEmpty)
                        ? Icon(
                            CupertinoIcons.house_fill,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.7),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      evento.nombreLocal,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (evento.fechaTexto != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      evento.fechaTexto!,
                      style: GoogleFonts.baloo2(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                evento.tituloEvento,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  height: 1.12,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<Color>(
                valueListenable: TemaFernecito.instancia.colorActual,
                builder: (context, colorTema, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(14),
                      color: colorTema,
                      onPressed: onVerEvento,
                      child: Text(
                        'Ver evento',
                        style: GoogleFonts.baloo2(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
