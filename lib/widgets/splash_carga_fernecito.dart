/// Splash de carga Flutter: port 1:1 de
/// `fernecito-logo-animado/v2d-bracitos-flexibles.html`.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fernecito_loader.dart';

const Color kVerdeSplashFernecito = Color(0xFF1DB954);
const String _logoSplashAsset =
    'assets/imagenes/fernecito_logo_base_sin_burbujas.svg';

const double _vbW = 398.25467;
const double _vbH = 635.39874;
const double _telRef = 290;
const double _entradaMs = 2750;
const double _loopMs = 1900;
const double _respirarMs = 2600;
const double _textoDelayMs = 2300;
const double _textoDurMs = 1680;
const double _lockupListoMs = _textoDelayMs + _textoDurMs;
const double _barridoDurMs = 740;
const double _residuoDurMs = 1760;
/// Lockup: isotipo y texto juntos, con un huelgo mínimo para que no se toquen.
const double _lockupDx = -116;
const double _textoLeftFrac = 0.296;
const double _burbujasTextoLeftFrac = 0.281;

/// Hold después del lockup, con splash sola (sin montar Home).
/// Da margen para que el primer layout de cartelera no pise los últimos frames.
const Duration kSplashHoldTrasLockup = Duration(milliseconds: 1500);

/// Tope de seguridad si el ticker nativo tarda en arrancar (Android debug).
const Duration kSplashSeguridadMaxima = Duration(seconds: 10);

/// Reveal de marca (2300+1680 ms) + hold. Home/Top Ultra esperan
/// [splashAnimacionCompleta], no este número de reloj.
const Duration kSplashMinimaVisible = Duration(milliseconds: 5480);

/// Isotipo + texto ya en su sitio. Recién ahí se monta Home/cartelera.
final ValueNotifier<bool> splashLockupListo = ValueNotifier<bool>(false);

/// Se pone en true al cumplir [kSplashMinimaVisible]. Home espera esto
/// antes de abrir Top Ultra u otros overlays, para no tapar el splash.
final ValueNotifier<bool> splashAnimacionCompleta = ValueNotifier<bool>(false);

Future<void> esperarSplashAnimacion() {
  if (splashAnimacionCompleta.value) return Future<void>.value();
  final listo = Completer<void>();
  late final VoidCallback listener;
  listener = () {
    if (!splashAnimacionCompleta.value) return;
    splashAnimacionCompleta.removeListener(listener);
    if (!listo.isCompleted) listo.complete();
  };
  splashAnimacionCompleta.addListener(listener);
  return listo.future;
}

/// cubic-bezier(.16, 1, .3, 1) del prototipo HTML.
const Cubic _salidaHtml = Cubic(0.16, 1.0, 0.30, 1.0);
const Color _colorBurbuja = Color(0xFFD4B198);
const Color _colorEspuma = Color(0xFFEBD8C3);

TextStyle? _estiloMarcaCache;
double _estiloMarcaU = -1;

/// Misma Baloo 2 que el resto de la app (`GoogleFonts.baloo2`).
TextStyle _estiloMarca(double u) {
  if (_estiloMarcaCache != null && (u - _estiloMarcaU).abs() < 0.0001) {
    return _estiloMarcaCache!;
  }
  _estiloMarcaU = u;
  _estiloMarcaCache = GoogleFonts.baloo2(
    fontSize: 26 * u,
    height: 1.2,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 0,
    shadows: [
      Shadow(
        color: const Color(0x1A000000),
        blurRadius: 4 * u,
        offset: Offset(0, 2 * u),
      ),
      Shadow(
        color: const Color(0x14000000),
        blurRadius: 22 * u,
        offset: Offset(0, 10 * u),
      ),
    ],
  );
  return _estiloMarcaCache!;
}

class SplashCargaFernecito extends StatefulWidget {
  const SplashCargaFernecito({super.key});

  @override
  State<SplashCargaFernecito> createState() => _SplashCargaFernecitoState();
}

class _SplashCargaFernecitoState extends State<SplashCargaFernecito>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _ms = ValueNotifier<double>(0);
  bool _reducir = false;

  @override
  void initState() {
    super.initState();
    // Vsync del dispositivo/navegador (120/60/30): igual que el resto de la app.
    _ticker = createTicker((d) {
      if (!mounted) return;
      final ms = _reducir ? _lockupListoMs : d.inMilliseconds.toDouble();
      _ms.value = ms;
      if (!splashLockupListo.value && ms >= _lockupListoMs) {
        splashLockupListo.value = true;
      }
    })..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducir = MediaQuery.disableAnimationsOf(context);
    if (_reducir && !splashLockupListo.value) {
      _ms.value = _lockupListoMs;
      splashLockupListo.value = true;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kVerdeSplashFernecito,
      child: LayoutBuilder(
        builder: (context, c) {
          return _EscenarioSplash(
            width: c.maxWidth,
            height: c.maxHeight,
            msListenable: _ms,
            reducir: _reducir,
          );
        },
      ),
    );
  }
}

