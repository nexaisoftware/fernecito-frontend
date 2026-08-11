/// Fernecito Match — servicio de RPCs + chat realtime.
///
/// Todo pasa por RPCs SECURITY DEFINER (JWT + rate limit en backend).
/// El chat lee `match_mensajes` directo (RLS de participantes) y se
/// suscribe por Supabase Realtime; los envíos van por RPC.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class MatchCard {
  const MatchCard({
    required this.idPlan,
    required this.tipo,
    required this.nombre,
    this.idUsuario,
    this.idGrupo,
    this.username,
    this.edad,
    this.sexo,
    this.perfilPublico = false,
    this.fotoPath,
    required this.planKey,
    required this.planEtiqueta,
    required this.lugarTexto,
    required this.lugarTipo,
    required this.cuandoEtiqueta,
    this.ciudad,
    this.miembros,
    this.edadPromedio,
    this.hombres,
    this.mujeres,
    this.teRecopo = false,
    this.lugarFoto,
    this.esRecopa = false,
    this.avataresMiembros = const [],
  });

  final String idPlan;
  final String tipo; // usuario | squad
  final String? idUsuario;
  final String? idGrupo;
  final String nombre;
  final String? username;
  final int? edad;
  final String? sexo;
  final bool perfilPublico;
  final String? fotoPath;
  final String planKey;
  final String planEtiqueta;
  final String lugarTexto;
  final String lugarTipo;
  final String cuandoEtiqueta;
  final String? ciudad;
  final int? miembros;
  final int? edadPromedio;
  final int? hombres;
  final int? mujeres;

  /// True si el dueño de esta card ya te dio "Me re pinta" 🥂
  final bool teRecopo;

  /// Foto del local del plan (solo cuando lugar_tipo == 'local').
  final String? lugarFoto;

  /// En pendientes: el interés recibido fue un "me re pinta".
  final bool esRecopa;

  /// Paths de fotos de miembros (squad), para stack 3+n en listas.
  final List<String> avataresMiembros;

  bool get esSquad => tipo == 'squad';
  String? get fotoUrl => ServicioSupabase().urlAvatar(fotoPath);
  String? get lugarFotoUrl => ServicioSupabase().urlAvatar(lugarFoto);

  /// URLs listas para [StackAvataresSquad].
  List<String> get avataresMiembrosUrls => avataresMiembros
      .map((p) => ServicioSupabase().urlAvatar(p))
      .whereType<String>()
      .where((u) => u.trim().isNotEmpty)
      .toList();

  /// Total de miembros para el badge +n (fallback a avatares disponibles).
  int get miembrosParaStack => miembros ?? avataresMiembrosUrls.length;

  factory MatchCard.fromMap(Map<String, dynamic> m) {
    int? n(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    final generos = m['generos'] is Map
        ? Map<String, dynamic>.from(m['generos'] as Map)
        : const <String, dynamic>{};
    final avatarsRaw = m['avatares_miembros'];
    final avatares = avatarsRaw is List
        ? avatarsRaw
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    return MatchCard(
      idPlan: m['id_plan']?.toString() ?? '',
      tipo: m['tipo']?.toString() ?? 'usuario',
      idUsuario: m['id_usuario']?.toString(),
      idGrupo: m['id_grupo']?.toString(),
      nombre: (m['nombre']?.toString().trim().isNotEmpty ?? false)
          ? m['nombre'].toString().trim()
          : 'Alguien',
      username: m['username']?.toString(),
      edad: n(m['edad']),
      sexo: m['sexo']?.toString(),
      perfilPublico: m['perfil_publico'] == true,
      fotoPath: m['foto_perfil_url']?.toString(),
      planKey: m['plan_key']?.toString() ?? '',
      planEtiqueta: m['plan_etiqueta']?.toString() ?? '',
      lugarTexto: m['lugar_texto']?.toString() ?? '',
      lugarTipo: m['lugar_tipo']?.toString() ?? 'custom',
      cuandoEtiqueta: m['cuando_etiqueta']?.toString() ?? '',
      ciudad: m['ciudad']?.toString(),
      miembros: n(m['miembros']),
      edadPromedio: n(m['edad_promedio']),
      hombres: n(generos['hombres']),
      mujeres: n(generos['mujeres']),
      teRecopo: m['te_recopo'] == true,
      lugarFoto: m['lugar_foto']?.toString(),
      esRecopa: m['es_recopa'] == true,
      avataresMiembros: avatares,
    );
  }
}

