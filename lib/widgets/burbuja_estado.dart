/// Burbuja de estado / mensaje con cola redondeada (estilo rompehielo).
/// Reutilizable en perfiles, pools, explorar, rompehielo, squads.
library;

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marquee/marquee.dart';

import '../core/constants.dart';

/// Burbuja con cola suave hacia el avatar (arriba) o hacia abajo (mensajes propios).
class BurbujaEstado extends StatelessWidget {
  final String texto;
  final double? fontSize;
  final double? maxWidth;
  final double? minWidth;
  final bool usarMarquee;
  final bool ajustarAnchoAlTexto;
  final int? maxLines;
  final bool colaHaciaArriba;
  final bool esMio;
  final bool mostrarPuntosSiVacio;
  final bool compacta;

  const BurbujaEstado({
    super.key,
    required this.texto,
    this.fontSize,
    this.maxWidth,
    this.minWidth,
    this.usarMarquee = false,
    this.ajustarAnchoAlTexto = false,
    this.maxLines = 2,
    this.colaHaciaArriba = true,
    this.esMio = false,
    this.mostrarPuntosSiVacio = true,
    this.compacta = false,
  });

  static const _defaultMaxW = 320.0;

  bool get _esVacio => texto.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final maxW = maxWidth ?? _defaultMaxW;
    final fs = fontSize ?? 12.0;
    final medidas = _MedidasBurbuja.de(
      fontSize: fs,
      compacta: compacta,
      colaArriba: colaHaciaArriba,
    );
    final minW = minWidth ??
        (_esVacio ? medidas.minAnchoVacio : medidas.minAnchoTexto);

    return Center(
      child: _BurbujaContenido(
        texto: texto,
        fontSize: fs,
        maxWidth: maxW,
        minWidth: minW,
        usarMarquee: usarMarquee,
        maxLines: maxLines,
        colaHaciaArriba: colaHaciaArriba,
        esMio: esMio,
        mostrarPuntosSiVacio: mostrarPuntosSiVacio,
        ajustarAnchoAlTexto: ajustarAnchoAlTexto,
        medidas: medidas,
      ),
    );
  }
}

class _MedidasBurbuja {
  const _MedidasBurbuja({
    required this.padH,
    required this.padTop,
    required this.padBottom,
    required this.tailH,
    required this.radio,
    required this.minAnchoVacio,
    required this.minAnchoTexto,
  });

  final double padH;
  final double padTop;
  final double padBottom;
  final double tailH;
  final double radio;
  final double minAnchoVacio;
  final double minAnchoTexto;

  factory _MedidasBurbuja.de({
    required double fontSize,
    required bool compacta,
    required bool colaArriba,
  }) {
    final c = compacta || fontSize <= 11;
    final tail = c ? 9.0 : 11.0;
    return _MedidasBurbuja(
      padH: c ? 7.0 : 12.0,
      padTop: colaArriba ? tail + (c ? 4.0 : 6.0) : (c ? 8.0 : 11.0),
      padBottom: colaArriba ? (c ? 5.0 : 8.0) : tail + (c ? 4.0 : 6.0),
      tailH: tail,
      radio: c ? 12.0 : 16.0,
      minAnchoVacio: c ? 46.0 : 56.0,
      minAnchoTexto: c ? 52.0 : 64.0,
    );
  }
}

class _BurbujaContenido extends StatelessWidget {
  const _BurbujaContenido({
    required this.texto,
    required this.fontSize,
    required this.maxWidth,
    required this.minWidth,
    required this.usarMarquee,
    required this.maxLines,
    required this.colaHaciaArriba,
    required this.esMio,
    required this.mostrarPuntosSiVacio,
    required this.ajustarAnchoAlTexto,
    required this.medidas,
  });

  final String texto;
  final double fontSize;
  final double maxWidth;
  final double minWidth;
  final bool usarMarquee;
  final int? maxLines;
  final bool colaHaciaArriba;
  final bool esMio;
  final bool mostrarPuntosSiVacio;
  final bool ajustarAnchoAlTexto;
  final _MedidasBurbuja medidas;

  TextStyle get _style => GoogleFonts.baloo2(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: ColoresApp.textoPrincipal,
        height: 1.12,
        letterSpacing: -0.15,
      );

