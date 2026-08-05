import 'package:flutter_test/flutter_test.dart';
import 'package:fernecito_frontend/core/estado_busqueda_ia.dart';

void main() {
  final cache = EstadoBusquedaIaCache.instancia;

  setUp(cache.resetConversacion);

  test('historial omite intentos fallidos y conserva la pregunta en curso', () {
    cache.agregarUsuario('Quiero pizzas baratas');
    cache.agregarAsistente(texto: 'Sin conexión', esError: true);
    cache.agregarUsuario('¿Y hamburguesas?');
    cache.agregarEscribiendo();

    expect(cache.historialParaEdge(), [
      {'rol': 'user', 'texto': '¿Y hamburguesas?'},
    ]);
  });

  test('historial conserva turnos exitosos y sus ids', () {
    cache.agregarUsuario('Planes para hoy');
    cache.agregarAsistente(texto: 'Encontré estas opciones');

    expect(cache.historialParaEdge(), [
      {'rol': 'user', 'texto': 'Planes para hoy'},
      {'rol': 'assistant', 'texto': 'Encontré estas opciones', 'ids': <dynamic>[]},
    ]);
  });
}
