/// Pantalla Pool de un evento - Banner flyer, squads y personas en grid estilo burbujas.
library;


import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_pools.dart';
import '../widgets/burbuja_estado.dart';
import '../models/rompehielo.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';

/// Flyer por defecto para el banner.
const String _flyerMockDefault = 'assets/imagenes/mockups/Screenshot_20260202_013949_Instagram.jpg';

bool _esAsset(String url) => url.startsWith('assets/');

/// Abre una URL (red social) en una app externa. Antepone https:// si falta.
Future<void> _abrirUrl(String raw) async {
  var url = raw.trim();
  if (url.isEmpty) return;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* silencioso */}
}

class PantallaPools extends StatefulWidget {
  final String idEvento;
  final String nombreEvento;
  final String? flyerUrl;
  final String nombreLocal;
  final String avatarLocal;

  const PantallaPools({
    super.key,
    required this.idEvento,
    required this.nombreEvento,
    this.flyerUrl,
    this.nombreLocal = 'Local',
    this.avatarLocal = 'assets/imagenes/mockups/perfiles_local/Screenshot_20260202_015301_Google.jpg',
  });

  @override
  State<PantallaPools> createState() => _PantallaPoolsState();
}

class _PantallaPoolsState extends State<PantallaPools> {
  final ServicioPools _srv = ServicioPools();

