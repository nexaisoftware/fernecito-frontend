import 'package:flutter/cupertino.dart';

/// Navigator global de la app (evita imports circulares).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Callback registrado por el Home para sincronizar la navbar desde push/notifs.
/// La firma concreta (`SocialVista`) la tipa quien registra/consume.
typedef HomeIrATab = void Function(int tabIndex, {Object? socialVista});

HomeIrATab? _homeIrATab;

void registrarHomeIrATab(HomeIrATab callback) {
  _homeIrATab = callback;
}

void limpiarHomeIrATab() {
  _homeIrATab = null;
}

/// Cambia el tab del home si está montado. `socialVista` suele ser un [SocialVista].
void irATabHome(int tabIndex, {Object? socialVista}) {
  _homeIrATab?.call(tabIndex, socialVista: socialVista);
}

bool get homeIrATabDisponible => _homeIrATab != null;
