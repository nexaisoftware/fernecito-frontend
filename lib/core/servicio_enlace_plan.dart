/// Captura y consume deep links `?plan=` / `/share-plan?id=` hacia [PantallaVerPlan].
library;

import 'package:flutter/foundation.dart';

class ServicioEnlacePlan {
  ServicioEnlacePlan._();
  static final ServicioEnlacePlan instancia = ServicioEnlacePlan._();

  final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  String? _idPendiente;

  String? get idPendiente => _idPendiente;

  void capturarDesdeUriActual() {
    if (!kIsWeb) return;
    capturarDesdeUri(Uri.base, notificar: false);
  }

  void capturarDesdeUri(Uri uri, {bool notificar = true}) {
    final query = uri.queryParameters['plan']?.trim();
    if (query != null && query.isNotEmpty) {
      fijarPendiente(query, notificar: notificar);
      return;
    }

    final share = uri.queryParameters['id']?.trim();
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (share != null &&
        share.isNotEmpty &&
        segs.isNotEmpty &&
        segs[0] == 'share-plan') {
      fijarPendiente(share, notificar: notificar);
      return;
    }

    if (segs.length >= 2 && segs[0] == 'p') {
      final id = segs[1].trim();
      if (id.isNotEmpty) fijarPendiente(id, notificar: notificar);
    }
  }

  void fijarPendiente(String idPlan, {bool notificar = true}) {
    final id = idPlan.trim();
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
