import 'package:fernecito_frontend/core/busqueda_natural.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignora mayúsculas, acentos y espacios en errores comunes', () {
    expect(
      BusquedaNatural.coincide('BUR GESA', ['Hamburguesas caseras']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('buegers', ['Hamburguesas caseras']),
      isTrue,
    );
    expect(BusquedaNatural.coincide('economico', ['Plan económico']), isTrue);
  });

  test('entiende sinónimos argentinos y en inglés', () {
    expect(
      BusquedaNatural.coincide('quiero una birrita', ['Cerveza artesanal IPA']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('tengo gula', ['Festival de hamburguesas']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('quiero bailar', ['Fiesta cachengue']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('birthday party', [
        'Festejá tu cumple en el boliche',
      ]),
      isTrue,
    );
    expect(BusquedaNatural.coincide('cerbesa', ['Birra artesanal']), isTrue);
    expect(
      BusquedaNatural.coincide('quiero salir', ['Fiesta en boliche']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('suchi', ['Noche de sushi y rolls']),
      isTrue,
    );
    expect(
      BusquedaNatural.coincide('pool', ['Bar con mesas de billar']),
      isTrue,
    );
  });

  test('no confunde términos cortos dentro de otras palabras', () {
    expect(BusquedaNatural.coincide('bar', ['Comida barata']), isFalse);
    expect(BusquedaNatural.coincide('ipa', ['Chipa XL']), isFalse);
  });
}
