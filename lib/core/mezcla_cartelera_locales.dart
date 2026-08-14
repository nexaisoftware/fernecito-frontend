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

  /// TOP solo admite pionero, verificado o plan pago (nunca cuentas free).
  static bool aptoParaTop(LocalCarteleraCard c) =>
      c.esPionero || c.esVerificado || c.tienePlanActivo;

  /// ¿Alguna sección necesita relleno según conteos de eventos filtrados?
  static bool necesitaRelleno(Map<String, int> conteosEventos) {
    for (final s in seccionesOrden) {
      if ((conteosEventos[s] ?? 0) < umbralEventos) return true;
    }
    return false;
  }

  /// Reparte hasta [maxTotal] locales entre secciones con &lt;10 eventos (máx 4 c/u).
  /// 1) Reserva TOP solo con pionero/verificado/plan.
  /// 2) Round-robin el resto para no starvear gratis/recomendados.
  static Map<String, List<LocalCarteleraCard>> distribuir({
    required List<LocalCarteleraCard> pool,
    required Map<String, int> conteosEventos,
    required int seed,
  }) {
    if (pool.isEmpty) return const {};

    final cupos = <String, int>{};
    for (final seccion in seccionesOrden) {
      final eventos = conteosEventos[seccion] ?? 0;
      if (eventos >= umbralEventos) continue;
      cupos[seccion] = math.min(maxPorSeccion, umbralEventos - eventos);
    }
    if (cupos.isEmpty) return const {};

    final ordenados = _ordenarPool(pool, seed);
    final usados = <String>{};
    var restantesTotal = math.min(maxTotal, ordenados.length);
    final result = <String, List<LocalCarteleraCard>>{
      for (final s in cupos.keys) s: <LocalCarteleraCard>[],
    };

    // Fase 1: TOP primero, solo elegibles (pionero / verificado / plan).
    final cupoTop = cupos['top'];
    if (cupoTop != null && cupoTop > 0) {
      final listaTop = result['top']!;
      for (final card in ordenados) {
        if (listaTop.length >= cupoTop || restantesTotal <= 0) break;
        if (usados.contains(card.localId) || !aptoParaTop(card)) continue;
        listaTop.add(card);
        usados.add(card.localId);
        restantesTotal--;
      }
    }

    // Fase 2: round-robin del resto (pueden ser free).
    final otras = seccionesOrden.where((s) => s != 'top' && cupos.containsKey(s));
    var progreso = true;
    while (restantesTotal > 0 && progreso) {
      progreso = false;
      for (final seccion in otras) {
        if (restantesTotal <= 0) break;
        final cupo = cupos[seccion]!;
        final lista = result[seccion]!;
        if (lista.length >= cupo) continue;

        LocalCarteleraCard? pick;
        for (final card in ordenados) {
          if (usados.contains(card.localId)) continue;
          pick = card;
          break;
        }
        if (pick == null) {
          restantesTotal = 0;
          break;
        }

        lista.add(pick);
        usados.add(pick.localId);
        restantesTotal--;
        progreso = true;
      }
    }

    result.removeWhere((_, v) => v.isEmpty);
    return result;
  }

  static List<LocalCarteleraCard> _ordenarPool(
    List<LocalCarteleraCard> pool,
    int seed,
  ) {
    final rng = math.Random(seed);
    int cmpScore(LocalCarteleraCard a, LocalCarteleraCard b) {
      final byScore = b.scorePerfil.compareTo(a.scorePerfil);
      if (byScore != 0) return byScore;
      return a.rankingPosition.compareTo(b.rankingPosition);
    }

    // TOP / prioridad: pioneros por score, luego verificados/plan por score.
    final pioneros = pool.where((c) => c.esPionero).toList()..sort(cmpScore);
    final premium = pool
        .where((c) => !c.esPionero && (c.esVerificado || c.tienePlanActivo))
        .toList()
      ..sort(cmpScore);
    final resto = pool
        .where((c) => !c.esPionero && !c.esVerificado && !c.tienePlanActivo)
        .toList()
      ..shuffle(rng);
    return [...pioneros, ...premium, ...resto];
  }

  /// Rellena: primero todos los eventos de la sección, al final las cards de locales.
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

  /// Alias de [appendLocales] (eventos primero, locales al final).
  static List<Map<String, dynamic>> mezclarEnLista(
    List<Map<String, dynamic>> eventos,
    List<LocalCarteleraCard>? locales,
  ) =>
      appendLocales(eventos, locales);
}
