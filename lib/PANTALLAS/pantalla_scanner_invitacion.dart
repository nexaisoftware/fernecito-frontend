import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';

/// Prefijo del payload del QR de invitación de RRPP.
/// Debe coincidir con kPrefijoQrInvitacion de la app de locales.
const String kPrefijoQrInvitacion = 'FERNECITO_INV:';

/// Resultado de un escaneo válido de invitación de RRPP.
class ResultadoInvitacionRrpp {
  const ResultadoInvitacionRrpp({
    required this.idInvitacion,
    required this.idEvento,
    this.nombreEvento,
  });

  final String idInvitacion;
  final String idEvento;
  final String? nombreEvento;
}

double _opacidadPuntoMarcoQr(double t, int seed) {
  final phase = (t + seed * 0.17) % 1.0;
  final op = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return 0.18 + op * 0.82;
}

/// Pantalla de escaneo QR (invitaciones RRPP y otros payloads Fernecito).
class PantallaScannerInvitacion extends StatefulWidget {
  const PantallaScannerInvitacion({super.key});

  @override
  State<PantallaScannerInvitacion> createState() =>
      _PantallaScannerInvitacionState();
}

class _PantallaScannerInvitacionState extends State<PantallaScannerInvitacion> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _procesando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue?.trim() ?? '';
    if (raw.isEmpty) return;

    if (!raw.startsWith(kPrefijoQrInvitacion)) {
      _mostrarErrorTransitorio('Este QR no es una invitación de Fernecito.');
      return;
    }
    final idInvitacion = raw.substring(kPrefijoQrInvitacion.length).trim();
    if (idInvitacion.isEmpty) {
      _mostrarErrorTransitorio('El QR de invitación es inválido.');
      return;
    }

    setState(() {
      _procesando = true;
      _mensajeError = null;
    });
    HapticFeedback.mediumImpact();
    await _controller.stop();

    try {
      final sb = ServicioSupabase().cliente;
      final res = await sb.functions.invoke(
        'invitacion_rrpp',
        body: {'accion': 'resolver', 'id_invitacion': idInvitacion},
      );
      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        final msg = (data is Map ? data['error']?.toString() : null) ??
            'La invitación no es válida.';
        _mostrarErrorYReanudar(msg);
        return;
      }
      final idEvento = data['id_evento']?.toString() ?? '';
      if (idEvento.isEmpty) {
        _mostrarErrorYReanudar('No se pudo identificar el evento.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        ResultadoInvitacionRrpp(
          idInvitacion: idInvitacion,
          idEvento: idEvento,
          nombreEvento: data['titulo_evento']?.toString() ??
              data['nombre_evento']?.toString(),
        ),
      );
    } catch (e) {
      _mostrarErrorYReanudar(
        'No se pudo validar la invitación. Revisá tu conexión.',
      );
    }
  }

  void _mostrarErrorTransitorio(String msg) {
    setState(() => _mensajeError = msg);
  }

  Future<void> _mostrarErrorYReanudar(String msg) async {
    if (!mounted) return;
    setState(() {
      _mensajeError = msg;
      _procesando = false;
    });
    try {
      await _controller.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) =>
                            _VistaErrorCamara(
                          colorTema: colorTema,
                          onReintentar: () async {
                            try {
                              await _controller.start();
                            } catch (_) {}
                          },
                        ),
                      ),
                      const RepaintBoundary(
                        child: Center(child: _MarcoEscaneoQr()),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Text(
                          'Centrá el QR en el recuadro',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            shadows: const [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      _BotonCircularScanner(
                        icono: CupertinoIcons.xmark,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _BotonCircularScanner(
                        icono: CupertinoIcons.bolt_fill,
                        onTap: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64, left: 28, right: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Leer QR',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            shadows: const [
                              Shadow(
                                blurRadius: 12,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escaneá QR de locales, RRPP, embajadores, promociones y más.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.88),
                            shadows: const [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_procesando)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorTema.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoActivityIndicator(
                                  radius: 11,
                                  color: colorTema,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Validando…',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_mensajeError != null) ...[
                          if (_procesando) const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.peligroMarca
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _mensajeError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
}

/// Marco animado 4×4 (clonado de locales_qr_validar, adaptado al tema usuario).
class _MarcoEscaneoQr extends StatefulWidget {
  const _MarcoEscaneoQr();

  @override
  State<_MarcoEscaneoQr> createState() => _MarcoEscaneoQrState();
}

class _MarcoEscaneoQrState extends State<_MarcoEscaneoQr>
    with SingleTickerProviderStateMixin {
  static const double _size = 230;
  static const double _inset = 16;
  static const int _gridN = 4;
  static const double _dotSize = 5.5;

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value;
            final bordeOp =
                0.55 + 0.3 * ((math.sin(t * math.pi * 2) + 1) / 2);
            final inner = _size - _inset * 2;
            final step = _gridN > 1 ? (inner - _dotSize) / (_gridN - 1) : 0.0;

            return SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorTema.withValues(
                          alpha: bordeOp.clamp(0.0, 1.0),
                        ),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorTema.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  for (var row = 0; row < _gridN; row++)
                    for (var col = 0; col < _gridN; col++)
                      Positioned(
                        left: _inset + col * step,
                        top: _inset + row * step,
                        child: Container(
                          width: _dotSize,
                          height: _dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorTema.withValues(
                              alpha: _opacidadPuntoMarcoQr(
                                t,
                                row * _gridN + col,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BotonCircularScanner extends StatelessWidget {
  const _BotonCircularScanner({
    required this.icono,
    required this.onTap,
  });

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icono, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _VistaErrorCamara extends StatelessWidget {
  const _VistaErrorCamara({
    required this.colorTema,
    required this.onReintentar,
  });

  final Color colorTema;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColoresApp.fondoPrincipal,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 44,
              color: colorTema,
            ),
            const SizedBox(height: 14),
            Text(
              'No se pudo usar la cámara',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 18),
            CupertinoButton(
              color: colorTema,
              borderRadius: BorderRadius.circular(50),
              onPressed: onReintentar,
              child: Text(
                'Reintentar',
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
