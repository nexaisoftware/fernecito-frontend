/// Datos geográficos compartidos para Fernecito MVP.
///
/// 🔁 SYNC: archivo espejo en `frontend_locales/lib/core/ubicaciones_data.dart`.
/// Si modificás esta lista, actualizá el otro proyecto. Mantener orden y nombres exactos
/// (impactan filtros de cartelera, perfiles de locales y consultas de eventos por ciudad).
library;

class UbicacionesData {
  UbicacionesData._();

  /// Provincia única del MVP. Se amplía cuando lanzamos en otras provincias.
  static const String provinciaPorDefecto = 'Córdoba';

  /// Lista de provincias soportadas (single source of truth para dropdowns).
  static const List<String> provincias = <String>[
    'Córdoba',
  ];

  /// Mapa provincia -> ciudades soportadas.
  /// Para una provincia nueva, agregar entrada acá y a `provincias`.
  static const Map<String, List<String>> ciudadesPorProvincia =
      <String, List<String>>{
    'Córdoba': <String>[
      'Córdoba capital',
      'Alta Gracia',
      'Bell Ville',
      'Bialet Massé',
      'Capilla del Monte',
      'Colonia Caroya',
      'Cosquín',
      'Embalse',
      'Hernando',
      'Jesús María',
      'La Calera',
      'La Falda',
      'Malagueño',
      'Marcos Juárez',
      'Mendiolaza',
      'Mina Clavero',
      'Nono',
      'Río Ceballos',
      'Río Cuarto',
      'Río Tercero',
      'Saldán',
      'San Francisco',
      'Santa María de Punilla',
      'Unquillo',
      'Villa Allende',
      'Villa Carlos Paz',
      'Villa Cura Brochero',
      'Villa María',
      'Villa Nueva',
    ],
  };

  /// Devuelve las ciudades para una provincia (o lista vacía si no existe).
  static List<String> ciudadesDe(String provincia) =>
      ciudadesPorProvincia[provincia] ?? const <String>[];

  /// Conjunto plano de TODAS las ciudades soportadas (para validaciones).
  static Set<String> get todasLasCiudades => <String>{
        for (final lista in ciudadesPorProvincia.values) ...lista,
      };

  /// Filtro por defecto al abrir la cartelera (capital de la provincia default).
  static String get ciudadPorDefecto =>
      ciudadesDe(provinciaPorDefecto).first;
}