class _EscenarioSplash extends StatelessWidget {
  const _EscenarioSplash({
    required this.width,
    required this.height,
    required this.msListenable,
    required this.reducir,
  });

  final double width;
  final double height;
  final ValueListenable<double> msListenable;
  final bool reducir;

  @override
  Widget build(BuildContext context) {
    final u = width / _telRef;
    final logoW = width * 0.45;
    final logoH = logoW * (_vbH / _vbW);

    // Misma estructura que la versión visible (sin width/height en Positioned).
    // Solo se sube el top para alinear el isotipo con el texto, no abajo.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ListenableBuilder(
          listenable: msListenable,
          builder: (context, _) {
            final ms = reducir ? _lockupListoMs : msListenable.value;
            final entrada = _entradaLogo(ms);
            final dx = entrada.dx * u;
            final respirar = reducir ? (dy: 0.0, scale: 1.0) : _respirar(ms);
            // El scale usa Alignment(0, 0.1) y el translate -logoW/2: el isotipo
            // pintado no cae en el centro del Positioned. En la 1ª posición se
            // compensa para coincidir con la splash nativa (icono centrado).
            // El lockup (tLockup=1) queda exactamente igual que antes.
            const alignY = 0.1;
            final originY = logoH * ((alignY + 1) / 2);
            final tL = entrada.tLockup;
            final leftLockup = width * 0.5 + dx;
            final topLockup = height * 0.514 - logoH / 2 - logoH * 0.09;
            final leftCentro =
                width * 0.5 - (logoW * 0.5) * (1.0 - entrada.scale);
            final topCentro = height * 0.5 -
                originY -
                (logoH * 0.5 - originY) * entrada.scale;
            const scaleFinEntrada = 0.70;
            final leftDespegue =
                width * 0.5 - (logoW * 0.5) * (1.0 - scaleFinEntrada);
            final topDespegue = height * 0.5 -
                originY -
                (logoH * 0.5 - originY) * scaleFinEntrada;
            final left =
                tL <= 0 ? leftCentro : _lerp(leftDespegue, leftLockup, tL);
            final top =
                tL <= 0 ? topCentro : _lerp(topDespegue, topLockup, tL);
            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: entrada.opacity,
                child: Transform.scale(
                  scale: entrada.scale * respirar.scale,
                  alignment: const Alignment(0, 0.1),
                  child: Transform.translate(
                    offset: Offset(-logoW / 2, respirar.dy * u),
                    child: SizedBox(
                      width: logoW,
                      height: logoH,
                      child: _LogoVivo(
                        ms: ms,
                        u: u,
                        reducir: reducir,
                        width: logoW,
                        height: logoH,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        _TextoMarca(
          width: width,
          height: height,
          msListenable: msListenable,
          u: u,
          reducir: reducir,
        ),
        ListenableBuilder(
          listenable: msListenable,
          builder: (context, _) {
            return _BurbujasTexto(
              width: width,
              height: height,
              ms: reducir ? _lockupListoMs : msListenable.value,
              u: u,
              reducir: reducir,
            );
          },
        ),
      ],
    );
  }
}

class _LogoVivo extends StatefulWidget {
  const _LogoVivo({
    required this.ms,
    required this.u,
    required this.reducir,
    required this.width,
    required this.height,
  });

  final double ms;
  final double u;
  final bool reducir;
  final double width;
  final double height;

  @override
  State<_LogoVivo> createState() => _LogoVivoState();
}

class _LogoVivoState extends State<_LogoVivo> {
  ui.Image? _raster;
  int _token = 0;
  double _tw = 0;
  double _th = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_rasterizar());
    });
  }

  @override
  void didUpdateWidget(covariant _LogoVivo old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width || old.height != widget.height) {
      unawaited(_rasterizar());
    }
  }

  @override
  void dispose() {
    _raster?.dispose();
    super.dispose();
  }

  Future<void> _rasterizar() async {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    var tw = (widget.width * dpr).round().clamp(1, 4096);
    var th = (widget.height * dpr).round().clamp(1, 4096);
    if (tw > 2048 || th > 2048) {
      final s = 2048 / math.max(tw, th);
      tw = math.max(1, (tw * s).round());
      th = math.max(1, (th * s).round());
    }
    if (_raster != null && _tw == tw && _th == th) return;
    final token = ++_token;
    final bundle = DefaultAssetBundle.of(context);
    try {
      final info = await vg.loadPicture(
        SvgAssetLoader(_logoSplashAsset, assetBundle: bundle),
        context,
      );
      if (!mounted || token != _token) {
        info.picture.dispose();
        return;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(tw / info.size.width, th / info.size.height);
      canvas.drawPicture(info.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(tw, th);
      picture.dispose();
      info.picture.dispose();
      if (!mounted || token != _token) {
        image.dispose();
        return;
      }
      setState(() {
        _raster?.dispose();
        _raster = image;
        _tw = tw.toDouble();
        _th = th.toDouble();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_raster == null) {
      return RepaintBoundary(child: _LogoVivoWidgets(widget));
    }
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: !widget.reducir,
        painter: _PintorLogoVivo(
          image: _raster!,
          ms: widget.ms,
          u: widget.u,
          reducir: widget.reducir,
        ),
      ),
    );
  }
}

/// Fallback del primer frame, mientras el raster está listo.
class _LogoVivoWidgets extends StatelessWidget {
  const _LogoVivoWidgets(this.w);

  final _LogoVivo w;

  @override
  Widget build(BuildContext context) {
    final width = w.width;
    final height = w.height;
    final ms = w.ms;
    final u = w.u;
    final reducir = w.reducir;
    final skew = reducir ? 0.0 : _skewBrazos(ms);
    final origin = Offset(width * (200 / _vbW), height * (300 / _vbH));
    Widget espumaEnCapa() => Stack(
      clipBehavior: Clip.none,
      children: [
        for (final spec in _burbujasEspuma)
          _Particula(
            left: width * spec.x / _vbW - spec.r * u / 2,
            top: height * spec.y / _vbH - spec.r * u / 2,
            size: spec.r * u,
            color: _colorBurbuja,
            frame: reducir
                ? const _Frame(opacity: 1, dx: 0, dy: 0, scale: 1)
                : _escalarFrame(_circular(ms, spec.delayMs), u),
          ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRect(
          clipper: const _ClipFranja(end: 205 / _vbW),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                _logoSplashAsset,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              espumaEnCapa(),
              if (!reducir)
                ClipPath(
                  clipper: const _ClipLiquido(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final spec in _burbujasLiquido)
                        _Particula(
                          left: width * spec.x / _vbW - spec.r * u / 2,
                          top: height * spec.y / _vbH - spec.r * u / 2,
                          size: spec.r * u,
                          color: _colorBurbuja,
                          frame: _escalarFrame(_circular(ms, spec.delayMs), u),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Transform(
          origin: origin,
          transform: Matrix4.skewY(skew),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRect(
                clipper: const _ClipFranja(start: 195 / _vbW),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SvgPicture.asset(
                      _logoSplashAsset,
                      width: width,
                      height: height,
                      fit: BoxFit.fill,
                    ),
                    espumaEnCapa(),
                  ],
                ),
              ),
              if (!reducir)
                for (final spec in _sueltasSvg)
                  _Particula(
                    left: width * spec.x / _vbW - spec.r * u / 2,
                    top: height * spec.y / _vbH - spec.r * u / 2,
                    size: spec.r * u,
                    color: _colorEspuma,
                    frame: _escalarFrame(_salpicar(ms, spec.delayMs), u),
                  ),
            ],
          ),
        ),
        if (!reducir)
          for (final spec in _columnaArribaHtml)
            _Particula(
              left: width * spec.x - spec.size * u / 2,
              top: height * spec.y - spec.size * u / 2,
              size: spec.size * u,
              color: spec.color,
              frame: _escalarFrame(_subirVapor(ms, spec.delayMs), u),
            ),
      ],
    );
  }
}

class _PintorLogoVivo extends CustomPainter {
  const _PintorLogoVivo({
    required this.image,
    required this.ms,
    required this.u,
    required this.reducir,
  });

  final ui.Image image;
  final double ms;
  final double u;
  final bool reducir;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;
    final paintImg = Paint()..filterQuality = FilterQuality.high;
    final corteIzq = size.width * 205 / _vbW;
    final corteDer = size.width * 195 / _vbW;
    final ox = size.width * 200 / _vbW;
    final oy = size.height * 300 / _vbH;
    final skew = reducir ? 0.0 : _skewBrazos(ms);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, corteIzq, size.height));
    canvas.drawImageRect(image, src, dst, paintImg);
    _pintarEspuma(canvas, size);
    _pintarLiquido(canvas, size);
    canvas.restore();

    canvas.save();
    canvas.translate(ox, oy);
    canvas.transform(Matrix4.skewY(skew).storage);
    canvas.translate(-ox, -oy);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(corteDer, 0, size.width, size.height));
    canvas.drawImageRect(image, src, dst, paintImg);
    _pintarEspuma(canvas, size);
    canvas.restore();
    if (!reducir) _pintarSueltas(canvas, size);
    canvas.restore();

    if (!reducir) _pintarColumna(canvas, size);
  }

  void _pintarEspuma(Canvas canvas, Size size) {
    for (final spec in _burbujasEspuma) {
      _pintarPunto(
        canvas,
        size,
        spec.x / _vbW * size.width,
        spec.y / _vbH * size.height,
        spec.r * u,
        _colorBurbuja,
        reducir
            ? const _Frame(opacity: 1, dx: 0, dy: 0, scale: 1)
            : _escalarFrame(_circular(ms, spec.delayMs), u),
      );
    }
  }

  void _pintarLiquido(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_pathLiquido(size));
    for (final spec in _burbujasLiquido) {
      _pintarPunto(
        canvas,
        size,
        spec.x / _vbW * size.width,
        spec.y / _vbH * size.height,
        spec.r * u,
        _colorBurbuja,
        reducir
            ? const _Frame(opacity: 1, dx: 0, dy: 0, scale: 1)
            : _escalarFrame(_circular(ms, spec.delayMs), u),
      );
    }
    canvas.restore();
  }

  void _pintarSueltas(Canvas canvas, Size size) {
    for (final spec in _sueltasSvg) {
      _pintarPunto(
        canvas,
        size,
        spec.x / _vbW * size.width,
        spec.y / _vbH * size.height,
        spec.r * u,
        _colorEspuma,
        _escalarFrame(_salpicar(ms, spec.delayMs), u),
      );
    }
  }

  void _pintarColumna(Canvas canvas, Size size) {
    for (final spec in _columnaArribaHtml) {
      _pintarPunto(
        canvas,
        size,
        spec.x * size.width,
        spec.y * size.height,
        spec.size * u,
        spec.color,
        _escalarFrame(_subirVapor(ms, spec.delayMs), u),
      );
    }
  }

  void _pintarPunto(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double diametro,
    Color color,
    _Frame frame,
  ) {
    if (frame.opacity <= 0.5) return;
    canvas.drawCircle(
      Offset(cx + frame.dx, cy + frame.dy),
      diametro * frame.scale / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorLogoVivo old) =>
      old.ms != ms || old.image != image || old.reducir != reducir;
}

