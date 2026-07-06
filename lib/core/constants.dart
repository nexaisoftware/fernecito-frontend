import 'package:flutter/material.dart';
import 'tema_fernecito.dart';

class ColoresApp {
  static const fondoPrincipal = Color(0xFF121212);
  static const fondoSuperficie = Color(0xFF1E1E1E);

  /// Color de tema (verde, rosa, rojo, azul, violeta). Se actualiza al cambiar tema.
  static Color get principalMarca => TemaFernecito.instancia.color;
  static const promoMarca = Color(
    0xFFE0B800,
  ); // Dorado flash promo, premium/VIP

  static Color get verdeFernet => principalMarca;
  static Color get fuegoFernet => principalMarca;

  static const flashPromo = Color(0xFFE0B800); // Dorado para promos destacadas
  static const peligroMarca = Color(
    0xFFD32F2F,
  ); // Rojo para alertas, errores, borrar cuenta

  static const textoPrincipal = Color(
    0xFFFFFFFF,
  ); // Blanco para textos principales
  static const textoSecundario = Color(
    0xFFAAAAAA,
  ); // Gris claro para descripciones/secundario
}

class CadenasApp {
  static const nombreApp = 'Fernecito';
  static const bienvenida = '¡Bienvenido a Fernecito! 🥃';
  static const lema = 'La app que revive las salidas en Córdoba';
}

// Otros constantes (ej: tamaños, si querés agregar)
class TamanosApp {
  static const relleno = 16.0;
  static const radioBorde = 12.0;
}

/// Superficies visuales compartidas (cards / sheets) con costo bajo de render.
class SuperficiesApp {
  SuperficiesApp._();

  static BoxDecoration card({
    required double radius,
    double temaTint = 0.18,
    double sombraAlpha = 0.14,
    double sombraBlur = 8,
    double sombraOffsetY = 4,
  }) {
    return BoxDecoration(
      color: ColoresApp.fondoSuperficie,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(sombraAlpha),
          blurRadius: sombraBlur,
          offset: Offset(0, sombraOffsetY),
        ),
      ],
    );
  }

  static BoxDecoration bottomSheet({double topRadius = 20}) {
    return BoxDecoration(
      color: ColoresApp.fondoSuperficie,
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
    );
  }

  /// Chip / botón secundario sin borde (contraste solo por relleno).
  static BoxDecoration chip({
    double radius = 20,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? ColoresApp.fondoSuperficie,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

/// Límites de texto en el hero del perfil de local (app usuarios).
class LimitesNombreLocalPerfil {
  LimitesNombreLocalPerfil._();

  static const maxCaracteresNombre = 50;
  static const saltoLineaNombreAntes = 10;
  static const minCaracteresUnaLinea = 22;
  static const minCaracteresDivisionBalanceada = 32;
}

/// Parte el nombre del hero para salto temprano y bloque más parejo.
class FormatoNombreLocalHero {
  FormatoNombreLocalHero._();

  static const _separadores = {' ', ',', '-', '–', '—', '/'};

  static String paraDisplay({
    required String nombre,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
    double reservaTrailing = 0,
  }) {
    final texto = nombre.trim();
    if (texto.isEmpty || texto.length <= LimitesNombreLocalPerfil.minCaracteresUnaLinea) {
      return texto;
    }

    final anchoTexto = (maxWidth - reservaTrailing).clamp(80.0, maxWidth);
    final finNatural = _finPrimeraLineaNatural(
      texto,
      textStyle,
      anchoTexto,
      textDirection,
    );

    final target = _indiceCorteObjetivo(texto.length, finNatural);
    if (target <= 0 || target >= texto.length) return texto;

    final corte = _indiceCorteEnPalabra(texto, target);
    if (corte <= 0 || corte >= texto.length) return texto;

    final linea1 = texto.substring(0, corte).trimRight();
    final linea2 = texto.substring(corte).trimLeft();
    if (linea1.isEmpty || linea2.isEmpty) return texto;
    return '$linea1\n$linea2';
  }

  static int _finPrimeraLineaNatural(
    String texto,
    TextStyle textStyle,
    double maxWidth,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: texto, style: textStyle),
      textDirection: textDirection,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.length < 2) return texto.length;

    return painter
        .getPositionForOffset(
          Offset(metrics.first.width, metrics.first.baseline),
        )
        .offset
        .clamp(1, texto.length);
  }

  static int _indiceCorteObjetivo(int largo, int finNatural) {
    if (largo >= LimitesNombreLocalPerfil.minCaracteresDivisionBalanceada) {
      return (largo / 2).round().clamp(1, largo - 1);
    }

    final anticipado = finNatural - LimitesNombreLocalPerfil.saltoLineaNombreAntes;
    return anticipado.clamp(10, largo - 1);
  }

  static int _indiceCorteEnPalabra(String texto, int target) {
    final limite = target.clamp(1, texto.length - 1);

    for (var i = limite; i >= limite - 12 && i > 0; i--) {
      if (_separadores.contains(texto[i])) return i + 1;
    }
    for (var i = limite; i < limite + 8 && i < texto.length; i++) {
      if (_separadores.contains(texto[i])) return i + 1;
    }
    return limite;
  }

  /// Espacio reservado en la última línea para insignia inline.
  static double reservaTrailingInsignia({
    required bool tieneInsignia,
    required double fontSize,
    required bool isNarrow,
  }) {
    if (!tieneInsignia) return 0;
    return (isNarrow ? 20.0 : 24.0) + 8;
  }
}