  Size _medirTexto(double maxContentW) {
    final t = texto.trim();
    if (t.isEmpty) {
      return Size(0, fontSize * 1.1);
    }
    final lineCap = (maxLines ?? 2).clamp(1, 6);

    final unaLinea = TextPainter(
      text: TextSpan(text: t, style: _style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    if (unaLinea.width <= maxContentW) {
      return Size(unaLinea.width, unaLinea.height);
    }

    final envuelto = TextPainter(
      text: TextSpan(text: t, style: _style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: lineCap,
    )..layout(maxWidth: maxContentW);

    return Size(maxContentW, envuelto.height);
  }

  @override
  Widget build(BuildContext context) {
    final vacio = texto.trim().isEmpty;
    final borderColor = esMio
        ? ColoresApp.principalMarca.withValues(alpha: 0.5)
        : ColoresApp.principalMarca.withValues(alpha: 0.28);

    final maxContentW = (maxWidth - medidas.padH * 2).clamp(24.0, maxWidth);

    late final double ancho;
    late final double altoContenido;

    if (vacio && mostrarPuntosSiVacio) {
      ancho = minWidth.clamp(medidas.minAnchoVacio, maxWidth);
      altoContenido = fontSize + 6;
    } else if (ajustarAnchoAlTexto) {
      final medida = _medirTexto(maxContentW);
      ancho = (medida.width + medidas.padH * 2).clamp(minWidth, maxWidth);
      altoContenido = medida.height;
    } else {
      ancho = maxWidth;
      final medida = _medirTexto(maxContentW);
      altoContenido = medida.height;
    }

    final alto = altoContenido + medidas.padTop + medidas.padBottom;

    final contenido = vacio && mostrarPuntosSiVacio
        ? Icon(
            CupertinoIcons.ellipsis,
            size: (fontSize + 6).clamp(16.0, 22.0),
            color: ColoresApp.textoSecundario.withValues(alpha: 0.55),
          )
        : _buildTexto(maxContentW);

    return SizedBox(
      width: ancho,
      height: alto,
      child: CustomPaint(
        painter: PintorBurbujaChat(
          colaHaciaArriba: colaHaciaArriba,
          fillColor: ColoresApp.fondoSuperficie.withValues(alpha: 0.94),
          borderColor: borderColor,
          tailHeight: medidas.tailH,
          radio: medidas.radio,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            medidas.padH,
            medidas.padTop,
            medidas.padH,
            medidas.padBottom,
          ),
          child: Center(child: contenido),
        ),
      ),
    );
  }

  Widget _buildTexto(double maxContentW) {
    if (usarMarquee) {
      return _TextoOMarquee(texto: texto, fontSize: fontSize + 1);
    }
    return Text(
      texto,
      textAlign: TextAlign.center,
      style: _style,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Pintor compartido: cola triangular redondeada (estilo rompehielo).
class PintorBurbujaChat extends CustomPainter {
  const PintorBurbujaChat({
    required this.colaHaciaArriba,
    required this.fillColor,
    required this.borderColor,
    required this.tailHeight,
    this.radio = 16,
  });

  final bool colaHaciaArriba;
  final Color fillColor;
  final Color borderColor;
  final double tailHeight;
  final double radio;

  Path _outline(Size size) {
    final r = radio;
    const tailHalfW = 8.0;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final path = Path();

    if (colaHaciaArriba) {
      final bt = tailHeight;
      final bb = h;
      path.moveTo(r, bb);
      path.arcToPoint(Offset(0, bb - r), radius: Radius.circular(r));
      path.lineTo(0, bt + r);
      path.arcToPoint(Offset(r, bt), radius: Radius.circular(r));
      path.lineTo(cx - tailHalfW, bt);
      path.cubicTo(
        cx - tailHalfW * 0.5, bt - tailHeight * 0.3,
        cx - 2.5, bt - tailHeight,
        cx, bt - tailHeight,
      );
      path.cubicTo(
        cx + 2.5, bt - tailHeight,
        cx + tailHalfW * 0.5, bt - tailHeight * 0.3,
        cx + tailHalfW, bt,
      );
      path.lineTo(w - r, bt);
      path.arcToPoint(Offset(w, bt + r), radius: Radius.circular(r));
      path.lineTo(w, bb - r);
      path.arcToPoint(Offset(w - r, bb), radius: Radius.circular(r));
      path.close();
    } else {
      final bt = 0.0;
      final bb = h - tailHeight;
      path.moveTo(r, bt);
      path.lineTo(w - r, bt);
      path.arcToPoint(Offset(w, bt + r), radius: Radius.circular(r));
      path.lineTo(w, bb - r);
      path.arcToPoint(Offset(w - r, bb), radius: Radius.circular(r));
      path.lineTo(cx + tailHalfW, bb);
      path.cubicTo(
        cx + tailHalfW * 0.5, bb + tailHeight * 0.3,
        cx + 2.5, bb + tailHeight,
        cx, bb + tailHeight,
      );
      path.cubicTo(
        cx - 2.5, bb + tailHeight,
        cx - tailHalfW * 0.5, bb + tailHeight * 0.3,
        cx - tailHalfW, bb,
      );
      path.lineTo(r, bb);
      path.arcToPoint(Offset(0, bb - r), radius: Radius.circular(r));
      path.lineTo(0, bt + r);
      path.arcToPoint(Offset(r, bt), radius: Radius.circular(r));
      path.close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _outline(size);
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant PintorBurbujaChat old) =>
      old.colaHaciaArriba != colaHaciaArriba ||
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.radio != radio;
}

/// Texto que muestra marquee horizontal si no cabe.
class TextoMarqueeSiLargo extends StatelessWidget {
  final String texto;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  const TextoMarqueeSiLargo({
    super.key,
    required this.texto,
    required this.fontSize,
    this.color = ColoresApp.textoPrincipal,
    this.fontWeight = FontWeight.w600,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return Text(
            texto,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        }
        final maxW = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: texto, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        if (painter.width > maxW) {
          return SizedBox(
            height: fontSize * 1.35,
            child: Marquee(
              text: texto,
              style: style,
              scrollAxis: Axis.horizontal,
              blankSpace: maxW * 0.25,
              velocity: 28,
              pauseAfterRound: const Duration(milliseconds: 600),
            ),
          );
        }
        return Text(
          texto,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}

class _TextoOMarquee extends StatelessWidget {
  final String texto;
  final double fontSize;

  const _TextoOMarquee({required this.texto, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: ColoresApp.textoPrincipal,
      height: 1.12,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return Text(
            texto,
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          );
        }
        final maxW = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: texto, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        if (painter.width > maxW) {
          return SizedBox(
            height: fontSize * 2.0,
            child: Marquee(
              text: texto,
              style: style,
              scrollAxis: Axis.horizontal,
              blankSpace: maxW * 0.25,
              velocity: 28,
              pauseAfterRound: const Duration(milliseconds: 600),
            ),
          );
        }
        return Text(
          texto,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
