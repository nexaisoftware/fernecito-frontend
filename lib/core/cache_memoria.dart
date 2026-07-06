/// Cache en memoria por usuario, con TTL opcional.
///
/// Uso típico:
/// - Entrar a una pantalla / tab: devolver cache si [tiene] / [fresco].
/// - Pull-to-refresh: ignorar cache (`forzarCompleto`).
library;

class CacheMemoria<T> {
  T? _data;
  String? _uid;
  DateTime? _at;

  T? get data => _data;
  DateTime? get fetchedAt => _at;
  String? get uid => _uid;

  bool tiene(String? uid) => _data != null && _uid == uid && uid != null;

  bool fresco(String? uid, Duration ttl) {
    if (!tiene(uid) || _at == null) return false;
    return DateTime.now().difference(_at!) < ttl;
  }

  void set(String? uid, T data) {
    _uid = uid;
    _data = data;
    _at = DateTime.now();
  }

  void clear() {
    _data = null;
    _uid = null;
    _at = null;
  }
}

/// Cache por clave (ej. idLocal, idEvento) acotado en tamaño.
class CachePorClave<T> {
  CachePorClave({this.maxEntradas = 40});

  final int maxEntradas;
  final Map<String, ({T data, DateTime at})> _map = {};

  bool tiene(String key) => _map.containsKey(key);

  bool fresco(String key, Duration ttl) {
    final e = _map[key];
    if (e == null) return false;
    return DateTime.now().difference(e.at) < ttl;
  }

  T? get(String key) => _map[key]?.data;

  void set(String key, T data) {
    _map[key] = (data: data, at: DateTime.now());
    if (_map.length > maxEntradas) {
      final oldest = _map.entries.reduce(
        (a, b) => a.value.at.isBefore(b.value.at) ? a : b,
      );
      _map.remove(oldest.key);
    }
  }

  void invalidate(String key) => _map.remove(key);

  void clear() => _map.clear();
}
