/// Servicio de tema Fernecito: colores seleccionables, persistencia y notificación.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Índices de tema (0=verde, 1=rosa, 2=rojo, 3=azul, 4=violeta).
class TemaFernecito {
  TemaFernecito._();
  static final TemaFernecito instancia = TemaFernecito._();

  static const _keyIndice = 'tema_fernecito_indice';

  /// Verde por defecto (marca Fernecito).
  static const verde = Color(0xFF1DB954);

  /// Rosa pastel claro.
  static const rosaPastel = Color(0xFFFFB6C1);

  /// Rojo claro.
  static const rojoClaro = Color(0xFFFF6B6B);

  /// Azul celeste medio.
  static const azulCeleste = Color(0xFF5DADE2);

  /// Violeta.
  static const violeta = Color(0xFFBB8FCE);

  static const List<Color> colores = [
    verde,
    rosaPastel,
    rojoClaro,
    azulCeleste,
    violeta,
  ];

  final ValueNotifier<Color> colorActual = ValueNotifier<Color>(verde);
  int _indiceActual = 0;

  int get indiceActual => _indiceActual;

  /// Carga el tema guardado al iniciar.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indice = prefs.getInt(_keyIndice) ?? 0;
      _aplicarIndice(indice);
    } catch (_) {}
  }

  /// Cambia al tema en [indice] (0-4) y persiste.
  Future<void> establecerIndice(int indice) async {
    if (indice < 0 || indice >= colores.length) return;
    _aplicarIndice(indice);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyIndice, indice);
    } catch (_) {}
  }

  void _aplicarIndice(int indice) {
    _indiceActual = indice;
    colorActual.value = colores[indice];
  }

  Color get color => colorActual.value;
}
