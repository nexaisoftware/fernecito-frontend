/// Fernecito Match — "tinder de planes".
///
/// Switch Personal/Squad → plan activo obligatorio (sheet de configuración)
/// → deck de cards para deslizar → match mutuo → chat realtime.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_match.dart';
import '../core/supabase_client.dart';
import '../core/servicio_squads.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/ubicaciones_data.dart';
import '../models/social.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/stack_avatares_squad.dart';
import 'pantalla_match_chat.dart';
import 'pantalla_match_chats.dart';

const _kPlanes = [
  ('lo_que_surja', 'Lo que surja', '✨'),
  ('charla_tragos', 'Charlar y tomar algo', '🍻'),
  ('merienda', 'Merienda tranqui', '☕'),
  ('fiesta', 'Buena fiesta', '🎉'),
  ('joda_previa', 'Joda y previa', '🥃'),
  ('joda_after', 'Joda y after', '🌙'),
  ('juntada', 'Juntada', '🛋️'),
];

const _kCuando = [
  ('hoy', 'Hoy'),
  ('finde', 'El finde'),
  ('semana', 'Esta semana'),
];

/// Azul del "Me re pinta" 🥂 (súper interés, 2 por día).
const _kAzulRecopa = Color(0xFF3B82F6);

/// Overlay "¡ME RE PINTA!" que aparece 3 segundos tras el brindis.
class _OverlayRePinta extends StatelessWidget {
  const _OverlayRePinta({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.champagneGlasses,
              color: _kAzulRecopa,
              size: 74,
            ),
            const SizedBox(height: 18),
            Text(
              '¡ME RE PINTA!',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Text(
                detalle,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaFernecitoMatch extends StatefulWidget {
  const PantallaFernecitoMatch({super.key});

  @override
  State<PantallaFernecitoMatch> createState() => _PantallaFernecitoMatchState();
}

class _PantallaFernecitoMatchState extends State<PantallaFernecitoMatch> {
  final _srv = ServicioMatch();

  String _modo = 'usuario'; // usuario | squad
  SquadResumen? _squad;
  List<SquadResumen> _misSquads = const [];

  bool _cargando = true;
  bool _sinPlan = false;
  bool _errorCarga = false;
  bool _sexoCargado = true;
  int _cantMatches = 0;

  /// Plan guardado (para reabrir el sheet con lo que ya elegiste).
  Map<String, dynamic>? _planActual;

  /// Requisitos para aparecer en las cards (los informa match_mi_estado).
  bool _perfilPublico = true;
  bool _tieneFoto = true;
  bool _edadOk = true;
  bool _activo = true;
  List<MatchPendiente> _pendientes = const [];
  List<MatchCard> _mazo = [];
  Offset _arrastre = Offset.zero;
  bool _swipeando = false;

  /// Paginación del mazo: ids ya traídos y si queda universo por delante.
  final Set<String> _idsVistos = {};
  bool _hayMasCards = true;
  bool _cargandoMas = false;
  /// Activa duración en el transform (vuelo al soltar / snap al centro).
  bool _animarArrastre = false;
  static const _duracionVuelo = Duration(milliseconds: 280);

  /// Texto del overlay "¡ME RE PINTA!" (null = oculto).
  String? _rePintaDetalle;
  Timer? _timerRePinta;

  /// Descarta respuestas viejas si el usuario cambia de ciudad enseguida.
  int _genUbicacion = 0;

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(_onUbicacionGlobal);
    _cargarSquads();
    _cargarEstado();
    _cargarCantMatches();
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(_onUbicacionGlobal);
    _timerRePinta?.cancel();
    super.dispose();
  }

  /// Cartelera / perfil / pill local: siempre nueva query y mazo limpio.
  void _onUbicacionGlobal() {
    unawaited(_recargarPorUbicacion());
  }

  /// Limpia cards al toque y vuelve a pedir el feed (plan o preview).
  Future<void> _recargarPorUbicacion() async {
    final gen = ++_genUbicacion;
    setState(() {
      _cargando = true;
      _errorCarga = false;
      _mazo = [];
      _idsVistos.clear();
      _hayMasCards = false;
      _arrastre = Offset.zero;
      _swipeando = false;
    });
    await PreferenciasCartelera.instancia.cargar();
    if (!mounted || gen != _genUbicacion) return;

    if (_sinPlan) {
      // Modo mirar: re-pedir preview con ciudades nuevas (antes solo
      // actualizaba el pill y quedaban cards de la ubicación anterior).
      if (_modo == 'usuario' && _perfilPublico && _tieneFoto) {
        final ciudades =
            PreferenciasCartelera.instancia.ciudadesActivas.toList();
        final preview = await _srv.feedPreview(ciudades: ciudades);
        if (!mounted || gen != _genUbicacion) return;
        setState(() {
          _mazo = preview;
          _cargando = false;
        });
      } else if (mounted && gen == _genUbicacion) {
        setState(() => _cargando = false);
      }
      return;
    }

    await _cargarMazo(gen: gen);
  }

  Future<void> _cargarSquads() async {
    final squads = await ServicioSquads().misSquads();
    // Match en modo squad: solo admin/líder (el BE exige es_admin_grupo).
    final admin = squads
        .where(
          (s) => s.soyLider || s.miRol == 'admin' || s.miRol == 'lider',
        )
        .toList();
    if (mounted) setState(() => _misSquads = admin);
  }

  Future<void> _cargarCantMatches() async {
    final resultados = await Future.wait([
      _srv.misMatches(),
      _srv.pendientes(),
    ]);
    if (!mounted) return;
    final matches = resultados[0] as List<MatchItem>;
    final pendientes = resultados[1] as List<MatchPendiente>;
    // Badge de "Mis matches": todo (personal+squad). La tira del mazo filtra.
    setState(() => _cantMatches = matches.length + pendientes.length);
  }

  Future<void> _cargarEstado() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
      _mazo = [];
    });
    try {
      final estado = await _srv.miEstado(
        tipo: _modo,
        idGrupo: _squad?.idGrupo,
      );
      final tiene = estado['tiene_plan'] == true;
      _sexoCargado = estado['sexo_cargado'] == true;
      _perfilPublico = estado['perfil_publico'] == true;
      _tieneFoto = estado['tiene_foto'] == true;
      _edadOk = estado['edad_ok'] != false;
      _activo = estado['activo'] == true;
      _planActual = estado['plan'] is Map
          ? Map<String, dynamic>.from(estado['plan'] as Map)
          : null;
      if (!tiene) {
        setState(() => _sinPlan = true);
        // Puede MIRAR sin plan si ya tiene perfil público, foto y edad ≥16.
        if (_modo == 'usuario' &&
            _perfilPublico &&
            _tieneFoto &&
            _edadOk) {
          final preview = await _srv.feedPreview(
            ciudades: PreferenciasCartelera.instancia.ciudadesActivas.toList(),
          );
          if (!mounted) return;
          setState(() {
            _mazo = preview;
            _cargando = false;
          });
          return;
        }
        setState(() => _cargando = false);
        return;
      }
      setState(() => _sinPlan = false);
      await _cargarPendientes();
      await _cargarMazo();
    } catch (_) {
      // Error real (red, rate limit, etc.): NO resetear como si no hubiera
      // plan — mostramos estado de error con reintento.
      if (mounted) {
        setState(() {
          _errorCarga = true;
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarMazo({int? gen}) async {
    final g = gen ?? _genUbicacion;
    try {
      await PreferenciasCartelera.instancia.cargar();
      final ciudades = PreferenciasCartelera.instancia.ciudadesActivas.toList();
      final mazo = await _srv.feed(
        tipo: _modo,
        idGrupo: _squad?.idGrupo,
        ciudades: ciudades,
      );
      if (!mounted || g != _genUbicacion) return;
      setState(() {
        _mazo = mazo;
        _idsVistos
          ..clear()
          ..addAll(mazo.map((c) => c.idPlan));
        // Tanda incompleta = no hay más universo por delante.
        _hayMasCards = mazo.length >= 30;
        _cargando = false;
      });
    } catch (_) {
      // Ante error de red tras cambio de ciudad: mazo vacío, no cards viejas.
      if (mounted && g == _genUbicacion) {
        setState(() {
          _mazo = [];
          _idsVistos.clear();
          _hayMasCards = false;
          _cargando = false;
        });
      }
    }
  }

  /// Trae la siguiente tanda y la agrega al final, sin reiniciar el mazo.
  Future<void> _cargarMasCards() async {
    if (_cargandoMas || !_hayMasCards || _sinPlan) return;
    _cargandoMas = true;
    try {
      final ciudades = PreferenciasCartelera.instancia.ciudadesActivas.toList();
      final mas = await _srv.feed(
        tipo: _modo,
        idGrupo: _squad?.idGrupo,
        ciudades: ciudades,
        excluir: _idsVistos.toList(),
      );
      if (!mounted) return;
      final nuevas = mas.where((c) => !_idsVistos.contains(c.idPlan)).toList();
      setState(() {
        _mazo = [..._mazo, ...nuevas];
        _idsVistos.addAll(nuevas.map((c) => c.idPlan));
        _hayMasCards = mas.length >= 30;
      });
    } catch (_) {
      // Si falla, reintentamos en el próximo swipe.
    } finally {
      _cargandoMas = false;
    }
  }

  Future<void> _cargarPendientes() async {
    final p = await _srv.pendientes();
    if (!mounted) return;
    setState(() => _pendientes = _filtrarPendientesPorModo(p));
  }

  /// En el mazo, la tira sigue el switch Personal/Squad (Mis matches sí mezcla).
  List<MatchPendiente> _filtrarPendientesPorModo(List<MatchPendiente> todos) {
    return todos.where((p) {
      final mi = p.miPlan ?? p.planPrincipal;
      if (_modo == 'usuario') {
        return mi == null || !mi.esSquad;
      }
      final gid = _squad?.idGrupo;
      if (mi == null || !mi.esSquad) return false;
      return gid == null || mi.idGrupo == gid;
    }).toList();
  }

  /// Aviso de requisito faltante (perfil público / foto / edad) al tocar Preferencias.
  Future<bool> _chequearRequisitos() async {
    if (!_edadOk) {
      await _avisoRequisito(
        'Match desde los 16',
        'Para usar Fernecito Match necesitás tener al menos 16 años.\n\nPodés seguir explorando el resto de la app sin problema.',
      );
      return false;
    }
    if (_modo == 'usuario' && !_perfilPublico) {
      await _avisoRequisito(
        '¡Necesitás el perfil público!',
        'Para usar Fernecito Match tu perfil tiene que ser público.\n\nAndá a Mi perfil → deslizá hasta "Visibilidad en explorar" y activá tu perfil público.',
      );
      return false;
    }
    if (!_tieneFoto) {
      await _avisoRequisito(
        _modo == 'squad' ? '¡El squad necesita portada!' : '¡Necesitás una foto!',
        _modo == 'squad'
            ? 'Subí una portada al squad para que puedan reconocerlo en las cards.'
            : 'Para usar Fernecito Match necesitás una foto de perfil.\n\nAndá a Mi perfil → Editar foto y subí una.',
      );
      return false;
    }
    return true;
  }

  Future<void> _avisoRequisito(String titulo, String detalle) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(detalle, style: GoogleFonts.baloo2(height: 1.3)),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActivo(bool v) async {
    final ok = await _srv.setActivo(
      activo: v,
      tipo: _modo,
      idGrupo: _modo == 'squad' ? _squad?.idGrupo : null,
    );
    if (ok && mounted) setState(() => _activo = v);
  }

  /// Tarjeta grande del pendiente + "Matchear y chatear".
  Future<void> _abrirPendiente(MatchPendiente p) async {
    final confirmado = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'pendiente',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, _) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.9 + 0.1 * anim.value.clamp(0.0, 1.0),
          child: _TarjetaPendiente(
            card: p.otro,
            esRecopa: p.esRecopa,
            onMatchear: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      final idMatch = await _srv.aceptarInteres(p.idPlanOrigen);
      if (!mounted) return;
      if (idMatch == null || idMatch.isEmpty) {
        await _avisoRequisito(
          'No pudimos matchear',
          'Probá de nuevo en un momento.',
        );
        return;
      }
      await _cargarPendientes();
      _cargarCantMatches();
      if (!mounted) return;
      final match = MatchItem(
        idMatch: idMatch,
        tipo: p.tipo,
        otro: p.otro,
        planPrincipal: p.planPrincipal ?? p.miPlan,
        miPlan: p.miPlan,
        otroTeRecopo: p.esRecopa,
        sinChat: true,
      );
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => PantallaMatchChat(match: match)),
      );
    } catch (_) {
      if (mounted) {
        await _avisoRequisito(
          'No pudimos matchear',
          'Probá de nuevo en un momento.',
        );
      }
    }
  }

  Future<void> _elegirUbicacion() async {
    final prefs = PreferenciasCartelera.instancia;
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual:
          prefs.provinciaActiva ?? UbicacionesData.provinciaPorDefecto,
      ciudadesActuales: prefs.ciudadesActivas,
      carteleraInteligente: prefs.inteligenteActiva,
    );
    if (res == null || res.ciudades.isEmpty || !mounted) return;
    // Misma persistencia global que cartelera: set local + ciudad al perfil.
    if (res.carteleraInteligente) {
      await ServicioUbicacionGlobal.aplicarInteligente(
        ciudades: res.ciudades,
        provincia: res.provincia,
        principal: res.ciudadPrincipal,
      );
    } else {
      await ServicioUbicacionGlobal.aplicarManual(
        provincia: res.provincia,
        ciudades: res.ciudades,
        principal: res.ciudadPrincipal,
      );
    }
    if (!mounted) return;
    // aplicarManual/Inteligente dispara PreferenciasCartelera.cambios; acá
    // reforzamos para cubrir también el modo mirar (sin plan).
    await _recargarPorUbicacion();
  }

  Offset _destinoVuelo(String decision) {
    final size = MediaQuery.sizeOf(context);
    final dy = _arrastre.dy;
    final dx = _arrastre.dx;
    return switch (decision) {
      'paso' => Offset(-size.width * 1.45, dy * 0.35 - 36),
      'recopa' => Offset(dx * 0.18, -size.height * 1.05),
      _ => Offset(size.width * 1.45, dy * 0.35 - 36), // interesa
    };
  }

  Future<void> _swipe(String decision) async {
    if (_mazo.isEmpty || _swipeando) return;
    final card = _mazo.first;

    // 1) Empujón: la card activa sale por el costado/arriba.
    //    La de atrás queda en el stack y pasa a ocupar el lugar.
    setState(() {
      _swipeando = true;
      _animarArrastre = true;
      _arrastre = _destinoVuelo(decision);
    });
    await Future<void>.delayed(_duracionVuelo);
    if (!mounted) return;

    // 2) Swap instantáneo (sin animar de vuelta al centro).
    setState(() {
      _animarArrastre = false;
      _mazo = _mazo.sublist(1);
      _arrastre = Offset.zero;
    });
    // Scroll infinito: cuando quedan pocas, se pide la siguiente tanda.
    if (_mazo.length <= 5) unawaited(_cargarMasCards());
    setState(() {
      // Brindis 🥂 → overlay "¡ME RE PINTA!" que se va solo a los 3 seg.
      if (decision == 'recopa') {
        _rePintaDetalle = _sinPlan
            ? 'Probaste "me re pinta" 🥂\nArmá tu plan para que le llegue de verdad'
            : 'Le va a llegar que te re pinta su plan\n${card.planEtiqueta} en ${card.lugarTexto}';
      }
    });
    if (decision == 'recopa') {
      _timerRePinta?.cancel();
      _timerRePinta = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _rePintaDetalle = null);
      });
    }

    try {
      // El like queda pendiente del otro lado; ya no hay match automático.
      // Sin plan: preview rate-limited (3 likes/día) en el backend.
      await _srv.swipe(
        idPlanDestino: card.idPlan,
        decision: decision,
        idGrupo: _modo == 'squad' ? _squad?.idGrupo : null,
      );
      if (mounted && !_sinPlan) _cargarCantMatches();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // Cualquier fallo: devolver la card al mazo (no perder el swipe).
      void restaurarCard() {
        setState(() {
          _animarArrastre = false;
          _arrastre = Offset.zero;
          _mazo = [card, ..._mazo];
          if (decision == 'recopa') _rePintaDetalle = null;
        });
      }
      restaurarCard();

      if (msg.contains('necesita_plan')) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Armá tu plan para seguir'),
            content: const Text(
              'Ya usaste tus 3 "me pinta" / "me re pinta" de hoy en modo mirar. '
              'Creá un plan para seguir haciendo match.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) await _abrirConfiguracion();
      } else if (decision == 'recopa' && msg.contains('rate_limit')) {
        // Cartel exclusivo: solo cuando se gastaron los 2 diarios.
        await _mostrarCartelRecopaAgotada();
      } else if (decision == 'interesa' &&
          msg.contains('rate_limit') &&
          !_sinPlan) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Tope de "me pinta" por hoy'),
            content: const Text(
              'Llegaste a los 100 "me pinta" de hoy. Mañana se renueva el cupo.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (msg.contains('edad_minima_match')) {
        setState(() => _edadOk = false);
        await _avisoRequisito(
          'Match desde los 16',
          'Para usar Fernecito Match necesitás tener al menos 16 años.',
        );
      } else if (msg.contains('bloqueado') || msg.contains('no_admin')) {
        // Card ya restaurada; sin ruido extra.
      } else {
        await _avisoRequisito(
          'No se pudo registrar',
          'Revisá tu conexión e intentá de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _swipeando = false);
    }
  }

  /// Cartelito estilo app cuando se agotaron los 2 "Me re pinta" del día.
  Future<void> _mostrarCartelRecopaAgotada() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'recopa',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, _) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - t)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _kAzulRecopa.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kAzulRecopa.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kAzulRecopa.withValues(alpha: 0.18),
                            ),
                            child: const Text('🥂', style: TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Me re pinta agotado',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ya usaste tus 2 de hoy — es exclusivo.\nMañana se renuevan. Mientras, seguí con "me pinta".',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: _kAzulRecopa,
                              borderRadius: BorderRadius.circular(16),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Seguir swipando',
                                style: GoogleFonts.baloo2(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _bloquearCardActual(MatchCard card) async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          card.esSquad ? 'Squad en el mazo' : 'Persona en el mazo',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
        ),
        message: Text(
          'Si bloqueás, no se van a volver a cruzar en Match ni en Social.',
          style: GoogleFonts.baloo2(fontSize: 13),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _srv.bloquear(
      idUsuario: card.esSquad ? null : card.idUsuario,
      idGrupo: card.esSquad ? card.idGrupo : null,
    );
    if (!mounted) return;
    if (done) {
      setState(() {
        _mazo = _mazo.where((c) => c.idPlan != card.idPlan).toList();
      });
      if (_mazo.length <= 5) unawaited(_cargarMasCards());
    } else {
      await _avisoRequisito('No se pudo bloquear', 'Probá de nuevo en un momento.');
    }
  }

  Future<void> _abrirConfiguracion() async {
    // Gate: perfil público + foto antes de dejar configurar el plan.
    if (!await _chequearRequisitos()) return;
    if (!mounted) return;
    final ok = await mostrarSheetConfigMatch(
      context,
      modo: _modo,
      squad: _squad,
      pedirSexo: _modo == 'usuario' && !_sexoCargado,
      planActual: _planActual,
      // Los filtros ordenan el mazo al instante: lo recargamos al vuelo.
      onFiltrosCambiados: () {
        if (!_sinPlan) _cargarMazo();
      },
    );
    if (ok == true) {
      await _cargarEstado();
    }
  }

  Future<void> _elegirSquad() async {
    if (_misSquads.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Sin squads para Match'),
          content: const Text(
            'Para matchear como squad tenés que ser admin o líder de uno. '
            'Crealo o pedile al líder que te haga admin.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => _modo = 'usuario');
      return;
    }
    final elegido = await showCupertinoModalPopup<SquadResumen>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          '¿Con qué squad salís?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
        ),
        actions: _misSquads
            .map(
              (s) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, s),
                child: Text('${s.nombre} (${s.cantidadMiembros})'),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (elegido == null) {
      setState(() => _modo = 'usuario');
      return;
    }
    setState(() => _squad = elegido);
    await _cargarEstado();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Text(
          'Match',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_sinPlan) ...[
              _pillNavbar(
                icono: CupertinoIcons.slider_horizontal_3,
                texto: 'Filtros y planes',
                onTap: _abrirConfiguracion,
              ),
              const SizedBox(width: 8),
            ],
            _pillNavbar(
              icono: CupertinoIcons.chat_bubble_text_fill,
              texto: 'Matchs',
              destacado: true,
              badge: _cantMatches,
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const PantallaMatchChats(),
                  ),
                );
                _cargarCantMatches();
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _switchModo(),
                    const SizedBox(width: 8),
                    _pillUbicacion(),
                  ],
                ),
                if (_modo == 'squad' && _squad != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Squad: ${_squad!.nombre}',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoSecundario,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(child: _cuerpo()),
              ],
            ),
            // Overlay del brindis (3 segundos, no bloquea el deslizar después)
            if (_rePintaDetalle != null)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: 1,
                  child: _OverlayRePinta(detalle: _rePintaDetalle!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Pill compacta para la navbar (Preferencias / Matchs con badge).
  Widget _pillNavbar({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
    bool destacado = false,
    int badge = 0,
  }) {
    final color = destacado
        ? ColoresApp.principalMarca
        : ColoresApp.textoSecundario;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: ColoresApp.fondoSuperficie,
              borderRadius: BorderRadius.circular(999),
              border: destacado
                  ? Border.all(
                      color: ColoresApp.principalMarca.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: destacado ? 18 : 15, color: color),
                const SizedBox(width: 5),
                Text(
                  texto,
                  style: GoogleFonts.baloo2(
                    color: destacado ? ColoresApp.principalMarca : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Botón principal pill (altura normalizada, texto siempre legible).
  Widget _botonPrimario(String texto, VoidCallback? onPressed) {
    return CupertinoButton(
      color: ColoresApp.principalMarca,
      disabledColor: ColoresApp.principalMarca.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
      minimumSize: const Size(0, 42),
      onPressed: onPressed,
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Pill de ubicación: muestra la ciudad principal global (+N si hay más)
  /// y abre el mismo selector inteligente/manual de cartelera.
  Widget _pillUbicacion() {
    final prefs = PreferenciasCartelera.instancia;
    final ciudades = prefs.ciudadesActivas;
    final principal = prefs.ciudadPrincipal;
    final texto = principal == null || principal.trim().isEmpty
        ? 'Ubicación'
        : ciudades.length > 1
        ? '$principal +${ciudades.length - 1}'
        : principal;
    return GestureDetector(
      onTap: _elegirUbicacion,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 13,
              color: ColoresApp.principalMarca,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchModo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentoModo('usuario', CupertinoIcons.person_fill, 'Personal'),
          _segmentoModo('squad', CupertinoIcons.person_3_fill, 'Squad'),
        ],
      ),
    );
  }

  Widget _segmentoModo(String valor, IconData icono, String label) {
    final activo = _modo == valor;
    return GestureDetector(
      onTap: () async {
        if (valor == _modo) return;
        setState(() {
          _modo = valor;
          _squad = null;
        });
        if (valor == 'squad') {
          await _elegirSquad();
        } else {
          await _cargarEstado();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? ColoresApp.principalMarca : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 15,
              color: activo ? Colors.white : ColoresApp.textoSecundario,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: activo ? Colors.white : ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_modo == 'squad' && _squad == null) {
      return _mensajeCentral(
        '👥',
        'Elegí tu squad',
        'Tocá el switch de nuevo para elegir con qué squad salir.',
      );
    }
    if (_cargando) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_errorCarga) {
      return _mensajeCentral(
        '📡',
        'No pudimos cargar Match',
        'Revisá tu conexión y probá de nuevo.',
        boton: ('Reintentar', _cargarEstado),
      );
    }
    if (_sinPlan) {
      // Modo mirar: puede deslizar con tope de 3 likes/día; después pide plan.
      if (_mazo.isNotEmpty) {
        return Column(
          children: [
            _bannerArmaTuPlan(),
            Expanded(child: _deck()),
          ],
        );
      }
      return _armarPlanCta();
    }
    if (_mazo.isEmpty) {
      return Column(
        children: [
          if (_pendientes.isNotEmpty) _tiraPendientes(),
          _barraActivo(),
          Expanded(
            child: _cargandoMas
                ? const Center(child: CupertinoActivityIndicator(radius: 13))
                : _mensajeCentral(
                    '🔭',
                    'Viste todos los planes de tu zona',
                    'Podés volver a revisar los que pasaste, ampliar tu ubicación o cambiar los filtros desde "Filtros y planes".',
                    boton: ('Volver a revisar 🔁', _volverARevisar),
                  ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (_pendientes.isNotEmpty) _tiraPendientes(),
        _barraActivo(),
        Expanded(child: _deck()),
      ],
    );
  }

  /// Burbujas: a quiénes les pintó tu plan (esperando que los matchees).
  Widget _tiraPendientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
          child: Text(
            _pendientes.length == 1
                ? 'A 1 le pinta tu plan · tocá para matchear'
                : 'A ${_pendientes.length} les pinta tu plan · tocá para matchear',
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoSecundario,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendientes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (_, i) => _burbujaPendiente(_pendientes[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _burbujaPendiente(MatchPendiente p) {
    final foto = p.otro.fotoUrl;
    final urls = p.otro.avataresMiembrosUrls;
    final esSquadStack = p.otro.esSquad && urls.isNotEmpty;
    return GestureDetector(
      onTap: () => _abrirPendiente(p),
      child: SizedBox(
        width: esSquadStack ? 88 : 62,
        child: Column(
          children: [
            if (esSquadStack)
              StackAvataresSquad(
                avatares: urls,
                totalExtra: p.otro.miembrosParaStack,
                size: 36,
                paddingExterno: 2,
              )
            else
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.esRecopa ? _kAzulRecopa : ColoresApp.principalMarca,
                    width: 2.3,
                  ),
                  boxShadow: p.esRecopa
                      ? [
                          BoxShadow(
                            color: _kAzulRecopa.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    image: foto != null
                        ? DecorationImage(
                            image: NetworkImage(foto),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: foto == null
                      ? Text(
                          p.otro.esSquad ? '👥' : '🙋',
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              p.otro.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner del modo mirar: puede probar likes con tope diario.
  Widget _bannerArmaTuPlan() {
    return GestureDetector(
      onTap: _abrirConfiguracion,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: ColoresApp.principalMarca.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Text('👀', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estás mirando nomás',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Tenés 3 "me pinta"/"me re pinta" por día. Armá tu plan para más.',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: ColoresApp.principalMarca,
            ),
          ],
        ),
      ),
    );
  }

  /// Switch para aparecer o dejar de aparecer en las cards.
  Widget _barraActivo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 12, 6),
      child: Row(
        children: [
          Icon(
            _activo ? CupertinoIcons.eye_solid : CupertinoIcons.eye_slash_fill,
            size: 15,
            color: _activo
                ? ColoresApp.principalMarca
                : ColoresApp.textoSecundario,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _activo
                  ? 'Apareciendo en las cards'
                  : 'Oculto: no aparecés en las cards',
              style: GoogleFonts.baloo2(
                color: _activo
                    ? ColoresApp.textoPrincipal
                    : ColoresApp.textoSecundario,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          CupertinoSwitch(
            value: _activo,
            activeTrackColor: ColoresApp.principalMarca,
            onChanged: _toggleActivo,
          ),
        ],
      ),
    );
  }

  /// Recicla los "paso" y rearma el mazo (los "me pinta" no vuelven).
  Future<void> _volverARevisar() async {
    setState(() {
      _cargando = true;
      _idsVistos.clear();
      _hayMasCards = true;
    });
    await _srv.reciclarPasados(
      tipo: _modo,
      idGrupo: _modo == 'squad' ? _squad?.idGrupo : null,
    );
    await _cargarMazo();
  }

  Widget _armarPlanCta() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💜', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(
              _modo == 'usuario'
                  ? '¿Qué plan tenés ganas de hacer?'
                  : '¿Qué plan tiene el squad?',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Armá tu plan en 30 segundos y empezá a cruzarte con gente que quiere lo mismo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoSecundario,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            _botonPrimario('Armar mi plan ✨', _abrirConfiguracion),
          ],
        ),
      ),
    );
  }

  Widget _mensajeCentral(
    String emoji,
    String titulo,
    String detalle, {
    (String, Future<void> Function())? boton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoSecundario,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (boton != null) ...[
              const SizedBox(height: 16),
              _botonPrimario(boton.$1, () => boton.$2()),
            ],
          ],
        ),
      ),
    );
  }

  /// Decisión que tomaría el gesto actual (null = suelto vuelve al centro).
  /// Umbral alto a propósito: arrastres cortos NO disparan nada.
  String? _decisionDelGesto(double ancho, double alto) {
    final umbralX = ancho * 0.38;
    final umbralY = alto * 0.20;
    if (_arrastre.dy < -umbralY && _arrastre.dx.abs() < umbralX) {
      return 'recopa';
    }
    if (_arrastre.dx > umbralX) return 'interesa';
    if (_arrastre.dx < -umbralX) return 'paso';
    return null;
  }

  Widget _deck() {
    final ancho = MediaQuery.sizeOf(context).width;
    final alto = MediaQuery.sizeOf(context).height;
    // Stamp visible apenas se insinúa el gesto (feedback), pero la decisión
    // solo se toma al soltar pasado el umbral grande.
    final esVertical =
        _arrastre.dy < -40 && _arrastre.dy.abs() > _arrastre.dx.abs();
    final promoviendo = _swipeando || _arrastre.distance > 48;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Card de atrás: al soltar/volar, sube a posición activa.
              if (_mazo.length > 1)
                AnimatedScale(
                  scale: promoviendo ? 1 : 0.94,
                  duration: _duracionVuelo,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: promoviendo ? 1 : 0.5,
                    duration: _duracionVuelo,
                    curve: Curves.easeOutCubic,
                    child: _MatchCardVisual(card: _mazo[1]),
                  ),
                ),
              // Card de arriba, arrastrable (horizontal y hacia arriba)
              GestureDetector(
                onLongPress: _swipeando
                    ? null
                    : () => _bloquearCardActual(_mazo.first),
                onPanUpdate: _swipeando
                    ? null
                    : (d) => setState(() {
                        _animarArrastre = false;
                        final dy = (_arrastre.dy + d.delta.dy).clamp(
                          -alto * 0.4,
                          24.0,
                        );
                        _arrastre = Offset(_arrastre.dx + d.delta.dx, dy);
                      }),
                onPanEnd: _swipeando
                    ? null
                    : (_) {
                        final decision = _decisionDelGesto(ancho, alto);
                        if (decision != null) {
                          _swipe(decision);
                        } else {
                          // Umbral no alcanzado: vuelve suave al centro.
                          setState(() {
                            _animarArrastre = true;
                            _arrastre = Offset.zero;
                          });
                          Future<void>.delayed(_duracionVuelo, () {
                            if (mounted) {
                              setState(() => _animarArrastre = false);
                            }
                          });
                        }
                      },
                child: AnimatedContainer(
                  duration: _animarArrastre ? _duracionVuelo : Duration.zero,
                  // easeOutCubic: empujón natural al salir y snap suave al volver.
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.identity()
                    ..setTranslationRaw(_arrastre.dx, _arrastre.dy, 0)
                    ..rotateZ(_arrastre.dx / ancho * 0.22),
                  transformAlignment: Alignment.center,
                  child: Stack(
                    children: [
                      _MatchCardVisual(card: _mazo.first),
                      if (esVertical)
                        Positioned(
                          top: 26,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _stamp('ME RE PINTA 🥂', _kAzulRecopa),
                          ),
                        )
                      else if (_arrastre.dx.abs() > 40)
                        Positioned(
                          top: 26,
                          left: _arrastre.dx > 0 ? 22 : null,
                          right: _arrastre.dx < 0 ? 22 : null,
                          child: _stamp(
                            _arrastre.dx > 0 ? 'ME PINTA 💜' : 'NO ME PINTA ✋',
                            _arrastre.dx > 0
                                ? const Color(0xFF27AE60)
                                : const Color(0xFFEB5757),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dislike: borde del theme, sin fondo, X en el medio
              _botonSwipe(
                icono: CupertinoIcons.xmark,
                color: ColoresApp.principalMarca,
                relleno: false,
                onTap: () => _swipe('paso'),
              ),
              const SizedBox(width: 26),
              // Me re copa: azul sólido, estrella blanca
              _botonSwipe(
                fontAwesome: true,
                icono: FontAwesomeIcons.champagneGlasses,
                color: _kAzulRecopa,
                onTap: () => _swipe('recopa'),
              ),
              const SizedBox(width: 26),
              // Like: theme sólido sin borde, corazón blanco
              _botonSwipe(
                icono: CupertinoIcons.heart_fill,
                color: ColoresApp.principalMarca,
                onTap: () => _swipe('interesa'),
                grande: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stamp(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _botonSwipe({
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
    bool grande = false,
    bool relleno = true,
    bool fontAwesome = false,
  }) {
    final size = grande ? 66.0 : 56.0;
    final colorIcono = relleno ? Colors.white : color;
    final sizeIcono = grande ? 30.0 : (fontAwesome ? 21.0 : 24.0);
    return GestureDetector(
      onTap: _swipeando ? null : onTap,
      child: Container(
        width: size,
        height: size,
        // El glifo de FontAwesome no se centra solo dentro del círculo
        // (métricas distintas a los iconos de Cupertino) → alineación explícita.
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: relleno ? color : Colors.transparent,
          border: relleno ? null : Border.all(color: color, width: 2.4),
          boxShadow: relleno
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: fontAwesome
            ? SizedBox(
                width: size,
                height: sizeIcono,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: FaIcon(icono, color: colorIcono, size: sizeIcono),
                ),
              )
            : Icon(icono, color: colorIcono, size: sizeIcono),
      ),
    );
  }
}

/// Card del deck: FOTO (con nombre y edad encima) + card de info abajita
/// (blanca, letras oscuras) con el plan y el lugar.
class _MatchCardVisual extends StatelessWidget {
  const _MatchCardVisual({required this.card});

  final MatchCard card;

  /// Solo el primer nombre para usuarios ("Santiago Medrano" → "Santiago").
  String get _nombreCorto {
    if (card.esSquad) return card.nombre;
    return card.nombre.trim().split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width - 40;
    final alto = MediaQuery.sizeOf(context).height * 0.58;
    final foto = card.fotoUrl;
    final urlsSquad = card.avataresMiembrosUrls;
    final esSquad = card.esSquad;
    return SizedBox(
      width: ancho,
      height: alto,
      child: Column(
        children: [
          // ─── Banner/foto con stack + nombre encima ───
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ColoresApp.fondoSuperficie,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (foto != null)
                    Image.network(
                      foto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  else
                    _placeholder(),
                  // Degradado suave abajo, solo para que el nombre se lea
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.62, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badge: ya te dio "Me re pinta" 🥂
                  if (card.teRecopo)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _kAzulRecopa,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: _kAzulRecopa.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          '🥂 ¡Le re pinta tu plan!',
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esSquad) ...[
                          StackAvataresSquad(
                            avatares: urlsSquad,
                            totalExtra: card.miembrosParaStack,
                            size: 48,
                            paddingExterno: 0,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          esSquad
                              ? '$_nombreCorto${card.miembros != null ? ' · ${card.miembros} 👥' : ''}'
                              : '$_nombreCorto${card.edad != null ? ', ${card.edad}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        if (esSquad && card.edadPromedio != null)
                          Text(
                            'Edad prom.: ${card.edadPromedio}'
                            '${(card.hombres ?? 0) + (card.mujeres ?? 0) > 0 ? ' · ${card.hombres ?? 0}🙋‍♂️ ${card.mujeres ?? 0}🙋‍♀️' : ''}',
                            style: GoogleFonts.baloo2(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ─── Debajo: plan + lugar ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${card.planEtiqueta} en ${card.lugarTexto}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          color: const Color(0xFF16161A),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (card.lugarTipo == 'local') ...[
                      const SizedBox(width: 6),
                      _AvatarLocal(url: card.lugarFotoUrl, size: 22),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  card.cuandoEtiqueta,
                  style: GoogleFonts.baloo2(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sin banner: color sólido estable por squad/usuario (no gris fijo).
  Widget _placeholder() {
    final seed = card.idGrupo ?? card.idUsuario ?? card.idPlan;
    return Container(
      color: _colorSolidoDesdeSeed(seed),
      alignment: Alignment.center,
      child: Text(
        card.esSquad ? '👥' : '🙋',
        style: TextStyle(
          fontSize: 64,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

Color _colorSolidoDesdeSeed(String seed) {
  const palette = <Color>[
    Color(0xFF2D6A4F),
    Color(0xFF1D3557),
    Color(0xFF9B2226),
    Color(0xFF6A4C93),
    Color(0xFFBC6C25),
    Color(0xFF0077B6),
    Color(0xFF3A5A40),
    Color(0xFF6D597A),
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE CONFIGURACIÓN (obligatorio antes de deslizar)
// ─────────────────────────────────────────────────────────────────────────────

Future<bool?> mostrarSheetConfigMatch(
  BuildContext context, {
  required String modo,
  SquadResumen? squad,
  bool pedirSexo = false,
  VoidCallback? onFiltrosCambiados,
  Map<String, dynamic>? planActual,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetConfigMatch(
      modo: modo,
      squad: squad,
      pedirSexo: pedirSexo,
      onFiltrosCambiados: onFiltrosCambiados,
      planActual: planActual,
    ),
  );
}

class _SheetConfigMatch extends StatefulWidget {
  const _SheetConfigMatch({
    required this.modo,
    this.squad,
    required this.pedirSexo,
    this.onFiltrosCambiados,
    this.planActual,
  });

  final String modo;
  final SquadResumen? squad;
  final bool pedirSexo;

  /// Se dispara al tocar un filtro (se aplican al instante, sin confirmar).
  final VoidCallback? onFiltrosCambiados;

  /// Plan ya guardado: el sheet abre con esa configuración, no con defaults.
  final Map<String, dynamic>? planActual;

  @override
  State<_SheetConfigMatch> createState() => _SheetConfigMatchState();
}

class _SheetConfigMatchState extends State<_SheetConfigMatch> {
  final _srv = ServicioMatch();
  final _busquedaCtrl = TextEditingController();
  final _customCtrl = TextEditingController();

  String? _sexo;
  String _interes = 'todos';
  String? _planKey = 'lo_que_surja';
  String _lugarTipo = 'local';
  String? _idLocal;
  String? _idEvento;
  String? _lugarNombre;
  String _cuando = 'finde';
  String _rangoEdad = 'todos'; // ordena, no excluye
  String _rangoMiembros = 'todos'; // todos | 2_4 | 5_mas
  List<Map<String, dynamic>> _resultados = const [];
  bool _buscando = false;
  bool _guardando = false;
  bool _aplicandoFiltros = false;
  String? _error;

  bool get _esSquad => widget.modo == 'squad';

  @override
  void initState() {
    super.initState();
    final p = widget.planActual;
    if (p == null) return;
    // Reabrir el sheet con lo que el usuario ya venía usando.
    _interes = (p['interes_genero'] ?? 'todos').toString();
    _planKey = (p['plan_key'] ?? 'lo_que_surja').toString();
    _cuando = (p['cuando_key'] ?? 'finde').toString();
    final lt = p['lugar_tipo']?.toString();
    if (lt != null && lt.isNotEmpty) _lugarTipo = lt;
    _idLocal = p['id_local']?.toString();
    _idEvento = p['id_evento']?.toString();
    final lugar = p['lugar_texto']?.toString();
    if (lugar != null && lugar.isNotEmpty) {
      if (_lugarTipo == 'custom') {
        _customCtrl.text = lugar;
      } else {
        _lugarNombre = lugar;
      }
    }
    _rangoEdad = _rangoDesde(p['edad_min'], p['edad_max']);
    _rangoMiembros = _miembrosDesde(p['miembros_min'], p['miembros_max']);
  }

  /// Mapea el rango guardado (min/max) de vuelta al chip correspondiente.
  String _rangoDesde(dynamic min, dynamic max) {
    final a = min is num ? min.toInt() : int.tryParse('${min ?? ''}');
    final b = max is num ? max.toInt() : int.tryParse('${max ?? ''}');
    if (a == null && b == null) return 'todos';
    if (a == 16 && b == 24) return '16_24';
    if (a == 18 && b == 24) return '16_24'; // legacy
    if (a == 25 && b == 29) return '25_29';
    if (a == 30 && b == 39) return '30_39';
    if (a == 40 && b == 49) return '40_49';
    if (a == 50) return '50_mas';
    return 'todos';
  }

  String _miembrosDesde(dynamic min, dynamic max) {
    final a = min is num ? min.toInt() : int.tryParse('${min ?? ''}');
    final b = max is num ? max.toInt() : int.tryParse('${max ?? ''}');
    if (a == null && b == null) return 'todos';
    if (a == 2 && b == 4) return '2_4';
    if (a == 5) return '5_mas';
    return 'todos';
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    final res = _lugarTipo == 'local'
        ? await _srv.buscarLocales(q)
        : await _srv.buscarEventos(q);
    if (mounted) {
      setState(() {
        _resultados = res;
        _buscando = false;
      });
    }
  }

  (int?, int?) get _edades => switch (_rangoEdad) {
    '16_24' => (16, 24),
    '18_24' => (16, 24),
    '25_29' => (25, 29),
    '30_39' => (30, 39),
    '40_49' => (40, 49),
    '50_mas' => (50, 99),
    _ => (null, null),
  };

  /// Guarda los filtros (ordenan el mazo), refresca y cierra el sheet.
  Future<void> _aplicarFiltros() async {
    if (_aplicandoFiltros) return;
    setState(() => _aplicandoFiltros = true);
    final (eMin, eMax) = _edades;
    final ok = await _srv.setFiltros(
      interesGenero: _esSquad ? null : _interes,
      edadMin: eMin,
      edadMax: eMax,
      tipo: widget.modo,
      idGrupo: widget.squad?.idGrupo,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _aplicandoFiltros = false;
        _error = 'No pude guardar los filtros. Probá de nuevo.';
      });
      return;
    }
    widget.onFiltrosCambiados?.call();
    if (mounted) Navigator.pop(context, true);
  }

  /// Botón de confirmación de cada sección.
  Widget _botonAplicar({
    required String texto,
    required VoidCallback onTap,
    bool cargando = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: ColoresApp.principalMarca,
        disabledColor: ColoresApp.principalMarca.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(vertical: 11),
        minimumSize: const Size(0, 44),
        onPressed: cargando ? null : onTap,
        child: Text(
          cargando ? 'Guardando...' : texto,
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  (int?, int?) get _miembros => switch (_rangoMiembros) {
    '2_4' => (2, 4),
    '5_mas' => (5, 50),
    _ => (null, null),
  };

  bool get _completo => _queFalta == null;

  /// Qué le falta completar (null = todo listo). Para avisar en vez de
  /// dejar un botón muerto.
  String? get _queFalta {
    if (widget.pedirSexo && _sexo == null) return 'Contanos cómo te identificás 🙋';
    if (_planKey == null) return 'Elegí un plan ✨';
    if (_lugarTipo == 'custom') {
      if (_customCtrl.text.trim().length < 2) {
        return 'Escribí el lugar de tu plan 📍';
      }
      return null;
    }
    if ((_lugarTipo == 'local' ? _idLocal : _idEvento) == null) {
      return _lugarTipo == 'local'
          ? 'Elegí el local de tu plan 📍 (buscalo arriba)'
          : 'Elegí el evento de tu plan 📍 (buscalo arriba)';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!_completo || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final (edadMin, edadMax) = _edades;
      final (miembrosMin, miembrosMax) = _miembros;
      final ok = await _srv.configurar(
        tipo: widget.modo,
        idGrupo: widget.squad?.idGrupo,
        planKey: _planKey!,
        lugarTipo: _lugarTipo,
        cuando: _cuando,
        interesGenero: _interes,
        idLocal: _lugarTipo == 'local' ? _idLocal : null,
        idEvento: _lugarTipo == 'evento' ? _idEvento : null,
        lugarTexto: _lugarTipo == 'custom' ? _customCtrl.text.trim() : null,
        edadMin: edadMin,
        edadMax: edadMax,
        miembrosMin: _esSquad ? miembrosMin : null,
        miembrosMax: _esSquad ? miembrosMax : null,
        sexo: _sexo,
      );
      if (!mounted) return;
      if (ok) {
        // Plan completo => empieza a aparecer en las cards (se puede apagar
        // despues a mano desde el switch).
        await _srv.setActivo(
          activo: true,
          tipo: widget.modo,
          idGrupo: widget.squad?.idGrupo,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() {
          _guardando = false;
          _error = 'No pude guardar el plan. Probá de nuevo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.toString().contains('falta_sexo')
            ? 'Contanos cómo te identificás para poder cruzarte bien.'
            : 'No pude guardar el plan. Probá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: ColoresApp.fondoPrincipal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: ColoresApp.textoSecundario.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _esSquad
                  ? 'El plan de ${widget.squad?.nombre ?? 'tu squad'} 👥'
                  : 'Armá tu plan 💜',
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (widget.pedirSexo) ...[
                    _titulo('Sos...'),
                    _chips(
                      opciones: const [
                        ('hombre', '🙋‍♂️ Hombre'),
                        ('mujer', '🙋‍♀️ Mujer'),
                        ('otro', '🙅 Otro'),
                      ],
                      valor: _sexo,
                      onTap: (v) => setState(() => _sexo = v),
                    ),
                    const SizedBox(height: 18),
                  ],
                  // ── Card 1: FILTROS (aplican al instante) ──
                  _subCard(
                    titulo: 'Filtros',
                    detalle:
                        'Ordenan tu mazo: primero quienes más coinciden con vos.',
                    hijos: [
                      if (!_esSquad) ...[
                        _titulo('Género que te interesa'),
                        _chips(
                          opciones: const [
                            ('todos', '✨ Todos'),
                            ('hombres', 'Hombres'),
                            ('mujeres', 'Mujeres'),
                          ],
                          valor: _interes,
                          onTap: (v) => setState(() => _interes = v),
                          destacada: 'todos',
                        ),
                        const SizedBox(height: 14),
                      ],
                      _titulo(_esSquad ? 'Edad del otro squad' : 'Edad'),
                      _chips(
                        opciones: const [
                          ('todos', '✨ Todas'),
                          ('16_24', '16-24'),
                          ('25_29', '25-29'),
                          ('30_39', '30-39'),
                          ('40_49', '40-49'),
                          ('50_mas', '50+'),
                        ],
                        valor: _rangoEdad,
                        onTap: (v) => setState(() => _rangoEdad = v),
                        destacada: 'todos',
                      ),
                      if (_esSquad) ...[
                        const SizedBox(height: 14),
                        _titulo('Tamaño del otro squad'),
                        _chips(
                          opciones: const [
                            ('todos', '✨ Cualquiera'),
                            ('2_4', '2-4'),
                            ('5_mas', '5+'),
                          ],
                          valor: _rangoMiembros,
                          onTap: (v) => setState(() => _rangoMiembros = v),
                          destacada: 'todos',
                        ),
                      ],
                      const SizedBox(height: 14),
                      _botonAplicar(
                        texto: 'Aplicar filtros',
                        cargando: _aplicandoFiltros,
                        onTap: _aplicarFiltros,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Card 2: MI PLAN (se guarda con el botón) ──
                  _subCard(
                    titulo: 'Mis planes y preferencias',
                    detalle:
                        'Indicá tu plan y tu lugar para que puedan coincidir mejor con vos.',
                    hijos: [
                  _titulo('El plan'),
                  _chips(
                    opciones: _kPlanes
                        .map((p) => (p.$1, '${p.$3} ${p.$2}'))
                        .toList(),
                    valor: _planKey,
                    onTap: (v) => setState(() => _planKey = v),
                  ),
                  const SizedBox(height: 18),
                  _titulo('¿Dónde?'),
                  _chips(
                    opciones: const [
                      ('local', '🍸 Un local'),
                      ('evento', '🎟️ Un evento'),
                      ('custom', '📍 Otro lugar'),
                    ],
                    valor: _lugarTipo,
                    onTap: (v) => setState(() {
                      _lugarTipo = v;
                      _idLocal = null;
                      _idEvento = null;
                      _lugarNombre = null;
                      _resultados = const [];
                      _busquedaCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (_lugarTipo == 'custom')
                    _campo(
                      _customCtrl,
                      'Ej: mi casa, plaza San Martín...',
                      onChanged: (_) => setState(() {}),
                    )
                  else ...[
                    if (_lugarNombre != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.principalMarca.withValues(
                            alpha: 0.18,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ColoresApp.principalMarca),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '📍 $_lugarNombre',
                                style: GoogleFonts.baloo2(
                                  color: ColoresApp.textoPrincipal,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _idLocal = null;
                                _idEvento = null;
                                _lugarNombre = null;
                              }),
                              child: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 20,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _campo(
                        _busquedaCtrl,
                        _lugarTipo == 'local'
                            ? 'Buscá el local...'
                            : 'Buscá el evento...',
                        onChanged: (v) {
                          if (v.trim().length >= 2) _buscar(v);
                        },
                      ),
                      if (_buscando)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: CupertinoActivityIndicator(),
                        ),
                      ..._resultados.map(
                        (r) => GestureDetector(
                          onTap: () => setState(() {
                            if (_lugarTipo == 'local') {
                              _idLocal = r['id']?.toString();
                              _lugarNombre = r['nombre_local']?.toString();
                            } else {
                              _idEvento = r['id_evento']?.toString();
                              _lugarNombre = r['titulo_evento']?.toString();
                            }
                            _resultados = const [];
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.fondoSuperficie,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Avatar real del local (la copa queda solo
                                // como respaldo si todavía no tiene foto).
                                if (_lugarTipo == 'local')
                                  _AvatarLocal(
                                    url: ServicioSupabase().urlAvatar(
                                      r['foto_perfil_url']?.toString(),
                                    ),
                                    size: 26,
                                  ),
                                if (_lugarTipo == 'local')
                                  const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _lugarTipo == 'local'
                                        ? '${r['nombre_local']}${(r['ciudad'] ?? '').toString().isNotEmpty ? ' · ${r['ciudad']}' : ''}'
                                        : '🎟️ ${r['titulo_evento']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.baloo2(
                                      color: ColoresApp.textoPrincipal,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                      const SizedBox(height: 14),
                      _titulo('¿Cuándo?'),
                      _chips(
                        opciones: _kCuando.map((c) => (c.$1, c.$2)).toList(),
                        valor: _cuando,
                        onTap: (v) => setState(() => _cuando = v),
                      ),
                      const SizedBox(height: 14),
                      _botonAplicar(
                        texto: _guardando
                            ? 'Guardando...'
                            : 'Aplicar plan y empezar',
                        cargando: _guardando,
                        onTap: () {
                          final falta = _queFalta;
                          if (falta != null) {
                            setState(() => _error = falta);
                            return;
                          }
                          _guardar();
                        },
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: GoogleFonts.baloo2(
                          color: const Color(0xFFEB5757),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contenedor de sección dentro del sheet.
  Widget _subCard({
    required String titulo,
    required String detalle,
    required List<Widget> hijos,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoPrincipal,
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detalle,
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoSecundario,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          ...hijos,
        ],
      ),
    );
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: GoogleFonts.baloo2(
        color: ColoresApp.textoPrincipal,
        fontWeight: FontWeight.w900,
        fontSize: 15,
      ),
    ),
  );

  Widget _chips({
    required List<(String, String)> opciones,
    required String? valor,
    required void Function(String) onTap,
    String? destacada,
  }) {
    // Chips pill, todos con la MISMA altura (la destacada solo lleva borde).
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: opciones.map((o) {
        final activa = valor == o.$1;
        final esDestacada = destacada == o.$1;
        return GestureDetector(
          onTap: () => onTap(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: activa
                  ? ColoresApp.principalMarca
                  : ColoresApp.fondoSuperficie,
              borderRadius: BorderRadius.circular(999),
              border: esDestacada && !activa
                  ? Border.all(color: ColoresApp.principalMarca, width: 1.2)
                  : null,
            ),
            child: Text(
              o.$2,
              style: GoogleFonts.baloo2(
                color: activa ? Colors.white : ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String hint, {
    void Function(String)? onChanged,
  }) {
    return CupertinoTextField(
      controller: ctrl,
      onChanged: onChanged,
      placeholder: hint,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      style: GoogleFonts.baloo2(
        color: ColoresApp.textoPrincipal,
        fontWeight: FontWeight.w700,
      ),
      placeholderStyle: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

/// Tarjeta grande de alguien a quien le pintó tu plan: foto, datos y el
/// plan que le interesó + "Matchear y chatear".
class _TarjetaPendiente extends StatelessWidget {
  const _TarjetaPendiente({
    required this.card,
    required this.onMatchear,
    this.esRecopa = false,
  });

  final MatchCard card;
  final bool esRecopa;
  final VoidCallback onMatchear;

  String get _genero => switch (card.sexo) {
    'hombre' => 'Hombre',
    'mujer' => 'Mujer',
    'otro' => 'Otrx',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final foto = card.fotoUrl;
    final ancho = MediaQuery.sizeOf(context).width * 0.86;
    final recopa = esRecopa;
    final urlsSquad = card.avataresMiembrosUrls;
    final esSquad = card.esSquad;
    final datos = [
      if (card.edad != null) '${card.edad} años',
      if (_genero.isNotEmpty) _genero,
      if (esSquad && card.miembros != null) '${card.miembros} personas',
    ].join(' · ');

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: ancho,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: MediaQuery.sizeOf(context).height * 0.4,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(26),
                  border: recopa
                      ? Border.all(color: _kAzulRecopa, width: 2.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: (recopa ? _kAzulRecopa : Colors.black).withValues(
                        alpha: recopa ? 0.45 : 0.5,
                      ),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (foto != null)
                      Image.network(
                        foto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _ph(),
                      )
                    else
                      _ph(),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.55, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: recopa
                              ? _kAzulRecopa
                              : ColoresApp.principalMarca,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recopa
                              ? '🥂 ¡Le RE pinta tu plan!'
                              : '💜 ¡Le pinta tu plan!',
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (esSquad) ...[
                            StackAvataresSquad(
                              avatares: urlsSquad,
                              totalExtra: card.miembrosParaStack,
                              size: 44,
                              paddingExterno: 0,
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            esSquad
                                ? card.nombre
                                : card.nombre.split(RegExp(r'\s+')).first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                          if (datos.isNotEmpty)
                            Text(
                              datos,
                              style: GoogleFonts.baloo2(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // El plan del OTRO (lo que propone para salir)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Su plan',
                      style: GoogleFonts.baloo2(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${card.planEtiqueta} en ${card.lugarTexto}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              color: const Color(0xFF16161A),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (card.lugarTipo == 'local') ...[
                          const SizedBox(width: 6),
                          _AvatarLocal(url: card.lugarFotoUrl, size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card.cuandoEtiqueta,
                      style: GoogleFonts.baloo2(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 46),
                  onPressed: onMatchear,
                  child: Text(
                    'Matchear y chatear 💬',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ph() => Container(
    color: const Color(0xFF2A2A2A),
    alignment: Alignment.center,
    child: Text(
      card.esSquad ? '👥' : '🙋',
      style: const TextStyle(fontSize: 64),
    ),
  );
}

/// Avatar del local. Si todavía no tiene foto, muestra la copita como
/// respaldo (antes se veía siempre el emoji aunque el local tuviera avatar).
class _AvatarLocal extends StatelessWidget {
  const _AvatarLocal({required this.url, this.size = 20});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tiene = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEDEDF2),
        image: tiene
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: tiene
          ? null
          : Text('🍸', style: TextStyle(fontSize: size * 0.55)),
    );
  }
}
