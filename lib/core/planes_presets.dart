library;

class PlanFondoPreset {
  const PlanFondoPreset({
    required this.id,
    required this.nombre,
    required this.asset,
    required this.emoji,
  });

  final String id;
  final String nombre;
  final String asset;
  final String emoji;
}

const fondosPlanesPreset = <PlanFondoPreset>[
  PlanFondoPreset(
    id: 'corazones',
    nombre: 'Solteros',
    emoji: '💜',
    asset: 'predeterminadas/imagenpredeterminada1.webp',
  ),
  PlanFondoPreset(
    id: 'birras',
    nombre: 'Birras',
    emoji: '🍺',
    asset: 'predeterminadas/imagenpredeterminada2.webp',
  ),
  PlanFondoPreset(
    id: 'cocktails',
    nombre: 'Tragos',
    emoji: '🍸',
    asset: 'predeterminadas/imagenpredeterminada3.webp',
  ),
  PlanFondoPreset(
    id: 'pizza',
    nombre: 'Pizza',
    emoji: '🍕',
    asset: 'predeterminadas/imagenpredeterminada4.webp',
  ),
  PlanFondoPreset(
    id: 'burger',
    nombre: 'Comida',
    emoji: '🍔',
    asset: 'predeterminadas/imagenpredeterminada5.webp',
  ),
  PlanFondoPreset(
    id: 'disco',
    nombre: 'Joda',
    emoji: '🪩',
    asset: 'predeterminadas/imagenpredeterminada6.webp',
  ),
  PlanFondoPreset(
    id: 'cafe',
    nombre: 'Café',
    emoji: '☕',
    asset: 'predeterminadas/imagenpredeterminada7.webp',
  ),
  PlanFondoPreset(
    id: 'juegos',
    nombre: 'Juegos',
    emoji: '🎲',
    asset: 'predeterminadas/imagenpredeterminada8.webp',
  ),
  PlanFondoPreset(
    id: 'picnic',
    nombre: 'Tranqui',
    emoji: '🌙',
    asset: 'predeterminadas/imagenpredeterminada9.webp',
  ),
  PlanFondoPreset(
    id: 'brindis',
    nombre: 'Brindis',
    emoji: '🥂',
    asset: 'predeterminadas/imagenpredeterminada10.webp',
  ),
];

bool esAssetPlanPreset(String? path) =>
    path != null &&
    (path.startsWith('predeterminadas/') ||
        path.startsWith('assets/imagenes/planes_presets/'));
