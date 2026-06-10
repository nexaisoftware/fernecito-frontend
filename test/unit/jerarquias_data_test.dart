import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/jerarquias_data.dart';

void main() {
  group('JerarquiasData.desdeSlug — slugs conocidos', () {
    test('resuelve top_ultra', () {
      expect(JerarquiasData.desdeSlug('top_ultra').slug, 'top_ultra');
    });

    test('resuelve top', () {
      expect(JerarquiasData.desdeSlug('top').slug, 'top');
    });

    test('resuelve recomendado_fernecito', () {
      expect(JerarquiasData.desdeSlug('recomendado_fernecito').slug, 'recomendado_fernecito');
    });

    test('resuelve normal', () {
      expect(JerarquiasData.desdeSlug('normal').slug, 'normal');
    });

    test('resuelve gratis', () {
      expect(JerarquiasData.desdeSlug('gratis').slug, 'gratis');
    });
  });

  group('JerarquiasData.desdeSlug — fallback a gratis', () {
    test('null → gratis', () {
      expect(JerarquiasData.desdeSlug(null).slug, 'gratis');
    });

    test('slug desconocido → gratis', () {
      expect(JerarquiasData.desdeSlug('slug_inventado').slug, 'gratis');
    });

    test('string vacío → gratis', () {
      expect(JerarquiasData.desdeSlug('').slug, 'gratis');
    });
  });

  group('JerarquiasData.desdeSlug — normalización', () {
    test('case-insensitive: TOP_ULTRA → top_ultra', () {
      expect(JerarquiasData.desdeSlug('TOP_ULTRA').slug, 'top_ultra');
    });

    test('case-insensitive: TOP → top', () {
      expect(JerarquiasData.desdeSlug('TOP').slug, 'top');
    });

    test('trimea espacios', () {
      expect(JerarquiasData.desdeSlug('  normal  ').slug, 'normal');
    });
  });

  group('JerarquiasData.todas', () {
    test('contiene exactamente 5 jerarquías', () {
      expect(JerarquiasData.todas.length, 5);
    });

    test('está ordenada de mayor a menor por campo orden', () {
      final ordenes = JerarquiasData.todas.map((j) => j.orden).toList();
      for (int i = 0; i < ordenes.length - 1; i++) {
        expect(
          ordenes[i],
          greaterThan(ordenes[i + 1]),
          reason: 'El índice $i (orden ${ordenes[i]}) debe ser mayor que índice ${i + 1} (orden ${ordenes[i + 1]})',
        );
      }
    });

    test('ningún slug está duplicado', () {
      final slugs = JerarquiasData.todas.map((j) => j.slug).toSet();
      expect(slugs.length, JerarquiasData.todas.length);
    });
  });

  group('JerarquiasData — permiteVerMas', () {
    test('top_ultra, top, recomendado_fernecito: permiteVerMas false (pagas)', () {
      expect(JerarquiasData.topUltra.permiteVerMas, isFalse);
      expect(JerarquiasData.top.permiteVerMas, isFalse);
      expect(JerarquiasData.recomendadoFernecito.permiteVerMas, isFalse);
    });

    test('normal y gratis: permiteVerMas true', () {
      expect(JerarquiasData.normal.permiteVerMas, isTrue);
      expect(JerarquiasData.gratis.permiteVerMas, isTrue);
    });
  });

  group('JerarquiasData.filtrosUsuario', () {
    test('excluye top_ultra (va en stories, no en chips)', () {
      final slugs = JerarquiasData.filtrosUsuario.map((j) => j.slug).toList();
      expect(slugs, isNot(contains('top_ultra')));
    });

    test('contiene los 4 filtros esperados', () {
      final slugs = JerarquiasData.filtrosUsuario.map((j) => j.slug).toSet();
      expect(slugs, containsAll(['top', 'recomendado_fernecito', 'normal', 'gratis']));
    });

    test('tiene exactamente 4 elementos', () {
      expect(JerarquiasData.filtrosUsuario.length, 4);
    });
  });

  group('CapacidadCartelera', () {
    test('topPorFila == 10', () => expect(CapacidadCartelera.topPorFila, 10));
    test('recomendadoPorFila == 15', () => expect(CapacidadCartelera.recomendadoPorFila, 15));
    test('normalPorFila == 15', () => expect(CapacidadCartelera.normalPorFila, 15));
    test('normalFilasIniciales == 2', () => expect(CapacidadCartelera.normalFilasIniciales, 2));
  });

  group('FiltroTiempoUI.label', () {
    test('cada filtro tiene label no vacío', () {
      for (final f in FiltroTiempo.values) {
        expect(f.label, isNotEmpty, reason: 'FiltroTiempo.${f.name} sin label');
      }
    });

    test('labels son únicos entre sí', () {
      final labels = FiltroTiempo.values.map((f) => f.label).toSet();
      expect(labels.length, FiltroTiempo.values.length);
    });
  });
}
