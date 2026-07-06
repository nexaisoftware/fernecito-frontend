import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

/// Captura [beforeinstallprompt] expuesto desde [index.html].
class InstalarPwaWeb {
  InstalarPwaWeb._();
  static final InstalarPwaWeb instancia = InstalarPwaWeb._();

  final List<void Function()> _alDisponible = [];
  final List<void Function()> _alInstalada = [];
  bool _configurado = false;

  bool get soportado => true;

  bool get yaInstalada {
    if (html.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    try {
      final nav = js.context['navigator'];
      if (nav != null && nav['standalone'] == true) return true;
    } catch (_) {}
    return false;
  }

  bool get instalacionDisponible {
    if (yaInstalada) return false;
    return js.context['deferredPrompt'] != null;
  }

  void configurar() {
    if (_configurado) return;
    _configurado = true;

    html.window.addEventListener('pwa-install-available', (_) {
      for (final cb in List.of(_alDisponible)) {
        cb();
      }
    });

    html.window.addEventListener('pwa-installed', (_) {
      js.context['deferredPrompt'] = null;
      for (final cb in List.of(_alInstalada)) {
        cb();
      }
    });

    if (instalacionDisponible) {
      scheduleMicrotask(() {
        for (final cb in List.of(_alDisponible)) {
          cb();
        }
      });
    }
  }

  void alDisponible(void Function() callback) {
    _alDisponible.add(callback);
    if (instalacionDisponible) callback();
  }

  void alInstalada(void Function() callback) {
    _alInstalada.add(callback);
    if (yaInstalada) callback();
  }

  Future<bool> solicitarInstalacion() async {
    try {
      final fn = js.context['solicitarInstalacionPwa'];
      if (fn == null) return false;
      final promise = fn.apply([]) as js.JsObject;
      return await _promiseToBool(promise);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _promiseToBool(js.JsObject promise) {
    final completer = Completer<bool>();
    promise.callMethod('then', [
      (result) {
        if (!completer.isCompleted) completer.complete(result == true);
      },
    ]);
    promise.callMethod('catch', [
      (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
    ]);
    return completer.future;
  }
}