Path _pathLiquido(Size size) {
  const tx = 487.333334;
  const ty = -104.280342;
  Offset toLocal(double x, double y) =>
      Offset((x + tx) / _vbW * size.width, (y + ty) / _vbH * size.height);

  var cur = Offset(-446.67762, 727.7781);
  final path = Path();
  final start = toLocal(cur.dx, cur.dy);
  path.moveTo(start.dx, start.dy);

  void cubic(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx,
    double dy,
  ) {
    final c1 = toLocal(cur.dx + dx1, cur.dy + dy1);
    final c2 = toLocal(cur.dx + dx2, cur.dy + dy2);
    final end = Offset(cur.dx + dx, cur.dy + dy);
    final e = toLocal(end.dx, end.dy);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
    cur = end;
  }

  cubic(-16.15963, -0.31078, -24.3785, -16.94802, -25.03231, -33.99571);
  cubic(-1.409, -83.4224, -1.08353, -166.86744, -3.06784, -250.28099);
  cubic(0.39637, -5.2816, -1.27907, -25.65506, 3.29088, -11.95651);
  cubic(18.62245, 56.46935, 89.51181, 116.08013, 153.39493, 108.34983);
  cubic(1.20635, 4.73274, 0.97813, 124.45609, -0.5104, 162.51548);
  cubic(-1.28616, 22.39309, -15.59305, 25.95075, -30.34919, 26.21929);
  cubic(-31.23806, 0.50179, -56.27242, -0.0542, -87.51231, -0.65496);
  path.close();
  return path;
}

