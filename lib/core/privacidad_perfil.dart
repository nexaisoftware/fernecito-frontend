library;

import '../models/social.dart';

/// Reglas de visibilidad para `perfil_publico` (false = privado).
class PrivacidadPerfil {
  PrivacidadPerfil._();

  static const String tituloPerfilPrivado = 'Usuario con perfil privado';

  static bool esPublico(Map<String, dynamic> datos) =>
      datos['perfil_publico'] == true;

  static bool esPublicoMiembro(MiembroSquad m) => m.perfilPublico;

  static bool esAmigoMap(Map<String, dynamic> datos) =>
      datos['estado_amistad'] == 'amigo' || datos['es_amigo'] == true;

  /// Contenido completo (métricas, redes, nombre real, zoom de foto).
  static bool puedeVerContenidoCompleto({
    required bool perfilPublico,
    bool esAmigo = false,
  }) =>
      perfilPublico || esAmigo;

  /// Candado en avatar: perfil privado y no sos amigo.
  static bool mostrarCandadoPrivado({
    required bool perfilPublico,
    bool esAmigo = false,
  }) =>
      !perfilPublico && !esAmigo;

  /// Candado en resultados de búsqueda: siempre si el perfil es privado.
  static bool mostrarCandadoEnBusqueda({required bool perfilPublico}) =>
      !perfilPublico;

  static String nombreEnBusqueda({
    required bool perfilPublico,
    required String nombre,
  }) =>
      mostrarCandadoEnBusqueda(perfilPublico: perfilPublico)
          ? tituloPerfilPrivado
          : nombre;

  static bool mostrarCandadoDesdeMap(Map<String, dynamic> usuario) =>
      mostrarCandadoPrivado(
        perfilPublico: esPublico(usuario),
        esAmigo: esAmigoMap(usuario),
      );

  static bool mostrarCandadoMiembroSquad(
    MiembroSquad m, {
    required Set<String> idsAmigos,
    String? miUid,
  }) {
    if (miUid != null && m.idUsuario == miUid) return false;
    return mostrarCandadoPrivado(
      perfilPublico: m.perfilPublico,
      esAmigo: idsAmigos.contains(m.idUsuario),
    );
  }

  /// Solicitud recibida de alguien con perfil privado (oculta nombre/foto en listados).
  static bool solicitudRecibidaPrivada(Map<String, dynamic> solicitud) {
    final esEnviada = solicitud['esEnviada'] as bool? ?? false;
    if (esEnviada) return false;
    return !esPublico(solicitud);
  }

  static String tituloSolicitudAmistadPrivado(String username) =>
      '¿Querés conocer a $username? Enviále una solicitud de amistad';
}
