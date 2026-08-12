library;

/// Identificadores de sección para impresiones / alcance.
abstract final class SeccionesImpresion {
  static const top = 'top';
  static const topUltra = 'top_ultra';
  static const topUltraStories = 'top_ultra_stories';
  static const recomendadoFernecito = 'recomendado_fernecito';
  static const normal = 'normal';
  static const gratis = 'gratis';
  static const perfilLocal = 'perfil_local';
  static const clickEvento = 'click_evento';
  /// Card de local en cartelera (fotos/banner/texto IA).
  /// Misma mecánica que un flyer: entra al viewport → +1 vista en el score.
  /// No es visita a perfil (`perfil_local`).
  static const cardLocal = 'card_local';
}