class MatchItem {
  const MatchItem({
    required this.idMatch,
    required this.tipo,
    required this.otro,
    this.planPrincipal,
    this.miPlan,
    this.ultimoMensaje,
    this.ultimoMensajeAutor,
    this.ultimoMensajeFecha,
    this.otroTeRecopo = false,
    this.sinChat = true,
    this.noLeidos = 0,
  });

  final String idMatch;
  final String tipo;
  final MatchCard otro;

  /// El otro te dio "Me re pinta" 🥂 → miniatura con borde azul.
  final bool otroTeRecopo;

  /// Sin mensajes todavía.
  final bool sinChat;

  /// Mensajes del otro sin leer.
  final int noLeidos;

  /// El plan sobre el que se dio el match (el que recibió el "me interesa"
  /// que lo completó). El chat muestra este: "Match con X · Plan en Lugar".
  final MatchCard? planPrincipal;
  final MatchCard? miPlan;
  final String? ultimoMensaje;
  final String? ultimoMensajeAutor;
  final DateTime? ultimoMensajeFecha;

  /// "Merienda tranqui en Patio Güemes"
  String get planResumen {
    final p = planPrincipal ?? miPlan ?? otro;
    return '${p.planEtiqueta} en ${p.lugarTexto}';
  }

  factory MatchItem.fromMap(Map<String, dynamic> m) {
    final ult = m['ultimo_mensaje'] is Map
        ? Map<String, dynamic>.from(m['ultimo_mensaje'] as Map)
        : null;
    return MatchItem(
      idMatch: m['id_match']?.toString() ?? '',
      tipo: m['tipo']?.toString() ?? 'usuario',
      otro: MatchCard.fromMap(
        Map<String, dynamic>.from((m['otro'] ?? const {}) as Map),
      ),
      planPrincipal: m['plan_principal'] is Map
          ? MatchCard.fromMap(
              Map<String, dynamic>.from(m['plan_principal'] as Map),
            )
          : null,
      miPlan: m['mi_plan'] is Map
          ? MatchCard.fromMap(Map<String, dynamic>.from(m['mi_plan'] as Map))
          : null,
      ultimoMensaje: ult?['cuerpo']?.toString(),
      ultimoMensajeAutor: ult?['id_autor']?.toString(),
      ultimoMensajeFecha: DateTime.tryParse(
        ult?['creado_en']?.toString() ?? '',
      )?.toLocal(),
      otroTeRecopo: m['otro_te_recopo'] == true,
      sinChat: m['sin_chat'] == true,
      noLeidos: m['no_leidos'] is num
          ? (m['no_leidos'] as num).toInt()
          : int.tryParse(m['no_leidos']?.toString() ?? '') ?? 0,
    );
  }
}

/// Like entrante todavía no aceptado (avatar arriba en Mis matches).
class MatchPendiente {
  const MatchPendiente({
    required this.idPlanOrigen,
    required this.idPlanDestino,
    required this.otro,
    this.miPlan,
    this.planPrincipal,
    this.esRecopa = false,
    this.tipo = 'usuario',
    this.creadoEn,
  });

  final String idPlanOrigen;
  final String idPlanDestino;
  final MatchCard otro;
  final MatchCard? miPlan;
  final MatchCard? planPrincipal;
  final bool esRecopa;
  final String tipo;
  final DateTime? creadoEn;

  String get planResumen {
    final p = planPrincipal ?? miPlan;
    if (p == null) return '';
    return '${p.planEtiqueta} en ${p.lugarTexto}';
  }

