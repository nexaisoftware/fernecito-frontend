import 'package:flutter_test/flutter_test.dart';
import 'package:fernecito_frontend/core/busqueda_natural.dart';
import 'package:fernecito_frontend/core/servicio_busqueda_cartelera.dart';

void main() {
  test('BusquedaNatural encuentra incompletas y sinonimos', () {
    expect(BusquedaNatural.coincide('hambur', ['Hamburguesería Norte']), isTrue);
    expect(BusquedaNatural.coincide('BIRRA', ['Bar de cerveza artesanal']), isTrue);
    expect(BusquedaNatural.coincide('promo', ['Noche 2x1']), isTrue);
  });

  test('prefijo desde 2 letras: vi/vid → Vidon', () {
    expect(BusquedaNatural.coincide('vi', ['Vidon Bar Achaval']), isTrue);
    expect(BusquedaNatural.coincide('vid', ['Vidon Bar Achaval']), isTrue);
    expect(BusquedaNatural.coincide('vido', ['Vidon Bar Achaval']), isTrue);
    expect(BusquedaNatural.coincide('la', ['La Esquina Bar']), isTrue);
    expect(BusquedaNatural.coincide('mr', ['Mr Birra']), isTrue);
    expect(BusquedaNatural.coincide('es', ['La Esquina Bar']), isTrue);
  });

  test('rankearDesdeMemoria encuentra bar y tostado', () {
    final res = ServicioBusquedaCartelera.rankearDesdeMemoria(
      query: 'bar',
      locales: [
        {'idLocal': '1', 'nombre': 'Vidon Bar Achaval', 'rubro': null},
        {'idLocal': '2', 'nombre': 'Pizzería Roma', 'rubro': null},
      ],
      eventos: [
        {'id': 'e1', 'titulo': 'tostado + papas', 'nombreLocal': 'La Esquina'},
        {'id': 'e2', 'titulo': 'Noche de birra', 'nombreLocal': 'Checa Bar'},
      ],
    );
    expect(res.lugares.map((e) => e['nombre']), contains('Vidon Bar Achaval'));
    expect(res.eventos.any((e) => e['nombreLocal'] == 'Checa Bar'), isTrue);

    final tostado = ServicioBusquedaCartelera.rankearDesdeMemoria(
      query: 'tostado',
      locales: const [],
      eventos: [
        {'id': 'e1', 'titulo': 'tostado + papas', 'nombreLocal': 'La Esquina'},
      ],
    );
    expect(tostado.eventos, isNotEmpty);

    final vi = ServicioBusquedaCartelera.rankearDesdeMemoria(
      query: 'vi',
      locales: [
        {'idLocal': '1', 'nombre': 'Vidon Bar Achaval', 'rubro': null},
      ],
      eventos: [
        {'id': 'e1', 'titulo': 'Viernes de fernet', 'nombreLocal': 'X'},
      ],
    );
    expect(vi.lugares, isNotEmpty);
    expect(vi.eventos, isNotEmpty);
  });
}
