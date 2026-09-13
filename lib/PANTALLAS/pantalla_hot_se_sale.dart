/// Feed fullscreen de Hot Se Sale (stories): flyer + título + obtener / QR.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../core/promos_hot.dart';
import '../core/servicio_reservar_promocion.dart';
import '../core/supabase_client.dart';
import '../widgets/dialogo_fernecito.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/flyer_red_con_fallback.dart';
import 'pantalla_ver_evento.dart';

class PantallaHotSeSale extends StatefulWidget {
  const PantallaHotSeSale({super.key});

  @override
  State<PantallaHotSeSale> createState() => _PantallaHotSeSaleState();
}

class _PantallaHotSeSaleState extends State<PantallaHotSeSale> {
  bool _cargando = true;
  String? _error;
  List<_CardHot> _todas = const [];
  String _filtro = 'Todos';
  final Map<String, String> _misCodigos = {};
  final Map<String, String> _estadoToken = {};
  final Set<String> _obteniendo = {};
  final PageController _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<_CardHot> get _visibles {
    if (_filtro == 'Todos') return _todas;
    return _todas.where((c) => c.etiquetaTipo == _filtro).toList();
  }

  List<String> get _chips {
    final tipos = <String>{};
    for (final c in _todas) {
      if (c.etiquetaTipo.isNotEmpty) tipos.add(c.etiquetaTipo);
    }
    return ['Todos', ...tipos];
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final sb = ServicioSupabase().cliente;
      List<Map<String, dynamic>> rows = [];
      try {
        final res = await sb
            .from('promociones')
            .select(
              '*, eventos(id_evento, titulo_evento, descripcion_evento, '
              'url_flyer, fecha_inicio, fecha_fin, ciudad_evento, '
              'estado_publicacion, id_local, tipo_evento, modo_evento, '
              'tiene_promo)',
            )
            .eq('estado_promocion', 'activa');
        rows = List<Map<String, dynamic>>.from(res as List);
      } catch (e) {
        debugPrint('[HotSeSale] join eventos falló, retry sin embed: $e');
        final res = await sb
            .from('promociones')
            .select('*')
            .eq('estado_promocion', 'activa');
        rows = List<Map<String, dynamic>>.from(res as List);
      }

      final cards = <_CardHot>[];
      for (final raw in rows) {
        final promo = Map<String, dynamic>.from(raw);
        final evento = _eventoDe(promo);
        if (!esPromoHot(promo, evento: evento) &&
            requiereAsistenciaPromo(promo, evento: evento)) {
          continue;
        }
        if (!promoVigente(promo)) continue;
        cards.add(_CardHot.fromRows(promo, evento));
      }

      final userId = sb.auth.currentUser?.id;
      _misCodigos.clear();
      _estadoToken.clear();
      if (userId != null && cards.isNotEmpty) {
        final ids = cards.map((c) => c.idPromo).where((id) => id.isNotEmpty).toList();
        if (ids.isNotEmpty) {
          try {
            final toks = await sb
                .from('tokens_promociones')
                .select('id_promocion, token_codigo, estado_token')
                .eq('id_usuario', userId)
                .inFilter('id_promocion', ids)
                .inFilter('estado_token', kEstadosTokenPromoUsuario);
            for (final t in (toks as List)) {
              final idP = t['id_promocion']?.toString() ?? '';
              final codigo = t['token_codigo']?.toString() ?? '';
              if (idP.isEmpty || codigo.isEmpty) continue;
              _misCodigos[idP] = codigo;
              _estadoToken[idP] =
                  t['estado_token']?.toString().toLowerCase() ?? 'activo';
            }
          } catch (e) {
            debugPrint('[HotSeSale] tokens: $e');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _todas = cards;
        _cargando = false;
        if (_filtro != 'Todos' && !_chips.contains(_filtro)) {
          _filtro = 'Todos';
        }
      });
    } catch (e, st) {
      debugPrint('[HotSeSale] _cargar: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar Hot Se Sale.';
        _cargando = false;
      });
    }
  }

  Map<String, dynamic>? _eventoDe(Map<String, dynamic> promo) {
    final raw = promo['eventos'] ?? promo['evento'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> _obtener(_CardHot card) async {
    if (_obteniendo.contains(card.idPromo)) return;
    setState(() => _obteniendo.add(card.idPromo));
    final r = await ServicioReservarPromocion.instancia.reservar(
      idPromocion: card.idPromo,
      idEvento: card.idEvento,
    );
    if (!mounted) return;
    setState(() => _obteniendo.remove(card.idPromo));
    if (r.ok) {
      HapticFeedback.mediumImpact();
      if ((r.codigo ?? '').isNotEmpty) {
        setState(() {
          _misCodigos[card.idPromo] = r.codigo!;
          _estadoToken[card.idPromo] = r.estadoToken ?? 'activo';
        });
      } else {
        await _cargar();
      }
      return;
    }
    await showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: Text(r.errorTitulo ?? 'No se pudo obtener la promo'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(r.errorMensaje ?? 'Intentá de nuevo en unos momentos.'),
        ),
        actions: [
          AccionDialogoFernecito(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _verEvento(_CardHot card) {
    final evento = <String, dynamic>{
      'id': card.idEvento,
      'id_evento': card.idEvento,
      'titulo': card.tituloEvento.isNotEmpty ? card.tituloEvento : card.titulo,
      'descripcion': card.descripcionEvento,
      'flyer': card.urlFlyer,
      'idLocal': card.idLocal,
      'tienePromo': true,
      'fechaInicio': card.fechaInicioIso,
      'fechaFin': card.fechaFinIso,
    };
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => PantallaVerEvento(evento: evento)),
    );
  }

  void _verQr(_CardHot card) {
    final codigo = _misCodigos[card.idPromo] ?? '';
    if (codigo.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SheetQrHot(
        codigo: codigo,
        titulo: card.titulo,
        canjeada: _estadoToken[card.idPromo] == 'canjeado',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      CupertinoIcons.back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.flame_fill,
                    color: Color(0xFFFF8C42),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HOT SE SALE',
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_chips.length > 1)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final chip = _chips[i];
                    final on = chip == _filtro;
                    return GestureDetector(
                      onTap: () => setState(() => _filtro = chip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: on
                              ? ColoresApp.principalMarca
                              : ColoresApp.fondoSuperficie,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chip,
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: on ? Colors.white : ColoresApp.textoSecundario,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _cuerpo()),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const FernecitoLoaderCentro(size: 28);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _cargar,
                child: Text(
                  'Reintentar',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final cards = _visibles;
    if (cards.isEmpty) {
      return Center(
        child: Text(
          'No hay Hot Se Sale activas por ahora.',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: cards.length,
      itemBuilder: (context, index) => _HotStoryCard(
        card: cards[index],
        codigo: _misCodigos[cards[index].idPromo] ?? '',
        obteniendo: _obteniendo.contains(cards[index].idPromo),
        onVerPromo: () => _verEvento(cards[index]),
        onVerQr: () => _verQr(cards[index]),
        onObtener: () => _obtener(cards[index]),
      ),
    );
  }
}

class _CardHot {
  const _CardHot({
    required this.idPromo,
    required this.idEvento,
    required this.idLocal,
    required this.titulo,
    required this.tituloEvento,
    required this.descripcionEvento,
    required this.urlFlyer,
    required this.etiquetaTipo,
    required this.cuposLibres,
    required this.venceTexto,
    required this.fechaInicioIso,
    required this.fechaFinIso,
  });

  final String idPromo;
  final String idEvento;
  final String idLocal;
  final String titulo;
  final String tituloEvento;
  final String descripcionEvento;
  final String urlFlyer;
  final String etiquetaTipo;
  final int? cuposLibres;
  final String venceTexto;
  final String fechaInicioIso;
  final String fechaFinIso;

  factory _CardHot.fromRows(
    Map<String, dynamic> promo,
    Map<String, dynamic>? evento,
  ) {
    return _CardHot(
      idPromo: promo['id_promocion']?.toString() ?? '',
      idEvento:
          (promo['id_evento'] ?? evento?['id_evento'] ?? evento?['id'])
              ?.toString() ??
          '',
      idLocal:
          (promo['id_local'] ?? evento?['id_local'])?.toString() ?? '',
      titulo: tituloVisiblePromo(promo, evento: evento),
      tituloEvento: evento?['titulo_evento']?.toString() ?? '',
      descripcionEvento: evento?['descripcion_evento']?.toString() ?? '',
      urlFlyer: urlFlyerPromo(promo, evento: evento),
      etiquetaTipo: etiquetaTipoPromo(promo),
      cuposLibres: cuposLibresPromo(promo),
      venceTexto: textoVencePromo(promo['fecha_fin']?.toString()),
      fechaInicioIso: (promo['fecha_inicio'] ?? evento?['fecha_inicio'])
              ?.toString() ??
          '',
      fechaFinIso:
          (promo['fecha_fin'] ?? evento?['fecha_fin'])?.toString() ?? '',
    );
  }
}

class _HotStoryCard extends StatelessWidget {
  const _HotStoryCard({
    required this.card,
    required this.codigo,
    required this.obteniendo,
    required this.onVerPromo,
    required this.onVerQr,
    required this.onObtener,
  });

  final _CardHot card;
  final String codigo;
  final bool obteniendo;
  final VoidCallback onVerPromo;
  final VoidCallback onVerQr;
  final VoidCallback onObtener;

  @override
  Widget build(BuildContext context) {
    final ya = codigo.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlyerRedConFallback(url: card.urlFlyer),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x00000000),
                          Color(0xCC000000),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _chip(
                      card.etiquetaTipo,
                      fondo: Colors.white,
                      color: Colors.black,
                    ),
                  ),
                  if (card.cuposLibres != null)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _chip(
                        'quedan ${card.cuposLibres}',
                        fondo: Colors.white,
                        color: Colors.black,
                        icono: CupertinoIcons.flame_fill,
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (card.venceTexto.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.timer,
                                size: 13,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                card.venceTexto,
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onVerPromo,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoSuperficie,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'Ver promo',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: obteniendo
                      ? null
                      : (ya ? onVerQr : onObtener),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ya
                          ? ColoresApp.principalMarca
                          : const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: obteniendo
                        ? const FernecitoLoader.inline(
                            size: 18,
                            color: Colors.black,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                ya
                                    ? CupertinoIcons.qrcode
                                    : CupertinoIcons.gift_fill,
                                size: 16,
                                color: ya ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ya ? 'Ver mi QR' : 'Obtener promo',
                                style: GoogleFonts.baloo2(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: ya ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String texto, {
    required Color fondo,
    required Color color,
    IconData? icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: const Color(0xFFFF8C42)),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetQrHot extends StatelessWidget {
  const _SheetQrHot({
    required this.codigo,
    required this.titulo,
    required this.canjeada,
  });

  final String codigo;
  final String titulo;
  final bool canjeada;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: SuperficiesApp.bottomSheet(topRadius: 24),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                canjeada ? 'Promo canjeada' : 'Tu código de promo',
                style: GoogleFonts.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: codigo.isNotEmpty ? codigo : 'SIN_CODIGO',
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              Text(
                codigo,
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      'Cerrar',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
}
