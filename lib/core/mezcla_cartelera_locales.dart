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
    final pioneros = pool.where((c) => c.esPionero).toList()..shuffle(rng);
    final premium = pool
        .where((c) => !c.esPionero && (c.esVerificado || c.tienePlanActivo))
        .toList()
      ..shuffle(rng);
    final resto = pool
        .where((c) => !c.esPionero && !c.esVerificado && !c.tienePlanActivo)
        .toList()
      ..shuffle(rng);
    return [...pioneros, ...premium, ...resto];
  }

  /// Intercala locales entre eventos para que no queden al final del carrusel.
  /// Patrón: 1º evento, 1º local, luego cada 2 eventos otro local; sobrantes al final.
  static List<Map<String, dynamic>> mezclarEnLista(
    List<Map<String, dynamic>> eventos,
    List<LocalCarteleraCard>? locales,
  ) {
    if (locales == null || locales.isEmpty) return eventos;
    final locItems = locales.map((l) => l.toItemCartelera()).toList();
    if (eventos.isEmpty) return locItems;

    final result = <Map<String, dynamic>>[];
    var li = 0;
    for (var i = 0; i < eventos.length; i++) {
      result.add(eventos[i]);
      final insertarAqui = li < locItems.length && (i == 0 || (i + 1) % 2 == 0);
      if (insertarAqui) {
        result.add(locItems[li++]);
      }
    }
    while (li < locItems.length) {
      result.add(locItems[li++]);
    }
    return result;
  }

  /// @deprecated Preferí [mezclarEnLista]; se mantiene por compat.
  static List<Map<String, dynamic>> appendLocales(
    List<Map<String, dynamic>> eventos,
    List<LocalCarteleraCard>? locales,
  ) =>
      mezclarEnLista(eventos, locales);
}
