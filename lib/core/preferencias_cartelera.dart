/// Ubicación global del usuario (cartelera + perfil + mapa + explorar).
/// Fuente única de verdad local. Additive: no toca backend; solo SharedPreferences.
///
/// Modelo:
/// - `inteligente` on  → se usan las ciudades del radio (`ciudadesInteligentes`),
///   resueltas por GPS. La principal es la más cercana.
/// - `inteligente` off → se usan las ciudades elegidas a mano (`ciudadesCustom`).
///   La principal es la primera que eligió el usuario.
/// - `ciudadPrincipal` = "tu ciudad": la que se muestra en el perfil y con la que
///   te ven en explorar. Siempre hay una si hay alguna ciudad activa.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenciasCartelera {
  PreferenciasCartelera._();
  static final PreferenciasCartelera instancia = PreferenciasCartelera._();

  static const _keyInteligente = 'cartelera_inteligente_activa';
  static const _keyProvinciaCustom = 'cartelera_custom_provincia';
  static const _keyCiudadesCustom = 'cartelera_custom_ciudades';
  // Nuevos (aditivos): ciudad principal + ciudades resueltas por GPS en inteligente.
  static const _keyCiudadPrincipal = 'ubicacion_ciudad_principal';
  static const _keyProvinciaPrincipal = 'ubicacion_provincia_principal';
  static const _keyCiudadesInteligentes = 'cartelera_inteligentes_ciudades';
  static const _keyProvinciaInteligente = 'cartelera_inteligente_provincia';
  static const radioKmDefault = 20.0;

  bool _inteligente = false;
  String? _provinciaCustom;
  Set<String> _ciudadesCustom = {};
  String? _ciudadPrincipal;
  String? _provinciaPrincipal;
  Set<String> _ciudadesInteligentes = {};
  String? _provinciaInteligente;
  final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  bool get inteligenteActiva => _inteligente;
  String? get provinciaCustom => _provinciaCustom;
  Set<String> get ciudadesCustom => Set<String>.unmodifiable(_ciudadesCustom);
  Set<String> get ciudadesInteligentes =>
      Set<String>.unmodifiable(_ciudadesInteligentes);

  /// Ciudades que se deben usar AHORA (según el modo activo).
  Set<String> get ciudadesActivas =>
      _inteligente ? ciudadesInteligentes : ciudadesCustom;

  /// Provincia activa según el modo.
  String? get provinciaActiva =>
      _inteligente ? _provinciaInteligente : _provinciaCustom;

  /// "Tu ciudad": la principal guardada, con fallback a la primera activa.
  String? get ciudadPrincipal {
    if (_ciudadPrincipal != null && _ciudadPrincipal!.trim().isNotEmpty) {
      return _ciudadPrincipal;
    }
    final activas = ciudadesActivas;
    return activas.isNotEmpty ? activas.first : null;
  }

  String? get provinciaPrincipal => _provinciaPrincipal ?? provinciaActiva;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _inteligente = prefs.getBool(_keyInteligente) ?? false;
      _provinciaCustom = prefs.getString(_keyProvinciaCustom);
      _ciudadesCustom = prefs.getStringList(_keyCiudadesCustom)?.toSet() ?? {};
      _ciudadPrincipal = prefs.getString(_keyCiudadPrincipal);
      _provinciaPrincipal = prefs.getString(_keyProvinciaPrincipal);
      _ciudadesInteligentes =
          prefs.getStringList(_keyCiudadesInteligentes)?.toSet() ?? {};
      _provinciaInteligente = prefs.getString(_keyProvinciaInteligente);
    } catch (_) {}
  }

  Future<void> setInteligente(bool valor) async {
    final cambio = _inteligente != valor;
    _inteligente = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyInteligente, valor);
    } catch (_) {}
    if (cambio) _notificarCambio();
  }

  /// Modo MANUAL: ciudades elegidas a mano.
  /// Regla de la principal: si la principal actual sigue en la nueva selección se
  /// mantiene; si la sacaste, toma la primera de la lista (o la única).
  /// La principal es un espejo local de `perfiles_usuarios.ciudad` (fuente de verdad).
  Future<void> setFiltroPersonalizado({
    required String provincia,
    required Set<String> ciudades,
    String? principal,
  }) async {
    _provinciaCustom = provincia;
    _ciudadesCustom = {...ciudades};
    final actual = _ciudadPrincipal;
    final ppal = (principal != null && principal.trim().isNotEmpty)
        ? principal
        : (actual != null &&
              actual.trim().isNotEmpty &&
              ciudades.contains(actual))
        ? actual
        : (ciudades.isNotEmpty ? ciudades.first : null);
    await _guardarPrincipal(ciudad: ppal, provincia: provincia);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProvinciaCustom, provincia);
      await prefs.setStringList(_keyCiudadesCustom, ciudades.toList());
    } catch (_) {}
    _notificarCambio();
  }

  /// Modo INTELIGENTE resuelto por GPS: ciudades del radio + la más cercana como
  /// principal. `principal` debe ser la ciudad más cercana calculada.
  Future<void> setInteligenteResuelto({
    required Set<String> ciudades,
    String? provincia,
    String? principal,
  }) async {
    _ciudadesInteligentes = {...ciudades};
    _provinciaInteligente = provincia;
    final ppal = (principal != null && principal.trim().isNotEmpty)
        ? principal
        : (ciudades.isNotEmpty ? ciudades.first : null);
    await _guardarPrincipal(ciudad: ppal, provincia: provincia);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCiudadesInteligentes, ciudades.toList());
      if (provincia != null) {
        await prefs.setString(_keyProvinciaInteligente, provincia);
      }
    } catch (_) {}
    _notificarCambio();
  }

  Future<void> _guardarPrincipal({String? ciudad, String? provincia}) async {
    if (ciudad == null || ciudad.trim().isEmpty) return;
    _ciudadPrincipal = ciudad;
    if (provincia != null && provincia.trim().isNotEmpty) {
      _provinciaPrincipal = provincia;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCiudadPrincipal, ciudad);
      if (_provinciaPrincipal != null) {
        await prefs.setString(_keyProvinciaPrincipal, _provinciaPrincipal!);
      }
    } catch (_) {}
  }

  void _notificarCambio() {
    cambios.value = cambios.value + 1;
  }
}
