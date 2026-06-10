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
    final base = ColoresApp.fondoSuperficie.withOpacity(0.95);
    final tonoTema = Color.lerp(
      ColoresApp.fondoSuperficie,
      ColoresApp.principalMarca.withOpacity(0.12),
      temaTint,
    )!;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, tonoTema],
      ),
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
    final base = ColoresApp.fondoSuperficie.withOpacity(0.97);
    final tonoTema = Color.lerp(
      ColoresApp.fondoSuperficie,
      ColoresApp.principalMarca.withOpacity(0.1),
      0.16,
    )!;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [base, tonoTema],
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
    );
  }
}
