/// Bottomsheet chat IA — estilo Gemini / premium Fernecito.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/coordenadas_ciudades.dart';
import '../core/estado_busqueda_ia.dart';
import '../core/servicio_busqueda_ia.dart';
import '../core/servicio_ubicacion_dispositivo.dart';
import '../core/ubicaciones_data.dart';
import '../PANTALLAS/pantalla_local_perfil.dart';
import '../PANTALLAS/pantalla_ver_evento.dart';
import 'avatar_local.dart';

const _kDorado = Color(0xFFE0B800);
const _kVioleta = Color(0xFFBB8FCE);
/// Violeta oscuro (app locales) — contraste sobre dorado / mostaza.
const _kVioletaOscuro = Color(0xFF4A1A8A);

/// Texto "A X km de ti" desde una referencia hasta la ciudad del ítem. null si falta data.
String? _distanciaHastaCiudad(LatLng? ref, String? ciudad) {
  if (ref == null) return null;
  final dest = CoordenadasCiudades.deCiudad(ciudad);
  if (dest == null) return null;
  final metros = const Distance()(ref, dest);
  if (metros < 1000) return 'A ${metros.round()} m de ti';
  final km = metros / 1000;
  if (km < 10) return 'A ${km.toStringAsFixed(1).replaceAll('.', ',')} km de ti';
  return 'A ${km.round()} km de ti';
}

/// Badge de distancia estilo mapa ("a X km de ti") para las cards de la IA.
class _BadgeDistanciaIa extends StatelessWidget {
  const _BadgeDistanciaIa({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3EE07A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF14261C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> mostrarBusquedaIaSheet(
  BuildContext context, {
  required Set<String> ciudades,
  String? preguntaInicial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _BusquedaIaChatSheet(
      ciudades: ciudades,
      preguntaInicial: preguntaInicial,
    ),
  );
}

class _BusquedaIaChatSheet extends StatefulWidget {
  const _BusquedaIaChatSheet({
    required this.ciudades,
    this.preguntaInicial,
  });

  final Set<String> ciudades;
  final String? preguntaInicial;

  @override
  State<_BusquedaIaChatSheet> createState() => _BusquedaIaChatSheetState();
}

class _BusquedaIaChatSheetState extends State<_BusquedaIaChatSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _cache = EstadoBusquedaIaCache.instancia;
  bool _cargando = false;
  /// Alcance de búsqueda: false = mi zona (ciudades activas), true = toda la app.
  bool _alcanceTodas = false;

  /// Posición del usuario para el badge "a X km de ti" (null = sin badge).
  LatLng? _refUsuario;

  @override
  void initState() {
    super.initState();
    final init = widget.preguntaInicial?.trim() ?? '';
    if (init.isNotEmpty) _ctrl.text = init;

    _refUsuario = ServicioUbicacionDispositivo.instancia.ultimaPosicionConocida;
    if (_refUsuario == null) {
      ServicioUbicacionDispositivo.instancia
          .posicionAproximadaSinPrompt()
          .then((p) {
        if (p != null && mounted) setState(() => _refUsuario = p);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    final texto = _ctrl.text.trim();
    if (texto.length < 3) return;

    // Si se agotaron los seguimientos, la próxima pregunta abre conversación nueva.
    if (_cache.mensajes.isNotEmpty && !_cache.puedeSeguir) {
      _cache.resetConversacion();
    }
    final seguir = _cache.mensajes.isNotEmpty && _cache.puedeSeguir;

    HapticFeedback.selectionClick();
    _ctrl.clear();
    _focus.unfocus();

    setState(() {
      _cargando = true;
      _cache.agregarUsuario(texto);
      _cache.agregarEscribiendo();
    });
    _scrollAlFinal(); // al MANDAR sí baja al final (se ve la pregunta + escribiendo)

    final res = await ServicioBusquedaIa.instancia.buscar(
      pregunta: texto,
      ciudades: widget.ciudades,
      ciudadesDisponibles: UbicacionesData.todasLasCiudades,
      alcanceTodas: _alcanceTodas,
      seguirConversacion: seguir,
      historial: seguir ? _cache.historialParaEdge() : const [],
    );
    if (!mounted) return;

    if (res.nombreUsuario != null && res.nombreUsuario!.isNotEmpty) {
      _cache.nombreUsuario = res.nombreUsuario;
    }

    setState(() {
      _cargando = false;
      if (seguir) _cache.seguimientosUsados++;
      _cache.agregarAsistente(
        texto: res.textoMostrar,
        recomendados: res.ok ? res.recomendados : const [],
        esError: !res.ok,
      );
    });
    // Al RECIBIR la respuesta NO bajamos el scroll: el usuario queda viendo el
    // mensaje de la IA (arriba de las cards) y scrollea si quiere ver más.
  }

  void _usarSugerencia(String texto) {
    if (_cargando) return;
    _ctrl.text = texto;
    _enviar();
  }

  void _nuevaConsulta() {
    setState(() {
      _cache.resetConversacion();
      _ctrl.clear();
    });
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _focus.requestFocus();
    });
  }

  void _abrirEvento(RecomendacionIa r) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaVerEvento(
          evento: {
            'id': r.id,
            'titulo': r.titulo,
            'flyer': r.imagenUrl ?? '',
            'nombreLocal': r.nombreLocal ?? 'Local',
            'idLocal': r.idLocal ?? '',
            'ciudadEvento': r.ciudad ?? '',
            'fechaInicio': r.fechaInicio,
            'tipoEvento': r.tipoEvento,
          },
        ),
      ),
    );
  }

