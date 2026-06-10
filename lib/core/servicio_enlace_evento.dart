/// Captura y consume deep links `?evento=` / `/e/{id}` hacia [PantallaVerEvento].
library;

import 'package:flutter/foundation.dart';

class ServicioEnlaceEvento {
  ServicioEnlaceEvento._();
  static final ServicioEnlaceEvento instancia = ServicioEnlaceEvento._();

  final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  String? _idPendiente;

  String? get idPendiente => _idPendiente;

  /// Lee la URL actual (web) y guarda el id si corresponde.
  void capturarDesdeUriActual() {
    if (!kIsWeb) return;
    capturarDesdeUri(Uri.base, notificar: false);
  }

  void capturarDesdeUri(Uri uri, {bool notificar = true}) {
    final query = uri.queryParameters['evento']?.trim();
    if (query != null && query.isNotEmpty) {
      fijarPendiente(query, notificar: notificar);
      return;
    }

    final share = uri.queryParameters['id']?.trim();
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (share != null &&
        share.isNotEmpty &&
        (segs.isNotEmpty && segs[0] == 'share-evento')) {
      fijarPendiente(share, notificar: notificar);
      return;
    }

    if (segs.length >= 2 && segs[0] == 'e') {
      final id = segs[1].trim();
      if (id.isNotEmpty) fijarPendiente(id, notificar: notificar);
    }
  }

  void fijarPendiente(String idEvento, {bool notificar = true}) {
    final id = idEvento.trim();
    if (id.isEmpty) return;
    _idPendiente = id;
    if (notificar) cambios.value++;
  }

  String? tomarPendiente() {
    final id = _idPendiente;
    _idPendiente = null;
    return id;
  }
}
