/// Normalización liviana para la búsqueda común de Cartelera.
/// Mantiene la misma intención que la taxonomía de la Edge Function sin usar IA.
library;

class BusquedaNatural {
  BusquedaNatural._();

  static const Map<String, List<String>> _conceptos = {
    'hamburguesa': [
      'hamburg',
      'hambur',
      'burger',
      'burguer',
      'bueger',
      'buegers',
      'bueguer',
      'bueguers',
      'burges',
      'bur ges',
      'hamburger',
      'paty',
      'patty',
      'medallon',
    ],
    'cerveza': [
      'cervez',
      'cerbesa',
      'cervesa',
      'serveza',
      'birra',
      'birrra',
      'birrita',
      'beer',
      'pinta',
      'jarra',
      'jarron',
      'chop',
      'chopp',
      'rubia',
      'negra',
      'artesanal',
      'ipa',
      'lager',
      'stout',
      'porter',
    ],
    'comida': [
      'comer',
      'comida',
      'morfar',
      'morfi',
      'gula',
      'hambre',
      'bajon',
      'cenar',
      'cena',
      'almorzar',
      'almuerzo',
      'hamburg',
      'burger',
      'pizza',
      'sandwich',
      'sanguche',
      'lomito',
      'milanesa',
      'parrilla',
    ],
    'pizza': ['pizza', 'piza', 'pitsa', 'muzza', 'muzzarella', 'mozzarella'],
    'parrilla': [
      'parrilla',
      'parrillada',
      'asado',
      'carne',
      'bife',
      'costilla',
      'vacio',
      'choripan',
      'bbq',
    ],
    'sushi': ['sushi', 'suchi', 'roll', 'nigiri', 'sashimi', 'japonesa'],
    'mexicano': ['taco', 'burrito', 'nachos', 'quesadilla', 'mexicano'],
    'joda': [
      'joda',
      'fiesta',
      'party',
      'boliche',
      'disco',
      'discoteca',
      'club',
      'salir de joda',
      'salir de pedo',
      'noche loca',
      'romperla',
      'perreo',
      'after',
      'afterparty',
      'rave',
    ],
    'salir': [
      'salir',
      'salida',
      'dar una vuelta',
      'hacer algo',
      'algun plan',
      'que pinta',
      'go out',
      'night out',
      'bar',
      'boliche',
      'fiesta',
    ],
    'baile': [
      'bailar',
      'baile',
      'dance',
      'dancing',
      'perrear',
      'perreo',
      'cachengue',
      'reggaeton',
      'regueton',
      'cumbia',
      'electronica',
      'techno',
      'house',
    ],
    'cumple': [
      'cumple',
      'cumpleanos',
      'cumple ano',
      'birthday',
      'festejar',
      'festejo',
      'celebrar',
      'celebracion',
      'aniversario',
    ],
    'tragos': [
      'trago',
      'cocktail',
      'coctel',
      'copas',
      'drinks',
      'fernet',
      'gin',
      'vodka',
      'whisky',
    ],
    'musica': [
      'musica en vivo',
      'banda',
      'recital',
      'concierto',
      'show',
      'live music',
      'live',
      'rock',
      'jazz',
      'indie',
    ],
    'pool': ['pool', 'billar', 'mesa de pool', 'mesas de pool', 'poolhouse'],
    'romantico': [
      'cita',
      'date',
      'romantico',
      'romantica',
      'pareja',
      'novia',
      'novio',
      'enamorados',
      'intimo',
      'san valentin',
    ],
    'barato': [
      'barato',
      'barata',
      'economico',
      'economica',
      'low cost',
      'accesible',
      'gasolero',
      'poca plata',
      'buen precio',
      'presupuesto',
    ],
    'promo': [
      'promo',
      'promocion',
      'descuento',
      'oferta',
      'beneficio',
      'happy hour',
      'dos por uno',
      '2x1',
      'gratis',
      'free',
    ],
  };

  static String normalizar(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9$]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _contiene(String texto, String aliasRaw) {
    final alias = normalizar(aliasRaw);
    if (alias.contains(' ')) {
      return texto.contains(alias) ||
          texto.replaceAll(' ', '').contains(alias.replaceAll(' ', ''));
    }
    if (alias.length <= 3) {
      return RegExp('(?:^| )${RegExp.escape(alias)}(?:\$| )').hasMatch(texto);
    }
    return texto.contains(alias);
  }

  static Set<String> conceptos(String raw) {
    final texto = normalizar(raw);
    return {
      for (final entry in _conceptos.entries)
        if (entry.value.any((alias) => _contiene(texto, alias))) entry.key,
    };
  }

  static bool coincide(String consulta, Iterable<Object?> campos) {
    final q = normalizar(consulta);
    if (q.isEmpty) return true;
    final texto = normalizar(campos.whereType<Object>().join(' '));
    final directa = q.length <= 3
        ? RegExp('(?:^| )${RegExp.escape(q)}(?:\$| )').hasMatch(texto)
        : texto.contains(q) ||
              texto.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
    if (directa) {
      return true;
    }
    final buscados = conceptos(q);
    if (buscados.isEmpty) return false;
    final disponibles = conceptos(texto);
    return buscados.any(disponibles.contains);
  }
}