  factory MatchPendiente.fromMap(Map<String, dynamic> m) => MatchPendiente(
    idPlanOrigen: m['id_plan_origen']?.toString() ?? '',
    idPlanDestino: m['id_plan_destino']?.toString() ?? '',
    otro: MatchCard.fromMap(
      Map<String, dynamic>.from((m['otro'] ?? const {}) as Map),
    ),
    miPlan: m['mi_plan'] is Map
        ? MatchCard.fromMap(Map<String, dynamic>.from(m['mi_plan'] as Map))
        : null,
    planPrincipal: m['plan_principal'] is Map
        ? MatchCard.fromMap(
            Map<String, dynamic>.from(m['plan_principal'] as Map),
          )
        : null,
    esRecopa: m['es_recopa'] == true || m['decision']?.toString() == 'recopa',
    tipo: m['tipo']?.toString() ?? 'usuario',
    creadoEn: DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal(),
  );
}

class MatchMensaje {
  const MatchMensaje({
    required this.id,
    required this.idAutor,
    required this.cuerpo,
    required this.creadoEn,
  });

  final int id;
  final String idAutor;
  final String cuerpo;
  final DateTime creadoEn;

  factory MatchMensaje.fromMap(Map<String, dynamic> m) => MatchMensaje(
    id: m['id'] is num
        ? (m['id'] as num).toInt()
        : int.tryParse(m['id']?.toString() ?? '') ?? 0,
    idAutor: m['id_autor']?.toString() ?? '',
    cuerpo: m['cuerpo']?.toString() ?? '',
    creadoEn:
        DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

class ServicioMatch {
  SupabaseClient get _c => ServicioSupabase().cliente;
  String? get miUid => ServicioSupabase().usuarioActual?.id;

  /// Estado de mi plan activo (para saber si mostrar el sheet obligatorio).
  Future<Map<String, dynamic>> miEstado({
    required String tipo,
    String? idGrupo,
  }) async {
    final res = await _c.rpc(
      'match_mi_estado',
      params: {'p_tipo': tipo, if (idGrupo != null) 'p_id_grupo': idGrupo},
    );
    return res is Map ? Map<String, dynamic>.from(res) : const {};
  }

  /// Configura (o reemplaza) el plan activo. Devuelve true si quedó activo.
  Future<bool> configurar({
    required String tipo,
    String? idGrupo,
    required String planKey,
    required String lugarTipo,
    required String cuando,
    String interesGenero = 'todos',
    String? idLocal,
    String? idEvento,
    String? lugarTexto,
    int? edadMin,
    int? edadMax,
    int? miembrosMin,
    int? miembrosMax,
    String? sexo,
  }) async {
    try {
      final res = await _c.rpc(
        'match_configurar',
        params: {
          'p_tipo': tipo,
          'p_plan_key': planKey,
          'p_lugar_tipo': lugarTipo,
          'p_cuando': cuando,
          if (idGrupo != null) 'p_id_grupo': idGrupo,
          'p_interes_genero': interesGenero,
          if (idLocal != null) 'p_id_local': idLocal,
          if (idEvento != null) 'p_id_evento': idEvento,
          if (lugarTexto != null) 'p_lugar_texto': lugarTexto,
          if (edadMin != null) 'p_edad_min': edadMin,
          if (edadMax != null) 'p_edad_max': edadMax,
          if (miembrosMin != null) 'p_miembros_min': miembrosMin,
          if (miembrosMax != null) 'p_miembros_max': miembrosMax,
          if (sexo != null) 'p_sexo': sexo,
        },
      );
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('⚠️ match_configurar: $e');
      rethrow;
    }
  }

  /// Vistazo al mazo SIN plan propio (solo lectura). Requiere perfil público
  /// y foto: sirve para que el usuario nuevo vea de qué se trata antes de
  /// armar su plan.
  Future<List<MatchCard>> feedPreview({List<String>? ciudades}) async {
    try {
      final res = await _c.rpc(
        'match_feed_preview',
        params: {
          if (ciudades != null && ciudades.isNotEmpty) 'p_ciudades': ciudades,
          'p_limite': 20,
        },
      );
      if (res is! List) return const [];
      return res
          .map((e) => MatchCard.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.idPlan.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ match_feed_preview: $e');
      return const [];
    }
  }

  /// El mazo de cards para deslizar. [ciudades] = las ciudades activas del
  /// selector global de ubicación (cartelera/explorar). Con lista no vacía
  /// la ciudad es excluyente; si va vacía el backend usa la ciudad del plan.
  Future<List<MatchCard>> feed({
    required String tipo,
    String? idGrupo,
    List<String>? ciudades,

    /// Planes que el cliente ya tiene en pantalla: la próxima tanda sigue
    /// desde ahí, sin repetir ni saltear.
    List<String>? excluir,
    int limite = 30,
  }) async {
    final res = await _c.rpc(
      'match_feed',
      params: {
        'p_tipo': tipo,
        if (idGrupo != null) 'p_id_grupo': idGrupo,
        'p_limite': limite,
        if (ciudades != null && ciudades.isNotEmpty) 'p_ciudades': ciudades,
        if (excluir != null && excluir.isNotEmpty) 'p_excluir': excluir,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => MatchCard.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.idPlan.isNotEmpty)
        .toList();
  }

  /// Swipe: decision = 'interesa' | 'paso' | 'recopa'.
  /// Ya no crea match automático: el dueño del plan acepta desde pendientes.
  /// Sin plan: hasta 3 likes (interesa+recopa) / 24h → `necesita_plan`.
  /// Con plan: 100 interesa / día; 'recopa' tope 2 / día (`rate_limit_exceeded`).
  Future<String?> swipe({
    required String idPlanDestino,
    required String decision,
    String? idGrupo,
  }) async {
    final res = await _c.rpc(
      'match_swipe',
      params: {
        'p_id_plan_destino': idPlanDestino,
        'p_decision': decision,
        if (idGrupo != null) 'p_id_grupo': idGrupo,
      },
    );
    // Compat: si el backend viejo aún devolviera match, lo respetamos.
    if (res is Map && res['match'] == true) {
      return res['id_match']?.toString();
    }
    return null;
  }

  /// Likes entrantes todavía no aceptados (avatars arriba).
  Future<List<MatchPendiente>> pendientes() async {
    try {
      final res = await _c.rpc('match_pendientes');
      if (res is! List) return const [];
      return res
          .map(
            (e) => MatchPendiente.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .where((p) => p.idPlanOrigen.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ match_pendientes: $e');
      return const [];
    }
  }

  /// Acepta un like entrante → crea el match. Devuelve id_match o null.
  Future<String?> aceptarInteres(String idPlanOrigen) async {
    try {
      final res = await _c.rpc(
        'match_aceptar_interes',
        params: {'p_id_plan_origen': idPlanOrigen},
      );
      if (res is Map && res['match'] == true) {
        return res['id_match']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ match_aceptar_interes: $e');
      rethrow;
    }
  }

  Future<List<MatchItem>> misMatches() async {
    try {
      final res = await _c.rpc('match_mis_matches');
      if (res is! List) return const [];
      return res
          .map((e) => MatchItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.idMatch.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ match_mis_matches: $e');
      return const [];
    }
  }

  /// Envía y devuelve el id real que quedó en la DB (para reconciliar la
  /// burbuja optimista y no duplicarla cuando llega por realtime).
  Future<int?> enviarMensaje(String idMatch, String cuerpo) async {
    final res = await _c.rpc(
      'match_enviar_mensaje',
      params: {'p_id_match': idMatch, 'p_cuerpo': cuerpo},
    );
    if (res is Map && res['id'] != null) {
      final id = res['id'];
      return id is num ? id.toInt() : int.tryParse(id.toString());
    }
    return null;
  }

  /// Marca el chat como leído (al abrirlo) para el indicador de no leídos.
  Future<void> marcarLeido(String idMatch) async {
    try {
      await _c.rpc('match_marcar_leido', params: {'p_id_match': idMatch});
    } catch (e) {
      debugPrint('⚠️ match_marcar_leido: $e');
    }
  }

  /// Histórico del chat (RLS: solo participantes).
  Future<List<MatchMensaje>> historial(String idMatch) async {
    final rows = await _c
        .from('match_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_match', idMatch)
        .order('id', ascending: true)
        .limit(300);
    return (rows as List)
        .map((e) => MatchMensaje.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Suscripción realtime a mensajes nuevos del match.
  RealtimeChannel suscribirMensajes(
    String idMatch,
    void Function(MatchMensaje) onMensaje,
  ) {
    final canal = _c
        .channel('match_chat_$idMatch')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'match_mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_match',
            value: idMatch,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            onMensaje(MatchMensaje.fromMap(Map<String, dynamic>.from(data)));
          },
        )
        .subscribe();
    return canal;
  }

  Future<void> cerrarCanal(RealtimeChannel canal) async {
    await _c.removeChannel(canal);
  }

  /// Filtros que ORDENAN el mazo (género/edad). Se aplican al instante: no
  /// tocan el plan ni esperan confirmación.
  Future<bool> setFiltros({
    String? interesGenero,
    int? edadMin,
    int? edadMax,
    String tipo = 'usuario',
    String? idGrupo,
  }) async {
    try {
      final res = await _c.rpc(
        'match_set_filtros',
        params: {
          if (interesGenero != null) 'p_interes_genero': interesGenero,
          'p_edad_min': edadMin,
          'p_edad_max': edadMax,
          'p_tipo': tipo,
          if (idGrupo != null) 'p_id_grupo': idGrupo,
        },
      );
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('⚠️ match_set_filtros: $e');
      return false;
    }
  }

  /// Enciende/apaga la visibilidad en las cards (sin borrar el plan).
  Future<bool> setActivo({
    required bool activo,
    String tipo = 'usuario',
    String? idGrupo,
  }) async {
    try {
      final res = await _c.rpc(
        'match_set_activo',
        params: {
          'p_activo': activo,
          'p_tipo': tipo,
          if (idGrupo != null) 'p_id_grupo': idGrupo,
        },
      );
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('⚠️ match_set_activo: $e');
      return false;
    }
  }

  /// "Volver a revisar": borra mis swipes de "paso" → esas cards reaparecen.
  Future<int> reciclarPasados({required String tipo, String? idGrupo}) async {
    try {
      final res = await _c.rpc(
        'match_reciclar_pasados',
        params: {'p_tipo': tipo, if (idGrupo != null) 'p_id_grupo': idGrupo},
      );
      return res is Map ? (res['reciclados'] as num?)?.toInt() ?? 0 : 0;
    } catch (e) {
      debugPrint('⚠️ match_reciclar_pasados: $e');
      return 0;
    }
  }

  /// Cancela un match: borra el chat y el match, pero pueden volver a
  /// cruzarse en las cards (no es un bloqueo).
  Future<bool> cancelarMatch(String idMatch) async {
    try {
      final res = await _c.rpc(
        'match_cancelar',
        params: {'p_id_match': idMatch},
      );
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('⚠️ match_cancelar: $e');
      return false;
    }
  }

  Future<bool> bloquear({String? idUsuario, String? idGrupo}) async {
    try {
      final res = await _c.rpc(
        'match_bloquear',
        params: {
          'p_tipo': idUsuario != null ? 'usuario' : 'squad',
          if (idUsuario != null) 'p_id_usuario': idUsuario,
          if (idGrupo != null) 'p_id_grupo': idGrupo,
        },
      );
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('⚠️ match_bloquear: $e');
      return false;
    }
  }

  /// Búsqueda liviana de locales adheridos para el picker de lugar.
  Future<List<Map<String, dynamic>>> buscarLocales(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _c
        .from('perfiles_locales')
        .select('id, nombre_local, ciudad, foto_perfil_url')
        .ilike('nombre_local', '%$q%')
        .eq('estado_cuenta', 'activa')
        .limit(12);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Búsqueda liviana de eventos vigentes para el picker de lugar.
  Future<List<Map<String, dynamic>>> buscarEventos(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _c
        .from('eventos')
        .select('id_evento, titulo_evento, ciudad_evento')
        .ilike('titulo_evento', '%$q%')
        .eq('estado_publicacion', 'publicado')
        .gte('fecha_fin', DateTime.now().toUtc().toIso8601String())
        .limit(12);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