  void _abrirLocal(RecomendacionIa r) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaLocalPerfil(
          avatarUrl: r.avatarUrl ?? r.imagenUrl ?? '',
          nombreLocal: r.titulo,
          idLocal: r.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final altura = MediaQuery.of(context).size.height * 0.92;
    final hayChat = _cache.mensajes.isNotEmpty;
    final puedeSeguir = _cache.puedeSeguir && hayChat;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: altura,
        decoration: const BoxDecoration(
          color: Color(0xFF141416),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kDorado.withValues(alpha: 0.35),
                          _kVioleta.withValues(alpha: 0.35),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: _kDorado,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fernecito IA',
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Planes con onda, a tu medida',
                          style: GoogleFonts.baloo2(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hayChat
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      itemCount: _cache.mensajes.length,
                      itemBuilder: (context, i) {
                        final m = _cache.mensajes[i];
                        if (m.rol == RolMensajeIa.usuario) {
                          return _BubbleUsuario(texto: m.texto);
                        }
                        if (m.rol == RolMensajeIa.escribiendo) {
                          return const _BubbleEscribiendo();
                        }
                        return _BloqueAsistente(
                          mensaje: m,
                          refUsuario: _refUsuario,
                          onVerEvento: _abrirEvento,
                          onVerLocal: _abrirLocal,
                        );
                      },
                    )
                  : _EmptyHint(nombre: _cache.nombreUsuario),
            ),
            // Contexto de la conversación: mensajes restantes + nueva consulta.
            if (hayChat)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _PillContexto(
                        texto: puedeSeguir
                            ? 'Te quedan ${_cache.seguimientosRestantes} '
                                'mensaje${_cache.seguimientosRestantes == 1 ? '' : 's'} en esta conversación'
                            : 'Conversación completa — tu próxima pregunta abre una nueva',
                        alerta: !puedeSeguir,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BotonNueva(onTap: _nuevaConsulta),
                  ],
                ),
              ),
            // Alcance de búsqueda (mi zona / toda la app).
            _ToggleAlcance(
              todas: _alcanceTodas,
              onChanged: (v) => setState(() => _alcanceTodas = v),
            ),
            const SizedBox(height: 8),
            // Sugerencias rápidas: tocar = poner en el textfield y enviar.
            if (!_cargando) _ChipsSugerencias(onTap: _usarSugerencia),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 10 + bottomSafe),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1F),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        maxLength: ServicioBusquedaIa.maxPregunta,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                        cursorColor: _kVioleta,
                        style: GoogleFonts.baloo2(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          counterText: '',
                          hintText: hayChat
                              ? (puedeSeguir
                                  ? 'Seguí preguntando…'
                                  : 'Tu próxima pregunta abre una nueva…')
                              : '¿Qué querés hacer?',
                          hintStyle: GoogleFonts.baloo2(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _cargando ? null : _enviar,
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_kDorado, Color(0xFFF5D76E)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CupertinoActivityIndicator(
                                  color: Colors.black87,
                                  radius: 8,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.arrow_up,
                                color: _kVioletaOscuro,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({this.nombre});
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final n = (nombre ?? '').trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          n.isEmpty
              ? 'Contame qué plan buscás ✨\nEj: ver el partido, cena con mamá, fiesta el sábado…'
              : 'Hola, $n! ✨ Contame qué plan buscás y te armo ideas cerca tuyo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            color: Colors.white54,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PillContexto extends StatelessWidget {
  const _PillContexto({required this.texto, this.alerta = false});
  final String texto;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final c = alerta ? _kDorado : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alerta
                ? CupertinoIcons.exclamationmark_circle
                : CupertinoIcons.chat_bubble_2,
            size: 13,
            color: c,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: c,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonNueva extends StatelessWidget {
  const _BotonNueva({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kVioleta.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.plus_circle, size: 14, color: _kVioleta),
            const SizedBox(width: 5),
            Text(
              'Nueva consulta',
              style: GoogleFonts.baloo2(
                color: _kVioleta,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleAlcance extends StatelessWidget {
  const _ToggleAlcance({required this.todas, required this.onChanged});
  final bool todas;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opt(String label, IconData ic, bool sel, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? _kVioleta.withValues(alpha: 0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ic, size: 13, color: sel ? _kVioleta : Colors.white54),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.baloo2(
                    color: sel ? _kVioleta : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            opt('Mi zona', CupertinoIcons.location_solid, !todas, () => onChanged(false)),
            opt('Toda la app', CupertinoIcons.globe, todas, () => onChanged(true)),
          ],
        ),
      ),
    );
  }
}

class _ChipsSugerencias extends StatelessWidget {
  const _ChipsSugerencias({required this.onTap});
  final ValueChanged<String> onTap;

  static const _items = <(String, String)>[
    ('🌙', '¿Qué hago esta noche?'),
    ('🎉', 'Quiero una fiesta este finde'),
    ('🍺', 'Un lugar para tomar algo'),
    ('🍔', '¿Dónde puedo comer rico?'),
    ('☕', 'Un café tranqui'),
    ('🎶', '¿Hay música en vivo?'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (emoji, texto) = _items[i];
          return GestureDetector(
            onTap: () => onTap(texto),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kVioleta.withValues(alpha: 0.22)),
              ),
              child: Text(
                '$emoji  $texto',
                style: GoogleFonts.baloo2(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BubbleUsuario extends StatelessWidget {
  const _BubbleUsuario({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _kVioleta.withValues(alpha: 0.55),
              _kVioleta.withValues(alpha: 0.28),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          texto,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontSize: 14.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BubbleEscribiendo extends StatefulWidget {
  const _BubbleEscribiendo();

  @override
  State<_BubbleEscribiendo> createState() => _BubbleEscribiendoState();
}

class _BubbleEscribiendoState extends State<_BubbleEscribiendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1F),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_c.value + i * 0.22) % 1.0;
                final scale = 0.65 + 0.35 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _kDorado.withValues(alpha: 0.55 + 0.45 * scale),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _BloqueAsistente extends StatelessWidget {
  const _BloqueAsistente({
    required this.mensaje,
    required this.onVerEvento,
    required this.onVerLocal,
    this.refUsuario,
  });

  final MensajeChatIa mensaje;
  final ValueChanged<RecomendacionIa> onVerEvento;
  final ValueChanged<RecomendacionIa> onVerLocal;
  final LatLng? refUsuario;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1F),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              mensaje.texto,
              style: GoogleFonts.baloo2(
                color: mensaje.esError
                    ? Colors.white70
                    : Colors.white.withValues(alpha: 0.92),
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (mensaje.recomendados.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in mensaje.recomendados) ...[
              if (r.esEvento)
                _CardEventoIa(
                  item: r,
                  refUsuario: refUsuario,
                  onVer: () => onVerEvento(r),
                )
              else
                _CardLocalIa(
                  item: r,
                  refUsuario: refUsuario,
                  onVer: () => onVerLocal(r),
                ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _CardEventoIa extends StatelessWidget {
  const _CardEventoIa({required this.item, required this.onVer, this.refUsuario});
  final RecomendacionIa item;
  final VoidCallback onVer;
  final LatLng? refUsuario;

  @override
  Widget build(BuildContext context) {
    final img = item.imagenUrl?.trim() ?? '';
    final dist = _distanciaHastaCiudad(refUsuario, item.ciudad);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.28,
              child: img.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF252528),
                      child: Icon(
                        CupertinoIcons.ticket_fill,
                        color: Colors.white24,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      memCacheWidth: 280,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF252528)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF252528)),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (item.nombreLocal != null &&
                        item.nombreLocal!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.nombreLocal!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          color: _kDorado.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (dist != null) ...[
                      const SizedBox(height: 6),
                      _BadgeDistanciaIa(texto: dist),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.porQue,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onVer,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kVioleta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Ver evento',
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardLocalIa extends StatelessWidget {
  const _CardLocalIa({required this.item, required this.onVer, this.refUsuario});
  final RecomendacionIa item;
  final VoidCallback onVer;
  final LatLng? refUsuario;

  @override
  Widget build(BuildContext context) {
    final cal = item.calificacionPromedio;
    final dist = _distanciaHastaCiudad(refUsuario, item.ciudad);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarLocal(
                imageUrl: item.avatarUrl ?? item.imagenUrl,
                size: 52,
                esPionero: item.esPionero,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.verificado || item.esPionero) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: item.esPionero
                                ? _kDorado
                                : ColoresApp.principalMarca,
                          ),
                        ],
                      ],
                    ),
                    if (item.rubro != null && item.rubro!.isNotEmpty)
                      Text(
                        item.rubro!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    if (cal != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            final filled = i < cal.round().clamp(0, 5);
                            return Icon(
                              filled
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.star,
                              size: 12,
                              color: const Color(0xFFFFC107),
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            cal.toStringAsFixed(1),
                            style: GoogleFonts.baloo2(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.calificacionCantidad != null) ...[
                            Text(
                              ' (${item.calificacionCantidad})',
                              style: GoogleFonts.baloo2(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (dist != null) ...[
            const SizedBox(height: 10),
            _BadgeDistanciaIa(texto: dist),
          ],
          const SizedBox(height: 10),
          Text(
            item.porQue,
            style: GoogleFonts.baloo2(
              color: Colors.white60,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onVer,
              style: FilledButton.styleFrom(
                backgroundColor: _kDorado,
                foregroundColor: _kVioletaOscuro,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Ver local',
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _kVioletaOscuro,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
