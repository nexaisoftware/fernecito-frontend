/// Jerarquías de eventos de Fernecito (cartelera de usuarios).
///
/// Esta tabla es **espejo** de las jerarquías que el local puede elegir al crear
/// un evento en `frontend_locales/lib/PANTALLAS/locales_crear_evento.dart`
/// (enum `_IntencionPublicacion`). Si agregás una jerarquía nueva, sincronizá ambos lados.
///
/// El valor `slug` matchea la columna `eventos.jerarquia` en Supabase.
library;

import 'package:flutter/cupertino.dart';

/// Identidad y metadata UI de una jerarquía de evento.
class JerarquiaEvento {
  const JerarquiaEvento({
    required this.slug,
    required this.labelChip,
    required this.labelSeccion,
    required this.icono,
    required this.orden,
    required this.permiteVerMas,
  });

  /// Valor exacto guardado en `eventos.jerarquia` (postgres).
  final String slug;

  /// Texto corto para chips de filtro.
  final String labelChip;

  /// Texto del título de la sección en cartelera.
  final String labelSeccion;

  /// Icono Cupertino representativo.
  final IconData icono;

  /// Orden visual en cartelera (mayor = primero).
  final int orden;

  /// Si la sección puede tener botón "Ver más" para cargar más filas.
  /// `top` y `recomendado_fernecito` son pagas → no se les agrega más espacio.
  final bool permiteVerMas;
}

class JerarquiasData {
  JerarquiasData._();

  static const topUltra = JerarquiaEvento(
    slug: 'top_ultra',
    labelChip: 'Top Ultra 🔥',
    labelSeccion: 'Destacados de la noche',
    icono: CupertinoIcons.flame_fill,
    orden: 100,
    permiteVerMas: false,
  );

  static const top = JerarquiaEvento(
    slug: 'top',
    labelChip: 'Top ⭐',
    labelSeccion: 'Top de la cartelera',
    icono: CupertinoIcons.star_fill,
    orden: 90,
    permiteVerMas: false,
  );

  static const recomendadoFernecito = JerarquiaEvento(
    slug: 'recomendado_fernecito',
    labelChip: 'Recomendado',
    labelSeccion: 'Recomendado Fernecito',
    icono: CupertinoIcons.heart_fill,
    orden: 80,
    permiteVerMas: false,
  );

  static const normal = JerarquiaEvento(
    slug: 'normal',
    labelChip: 'Verificado',
    labelSeccion: 'Destacados en tu ciudad',
    icono: CupertinoIcons.checkmark_seal_fill,
    orden: 50,
    permiteVerMas: true,
  );

  static const gratis = JerarquiaEvento(
    slug: 'gratis',
    labelChip: 'Más eventos',
    labelSeccion: 'Más eventos',
    icono: CupertinoIcons.square_grid_2x2,
    orden: 10,
    permiteVerMas: true,
  );

  /// Todas las jerarquías ordenadas de mayor a menor.
  static const List<JerarquiaEvento> todas = <JerarquiaEvento>[
    topUltra,
    top,
    recomendadoFernecito,
    normal,
    gratis,
  ];

  /// Jerarquías que el USUARIO puede usar como filtro en la cartelera
  /// (se excluye top_ultra porque sale en stories, no en chip).
  static const List<JerarquiaEvento> filtrosUsuario = <JerarquiaEvento>[
    top,
    recomendadoFernecito,
    normal,
    gratis,
  ];

  /// Resuelve por slug; si no existe devuelve `gratis` como fallback seguro.
  static JerarquiaEvento desdeSlug(String? slug) {
    final s = (slug ?? '').toLowerCase().trim();
    for (final j in todas) {
      if (j.slug == s) return j;
    }
    return gratis;
  }
}

/// Capacidad de cards por carrusel.
///
/// Base 12; si sobran 1–3 (13–15) se quedan en la misma fila para que no
/// quede una card suelta sin scroll. A partir de 16: 12 arriba y el resto
/// abajo con la misma regla, infinito.
class CapacidadCartelera {
  CapacidadCartelera._();

  static const int porFilaBase = 12;
  static const int porFilaMax = 15;

  static const int topPorFila = porFilaBase;
  static const int recomendadoPorFila = porFilaBase;
  static const int normalPorFila = porFilaBase;

  /// Máximo de filas iniciales para `normal` antes de pedir "Ver más".
  static const int normalFilasIniciales = 2;

  static List<List<T>> partirFilas<T>(List<T> items) {
    if (items.isEmpty) return const [];
    final filas = <List<T>>[];
    var i = 0;
    while (i < items.length) {
      final restan = items.length - i;
      if (restan <= porFilaMax) {
        filas.add(items.sublist(i));
        break;
      }
      filas.add(items.sublist(i, i + porFilaBase));
      i += porFilaBase;
    }
    return filas;
  }
}

/// Filtros de tiempo disponibles en la barra Spotlight.
enum FiltroTiempo {
  todos,
  hoy,
  esteFinde, // viernes, sábado, domingo más cercanos
  estaSemana,
}

extension FiltroTiempoUI on FiltroTiempo {
  String get label {
    switch (this) {
      case FiltroTiempo.todos:
        return 'Para cuando';
      case FiltroTiempo.hoy:
        return 'Hoy';
      case FiltroTiempo.esteFinde:
        return 'Este finde';
      case FiltroTiempo.estaSemana:
        return 'Esta semana';
    }
  }
}
