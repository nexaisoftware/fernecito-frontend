/// Tipos de evento que el local puede elegir al crear/editar un evento.
///
/// 🔁 SYNC: debe coincidir con la lista hardcodeada en
/// `frontend_locales/lib/PANTALLAS/locales_crear_evento.dart` (≈línea 1898).
/// Si agregás un tipo nuevo, sincronizá los dos lados.
///
/// El `slug` matchea la columna `eventos.tipo_evento` en Supabase (lowercase).
library;

import 'package:flutter/cupertino.dart';

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
  static const List<TipoEvento> todos = <TipoEvento>[
    TipoEvento(slug: 'boliche', label: 'Boliche', icono: CupertinoIcons.music_house_fill),
    TipoEvento(slug: 'fiesta', label: 'Fiesta', icono: CupertinoIcons.sparkles),
    TipoEvento(slug: 'baile', label: 'Baile', icono: CupertinoIcons.music_note_2),
    TipoEvento(slug: 'sunset', label: 'Sunset', icono: CupertinoIcons.sun_max_fill),
    TipoEvento(slug: 'concierto', label: 'Concierto', icono: CupertinoIcons.music_mic),
    TipoEvento(slug: 'bar', label: 'Bar', icono: CupertinoIcons.drop_fill),
    TipoEvento(slug: 'gastro', label: 'Gastro', icono: CupertinoIcons.bag_fill),
    TipoEvento(slug: 'cafe', label: 'Café', icono: CupertinoIcons.book_fill),
    TipoEvento(slug: 'evento', label: 'Evento', icono: CupertinoIcons.calendar),
    TipoEvento(slug: 'otro', label: 'Otro', icono: CupertinoIcons.ellipsis),
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