  PoolData _data = const PoolData();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = await _srv.pool(widget.idEvento);
    if (!mounted) return;
    setState(() {
      _data = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final squads = _data.squads;
    final personas = _data.personas;
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    final flyer = widget.flyerUrl ?? _flyerMockDefault;
    final nombreEvento = widget.nombreEvento;
    final nombreLocal = widget.nombreLocal;
    final avatarLocal = widget.avatarLocal;
    final bannerHeight = size.height * 0.60;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: ListView(
        padding: EdgeInsets.only(bottom: padding.bottom + 24),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner pegado al top, sin padding, 60% alto, ancho pantalla
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerHeight,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.6, 0.9, 1.0],
                    colors: [
                      Colors.white.withOpacity(0.6),
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _esAsset(flyer)
                          ? Image.asset(
                              flyer,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              cacheHeight: 800,
                              errorBuilder: (_, __, ___) => _placeholderBanner(),
                            )
                          : CachedNetworkImage(
                              imageUrl: flyer,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _placeholderBanner(),
                              errorWidget: (_, __, ___) => _placeholderBanner(),
                            ),
                      Container(color: Colors.black.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
              // Layer con contenido sobre el banner y el fondo
              Padding(
                padding: EdgeInsets.fromLTRB(20, padding.top + 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Personas que irán a',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nombreEvento,
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PantallaLocalPerfil(
                        avatarUrl: avatarLocal,
                        nombreLocal: nombreLocal,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoSuperficie,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.5)),
                          ),
                          child: ClipOval(
                            child: _esAsset(avatarLocal)
                                ? Image.asset(avatarLocal, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _iconLocal())
                                : CachedNetworkImage(imageUrl: avatarLocal, fit: BoxFit.cover, errorWidget: (_, __, ___) => _iconLocal()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          nombreLocal,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(CupertinoIcons.chevron_right, size: 16, color: ColoresApp.textoSecundario),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_cargando)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CupertinoActivityIndicator(
                        color: ColoresApp.principalMarca,
                        radius: 16,
                      ),
                    ),
                  )
                else if (personas.isEmpty && squads.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.person_2,
                              size: 48, color: ColoresApp.textoSecundario),
                          const SizedBox(height: 12),
                          Text(
                            'Todavía no hay nadie confirmado',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¡Sé el primero en sumarte al pool!',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ColoresApp.textoSecundario,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Sección Personas que van a este evento
                  if (personas.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 12),
                      child: Text(
                        'Personas que van a este evento',
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    _GridPersonasAlternado(
                      personas: personas,
                      onTap: (p) => _mostrarBottomSheetPersona(context, p),
                    ),
                    const SizedBox(height: 32),
                  ],
                  // Sección Squads (más relevancia)
                  if (squads.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 12),
                      child: Row(
                        children: [
                          Text(
                            '👥 Squads del evento',
                            style: GoogleFonts.baloo2(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _GridSquadsAlternado(
                      squads: squads,
                      onTap: (s) => _mostrarBottomSheetSquad(context, s),
                    ),
                  ],
                ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconLocal() => Icon(CupertinoIcons.building_2_fill, size: 16, color: ColoresApp.textoSecundario);

  Widget _placeholderBanner() => Container(
        color: ColoresApp.fondoSuperficie,
        child: Icon(CupertinoIcons.photo, size: 64, color: ColoresApp.textoSecundario),
      );

  void _mostrarBottomSheetSquad(BuildContext context, Map<String, dynamic> squad) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _BottomSheetSquad(
        squad: squad,
        idEvento: widget.idEvento,
        nombreEvento: widget.nombreEvento,
      ),
    );
  }

  void _mostrarBottomSheetPersona(BuildContext context, Map<String, dynamic> persona) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _BottomSheetPersona(
        persona: persona,
        idEvento: widget.idEvento,
        nombreEvento: widget.nombreEvento,
      ),
    );
  }
}

/// Constantes del grid: tamaño fijo de celdas, el contenido se amolda.
const double _gridEspaciado = 16.0;
const double _gridCeldaAltura = 215.0;

/// Grid personas: filas 3-2-3-2, celdas fijas, contenido adaptado, siempre centrado.
class _GridPersonasAlternado extends StatelessWidget {
  final List<Map<String, dynamic>> personas;
  final void Function(Map<String, dynamic>) onTap;

  const _GridPersonasAlternado({required this.personas, required this.onTap});

  List<List<int>> _filasAlternadas(int n) {
    final filas = <List<int>>[];
    var i = 0;
    var colCount = 3;
    while (i < n) {
      final cols = colCount;
      final fila = <int>[];
      for (var c = 0; c < cols && i < n; c++) {
        fila.add(i++);
      }
      filas.add(fila);
      colCount = colCount == 3 ? 2 : 3;
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 40;
    final filas = _filasAlternadas(personas.length);
    final tamCelda = (w - _gridEspaciado * 2) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: filas.map((indices) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indices.map((idx) {
              final p = personas[idx];
              return Padding(
                padding: EdgeInsets.only(right: idx < indices.length - 1 ? _gridEspaciado : 0),
                child: SizedBox(
                  width: tamCelda,
                  height: _gridCeldaAltura,
                  child: _CeldaPersonaSoloAvatar(
                    persona: p,
                    tamCelda: tamCelda,
                    onTap: () => onTap(p),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Celda persona: contenido amoldado a la celda fija (avatar + burbuja).
class _CeldaPersonaSoloAvatar extends StatelessWidget {
  final Map<String, dynamic> persona;
  final double tamCelda;
  final VoidCallback onTap;

  const _CeldaPersonaSoloAvatar({
    required this.persona,
    required this.tamCelda,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = persona['avatar'] as String? ?? '';
    final estado = persona['estado'] as String? ?? '';
    final username = persona['username'] as String? ?? '';
    final avatarSize = tamCelda * 0.9;
    final maxBurbuja = tamCelda - 8;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (username.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBurbuja),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ColoresApp.principalMarca.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.4), width: 1),
                    ),
                    child: Text(
                      username,
                      style: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.w700, color: ColoresApp.principalMarca),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.6), width: 2),
              ),
              child: _AvatarRed(url: avatar, size: avatarSize),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBurbuja),
              child: BurbujaEstado(
                texto: estado,
                fontSize: 11,
                maxWidth: maxBurbuja,
                maxLines: 2,
                ajustarAnchoAlTexto: true,
                compacta: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid squads: filas 3-2-3-2, celdas fijas iguales, contenido adaptado, siempre centrado.
class _GridSquadsAlternado extends StatelessWidget {
  final List<Map<String, dynamic>> squads;
  final void Function(Map<String, dynamic>) onTap;

  const _GridSquadsAlternado({required this.squads, required this.onTap});

  List<List<int>> _filasAlternadas(int n) {
    final filas = <List<int>>[];
    var i = 0;
    var colCount = 3;
    while (i < n) {
      final cols = colCount;
      final fila = <int>[];
      for (var c = 0; c < cols && i < n; c++) {
        fila.add(i++);
      }
      filas.add(fila);
      colCount = colCount == 3 ? 2 : 3;
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 40;
    final filas = _filasAlternadas(squads.length);
    final tamCelda = (w - _gridEspaciado * 2) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: filas.map((indices) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indices.map((idx) {
              final s = squads[idx];
              return Padding(
                padding: EdgeInsets.only(right: idx < indices.length - 1 ? _gridEspaciado : 0),
                child: SizedBox(
                  width: tamCelda,
                  height: _gridCeldaAltura,
                  child: _CeldaSquadGrid(
                    squad: s,
                    tamCelda: tamCelda,
                    onTap: () => onTap(s),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Celda squad: nombre, avatar stack, burbuja. Contenido amoldado a celda fija.
class _CeldaSquadGrid extends StatelessWidget {
  final Map<String, dynamic> squad;
  final double tamCelda;
  final VoidCallback onTap;

  const _CeldaSquadGrid({
    required this.squad,
    required this.tamCelda,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final miembros = List<Map<String, dynamic>>.from(squad['miembros'] as List? ?? []);
    const mostrar = 3;
    final visible = miembros.length > mostrar ? mostrar : miembros.length;
    final overflow = miembros.length - visible;
    final nombre = squad['nombre'] as String? ?? 'Squad';
    final estado = squad['estado'] as String? ?? '';
    final maxBurbuja = tamCelda - 8;
    const avatarStackSize = 48.0;
    final stackWidth = avatarStackSize * 1.6;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 40,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBurbuja),
                  child: Text(
                    nombre,
                    style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w700, color: ColoresApp.textoPrincipal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: stackWidth,
                height: avatarStackSize + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                children: [
                  for (var i = visible - 1; i >= 0; i--)
                    Positioned(
                      left: i * 20.0,
                      child: Container(
                        width: avatarStackSize,
                        height: avatarStackSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ColoresApp.fondoPrincipal, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _AvatarRed(
                          url: miembros[i]['avatar'] as String? ?? '',
                          size: avatarStackSize,
                        ),
                      ),
                    ),
                  if (overflow > 0)
                    Positioned(
                      left: 64,
                      top: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ColoresApp.fondoPrincipal,
                          border: Border.all(color: ColoresApp.fondoPrincipal, width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            '+$overflow',
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBurbuja),
              child: BurbujaEstado(
                texto: estado,
                fontSize: 11,
                maxWidth: maxBurbuja,
                maxLines: 2,
                ajustarAnchoAlTexto: true,
                compacta: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRed extends StatelessWidget {
  final String url;
  final double size;

  const _AvatarRed({required this.url, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: ColoresApp.fondoSuperficie,
        child: Icon(CupertinoIcons.person_fill, size: size * 0.5, color: ColoresApp.textoSecundario),
      );
}

class _BottomSheetSquad extends StatelessWidget {
  final Map<String, dynamic> squad;
  final String idEvento;
  final String nombreEvento;

  const _BottomSheetSquad({
    required this.squad,
    required this.idEvento,
    required this.nombreEvento,
  });

  void _abrirPersona(BuildContext context, Map<String, dynamic> m) {
    final persona = {
      'id_usuario': m['id_usuario'],
      'nombre': m['nombre'],
      'username': m['username'] ?? '@user',
      'estado': m['estado'] ?? '',
      'avatar': m['avatar'],
      'edad': m['edad'],
      'instagram_url': m['instagram_url'] ?? '',
      'tiktok_url': m['tiktok_url'] ?? '',
      'esDeSquad': true,
      'squad': squad['nombre'],
    };
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _BottomSheetPersona(
        persona: persona,
        idEvento: idEvento,
        nombreEvento: nombreEvento,
      ),
    );
  }

  void _verSquad(BuildContext context) {
    final s = squad;
    final miembros = List<Map<String, dynamic>>.from(s['miembros'] as List? ?? []);
    final avatares = miembros.map((m) => m['avatar'] as String? ?? '').toList();
    final squadParaPerfil = {
      ...s,
      'miembros': miembros.length,
      'miembrosAvatares': avatares,
      'descripcion': s['descripcion'] ?? 'Grupo del pool del evento',
      'avatar': s['avatar'] ?? (miembros.isNotEmpty ? miembros.first['avatar'] : 'https://i.pravatar.cc/200?img=30'),
      'username': s['username'] ?? '@${(s['nombre'] as String? ?? 'squad').toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}',
    };
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilSquads(
          squad: squadParaPerfil,
          estadoRelacion: EstadoRelacionSquad.ninguno,
          rompehieloOrigen: RompehieloOrigen.pool,
          rompehieloIdEvento: idEvento,
          rompehieloNombreEvento: nombreEvento,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final miembros = List<Map<String, dynamic>>.from(squad['miembros'] as List? ?? []);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: SuperficiesApp.bottomSheet(topRadius: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  children: [
                    Text(
                      squad['nombre'] as String? ?? 'Squad',
                      style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    BurbujaEstado(
                      texto: squad['estado'] as String? ?? '',
                      fontSize: 14,
                      ajustarAnchoAlTexto: true,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _verSquad(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: ColoresApp.principalMarca, width: 2),
                        ),
                        child: Text(
                          'Ver squad',
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.principalMarca,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '👤 Miembros (${miembros.length})',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(miembros.length, (index) {
                    final m = miembros[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _abrirPersona(context, m),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColoresApp.fondoPrincipal,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              _AvatarRed(url: m['avatar'] as String? ?? '', size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m['nombre'] as String? ?? 'Miembro',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: ColoresApp.textoPrincipal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m['username'] as String? ?? '',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _igColor = Color(0xFFE1306C);
const Color _tiktokColor = Color(0xFF00F2EA);

class _BottomSheetPersona extends StatefulWidget {
  final Map<String, dynamic> persona;
  final String idEvento;
  final String nombreEvento;

  const _BottomSheetPersona({
    required this.persona,
    required this.idEvento,
    required this.nombreEvento,
  });

  @override
  State<_BottomSheetPersona> createState() => _BottomSheetPersonaState();
}

class _BottomSheetPersonaState extends State<_BottomSheetPersona> {
  final ServicioAmigos _srvAmigos = ServicioAmigos();
  bool _solicitudEnviada = false;
  bool _enviando = false;

  Future<void> _agregarAmigo() async {
    final idUsuario = widget.persona['id_usuario']?.toString();
    if (idUsuario == null || idUsuario.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    final estado = await _srvAmigos.solicitar(idUsuario);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _solicitudEnviada = estado != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final persona = widget.persona;
    final nombre = persona['nombre'] as String? ?? 'Usuario';

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: SuperficiesApp.bottomSheet(topRadius: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ColoresApp.principalMarca, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: ColoresApp.principalMarca.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _AvatarRed(url: persona['avatar'] as String? ?? '', size: 100),
                    ),
                    const SizedBox(height: 12),
                    BurbujaEstado(
                      texto: persona['estado'] as String? ?? '',
                      fontSize: 14,
                      ajustarAnchoAlTexto: true,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        final usuario = {
                          'id_usuario': persona['id_usuario'],
                          'nombre': persona['nombre'],
                          'username': persona['username'] ?? '@usuario',
                          'avatar': persona['avatar'],
                          'estado': persona['estado'] ?? '',
                          'edad': persona['edad'],
                          'instagram_url': persona['instagram_url'] ?? '',
                          'tiktok_url': persona['tiktok_url'] ?? '',
                        };
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          CupertinoPageRoute(
                            builder: (_) => PantallaPerfilUsuarios(
                              usuario: usuario,
                              estadoRelacion: EstadoRelacionUsuario.ninguno,
                              rompehieloOrigen: RompehieloOrigen.pool,
                              rompehieloIdEvento: widget.idEvento,
                              rompehieloNombreEvento: widget.nombreEvento,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: ColoresApp.principalMarca, width: 2),
                        ),
                        child: Text(
                          'Ver perfil',
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.principalMarca,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nombre,
                      style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoPrincipal,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        '${persona['edad'] ?? '—'} años',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    if (persona['esDeSquad'] == true) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: ColoresApp.promoMarca.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: ColoresApp.promoMarca.withOpacity(0.5)),
                        ),
                        child: Text(
                          'Squad: ${persona['squad']}',
                          style: GoogleFonts.baloo2(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.promoMarca),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Builder(builder: (context) {
                final tiktokUrl = (persona['tiktok_url'] as String?)?.trim() ?? '';
                final igUrl = (persona['instagram_url'] as String?)?.trim() ?? '';
                final tieneId = (persona['id_usuario']?.toString() ?? '').isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      if (tiktokUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _abrirUrl(tiktokUrl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: ColoresApp.fondoPrincipal,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _tiktokColor, width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(FontAwesomeIcons.tiktok, size: 20, color: _tiktokColor),
                                const SizedBox(width: 10),
                                Text(
                                  'Ver TikTok',
                                  style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoPrincipal),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (igUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _abrirUrl(igUrl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: ColoresApp.fondoPrincipal,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _igColor, width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(FontAwesomeIcons.instagram, size: 20, color: _igColor),
                                const SizedBox(width: 10),
                                Text(
                                  'Ver Instagram',
                                  style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoPrincipal),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (tieneId)
                        GestureDetector(
                          onTap: (_solicitudEnviada || _enviando) ? null : _agregarAmigo,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _solicitudEnviada ? Colors.transparent : ColoresApp.principalMarca,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: ColoresApp.principalMarca, width: 2),
                            ),
                            child: _enviando
                                ? Center(
                                    child: CupertinoActivityIndicator(color: ColoresApp.principalMarca),
                                  )
                                : _solicitudEnviada
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(CupertinoIcons.checkmark_circle_fill, size: 20, color: ColoresApp.principalMarca),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Solicitud enviada',
                                            style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.principalMarca),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(CupertinoIcons.person_add, size: 20, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Agregar amigo',
                                            style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