class _TextoMarca extends StatefulWidget {
  const _TextoMarca({
    required this.width,
    required this.height,
    required this.msListenable,
    required this.u,
    required this.reducir,
  });

  final double width;
  final double height;
  final ValueListenable<double> msListenable;
  final double u;
  final bool reducir;

  @override
  State<_TextoMarca> createState() => _TextoMarcaState();
}

class _TextoMarcaState extends State<_TextoMarca> {
  late double _ms;
  bool _congelado = false;

  @override
  void initState() {
    super.initState();
    _ms = widget.reducir ? _lockupListoMs : widget.msListenable.value;
    _congelado = widget.reducir || _progreso(_ms) >= 1;
    if (!_congelado) widget.msListenable.addListener(_onTick);
  }

  @override
  void dispose() {
    if (!_congelado) widget.msListenable.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final ms = widget.msListenable.value;
    setState(() => _ms = ms);
    if (_progreso(ms) >= 1) {
      _congelado = true;
      widget.msListenable.removeListener(_onTick);
    }
  }

  double _progreso(double ms) =>
      ((ms - _textoDelayMs) / _textoDurMs).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final local = widget.reducir ? 1.0 : _progreso(_ms);
    // Opacidad/asiento: ease suave. El wipe NO usa _salidaHtml
    // (cubic-bezier .16,1,.3,1 salta casi todo el progreso al inicio).
    final asiento = Curves.easeOutCubic.transform(local);
    final opacity = _kf(local, const [(0.0, 0.0), (0.14, 1.0), (1.0, 1.0)]);
    final dx = _lerp(-8, 0, asiento) * widget.u;
    final scale = _lerp(0.992, 1, asiento);

