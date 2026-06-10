/// Servicio singleton para acceso centralizado al cliente de Supabase.
/// 
/// Responsabilidades:
/// - Proporcionar acceso único y consistente a SupabaseClient en toda la app
/// - Exponer usuario actual autenticado de forma sencilla
/// - Patrón Singleton para evitar múltiples instancias del cliente
/// 
/// Uso:
/// ```dart
/// final supabase = ServicioSupabase();
/// final promos = await supabase.cliente.from('promos').select();
/// final usuario = supabase.usuarioActual;
/// ```
/// 
/// Backend: Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class ServicioSupabase {
  // Patrón Singleton: una única instancia en toda la app
  static final ServicioSupabase _instancia = ServicioSupabase._interno();
  factory ServicioSupabase() => _instancia;
  ServicioSupabase._interno();

  /// Cliente de Supabase para consultas a DB, Auth, Storage, etc.
  SupabaseClient get cliente => Supabase.instance.client;

  /// Usuario actual autenticado (null si no hay sesión activa)
  User? get usuarioActual => cliente.auth.currentUser;

  /// Resuelve la URL pública de un avatar de usuario.
  /// `foto_perfil_url` se guarda como path en el bucket `avatars`; si ya viene
  /// como URL absoluta se devuelve tal cual.
  String? urlAvatar(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return cliente.storage.from('avatars').getPublicUrl(path);
  }

  /// Portada de squad (`squad-banners`). Acepta path relativo o URL absoluta.
  String? urlPortadaSquad(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    return cliente.storage.from('squad-banners').getPublicUrl(pathOrUrl);
  }

  /// URL de portada con `?v=` para bust de caché (CDN + CachedNetworkImage).
  String? urlPortadaSquadDisplay(
    String? pathOrUrl, {
    String? version,
    String? fallbackSeed,
  }) {
    final base = urlPortadaSquad(pathOrUrl);
    if (base == null) return null;
    final token = () {
      final v = version?.trim();
      if (v != null && v.isNotEmpty) return v;
      final seed = fallbackSeed?.trim();
      if (seed != null && seed.isNotEmpty) return seed;
      return null;
    }();
    if (token == null) return base;
    final uri = Uri.parse(base);
    final params = Map<String, String>.from(uri.queryParameters)..['v'] = token;
    return uri.replace(queryParameters: params).toString();
  }

  /// Clave de caché alineada con [urlPortadaSquadDisplay].
  String? portadaSquadCacheKey(
    String? pathOrUrl, {
    String? version,
    String? fallbackSeed,
  }) =>
      urlPortadaSquadDisplay(
        pathOrUrl,
        version: version,
        fallbackSeed: fallbackSeed,
      );
}