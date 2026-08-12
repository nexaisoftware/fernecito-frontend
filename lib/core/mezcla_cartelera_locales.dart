/// Distribuye cards de locales en secciones de cartelera según reglas de negocio.
library;

import 'dart:math' as math;

import '../models/local_cartelera_card.dart';

abstract final class MezclaCarteleraLocales {
  static const int umbralEventos = 10;
  static const int maxPorSeccion = 4;
  static const int maxTotal = 12;

  static const List<String> seccionesOrden = <String>[
    'top',
    'recomendado_fernecito',
    'normal',
    'gratis',
  ];

  /// ¿Alguna sección necesita relleno según conteos de eventos filtrados?
  static bool necesitaRelleno(Map<String, int> conteosEventos) {
    for (final s in seccionesOrden) {
      if ((conteosEventos[s] ?? 0) < umbralEventos) return true;
    }
    return false;
  }

  /// Reparte hasta [maxTotal] locales entre secciones con <10 eventos (máx 4 c/u).
  /// Prioriza pioneros/plan; mezcla pseudo-aleatoria con [seed].
  static Map<String, List<LocalCarteleraCard>> distribuir({
    required List<LocalCarteleraCard> pool,
    required Map<String, int> conteosEventos,
    required int seed,
  }) {
    if (pool.isEmpty) return const {};

    final ordenados = _ordenarPool(pool, seed);
    final usados = <String>{};
    var restantesTotal = maxTotal;
    final result = <String, List<LocalCarteleraCard>>{};

    for (final seccion in seccionesOrden) {
      final eventos = conteosEventos[seccion] ?? 0;
      if (eventos >= umbralEventos || restantesTotal <= 0) continue;

      final cupoSeccion = math.min(maxPorSeccion, umbralEventos - eventos);
      final aTomar = math.min(cupoSeccion, restantesTotal);
      final picked = <LocalCarteleraCard>[];

      for (final card in ordenados) {
        if (picked.length >= aTomar) break;
        if (usados.contains(card.localId)) continue;
        picked.add(card);
        usados.add(card.localId);
      }

      if (picked.isNotEmpty) {
        result[seccion] = picked;
        restantesTotal -= picked.length;
      }
    }

    return result;
  }

  static List<LocalCarteleraCard> _ordenarPool(
    List<LocalCarteleraCard> pool,
    int seed,
  ) {
    final rng = math.Random(seed);
    final pioneros = pool.where((c) => c.esPionero).toList()..shuffle(rng);
    final plan = pool
        .where((c) => !c.esPionero && c.tienePlanActivo)
        .toList()
      ..shuffle(rng);
    final resto = pool
        .where((c) => !c.esPionero && !c.tienePlanActivo)
        .toList()
      ..shuffle(rng);
    return [...pioneros, ...plan, ...resto];
  }

  static List<Map<String, dynamic>> appendLocales(
    List<Map<String, dynamic>> eventos,
    List<LocalCarteleraCard>? locales,
  ) {
    if (locales == null || locales.isEmpty) return eventos;
    return [
      ...eventos,
      ...locales.map((l) => l.toItemCartelera()),
    ];
  }
}
