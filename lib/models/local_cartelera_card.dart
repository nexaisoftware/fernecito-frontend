/// Card semanal de local pre-generada para rellenar secciones de cartelera.
library;

class LocalCarteleraCard {
  const LocalCarteleraCard({
    required this.id,
    required this.localId,
    required this.ciudad,
    required this.provincia,
    required this.rankingPosition,
    required this.textoIa,
    required this.imagenesUrls,
    required this.nombreLocal,
    this.avatarUrl,
    this.ratingPromedio,
    this.cantidadResenas = 0,
    this.esPionero = false,
    this.esVerificado = false,
    this.tienePlanActivo = false,
    this.scorePerfil = 0,
  });

  final String id;
  final String localId;
  final String ciudad;
  final String provincia;
  final int rankingPosition;
  final String textoIa;
  final List<String> imagenesUrls;
  final String? avatarUrl;
  final String nombreLocal;
  final double? ratingPromedio;
  final int cantidadResenas;
  final bool esPionero;
  final bool esVerificado;
  final bool tienePlanActivo;
  final double scorePerfil;

  bool get tieneResenas => cantidadResenas > 0 && (ratingPromedio ?? 0) > 0;

  factory LocalCarteleraCard.fromMap(Map<String, dynamic> map) {
    final imgsRaw = map['imagenes_urls'];
    final imgs = <String>[];
    if (imgsRaw is List) {
      for (final item in imgsRaw) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) imgs.add(s);
      }
    }
    return LocalCarteleraCard(
      id: map['id']?.toString() ?? '',
      localId: map['local_id']?.toString() ?? '',
      ciudad: map['ciudad']?.toString() ?? '',
      provincia: map['provincia']?.toString() ?? '',
      rankingPosition: (map['ranking_position'] as num?)?.toInt() ?? 0,
      textoIa: map['texto_ia']?.toString() ?? '',
      imagenesUrls: imgs,
      avatarUrl: map['avatar_url']?.toString(),
      nombreLocal: map['nombre_local']?.toString() ?? 'Local',
      ratingPromedio: (map['rating_promedio'] as num?)?.toDouble(),
      cantidadResenas: (map['cantidad_resenas'] as num?)?.toInt() ?? 0,
      esPionero: map['es_pionero'] == true,
      esVerificado: map['es_verificado'] == true,
      tienePlanActivo: map['tiene_plan_activo'] == true,
      scorePerfil: (map['score_perfil'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Mapa para mezclar en listas de cartelera junto a eventos.
  Map<String, dynamic> toItemCartelera() {
    return {
      '_tipoContenido': 'local_cartelera',
      'id': id,
      'localId': localId,
      'ciudad': ciudad,
      'provincia': provincia,
      'textoIa': textoIa,
      'imagenesUrls': imagenesUrls,
      'avatarUrl': avatarUrl,
      'nombreLocal': nombreLocal,
      'ratingPromedio': ratingPromedio,
      'cantidadResenas': cantidadResenas,
      'esPionero': esPionero,
      'esVerificado': esVerificado,
      'tienePlanActivo': tienePlanActivo,
    };
  }

  static bool esItemLocal(Map<String, dynamic> item) =>
      item['_tipoContenido']?.toString() == 'local_cartelera';

  static LocalCarteleraCard? desdeItemCartelera(Map<String, dynamic> item) {
    if (!esItemLocal(item)) return null;
    return LocalCarteleraCard(
      id: item['id']?.toString() ?? '',
      localId: item['localId']?.toString() ?? '',
      ciudad: item['ciudad']?.toString() ?? '',
      provincia: item['provincia']?.toString() ?? '',
      rankingPosition: 0,
      textoIa: item['textoIa']?.toString() ?? '',
      imagenesUrls: (item['imagenesUrls'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      avatarUrl: item['avatarUrl']?.toString(),
      nombreLocal: item['nombreLocal']?.toString() ?? 'Local',
      ratingPromedio: (item['ratingPromedio'] as num?)?.toDouble(),
      cantidadResenas: (item['cantidadResenas'] as num?)?.toInt() ?? 0,
      esPionero: item['esPionero'] == true,
      esVerificado: item['esVerificado'] == true,
      tienePlanActivo: item['tienePlanActivo'] == true,
    );
  }
}
