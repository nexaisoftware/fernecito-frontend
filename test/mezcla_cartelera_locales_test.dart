import 'package:flutter_test/flutter_test.dart';

import 'package:fernecito_frontend/core/mezcla_cartelera_locales.dart';
import 'package:fernecito_frontend/models/local_cartelera_card.dart';

LocalCarteleraCard _card(String id, {bool pionero = false, bool plan = false}) {
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
    tienePlanActivo: plan,
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
        pool: List.generate(12, (i) => _card('$i')),
        conteosEventos: conteos,
        seed: 1,
      );
      expect(out, isEmpty);
    });

    test('round-robin reparte cupo y no starvea gratis', () {
      final pool = List.generate(12, (i) => _card('$i', pionero: i < 2));
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
      expect(out['top']?.length, 3);
      expect(out['recomendado_fernecito']?.length, 3);
      expect(out['normal']?.length, 3);
      expect(out['gratis']?.length, 3);
      final ids = out.values.expand((e) => e.map((c) => c.localId)).toSet();
      expect(ids.length, 12);
    });

    test('respeta max 4 por sección y cupo por umbral', () {
      final out = MezclaCarteleraLocales.distribuir(
        pool: List.generate(12, (i) => _card('$i')),
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

    test('mezclarEnLista intercala locales visibles', () {
      final eventos = List.generate(
        4,
        (i) => <String, dynamic>{'id': 'e$i', 'titulo': 'E$i'},
      );
      final locales = [_card('a'), _card('b')];
      final mezclado = MezclaCarteleraLocales.mezclarEnLista(eventos, locales);
      expect(mezclado.length, 6);
      expect(LocalCarteleraCard.esItemLocal(mezclado[1]), isTrue);
      expect(mezclado[0]['id'], 'e0');
    });
  });
}
