import 'dart:html' as html;
import 'dart:js' as js;

Future<void> recargarAppWeb() async {
  try {
    js.context.callMethod('fernecitoForzarRecargaPwa');
    return;
  } catch (_) {}
  html.window.location.reload();
}
