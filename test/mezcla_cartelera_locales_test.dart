import 'package:flutter_test/flutter_test.dart';

import 'package:fernecito_frontend/core/mezcla_cartelera_locales.dart';
import 'package:fernecito_frontend/models/local_cartelera_card.dart';

LocalCarteleraCard _card(
  String id, {
  bool pionero = false,
  bool plan = false,
  bool verificado = false,
  double score = 0,
}) {
  return LocalCarteleraCard(
    id: 'card-$id',
    localId: id,
    ciudad: 'Córdoba capital',
    provincia: 'Córdoba',
    rankingPosition: 1,
    textoIa: 'Texto IA de prueba para $id',
    imagenesUrls: const [],
    nombreLocal: 'Local $id',
    esPionero: pionero,
    esVerificado: verificado,
    tienePlanActivo: plan,
    scorePerfil: score,
  );
}

void main() {
  group('MezclaCarteleraLocales', () {
    test('no rellena si todas las secciones tienen ≥10 eventos', () {
      final conteos = {
        'top': 10,
        'recomendado_fernecito': 12,
        'normal': 15,
        'gratis': 10,
      };
      expect(MezclaCarteleraLocales.necesitaRelleno(conteos), isFalse);
      final out = MezclaCarteleraLocales.distribuir(
        pool: List.generate(12, (i) => _card('$i', pionero: true)),
        conteosEventos: conteos,
        seed: 1,
      );
      expect(out, isEmpty);
    });

    test('TOP reserva elegibles primero; resto round-robin sin starvear', () {
      final pool = List.generate(12, (i) => _card('$i', pionero: i < 4));
      final out = MezclaCarteleraLocales.distribuir(
        pool: pool,
        conteosEventos: {
          'top': 0,
          'recomendado_fernecito': 0,
          'normal': 0,
          'gratis': 0,
        },
        seed: 42,
      );
      expect(out['top']?.length, 4);
      expect(out['top']!.every(MezclaCarteleraLocales.aptoParaTop), isTrue);
      final resto = (out['recomendado_fernecito']?.length ?? 0) +
          (out['normal']?.length ?? 0) +
          (out['gratis']?.length ?? 0);
      expect(resto, 8);
      expect(out['gratis'], isNotEmpty);
      final ids = out.values.expand((e) => e.map((c) => c.localId)).toSet();
      expect(ids.length, 12);
    });

    test('TOP solo admite pionero/verificado/plan, nunca free', () {
      final pool = [
        _card('free1'),
        _card('free2'),
        _card('pio', pionero: true),
        _card('ver', verificado: true),
        _card('plan', plan: true),
        _card('free3'),
      ];
      final out = MezclaCarteleraLocales.distribuir(
        pool: pool,
        conteosEventos: {
          'top': 0,
          'recomendado_fernecito': 9,
          'normal': 10,
          'gratis': 10,
        },
        seed: 1,
      );
      final tops = out['top'] ?? const [];
      expect(tops.length, 3);
      expect(tops.every(MezclaCarteleraLocales.aptoParaTop), isTrue);
      expect(tops.any((c) => c.localId.startsWith('free')), isFalse);
    });

    test('si no hay elegibles TOP, otras secciones igual reciben free', () {
      final pool = List.generate(6, (i) => _card('free$i'));
      final out = MezclaCarteleraLocales.distribuir(
        pool: pool,
        conteosEventos: {
          'top': 0,
          'recomendado_fernecito': 0,
          'normal': 0,
          'gratis': 0,
        },
        seed: 3,
      );
      expect(out.containsKey('top'), isFalse);
      expect(out['recomendado_fernecito'], isNotEmpty);
      expect(out['gratis'], isNotEmpty);
    });

    test('respeta max 4 por sección y cupo por umbral', () {
      final out = MezclaCarteleraLocales.distribuir(
        pool: List.generate(12, (i) => _card('$i', pionero: true)),
        conteosEventos: {
          'top': 8,
          'recomendado_fernecito': 9,
          'normal': 10,
          'gratis': 7,
        },
        seed: 7,
      );
      expect(out['top']?.length, 2);
      expect(out['recomendado_fernecito']?.length, 1);
      expect(out.containsKey('normal'), isFalse);
      expect(out['gratis']?.length, 3);
    });

    test('appendLocales pone eventos primero y locales al final', () {
      final eventos = List.generate(
        4,
        (i) => <String, dynamic>{'id': 'e$i', 'titulo': 'E$i'},
      );
      final locales = [_card('a', pionero: true), _card('b')];
      final mezclado = MezclaCarteleraLocales.appendLocales(eventos, locales);
      expect(mezclado.length, 6);
      expect(mezclado[0]['id'], 'e0');
      expect(mezclado[3]['id'], 'e3');
      expect(LocalCarteleraCard.esItemLocal(mezclado[4]), isTrue);
      expect(LocalCarteleraCard.esItemLocal(mezclado[5]), isTrue);
    });

    test('TOP prioriza mayor score entre elegibles', () {
      final pool = [
        _card('low', pionero: true, score: 10),
        _card('high', pionero: true, score: 90),
        _card('mid', verificado: true, score: 50),
        _card('free', score: 999),
      ];
      final out = MezclaCarteleraLocales.distribuir(
        pool: pool,
        conteosEventos: {
          'top': 8,
          'recomendado_fernecito': 10,
          'normal': 10,
          'gratis': 10,
        },
        seed: 1,
      );
      expect(out['top']!.map((c) => c.localId).toList(), ['high', 'low']);
    });
  });
}
