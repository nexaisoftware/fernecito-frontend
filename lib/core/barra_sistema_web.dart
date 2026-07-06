import 'dart:js_interop';

@JS('fernecitoActualizarThemeColor')
external void _fernecitoActualizarThemeColor();

void actualizarThemeColorPwa(bool modoOscuro) {
  _fernecitoActualizarThemeColor();
}
