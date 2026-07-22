/// Tipos de evento que el local puede elegir al crear/editar un evento.
///
/// 🔁 SYNC (slugs): debe coincidir con la lista hardcodeada en
/// `frontend_locales/lib/PANTALLAS/locales_crear_evento.dart`.
/// Si agregás un tipo nuevo, sincronizá los dos lados.
///
/// Los `slug` matchean `eventos.tipo_evento` en Supabase (lowercase).
/// Los iconos son solo UI del filtro (usuarios); se pueden cambiar sin tocar slugs.
library;

import 'package:flutter/material.dart';

class TipoEvento {
  const TipoEvento({
    required this.slug,
    required this.label,
    required this.icono,
  });

  final String slug;
  final String label;
  final IconData icono;
}

class TiposEventoData {
  TiposEventoData._();

  /// Lista canónica + orden visual.
  /// Slugs invariables (producción). Labels/iconos = solo presentación.
  static const List<TipoEvento> todos = <TipoEvento>[
    TipoEvento(
      slug: 'boliche',
      label: 'Boliche',
      icono: Icons.nightlife,
    ),
    TipoEvento(
      slug: 'fiesta',
      label: 'Fiesta',
      icono: Icons.celebration,
    ),
    TipoEvento(
      slug: 'baile',
      label: 'Baile',
      icono: Icons.music_note,
    ),
    TipoEvento(
      slug: 'sunset',
      label: 'Sunset',
      icono: Icons.wb_twilight,
    ),
    TipoEvento(
      slug: 'concierto',
      label: 'Concierto',
      icono: Icons.mic,
    ),
    TipoEvento(
      slug: 'bar',
      label: 'Bar',
      icono: Icons.local_bar,
    ),
    TipoEvento(
      slug: 'gastro',
      label: 'Comer',
      icono: Icons.restaurant,
    ),
    TipoEvento(
      slug: 'cafe',
      label: 'Café',
      icono: Icons.local_cafe,
    ),
    TipoEvento(
      slug: 'evento',
      label: 'Evento',
      icono: Icons.event,
    ),
    TipoEvento(
      slug: 'otro',
      label: 'Otro',
      icono: Icons.more_horiz,
    ),
  ];

  static TipoEvento? desdeSlug(String? slug) {
    final s = (slug ?? '').toLowerCase().trim();
    if (s.isEmpty) return null;
    for (final t in todos) {
      if (t.slug == s) return t;
    }
    return null;
  }
}
