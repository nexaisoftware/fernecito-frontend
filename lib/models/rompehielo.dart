/// Estado de un rompehielo (ping-pong) entre dos participantes.
library;

enum RompehieloAccion { iniciar, responder, replicar, esperar, ignorado }

enum RompehieloOrigen { perfil, pool, explorar }

class RompehieloEstado {
  final bool existe;
  final String? id;
  final String? miLado;
  final String? turno;
  final bool turnoEsMio;
  final String? fase;
  final String? mensajeMio;
  final String? mensajeOtro;
  final bool puedeIniciar;
  final bool puedeActuar;
  final bool ignorado;
  final bool ignoradoPorMi;
  final RompehieloAccion accionSugerida;
  final String jerarquia;
  final RompehieloOrigen? origen;
  final String? idEvento;
  final String? nombreEvento;
  final String? ciudadSnapshot;
  final bool yoInicie;
  final String? badgeContexto;
  final String? nombreOtro;
  final String otroTipo;
  final String otroId;
  final String? ladoATipo;
  final String? ladoAId;
  final String? ladoBTipo;
  final String? ladoBId;

  const RompehieloEstado({
    required this.existe,
    this.id,
    this.miLado,
    this.turno,
    this.turnoEsMio = false,
    this.fase,
    this.mensajeMio,
    this.mensajeOtro,
    this.puedeIniciar = false,
    this.puedeActuar = false,
    this.ignorado = false,
    this.ignoradoPorMi = false,
    this.accionSugerida = RompehieloAccion.iniciar,
    this.jerarquia = 'alta',
    this.origen,
    this.idEvento,
    this.nombreEvento,
    this.ciudadSnapshot,
    this.yoInicie = false,
    this.badgeContexto,
    this.nombreOtro,
    required this.otroTipo,
    required this.otroId,
    this.ladoATipo,
    this.ladoAId,
    this.ladoBTipo,
    this.ladoBId,
  });

  /// Squad con el que participo en esta fila (`null` = yo como usuario).
  String? get idGrupoActorMio {
    if (miLado == 'a' && ladoATipo == 'squad') return ladoAId;
    if (miLado == 'b' && ladoBTipo == 'squad') return ladoBId;
    return null;
  }

  bool get jerarquiaAlta => jerarquia == 'alta';
  bool get esEmisor => existe && mensajeMio != null && mensajeMio!.isNotEmpty;
  bool get debeResponder =>
      accionSugerida == RompehieloAccion.responder && puedeActuar;
  bool get debeReplicar =>
      accionSugerida == RompehieloAccion.replicar && puedeActuar;

  /// Puedo ignorar: la conversación existe, hay algo del otro lado y todavía
  /// no fue ignorada. (Botón chico "Ignorar" cuando me llega y no quiero seguir.)
  bool get puedeIgnorar =>
      existe && !ignorado && miLado != null && (mensajeOtro?.isNotEmpty ?? false);

  factory RompehieloEstado.vacio({
    required String otroTipo,
    required String otroId,
    String? nombreOtro,
  }) {
    return RompehieloEstado(
      existe: false,
      puedeIniciar: true,
      puedeActuar: true,
      accionSugerida: RompehieloAccion.iniciar,
      jerarquia: 'alta',
      turnoEsMio: true,
      nombreOtro: nombreOtro,
      otroTipo: otroTipo,
      otroId: otroId,
    );
  }

  factory RompehieloEstado.fromMap(Map<String, dynamic> m) {
    final accionRaw = m['accion_sugerida'] as String? ?? 'iniciar';
    RompehieloAccion accion;
    switch (accionRaw) {
      case 'responder':
        accion = RompehieloAccion.responder;
        break;
      case 'replicar':
        accion = RompehieloAccion.replicar;
        break;
      case 'esperar':
        accion = RompehieloAccion.esperar;
        break;
      case 'ignorado':
        accion = RompehieloAccion.ignorado;
        break;
      default:
        accion = RompehieloAccion.iniciar;
    }

    RompehieloOrigen? origen;
    final o = m['origen'] as String?;
    if (o == 'pool') {
      origen = RompehieloOrigen.pool;
    } else if (o == 'explorar') {
      origen = RompehieloOrigen.explorar;
    } else if (o == 'perfil') {
      origen = RompehieloOrigen.perfil;
    }

    return RompehieloEstado(
      existe: m['existe'] == true,
      id: m['id']?.toString(),
      miLado: m['mi_lado'] as String?,
      turno: m['turno'] as String?,
      turnoEsMio: m['turno_es_mio'] == true,
      fase: m['fase'] as String?,
      mensajeMio: m['mensaje_mio'] as String?,
      mensajeOtro: m['mensaje_otro'] as String?,
      puedeIniciar: m['puede_iniciar'] == true,
      puedeActuar: m['puede_actuar'] == true,
      ignorado: m['ignorado'] == true,
      ignoradoPorMi: m['ignorado_por_mi'] == true,
      accionSugerida: accion,
      jerarquia: m['jerarquia'] as String? ?? 'alta',
      origen: origen,
      idEvento: m['id_evento']?.toString(),
      nombreEvento: m['nombre_evento'] as String?,
      ciudadSnapshot: m['ciudad_snapshot'] as String?,
      yoInicie: m['yo_inicie'] == true,
      badgeContexto: m['badge_contexto'] as String?,
      nombreOtro: m['nombre_otro'] as String?,
      otroTipo: m['otro_tipo'] as String? ?? 'usuario',
      otroId: m['otro_id']?.toString() ?? '',
      ladoATipo: m['lado_a_tipo'] as String?,
      ladoAId: m['lado_a_id']?.toString(),
      ladoBTipo: m['lado_b_tipo'] as String?,
      ladoBId: m['lado_b_id']?.toString(),
    );
  }
}
