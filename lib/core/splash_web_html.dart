import 'dart:js_interop';

@JS('removeSplashFromWeb')
external void _removeSplashFromWeb();

void quitarSplashHtml() {
  try {
    _removeSplashFromWeb();
  } catch (_) {}
}
