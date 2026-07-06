/// Señal de que la cartelera terminó su primera carga (para no mostrar navbar
/// encima del splash).
library;

import 'package:flutter/foundation.dart';

import 'barra_sistema_fernecito.dart';

class BootstrapCartelera {
  BootstrapCartelera._();

  static final ValueNotifier<bool> lista = ValueNotifier<bool>(false);

  static void marcarLista() {
    if (lista.value) return;
    lista.value = true;
    BarraSistemaFernecito.aplicar();
  }

  static void reset() {
    lista.value = false;
  }
}