    return Positioned(
      left: widget.width * _textoLeftFrac + dx,
      top: widget.height * 0.514,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: FractionalTranslation(
            translation: const Offset(0, -0.5),
            child: _MascaraReveal(
              progress: Curves.easeInOutCubic.transform(local),
              u: widget.u,
              child: Text(
                'FernecitoApp',
                maxLines: 1,
                softWrap: false,
                style: _estiloMarca(widget.u),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wipe suave recortando el texto (no una capa verde encima).
class _MascaraReveal extends StatelessWidget {
  const _MascaraReveal({
    required this.progress,
    required this.u,
    required this.child,
  });

  final double progress;
  final double u;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(6 * u, 32 * u, 14 * u, 32 * u),
      child: child,
    );
    if (progress >= 1) return padded;
    final opaque = progress.clamp(0.0, 1.0);
    var fadeAt = (progress + 0.16).clamp(0.0, 1.0);
    if (fadeAt - opaque < 0.002) fadeAt = (opaque + 0.002).clamp(0.0, 1.0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, opaque, fadeAt, 1.0],
        ).createShader(bounds);
      },
      child: padded,
    );
  }
}

class _BurbujasTexto extends StatelessWidget {
  const _BurbujasTexto({
    required this.width,
    required this.height,
    required this.ms,
    required this.u,
    required this.reducir,
  });

  final double width;
  final double height;
  final double ms;
  final double u;
  final bool reducir;

  @override
  Widget build(BuildContext context) {
    if (reducir) return const SizedBox.shrink();
    final boxW = 185 * u;
    final boxH = 52 * u;
    return Positioned(
      left: width * _burbujasTextoLeftFrac,
      top: height * 0.514 - boxH / 2,
      child: SizedBox(
        width: boxW,
        height: boxH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final spec in _burbujasTextoHtml)
              _Particula(
                left: spec.x * u,
                top: spec.y * u,
                size: spec.size * u,
                color: spec.color,
                frame: _escalarFrame(
                  _barridoTexto(ms, _delayBarrido(spec.x)),
                  u,
                ),
              ),
            for (final spec in _residuosTextoHtml)
              _Particula(
                left: spec.x * u,
                top: spec.y * u,
                size: spec.size * u,
                color: spec.color,
                frame: _escalarFrame(_residuoBarrido(ms, spec.delayMs), u),
              ),
          ],
        ),
      ),
    );
  }
}

class _Particula extends StatelessWidget {
  const _Particula({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    required this.frame,
  });

  final double left;
  final double top;
  final double size;
  final Color color;
  final _Frame frame;

