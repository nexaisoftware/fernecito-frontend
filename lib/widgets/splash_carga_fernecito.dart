/// Splash de carga Flutter (capa C): logo + «Fernecito App» + loader de íconos.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fernecito_loader.dart';

/// Verde unificado con splash nativa (`flutter_native_splash` / Android / iOS / PWA).
const Color kVerdeSplashFernecito = Color(0xFF1DB954);

/// Splash de app mientras carga sesión o cartelera.
///
/// Logo (fondo transparente) centrado → sube un poco y debajo, pegado,
/// aparece «Fernecito App». Más abajo, íconos blancos con sombra.
class SplashCargaFernecito extends StatefulWidget {
  const SplashCargaFernecito({super.key});

  @override
  State<SplashCargaFernecito> createState() => _SplashCargaFernecitoState();
}

class _SplashCargaFernecitoState extends State<SplashCargaFernecito>
    with SingleTickerProviderStateMixin {
  static const _logoSize = 88.0;
  static const _subidaLogo = 12.0;

  late final AnimationController _controller;
  late final Animation<double> _entrada;
  late final Animation<double> _subirLogo;
  late final Animation<double> _revelarTexto;
  late final Animation<double> _loaderOpacidad;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _entrada = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
    );
    _subirLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.72, curve: Curves.easeInOutCubic),
    );
    _revelarTexto = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.80, curve: Curves.easeOutCubic),
    );
    _loaderOpacidad = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.95, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kVerdeSplashFernecito,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final entrada = _entrada.value.clamp(0.0, 1.0);
            final subir = _subirLogo.value.clamp(0.0, 1.0);
            final revelar = _revelarTexto.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: entrada,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - entrada)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + texto en el mismo bloque (gap 0), suben juntos.
                    Transform.translate(
                      offset: Offset(0, -_subidaLogo * subir),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LogoSplash(size: _logoSize),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: revelar,
                              child: Opacity(
                                opacity: Curves.easeOut.transform(revelar),
                                child: Text(
                                  'Fernecito App',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -0.4,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x33000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Compensa la subida para que el loader no salte.
                    SizedBox(height: _subidaLogo * subir),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: _loaderOpacidad.value.clamp(0.0, 1.0),
                      child: const FernecitoLoader.inline(
                        size: 32,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x40000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                          Shadow(
                            color: Color(0x22000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogoSplash extends StatelessWidget {
  const _LogoSplash({required this.size});

  static const assetPath = 'assets/imagenes/logo_sin_fondo_splash.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image(
        image: const AssetImage(assetPath),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: false,
      ),
    );
  }
}

/// Compat: barra antigua (pantalla_splash legacy).
class SplashCargaFernecitoBarra extends StatelessWidget {
  const SplashCargaFernecitoBarra({super.key});

  @override
  Widget build(BuildContext context) {
    return const FernecitoLoader.inline(
      size: 28,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Color(0x40000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}

/// Compat: barra espejo (ya no se usa en el splash principal).
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
