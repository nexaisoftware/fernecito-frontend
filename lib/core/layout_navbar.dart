import 'package:flutter/widgets.dart';

/// Altura de la navbar inferior (sin safe area del home indicator).
const double kHomeTabBarHeight = 66.0;

/// Espacio entre el pill flotante y el borde superior de la navbar.
const double kHomeFabGapSobreNav = 14.0;

/// Ancho del pill vertical (mapa + QR).
const double kHomeFabPillWidth = 52.0;

/// Alto del pill: dos zonas táctiles compactas.
const double kHomeFabPillHeight = 92.0;

/// Inset inferior del navbar: en iPhone no usar todo el safe area (queda mucho vacío).
double homeTabBarBottomInset(BuildContext context) {
  final safe = MediaQuery.paddingOf(context).bottom;
  if (safe <= 10) return safe;
  return (safe * 0.35).clamp(10.0, 14.0);
}

double homeFabBottomOffset(BuildContext context) {
  return kHomeTabBarHeight +
      homeTabBarBottomInset(context) +
      kHomeFabGapSobreNav;
}

double homeCarteleraScrollBottomPadding(BuildContext context) {
  return homeFabBottomOffset(context) + kHomeFabPillHeight + 12;
}

/// Padding para que un CTA de detalle (Ver Evento / Hot) quede sobre navbar + safe area.
double paddingBottomDetalleSobreNav(BuildContext context) {
  return kHomeTabBarHeight + homeTabBarBottomInset(context) + 28;
}
