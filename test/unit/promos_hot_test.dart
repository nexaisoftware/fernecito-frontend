import 'package:fernecito_frontend/core/promos_hot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('esPromoHot', () {
    test('detecta tipo_promo hot_se_sale', () {
      expect(
        esPromoHot({'tipo_promo': 'hot_se_sale'}),
        isTrue,
      );
    });

    test('detecta flag y modo_evento del evento', () {
      expect(
        esPromoHot(
          {'titulo_promocion': '2x1'},
          evento: {'modo_evento': 'hot_se_sale'},
        ),
        isTrue,
      );
      expect(esPromoHot({'es_hot_se_sale': true}), isTrue);
    });

    test('no marca promo regular', () {
      expect(
        esPromoHot({
          'titulo_promocion': '2x1 tragos',
          'modo_uso': 'individual',
        }),
        isFalse,
      );
    });
  });

  group('requiereAsistenciaPromo', () {
    test('Hot no pide lista salvo flag explícito', () {
      expect(
        requiereAsistenciaPromo({'tipo_promo': 'hot_se_sale'}),
        isFalse,
      );
      expect(
        requiereAsistenciaPromo({
          'tipo_promo': 'hot_se_sale',
          'requiere_asistencia': true,
        }),
        isTrue,
      );
    });

    test('promo regular pide lista por defecto', () {
      expect(requiereAsistenciaPromo({'titulo_promocion': '2x1'}), isTrue);
    });
  });

  group('titulo y flyer', () {
    test('titulo cae al evento si la promo no tiene', () {
      expect(
        tituloVisiblePromo(
          {},
          evento: {'titulo_evento': 'After Texas'},
        ),
        'After Texas',
      );
    });

    test('chip 2x1 sale del título si el tipo es hot', () {
      expect(
        etiquetaTipoPromo({
          'tipo_promo': 'hot_se_sale',
          'titulo_promocion': '2x1 en tragos',
        }),
        '2x1',
      );
    });

    test('flyer de promo pisa al del evento', () {
      expect(
        urlFlyerPromo(
          {'url_flyer': 'https://cdn/promo.webp'},
          evento: {'url_flyer': 'https://cdn/evento.webp'},
        ),
        'https://cdn/promo.webp',
      );
      expect(
        urlFlyerPromo({}, evento: {'url_flyer': 'https://cdn/evento.webp'}),
        'https://cdn/evento.webp',
      );
    });
  });

  group('mensajePromoAmigable', () {
    test('prioriza code de la edge', () {
      expect(
        mensajePromoAmigable({'code': 'no_cupos'}, 409),
        'No quedan cupos para esta promo.',
      );
      expect(
        mensajePromoAmigable({'code': 'invalid_jwt'}, 401),
        contains('sesión'),
      );
      expect(
        mensajePromoAmigable({'code': 'stale_cupos'}, 409),
        contains('cupos'),
      );
    });

    test('si solo hay code desconocido lo muestra', () {
      expect(
        mensajePromoAmigable({'code': 'algo_nuevo'}, 400),
        'No se pudo obtener la promo (algo_nuevo).',
      );
    });

    test('duplicate se reconoce', () {
      expect(errorPromoDuplicada({'code': 'already_reserved'}), isTrue);
      expect(errorPromoDuplicada({'error': 'duplicate key'}), isTrue);
    });
  });

  group('puedeObtenerEstaPromo', () {
    test('Hot sin lista se puede obtener', () {
      expect(
        puedeObtenerEstaPromo(
          promo: {'tipo_promo': kTipoPromoHotSeSale},
          estadoLista: null,
        ),
        isTrue,
      );
    });

    test('regular exige lista aceptada', () {
      expect(
        puedeObtenerEstaPromo(
          promo: {'titulo_promocion': '2x1'},
          estadoLista: 'pendiente',
        ),
        isFalse,
      );
      expect(
        puedeObtenerEstaPromo(
          promo: {'titulo_promocion': '2x1'},
          estadoLista: 'aceptada',
        ),
        isTrue,
      );
    });
  });
}
