/// Detección y copy de Hot Se Sale / promos "solo cupón QR".
///
/// El schema de `promociones` puede traer columnas nuevas (`tipo_promo`,
/// `requiere_asistencia`, `url_flyer`) o no. Se leen con fallbacks para no
/// romper si falta alguna.
library;

const kTipoPromoHotSeSale = 'hot_se_sale';
const kAssetFlyerMarcaDefault = 'assets/imagenes/logoiconapp.png';

const kEstadosTokenPromoUsuario = <String>[
  'activo',
  'canjeado',
  'pendiente',
  'reservada',
  'reservado',
];

bool _truthy(dynamic value) {
  if (value == true) return true;
  if (value is num) return value == 1;
  final s = value?.toString().toLowerCase().trim() ?? '';
  return s == 'true' || s == '1' || s == 't' || s == 'yes';
}

String _campoTexto(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return '';
  for (final key in keys) {
    final v = row[key]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

bool _textoEsHot(String raw) {
  final s = raw.toLowerCase().trim();
  if (s.isEmpty) return false;
  return s == kTipoPromoHotSeSale ||
      s == 'tipo_promo_hot_se_sale' ||
      s.contains('hot_se_sale') ||
      s.contains('hotsesale') ||
      s == 'hot' ||
      s.startsWith('hot_');
}

/// Promo o evento marcado como Hot Se Sale.
bool esPromoHot(
  Map<String, dynamic> promo, {
  Map<String, dynamic>? evento,
}) {
  for (final flag in [
    promo['es_hot_se_sale'],
    promo['hot_se_sale'],
    promo['es_hot'],
    evento?['es_hot_se_sale'],
    evento?['hot_se_sale'],
  ]) {
    if (_truthy(flag)) return true;
  }

  final textos = <String>[
    _campoTexto(promo, [
      'tipo_promo',
      'tipo_promocion',
      'tipo_promo_hot',
      'categoria_promo',
      'categoria',
      'modo_uso',
    ]),
    _campoTexto(evento, ['tipo_evento', 'modo_evento', 'tipo_promo']),
  ];
  for (final t in textos) {
    if (_textoEsHot(t)) return true;
  }
  return false;
}

/// Hot (y "solo cupón") no exige lista aceptada, salvo que el row lo pida.
bool requiereAsistenciaPromo(
  Map<String, dynamic> promo, {
  Map<String, dynamic>? evento,
}) {
  final hot = esPromoHot(promo, evento: evento);
  if (promo.containsKey('requiere_asistencia')) {
    return _truthy(promo['requiere_asistencia']);
  }
  if (evento != null && evento.containsKey('requiere_asistencia')) {
    return _truthy(evento['requiere_asistencia']);
  }
  return !hot;
}

bool listaPermiteObtenerPromos(String? estadoToken) {
  final e = estadoToken?.trim().toLowerCase() ?? '';
  return e == 'aceptada' || e == 'canjeada';
}

bool puedeObtenerEstaPromo({
  required Map<String, dynamic> promo,
  String? estadoLista,
  Map<String, dynamic>? evento,
}) {
  if (!requiereAsistenciaPromo(promo, evento: evento)) return true;
  return listaPermiteObtenerPromos(estadoLista);
}

String tituloVisiblePromo(
  Map<String, dynamic> promo, {
  Map<String, dynamic>? evento,
}) {
  final titulo = _campoTexto(promo, [
    'titulo_promocion',
    'titulo_promo',
    'titulo',
    'nombre_promocion',
  ]);
  if (titulo.isNotEmpty) return titulo;
  final eventoTitulo = _campoTexto(evento ?? _eventoEmbedido(promo), [
    'titulo_evento',
    'titulo',
    'nombre_evento',
  ]);
  if (eventoTitulo.isNotEmpty) return eventoTitulo;
  return 'Promo';
}

String etiquetaTipoPromo(Map<String, dynamic> promo) {
  final tipo = _campoTexto(promo, [
    'tipo_promo',
    'tipo_promocion',
    'categoria_promo',
    'categoria',
  ]);
  if (tipo.isNotEmpty && !_textoEsHot(tipo)) return tipo;
  final titulo = _campoTexto(promo, [
    'titulo_promocion',
    'titulo_promo',
    'titulo',
  ]);
  final chipTitulo = RegExp(
    r'(2\s*x\s*1|3\s*x\s*2|\d+\s*%)',
    caseSensitive: false,
  ).firstMatch(titulo);
  if (chipTitulo != null) {
    return chipTitulo.group(1)!.replaceAll(' ', '').toLowerCase();
  }
  if (_textoEsHot(tipo) || esPromoHot(promo)) return 'HOT';
  if (titulo.isEmpty) return 'HOT';
  final compacto = titulo.split(RegExp(r'\s+')).first;
  return compacto.length > 18 ? 'HOT' : compacto;
}

String urlFlyerPromo(
  Map<String, dynamic> promo, {
  Map<String, dynamic>? evento,
}) {
  final directo = _campoTexto(promo, ['url_flyer', 'flyer', 'url_imagen']);
  if (directo.isNotEmpty) return directo;
  return _campoTexto(evento ?? _eventoEmbedido(promo), [
    'url_flyer',
    'flyer',
  ]);
}

Map<String, dynamic>? _eventoEmbedido(Map<String, dynamic> promo) {
  final raw = promo['eventos'] ?? promo['evento'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

int? cuposLibresPromo(Map<String, dynamic> promo) {
  final total = _entero(promo['cupos_totales']);
  if (total == null) return null;
  final usados = _entero(promo['cupos_usados']) ?? 0;
  return total - usados;
}

int? _entero(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

bool promoVigente(Map<String, dynamic> promo) {
  final finRaw = promo['fecha_fin']?.toString();
  if (finRaw == null || finRaw.isEmpty) return true;
  try {
    final fin = DateTime.parse(finRaw).toUtc();
    return DateTime.now().toUtc().millisecondsSinceEpoch <=
        fin.millisecondsSinceEpoch;
  } catch (_) {
    return true;
  }
}

String textoVencePromo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return 'vence ${dt.day} ${meses[dt.month - 1]}';
  } catch (_) {
    return '';
  }
}

/// Normaliza el body de error de una Edge (Map o JSON en string).
Map<String, dynamic>? detallesEdgePromo(dynamic details) {
  if (details == null) return null;
  if (details is Map) return Map<String, dynamic>.from(details);
  return null;
}

String codigoEdgePromo(dynamic details) {
  final map = detallesEdgePromo(details);
  if (map == null) return '';
  return (map['code'] ?? map['error_code'] ?? '').toString().trim();
}

String mensajeEdgePromo(dynamic details) {
  if (details is Map) {
    final m = Map<String, dynamic>.from(details);
    final msg =
        m['error']?.toString() ??
        m['message']?.toString() ??
        m['mensaje']?.toString() ??
        m['detail']?.toString();
    if (msg != null && msg.trim().isNotEmpty) return msg.trim();
  }
  if (details is String && details.trim().isNotEmpty) return details.trim();
  return '';
}

bool errorPromoDuplicada(Object? details) {
  final code = codigoEdgePromo(details).toLowerCase();
  if (code.contains('already') ||
      code.contains('duplicate') ||
      code == 'already_reserved' ||
      code == 'token_exists' ||
      code == 'promo_already_claimed') {
    return true;
  }
  final s = (mensajeEdgePromo(details).isNotEmpty
          ? mensajeEdgePromo(details)
          : details?.toString() ?? '')
      .toLowerCase();
  return s.contains('ya ') ||
      s.contains('duplicate') ||
      s.contains('409') ||
      s.contains('activa') ||
      s.contains('reservad');
}

/// Mensaje de UI. Prioriza `code` de la edge cuando hay mapeo.
String mensajePromoAmigable(Object? details, int? httpStatus) {
  final combined = [
    if (details != null) details.toString(),
    if (httpStatus != null) '$httpStatus',
  ].join(' ').toLowerCase();

  if (combined.contains('socket') ||
      combined.contains('network') ||
      combined.contains('connection refused') ||
      combined.contains('timeout') ||
      combined.contains('failed host lookup') ||
      combined.contains('handshake')) {
    return 'Sin conexión o el servidor tardó demasiado. Revisá tu internet e intentá de nuevo.';
  }

  final code = codigoEdgePromo(details).toLowerCase();
  final mapped = _mensajePorCodigoEdge(code);
  if (mapped != null) return mapped;

  final msg = mensajeEdgePromo(details).toLowerCase();
  if (msg.contains('expir') ||
      msg.contains('venc') ||
      msg.contains('promo_expired') ||
      msg.contains('finaliz')) {
    return 'Esta promo ya no está disponible: la fecha de fin venció.';
  }
  if (msg.contains('promo_not_started') || msg.contains('aún no')) {
    return 'Esta promo todavía no está disponible.';
  }
  if (msg.contains('attendance') ||
      msg.contains('asistencia') ||
      msg.contains('lista')) {
    return 'Necesitás tener la lista aceptada en el local para obtener esta promo.';
  }
  if (msg.contains('cupo') || msg.contains('agot') || msg.contains('sin cupo')) {
    return 'No quedan cupos para esta promo.';
  }
  if (msg.contains('403') ||
      combined.contains('403') ||
      msg.contains('no autorizado')) {
    return 'No podés obtener esta promo con tu cuenta actual.';
  }
  if (httpStatus == 429 || combined.contains('429')) {
    return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
  }

  final readable = details is String
      ? details.replaceAll('Exception: ', '')
      : mensajeEdgePromo(details);
  if (readable.isNotEmpty) return readable;
  if (code.isNotEmpty) return 'No se pudo obtener la promo ($code).';
  return 'No pudimos obtener la promo. Intentá de nuevo en unos momentos.';
}

String? _mensajePorCodigoEdge(String code) {
  switch (code) {
    case 'invalid_jwt':
    case 'missing_authorization':
    case 'auth_refresh_failed':
      return 'Tu sesión expiró. Cerrá sesión y volvé a entrar para obtener la promo.';
    case 'promo_expired':
    case 'expired':
      return 'Esta promo ya no está disponible: la fecha de fin venció.';
    case 'promo_not_started':
      return 'Esta promo todavía no está disponible.';
    case 'attendance_required':
    case 'requires_attendance':
    case 'lista_required':
    case 'lista_no_aceptada':
      return 'Necesitás tener la lista aceptada en el local para obtener esta promo.';
    case 'no_cupos':
    case 'cupos_agotados':
    case 'sold_out':
    case 'promo_sold_out':
      return 'No quedan cupos para esta promo.';
    case 'counter_retry_conflict':
    case 'stale_cupos':
      return 'Los cupos cambiaron recién. Probá de nuevo.';
    case 'promo_not_found':
    case 'promo_inactive':
      return 'Esta promo ya no está disponible.';
    case 'rate_limit_exceeded':
      return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
    case 'already_reserved':
    case 'token_exists':
    case 'promo_already_claimed':
    case 'duplicate_token':
      return 'Ya tenés esta promo. Revisá tu QR.';
    case 'hot_promo_insert_failed':
      return 'El local no pudo publicar esta Hot Se Sale. Probá más tarde.';
    default:
      return null;
  }
}
