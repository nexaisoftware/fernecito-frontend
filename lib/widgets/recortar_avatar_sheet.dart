/// Sheet de recorte circular para foto de perfil (pan + zoom).
/// Implementación propia web-safe: InteractiveViewer + overlay con Path.combine
/// (even-odd) + captura por RepaintBoundary.toImage. Evita el paquete externo que
/// no renderiza el recorte ni los gestos en Flutter web/PWA.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import 'fernecito_loader.dart';

/// Muestra vista previa circular con pan/zoom. Devuelve los bytes recortados
/// (PNG cuadrado, el avatar se ve circular al recortar en el display) o `null`.
Future<Uint8List?> mostrarRecorteAvatarSheet(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RecorteAvatarSheet(imageBytes: imageBytes),
  );
}

class _RecorteAvatarSheet extends StatefulWidget {
  const _RecorteAvatarSheet({required this.imageBytes});
  final Uint8List imageBytes;

  @override
  State<_RecorteAvatarSheet> createState() => _RecorteAvatarSheetState();
}

class _RecorteAvatarSheetState extends State<_RecorteAvatarSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _recortando = false;

  Future<void> _confirmar() async {
    if (_recortando) return;
    setState(() => _recortando = true);
    try {
      // Asegura que el frame con la transformación actual esté pintado.
      await WidgetsBinding.instance.endOfFrame;
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw StateError('boundary_no_listo');
      }
      final ui.Image img = await obj.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (!mounted) return;
      Navigator.pop(context, bytes?.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _recortando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (_, __) => Container(
        decoration: SuperficiesApp.bottomSheet(topRadius: 22),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encuadrá tu foto',
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Mové y hacé zoom. Así se verá en tu perfil.',
                          style: GoogleFonts.baloo2(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.textoSecundario,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: _recortando ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(22),
                    onPressed: _recortando ? null : _confirmar,
                    child: _recortando
                        ? const FernecitoLoader.inline(size: 16, color: Colors.white)
                        : Text(
                            'Listo',
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Área cuadrada centrada (el círculo va inscripto).
                    final lado = constraints.biggest.shortestSide;
                    return Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: lado,
                          height: lado,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: ColoresApp.fondoPrincipal),
                              // Solo esto se captura (sin el overlay).
                              RepaintBoundary(
                                key: _boundaryKey,
                                child: InteractiveViewer(
                                  clipBehavior: Clip.hardEdge,
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  child: Image.memory(
                                    widget.imageBytes,
                                    width: lado,
                                    height: lado,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              // Guía circular (NO se captura).
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size(lado, lado),
                                  painter: _GuiaCircular(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oscurece todo menos el círculo inscripto + dibuja el aro guía.
class _GuiaCircular extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.shortestSide / 2;
    final circulo = Path()
      ..addOval(Rect.fromCircle(center: centro, radius: radio));
    final full = Path()..addRect(Offset.zero & size);
    final fuera = Path.combine(PathOperation.difference, full, circulo);
    canvas.drawPath(fuera, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _GuiaCircular oldDelegate) => false;
}