  @override
  Widget build(BuildContext context) {
    if (frame.opacity <= 0.5) return const SizedBox.shrink();
    return Positioned(
      left: left + frame.dx,
      top: top + frame.dy,
      child: Transform.scale(
        scale: frame.scale,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}

class _ClipFranja extends CustomClipper<Rect> {
  const _ClipFranja({this.start = 0, this.end = 1});

  final double start;
  final double end;

  @override
  Rect getClip(Size size) {
    final left = size.width * start;
    final right = size.width * end;
    return Rect.fromLTRB(left, 0, right, size.height);
  }

  @override
  bool shouldReclip(covariant _ClipFranja old) =>
      old.start != start || old.end != end;
}

class _ClipLiquido extends CustomClipper<Path> {
  const _ClipLiquido();

  @override
  Path getClip(Size size) => _pathLiquido(size);

  @override
  bool shouldReclip(covariant _ClipLiquido old) => false;
}

class _Frame {
  const _Frame({
    required this.opacity,
    required this.dx,
    required this.dy,
    required this.scale,
  });

  final double opacity;
  final double dx;
  final double dy;
  final double scale;
}

class _Entrada {
  const _Entrada({
    required this.opacity,
    required this.scale,
    required this.dx,
    required this.tLockup,
  });

  final double opacity;
  final double scale;
  final double dx;
  final double tLockup;
}

class _Dot {
  const _Dot(
    this.x,
    this.y,
    this.r,
    this.delayMs, [
    this.color = const Color(0xFFD4B198),
  ]);

  final double x;
  final double y;
  final double r;
  final double delayMs;
  final Color color;
}

class _HtmlDot {
  const _HtmlDot(this.x, this.y, this.size, this.delayMs, this.color);

  final double x;
  final double y;
  final double size;
  final double delayMs;
  final Color color;
}

/// Burbujas de la espuma (beige). Mismo `circular` del HTML:
/// pop in/out con poco desplazamiento vertical, sin subir al cluster.
const _burbujasEspuma = <_Dot>[
  _Dot(318.69, 158.82, 11.39, 860),
  _Dot(222.05, 190.24, 7.66, 980),
  _Dot(61.77, 191.03, 15.32, 760),
  _Dot(107.69, 347.20, 13.16, 1140),
  _Dot(257.65, 355.38, 6.87, 1030),
];

/// Burbujas del líquido oscuro: mismo `circular` del HTML, recortadas
/// al path curvo del líquido para no delatar un borde cuadrado ni pasar
/// a la espuma clara.
const _burbujasLiquido = <_Dot>[
  _Dot(115.98, 473.48, 11.59, 720),
  _Dot(78.78, 594.60, 6.48, 910),
  _Dot(69.30, 502.61, 11.00, 790),
  _Dot(88.88, 549.10, 7.66, 1060),
  _Dot(61.54, 438.67, 13.36, 880),
];

const _sueltasSvg = <_Dot>[
  _Dot(342.14, 39.74, 14.0, 980),
  _Dot(378.04, 70.90, 10.0, 1030),
  _Dot(336.30, 70.98, 8.0, 1080),
];

/// Columna encadenada encima de las 3: 2, luego 3, luego 3.
/// Arranca cuando las 3 del latigazo ya salieron.
const _columnaArribaHtml = <_HtmlDot>[
  _HtmlDot(0.82, -0.12, 8, 1220, _colorEspuma),
  _HtmlDot(0.95, -0.07, 6, 1280, _colorEspuma),
  _HtmlDot(0.78, -0.24, 7, 1420, _colorEspuma),
  _HtmlDot(0.90, -0.28, 8, 1480, _colorEspuma),
  _HtmlDot(1.01, -0.22, 6, 1540, _colorEspuma),
  _HtmlDot(0.75, -0.40, 6, 1680, _colorEspuma),
  _HtmlDot(0.88, -0.46, 7, 1740, _colorEspuma),
  _HtmlDot(1.02, -0.42, 5, 1800, _colorEspuma),
];

const _burbujasTextoHtml = <_HtmlDot>[
  _HtmlDot(8, 30, 8, 0, _colorEspuma),
  _HtmlDot(23, 22, 5, 0, _colorBurbuja),
  _HtmlDot(37, 34, 6, 0, _colorEspuma),
  _HtmlDot(52, 20, 4, 0, _colorBurbuja),
  _HtmlDot(68, 31, 7, 0, _colorBurbuja),
  _HtmlDot(82, 18, 5, 0, _colorEspuma),
  _HtmlDot(98, 33, 8, 0, _colorEspuma),
  _HtmlDot(111, 24, 4, 0, _colorBurbuja),
  _HtmlDot(124, 29, 6, 0, _colorBurbuja),
  _HtmlDot(138, 19, 5, 0, _colorEspuma),
  _HtmlDot(151, 32, 7, 0, _colorEspuma),
  _HtmlDot(164, 26, 4, 0, _colorBurbuja),
  _HtmlDot(174, 35, 5, 0, _colorBurbuja),
  _HtmlDot(181, 21, 3, 0, _colorEspuma),
];

/// Residuos sueltos que se desprenden del barrido, no en cada letra.
const _residuosTextoHtml = <_HtmlDot>[
  _HtmlDot(19, 34, 5, 2780, _colorEspuma),
  _HtmlDot(61, 18, 4, 3180, _colorBurbuja),
  _HtmlDot(94, 42, 6, 3480, _colorEspuma),
  _HtmlDot(132, 16, 4, 3780, _colorBurbuja),
  _HtmlDot(168, 36, 5, 4080, _colorEspuma),
  _HtmlDot(78, 28, 3, 4320, _colorBurbuja),
  _HtmlDot(148, 44, 4, 4560, _colorEspuma),
];

_Entrada _entradaLogo(double ms) {
  final raw = (ms / _entradaMs).clamp(0.0, 1.0);
  double seg(double a, double b) {
    if (raw <= a) return 0;
    if (raw >= b) return 1;
    return _salidaHtml.transform((raw - a) / (b - a));
  }

  final t1 = seg(0, 0.18);
  final t3 = seg(0.58, 1);
  return _Entrada(
    opacity: _lerp(0, 1, t1),
    scale: raw < 0.58 ? _lerp(0.62, 0.70, t1) : _lerp(0.70, 0.32, t3),
    dx: raw < 0.58 ? 0 : _lerp(0, _lockupDx, t3),
    tLockup: t3,
  );
}

({double dy, double scale}) _respirar(double ms) {
  final local = ms - _entradaMs;
  if (local < 0) return (dy: 0.0, scale: 1.0);
  final t = (local % _respirarMs) / _respirarMs;
  final wave = Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
  return (dy: _lerp(0, -2, wave), scale: _lerp(1, 1.006, wave));
}

double _skewBrazos(double ms) {
  final local = ms - 720;
  if (local < 0) return 0;
  final t = (local % _loopMs) / _loopMs;
  final deg = _kf(t, const [
    (0.00, 0.0),
    (0.06, 2.6),
    (0.16, -1.55),
    (0.25, 0.6),
    (0.34, -0.18),
    (0.43, 0.0),
    (1.00, 0.0),
  ], curve: Curves.easeInOut);
  return deg * math.pi / 180;
}

_Frame _circular(double ms, double delay) {
  final local = ms - delay;
  if (local < 0) {
    return const _Frame(opacity: 1, dx: 0, dy: 0, scale: 1);
  }
  final t = (local % _loopMs) / _loopMs;
  return _Frame(
    opacity: _kf(t, const [
      (0.00, 1.0),
      (0.36, 1.0),
      (0.50, 0.0),
      (0.51, 0.0),
      (0.68, 1.0),
      (1.00, 1.0),
    ], curve: Curves.easeInOut),
    dx: 0,
    dy: _kf(t, const [
      (0.00, 0.0),
      (0.36, -15.0),
      (0.50, -24.0),
      (0.51, 13.0),
      (0.68, 7.0),
      (1.00, 0.0),
    ], curve: Curves.easeInOut),
    scale: _kf(t, const [
      (0.00, 1.0),
      (0.36, 1.0),
      (0.50, 0.86),
      (0.51, 0.50),
      (0.68, 1.0),
      (1.00, 1.0),
    ], curve: Curves.easeInOut),
  );
}

_Frame _salpicar(double ms, double delay) {
  final local = ms - delay;
  if (local < 0) {
    return const _Frame(opacity: 0, dx: 0, dy: 30, scale: 0.15);
  }
  final t = (local % _loopMs) / _loopMs;
  return _Frame(
    opacity: _kf(t, const [
      (0.00, 0.0),
      (0.12, 1.0),
      (0.21, 1.0),
      (0.50, 1.0),
      (0.66, 0.0),
      (1.00, 0.0),
    ], curve: Curves.easeInOut),
    dx: _kf(t, const [
      (0.00, 0.0),
      (0.50, 3.0),
      (0.66, 6.0),
      (1.00, 0.0),
    ], curve: Curves.easeInOut),
    dy: _kf(t, const [
      (0.00, 30.0),
      (0.12, 3.0),
      (0.21, 0.0),
      (0.50, -10.0),
      (0.66, -21.0),
      (1.00, 30.0),
    ], curve: Curves.easeInOut),
    scale: _kf(t, const [
      (0.00, 0.15),
      (0.12, 1.04),
      (0.21, 1.0),
      (0.50, 1.0),
      (0.66, 0.86),
      (1.00, 0.15),
    ], curve: Curves.easeInOut),
  );
}

_Frame _subirVapor(double ms, double delay) {
  final local = ms - delay;
  if (local < 0) {
    return const _Frame(opacity: 0, dx: 0, dy: 8, scale: 0.38);
  }
  final t = (local % _loopMs) / _loopMs;
  return _Frame(
    opacity: _kf(t, const [
      (0.00, 0.0),
      (0.14, 1.0),
      (0.62, 1.0),
      (0.78, 0.0),
      (1.00, 0.0),
    ], curve: Curves.easeInOut),
    dx: _kf(t, const [
      (0.00, 0.0),
      (0.46, 3.0),
      (0.78, -2.0),
      (1.00, 0.0),
    ], curve: Curves.easeInOut),
    dy: _kf(t, const [
      (0.00, 8.0),
      (0.14, 0.0),
      (0.46, -12.0),
      (0.78, -20.0),
      (1.00, 8.0),
    ], curve: Curves.easeInOut),
    scale: _kf(t, const [
      (0.00, 0.38),
      (0.14, 1.0),
      (0.46, 1.0),
      (0.78, 0.72),
      (1.00, 0.38),
    ], curve: Curves.easeInOut),
  );
}

_Frame _barridoTexto(double ms, double delay) {
  final local = ms - delay;
  if (local < 0 || local > _barridoDurMs) {
    return const _Frame(opacity: 0, dx: 0, dy: 8, scale: 0.4);
  }
  final t = _salidaHtml.transform((local / _barridoDurMs).clamp(0.0, 1.0));
  return _Frame(
    opacity: _kf(t, const [(0.00, 0.0), (0.10, 1.0), (0.70, 1.0), (1.00, 0.0)]),
    dx: _kf(t, const [(0.00, 0.0), (0.70, 3.0), (1.00, 7.0)]),
    dy: _kf(t, const [(0.00, 8.0), (0.12, 0.0), (0.70, -14.0), (1.00, -26.0)]),
    scale: _kf(t, const [(0.00, 0.4), (0.12, 1.06), (0.70, 1.0), (1.00, 0.5)]),
  );
}

double _delayBarrido(double x) {
  const boxW = 185.0;
  final along = (x / boxW).clamp(0.0, 1.0);
  return _textoDelayMs + _textoDurMs * along - 60;
}

_Frame _residuoBarrido(double ms, double delay) {
  final local = ms - delay;
  if (local < 0 || local > _residuoDurMs) {
    return const _Frame(opacity: 0, dx: 0, dy: 8, scale: 0.28);
  }
  final t = _salidaHtml.transform((local / _residuoDurMs).clamp(0.0, 1.0));
  return _Frame(
    opacity: _kf(t, const [(0.00, 0.0), (0.10, 1.0), (0.70, 1.0), (1.00, 0.0)]),
    dx: _kf(t, const [(0.00, 0.0), (0.48, 6.0), (1.00, 14.0)]),
    dy: _kf(t, const [(0.00, 8.0), (0.48, -28.0), (1.00, -62.0)]),
    scale: _kf(t, const [(0.00, 0.28), (0.18, 1.0), (0.48, 1.0), (1.00, 0.42)]),
  );
}

_Frame _escalarFrame(_Frame f, double u) =>
    _Frame(opacity: f.opacity, dx: f.dx * u, dy: f.dy * u, scale: f.scale);

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double _kf(
  double t,
  List<(double, double)> keys, {
  Curve curve = Curves.linear,
}) {
  final x = t.clamp(0.0, 1.0);
  if (x <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    if (x <= keys[i].$1) {
      final a = keys[i - 1];
      final b = keys[i];
      final span = b.$1 - a.$1;
      final local = span == 0 ? 1.0 : ((x - a.$1) / span).clamp(0.0, 1.0);
      return _lerp(a.$2, b.$2, curve.transform(local));
    }
  }
  return keys.last.$2;
}

class SplashCargaFernecitoBarra extends StatelessWidget {
  const SplashCargaFernecitoBarra({super.key});

  @override
  Widget build(BuildContext context) {
    return const FernecitoLoader.inline(
      size: 28,
      color: Colors.white,
      shadows: [
        Shadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 2)),
      ],
    );
  }
}

class BarraEspejoFernecito extends StatelessWidget {
  const BarraEspejoFernecito({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final halfWidth = 86.0 * value.clamp(0.0, 1.0);
    return SizedBox(
      width: 172,
      height: 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            width: halfWidth * 2,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ],
      ),
    );
  }
}
