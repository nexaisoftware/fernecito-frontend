/// Estado en memoria del chat IA (sobrevive al cerrar el sheet; se limpia al
/// recargar la app o al tocar «Nueva consulta»).
library;

import 'servicio_busqueda_ia.dart';

enum RolMensajeIa { usuario, asistente, escribiendo }

class MensajeChatIa {
  MensajeChatIa({
    required this.rol,
    required this.texto,
    this.recomendados = const [],
    this.esError = false,
  });

  final RolMensajeIa rol;
  final String texto;
  final List<RecomendacionIa> recomendados;
  final bool esError;
}

class EstadoBusquedaIaCache {
  EstadoBusquedaIaCache._();
  static final instancia = EstadoBusquedaIaCache._();

  static const maxSeguimientos = 5;

  final List<MensajeChatIa> mensajes = [];
  int seguimientosUsados = 0;
  String? nombreUsuario;

  bool get puedeSeguir => seguimientosUsados < maxSeguimientos;

  int get seguimientosRestantes =>
      (maxSeguimientos - seguimientosUsados).clamp(0, maxSeguimientos);

  void resetConversacion() {
    mensajes.clear();
    seguimientosUsados = 0;
  }

  void agregarUsuario(String texto) {
    mensajes.add(MensajeChatIa(rol: RolMensajeIa.usuario, texto: texto));
  }

  void agregarEscribiendo() {
    mensajes.removeWhere((m) => m.rol == RolMensajeIa.escribiendo);
    mensajes.add(MensajeChatIa(rol: RolMensajeIa.escribiendo, texto: ''));
  }

  void quitarEscribiendo() {
    mensajes.removeWhere((m) => m.rol == RolMensajeIa.escribiendo);
  }

  void agregarAsistente({
    required String texto,
    List<RecomendacionIa> recomendados = const [],
    bool esError = false,
  }) {
    quitarEscribiendo();
    mensajes.add(
      MensajeChatIa(
        rol: RolMensajeIa.asistente,
        texto: texto,
        recomendados: recomendados,
        esError: esError,
      ),
    );
  }

  /// Contexto compacto para la edge (follow-up).
  List<Map<String, dynamic>> historialParaEdge() {
    final out = <Map<String, dynamic>>[];
    for (final m in mensajes) {
      if (m.rol == RolMensajeIa.escribiendo) continue;
      if (m.rol == RolMensajeIa.usuario) {
        out.add({'rol': 'user', 'texto': m.texto});
      } else {
        out.add({
          'rol': 'assistant',
          'texto': m.texto,
          'ids': m.recomendados
              .map((r) => {'tipo': r.tipo, 'id': r.id, 'titulo': r.titulo})
              .toList(),
        });
      }
    }
    return out;
  }
}
