/// Modal para elegir identidad al iniciar o continuar un rompehielo.

library;



import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/cupertino.dart';

import 'package:google_fonts/google_fonts.dart';



import '../core/constants.dart';

import '../core/rompehielo_navegacion.dart';

import '../models/rompehielo.dart';

import '../models/social.dart';

import 'social_ui.dart';



class EleccionIdentidadRompehielo {

  final String? idGrupoActor;

  final Map<String, dynamic>? squadMap;



  const EleccionIdentidadRompehielo({this.idGrupoActor, this.squadMap});

}



class RompehieloModalContexto {

  final String miAvatar;

  final String miUsername;



  const RompehieloModalContexto({

    required this.miAvatar,

    required this.miUsername,

  });

}



class RompehieloOpcionResult {

  final bool esContinuar;

  final RompehieloInvolucramiento? involucramiento;

  final String? idGrupoActor;

  final Map<String, dynamic>? squadMap;



  RompehieloOpcionResult.continuar(RompehieloInvolucramiento h)

      : esContinuar = true,

        involucramiento = h,

        idGrupoActor = h.idGrupoActor,

        squadMap = null;



  const RompehieloOpcionResult.nuevo({this.idGrupoActor, this.squadMap})

      : esContinuar = false,

        involucramiento = null;

}



Future<RompehieloOpcionResult?> mostrarModalOpcionesRompehielo(

  BuildContext context, {

  required RompehieloModalContexto contexto,

  required List<RompehieloInvolucramiento> hilosActivos,

  required List<SquadResumen> misSquads,

  required List<SquadResumen> squadsNuevos,

  required bool puedeNuevoYo,

}) {

  return showCupertinoModalPopup<RompehieloOpcionResult>(

    context: context,

    builder: (ctx) => _ModalOpcionesRompehielo(

      contexto: contexto,

      hilosActivos: hilosActivos,

      misSquads: misSquads,

      squadsNuevos: squadsNuevos,

      puedeNuevoYo: puedeNuevoYo,

    ),

  );

}



Future<EleccionIdentidadRompehielo?> mostrarModalIdentidadRompehielo(

  BuildContext context, {

  required RompehieloModalContexto contexto,

  required List<SquadResumen> squads,

}) {

  return showCupertinoModalPopup<EleccionIdentidadRompehielo>(

    context: context,

    builder: (ctx) => _ModalIniciarRompehielo(

      contexto: contexto,

      squads: squads,

      onElegir: (id, map) {

        Navigator.pop(

          ctx,

          EleccionIdentidadRompehielo(idGrupoActor: id, squadMap: map),

        );

      },

    ),

  );

}



Future<RompehieloInvolucramiento?> mostrarModalElegirHiloRompehielo(

  BuildContext context, {

  required RompehieloModalContexto contexto,

  required List<RompehieloInvolucramiento> hilos,

  required List<SquadResumen> misSquads,

}) {

  return showCupertinoModalPopup<RompehieloInvolucramiento>(

    context: context,

    builder: (ctx) => _ModalElegirHiloRompehielo(

      contexto: contexto,

      hilos: hilos,

      misSquads: misSquads,

    ),

  );

}



class _ShellModalRompehielo extends StatelessWidget {

  const _ShellModalRompehielo({

    required this.cuerpo,

    this.mostrarConfirmar = true,

    this.puedeConfirmar = false,

    this.textoBoton = 'Continuar',

    this.onConfirmar,

  });



  final Widget cuerpo;

  final bool mostrarConfirmar;

  final bool puedeConfirmar;

  final String textoBoton;

  final VoidCallback? onConfirmar;



  @override

  Widget build(BuildContext context) {

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(

      constraints: BoxConstraints(

        maxHeight: MediaQuery.sizeOf(context).height * 0.84,

      ),

      decoration: BoxDecoration(

        color: ColoresApp.fondoPrincipal,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          const SizedBox(height: 10),

          Container(

            width: 36,

            height: 4,

            decoration: BoxDecoration(

              color: ColoresApp.textoSecundario.withValues(alpha: 0.35),

              borderRadius: BorderRadius.circular(2),

            ),

          ),

          Flexible(

            child: SingleChildScrollView(

              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),

              child: cuerpo,

            ),

          ),

          Padding(

            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),

            child: Row(

              children: [

                Expanded(

                  child: CupertinoButton(

                    padding: const EdgeInsets.symmetric(vertical: 14),

                    color: ColoresApp.fondoSuperficie,

                    borderRadius: BorderRadius.circular(14),

                    onPressed: () => Navigator.pop(context),

                    child: Text(

                      'Cancelar',

                      style: GoogleFonts.baloo2(

                        fontWeight: FontWeight.w700,

                        color: ColoresApp.textoSecundario,

                      ),

                    ),

                  ),

                ),

                if (mostrarConfirmar) ...[

                  const SizedBox(width: 12),

                  Expanded(

                    child: CupertinoButton(

                      padding: const EdgeInsets.symmetric(vertical: 14),

                      color: puedeConfirmar

                          ? ColoresApp.principalMarca

                          : ColoresApp.fondoSuperficie,

                      borderRadius: BorderRadius.circular(14),

                      onPressed: puedeConfirmar ? onConfirmar : null,

                      child: Text(

                        textoBoton,

                        style: GoogleFonts.baloo2(

                          fontWeight: FontWeight.w800,

                          color: puedeConfirmar

                              ? CupertinoColors.white

                              : ColoresApp.textoSecundario,

                        ),

                      ),

                    ),

                  ),

                ],

              ],

            ),

          ),

        ],

      ),

    );

  }

}



class _TituloSeccionModal extends StatelessWidget {

  const _TituloSeccionModal({required this.titulo, this.primaria = true});



  final String titulo;

  final bool primaria;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: EdgeInsets.only(bottom: primaria ? 10 : 8, top: primaria ? 2 : 0),

      child: Text(

        titulo,

        style: GoogleFonts.baloo2(

          fontSize: primaria ? 16 : 14,

          fontWeight: primaria ? FontWeight.w900 : FontWeight.w800,

          color: primaria

              ? ColoresApp.textoPrincipal

              : ColoresApp.textoSecundario,

          height: 1.2,

        ),

      ),

    );

  }

}



class _SeparadorSeccionesModal extends StatelessWidget {

  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 18),

      child: Row(

        children: [

          Expanded(

            child: Container(

              height: 1,

              color: ColoresApp.textoSecundario.withValues(alpha: 0.18),

            ),

          ),

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 12),

            child: Text(

              'o',

              style: GoogleFonts.baloo2(

                fontSize: 12,

                fontWeight: FontWeight.w700,

                color: ColoresApp.textoSecundario.withValues(alpha: 0.55),

              ),

            ),

          ),

          Expanded(

            child: Container(

              height: 1,

              color: ColoresApp.textoSecundario.withValues(alpha: 0.18),

            ),

          ),

        ],

      ),

    );

  }

}



class _CardContinuarRompehielo extends StatelessWidget {

  const _CardContinuarRompehielo({

    required this.onTap,

    required this.titulo,

    required this.subtitulo,

    required this.leading,

    this.badge,

    this.miembrosAvatares = const [],

  });



  final VoidCallback onTap;

  final String titulo;

  final String subtitulo;

  final Widget leading;

  final String? badge;

  final List<String> miembrosAvatares;



  @override

  Widget build(BuildContext context) {

    final accent = ColoresApp.principalMarca;

    return GestureDetector(

      onTap: onTap,

      child: Container(

        margin: const EdgeInsets.only(bottom: 10),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [

              ColoresApp.fondoSuperficie.withValues(alpha: 0.95),

              accent.withValues(alpha: 0.12),

            ],

          ),

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: accent.withValues(alpha: 0.28)),

          boxShadow: [

            BoxShadow(

              color: accent.withValues(alpha: 0.12),

              blurRadius: 12,

              offset: const Offset(0, 3),

            ),

          ],

        ),

        child: Row(

          children: [

            leading,

            const SizedBox(width: 12),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    titulo,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: GoogleFonts.baloo2(

                      fontSize: 16,

                      fontWeight: FontWeight.w900,

                      color: ColoresApp.textoPrincipal,

                    ),

                  ),

                  const SizedBox(height: 2),

                  Text(

                    subtitulo,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: GoogleFonts.baloo2(

                      fontSize: 13,

                      fontWeight: FontWeight.w600,

                      color: ColoresApp.textoSecundario,

                    ),

                  ),

                  if (miembrosAvatares.isNotEmpty) ...[

                    const SizedBox(height: 6),

                    _StackAvataresMiembros(urls: miembrosAvatares),

                  ],

                ],

              ),

            ),

            if (badge != null) ...[

              const SizedBox(width: 8),

              _BadgeEstadoRompehielo(texto: badge!),

            ],

            const SizedBox(width: 6),

            Icon(

              CupertinoIcons.chevron_right,

              color: accent.withValues(alpha: 0.75),

              size: 18,

            ),

          ],

        ),

      ),

    );

  }

}



class _CardIdentidadRompehielo extends StatelessWidget {

  const _CardIdentidadRompehielo({

    required this.seleccionado,

    required this.onTap,

    required this.titulo,

    required this.subtitulo,

    required this.leading,

    this.miembrosAvatares = const [],

  });



  final bool seleccionado;

  final VoidCallback onTap;

  final String titulo;

  final String subtitulo;

  final Widget leading;

  final List<String> miembrosAvatares;



  @override

  Widget build(BuildContext context) {

    final accent = ColoresApp.principalMarca;

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 180),

        margin: const EdgeInsets.only(bottom: 8),

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(

          color: seleccionado

              ? accent.withValues(alpha: 0.12)

              : ColoresApp.fondoSuperficie.withValues(alpha: 0.85),

          borderRadius: BorderRadius.circular(16),

          border: Border.all(

            color: seleccionado

                ? accent.withValues(alpha: 0.50)

                : accent.withValues(alpha: 0.12),

            width: seleccionado ? 1.5 : 1,

          ),

        ),

        child: Row(

          children: [

            leading,

            const SizedBox(width: 12),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    titulo,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: GoogleFonts.baloo2(

                      fontSize: 14,

                      fontWeight: FontWeight.w900,

                      color: ColoresApp.textoPrincipal,

                    ),

                  ),

                  const SizedBox(height: 2),

                  Text(

                    subtitulo,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: GoogleFonts.baloo2(

                      fontSize: 12,

                      fontWeight: FontWeight.w600,

                      color: ColoresApp.textoSecundario,

                    ),

                  ),

                  if (miembrosAvatares.isNotEmpty) ...[

                    const SizedBox(height: 6),

                    _StackAvataresMiembros(urls: miembrosAvatares),

                  ],

                ],

              ),

            ),

            Icon(

              seleccionado

                  ? CupertinoIcons.check_mark_circled_solid

                  : CupertinoIcons.circle,

              color: seleccionado

                  ? accent

                  : ColoresApp.textoSecundario.withValues(alpha: 0.40),

              size: 22,

            ),

          ],

        ),

      ),

    );

  }

}



class _BadgeEstadoRompehielo extends StatelessWidget {

  const _BadgeEstadoRompehielo({required this.texto});



  final String texto;



  @override

  Widget build(BuildContext context) {

    final urgente = texto.contains('Responder') || texto.contains('Replicar');

    final color = urgente

        ? ColoresApp.principalMarca

        : ColoresApp.textoSecundario;

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(

        color: color.withValues(alpha: urgente ? 0.16 : 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: color.withValues(alpha: 0.35)),

      ),

      child: Text(

        texto,

        style: GoogleFonts.baloo2(

          fontSize: 10,

          fontWeight: FontWeight.w800,

          color: urgente ? ColoresApp.principalMarca : ColoresApp.textoSecundario,

        ),

      ),

    );

  }

}



class _AvatarSquadModal extends StatelessWidget {

  const _AvatarSquadModal({required this.url, this.size = 48});



  final String url;

  final double size;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: size,

      height: size,

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(size * 0.22),

        border: Border.all(

          color: ColoresApp.principalMarca.withValues(alpha: 0.40),

          width: 1.4,

        ),

      ),

      clipBehavior: Clip.antiAlias,

      child: url.isEmpty

          ? ColoredBox(

              color: ColoresApp.fondoSuperficie,

              child: Icon(

                CupertinoIcons.person_3_fill,

                color: ColoresApp.textoSecundario,

                size: size * 0.42,

              ),

            )

          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),

    );

  }

}



class _StackAvataresMiembros extends StatelessWidget {

  const _StackAvataresMiembros({required this.urls});



  final List<String> urls;



  @override

  Widget build(BuildContext context) {

    final visibles = urls.where((u) => u.isNotEmpty).take(4).toList();

    if (visibles.isEmpty) return const SizedBox.shrink();

    const size = 22.0;

    const overlap = 14.0;

    return SizedBox(

      height: size,

      width: size + (visibles.length - 1) * overlap,

      child: Stack(

        clipBehavior: Clip.none,

        children: [

          for (var i = 0; i < visibles.length; i++)

            Positioned(

              left: i * overlap,

              child: Container(

                width: size,

                height: size,

                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  border: Border.all(

                    color: ColoresApp.fondoPrincipal,

                    width: 1.5,

                  ),

                ),

                clipBehavior: Clip.antiAlias,

                child: CachedNetworkImage(

                  imageUrl: visibles[i],

                  fit: BoxFit.cover,

                  errorWidget: (context, url, error) => Icon(

                    CupertinoIcons.person_fill,

                    size: 12,

                    color: ColoresApp.textoSecundario,

                  ),

                ),

              ),

            ),

        ],

      ),

    );

  }

}



Map<String, dynamic> _mapSquad(SquadResumen s) {

  final user = s.username ?? '';

  return {

    'id_grupo': s.idGrupo,

    'nombre': s.nombre,

    'username': user.startsWith('@') ? user : '@$user',

    'avatar': s.portadaUrl ?? '',

    'miembrosAvatares': s.avataresMiembros,

  };

}



String _subtituloEstado(RompehieloEstado e) {

  if (e.debeResponder) return 'Responder';

  if (e.debeReplicar) return 'Replicar';

  if (e.puedeActuar) return 'Tu turno';

  return 'En curso';

}



String _usernameSquad(SquadResumen s) {

  final u = s.username?.replaceAll('@', '').trim() ?? '';

  return u.isEmpty ? 'Squad' : '@$u';

}



SquadResumen? _squadPorId(List<SquadResumen> lista, String? id) {

  if (id == null) return null;

  return lista.where((x) => x.idGrupo == id).firstOrNull;

}



class _ModalOpcionesRompehielo extends StatefulWidget {

  const _ModalOpcionesRompehielo({

    required this.contexto,

    required this.hilosActivos,

    required this.misSquads,

    required this.squadsNuevos,

    required this.puedeNuevoYo,

  });



  final RompehieloModalContexto contexto;

  final List<RompehieloInvolucramiento> hilosActivos;

  final List<SquadResumen> misSquads;

  final List<SquadResumen> squadsNuevos;

  final bool puedeNuevoYo;



  @override

  State<_ModalOpcionesRompehielo> createState() =>

      _ModalOpcionesRompehieloState();

}



class _ModalOpcionesRompehieloState extends State<_ModalOpcionesRompehielo> {

  String? _selKey;



  bool get _hayNuevas =>

      widget.puedeNuevoYo || widget.squadsNuevos.isNotEmpty;



  void _continuar(RompehieloInvolucramiento h) {

    Navigator.pop(context, RompehieloOpcionResult.continuar(h));

  }



  void _confirmarNueva() {

    if (_selKey == null) return;

    if (_selKey == 'nuevo:yo') {

      Navigator.pop(context, const RompehieloOpcionResult.nuevo());

      return;

    }

    if (_selKey!.startsWith('nuevo:')) {

      final id = _selKey!.substring(6);

      final s = widget.squadsNuevos.where((x) => x.idGrupo == id).firstOrNull;

      if (s != null) {

        Navigator.pop(

          context,

          RompehieloOpcionResult.nuevo(

            idGrupoActor: s.idGrupo,

            squadMap: _mapSquad(s),

          ),

        );

      }

    }

  }



  Widget _cardContinuarYo(RompehieloInvolucramiento h) {

    final ctx = widget.contexto;

    return _CardContinuarRompehielo(

      onTap: () => _continuar(h),

      titulo: 'Mi perfil',

      subtitulo: ctx.miUsername,

      badge: _subtituloEstado(h.estado),

      leading: AvatarSocial(url: ctx.miAvatar, size: 48),

    );

  }



  Widget _cardContinuarSquad(SquadResumen s, RompehieloInvolucramiento h) {

    return _CardContinuarRompehielo(

      onTap: () => _continuar(h),

      titulo: s.nombre,

      subtitulo: _usernameSquad(s),

      badge: _subtituloEstado(h.estado),

      miembrosAvatares: s.avataresMiembros,

      leading: _AvatarSquadModal(url: s.portadaUrl?.trim() ?? '', size: 48),

    );

  }



  @override

  Widget build(BuildContext context) {

    final ctx = widget.contexto;



    return _ShellModalRompehielo(

      mostrarConfirmar: _hayNuevas,

      puedeConfirmar: _selKey != null && _selKey!.startsWith('nuevo:'),

      textoBoton: 'Iniciar nueva',

      onConfirmar: _confirmarNueva,

      cuerpo: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          if (widget.hilosActivos.isNotEmpty) ...[

            const _TituloSeccionModal(

              titulo: 'Continuar conversación como:',

              primaria: true,

            ),

            ...widget.hilosActivos.map((h) {

              if (h.idGrupoActor == null) return _cardContinuarYo(h);

              final s = _squadPorId(widget.misSquads, h.idGrupoActor);

              if (s == null) {

                return _CardContinuarRompehielo(

                  onTap: () => _continuar(h),

                  titulo: h.etiqueta,

                  subtitulo: 'Como squad',

                  badge: _subtituloEstado(h.estado),

                  leading: const _AvatarSquadModal(url: '', size: 48),

                );

              }

              return _cardContinuarSquad(s, h);

            }),

          ],

          if (widget.hilosActivos.isNotEmpty && _hayNuevas)

            _SeparadorSeccionesModal(),

          if (_hayNuevas) ...[

            const _TituloSeccionModal(

              titulo: 'Iniciar nueva conversación como:',

              primaria: false,

            ),

            if (widget.puedeNuevoYo)

              _CardIdentidadRompehielo(

                seleccionado: _selKey == 'nuevo:yo',

                onTap: () => setState(() => _selKey = 'nuevo:yo'),

                titulo: 'Mi perfil',

                subtitulo: ctx.miUsername,

                leading: AvatarSocial(url: ctx.miAvatar, size: 44),

              ),

            ...widget.squadsNuevos.map((s) {

              return _CardIdentidadRompehielo(

                seleccionado: _selKey == 'nuevo:${s.idGrupo}',

                onTap: () => setState(() => _selKey = 'nuevo:${s.idGrupo}'),

                titulo: s.nombre,

                subtitulo: _usernameSquad(s),

                miembrosAvatares: s.avataresMiembros,

                leading: _AvatarSquadModal(

                  url: s.portadaUrl?.trim() ?? '',

                  size: 44,

                ),

              );

            }),

          ],

        ],

      ),

    );

  }

}



class _ModalIniciarRompehielo extends StatefulWidget {

  const _ModalIniciarRompehielo({

    required this.contexto,

    required this.squads,

    required this.onElegir,

  });



  final RompehieloModalContexto contexto;

  final List<SquadResumen> squads;

  final void Function(String? idGrupo, Map<String, dynamic>? squadMap) onElegir;



  @override

  State<_ModalIniciarRompehielo> createState() =>

      _ModalIniciarRompehieloState();

}



class _ModalIniciarRompehieloState extends State<_ModalIniciarRompehielo> {

  String? _selId;



  void _confirmar() {

    if (_selId == null || _selId == '__yo__') {

      widget.onElegir(null, null);

    } else {

      final s = widget.squads.where((x) => x.idGrupo == _selId).firstOrNull;

      if (s != null) widget.onElegir(s.idGrupo, _mapSquad(s));

    }

  }



  @override

  Widget build(BuildContext context) {

    final ctx = widget.contexto;



    return _ShellModalRompehielo(

      mostrarConfirmar: true,

      puedeConfirmar: _selId != null,

      textoBoton: 'Romper el hielo',

      onConfirmar: _confirmar,

      cuerpo: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          const _TituloSeccionModal(

            titulo: 'Romper el hielo como:',

            primaria: true,

          ),

          _CardIdentidadRompehielo(

            seleccionado: _selId == '__yo__',

            onTap: () => setState(() => _selId = '__yo__'),

            titulo: 'Mi perfil',

            subtitulo: ctx.miUsername,

            leading: AvatarSocial(url: ctx.miAvatar, size: 44),

          ),

          ...widget.squads.map((s) {

            return _CardIdentidadRompehielo(

              seleccionado: _selId == s.idGrupo,

              onTap: () => setState(() => _selId = s.idGrupo),

              titulo: s.nombre,

              subtitulo: _usernameSquad(s),

              miembrosAvatares: s.avataresMiembros,

              leading: _AvatarSquadModal(

                url: s.portadaUrl?.trim() ?? '',

                size: 44,

              ),

            );

          }),

        ],

      ),

    );

  }

}



class _ModalElegirHiloRompehielo extends StatelessWidget {

  const _ModalElegirHiloRompehielo({

    required this.contexto,

    required this.hilos,

    required this.misSquads,

  });



  final RompehieloModalContexto contexto;

  final List<RompehieloInvolucramiento> hilos;

  final List<SquadResumen> misSquads;



  @override

  Widget build(BuildContext context) {

    final ctx = contexto;



    return _ShellModalRompehielo(

      mostrarConfirmar: false,

      cuerpo: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          const _TituloSeccionModal(

            titulo: 'Continuar conversación como:',

            primaria: true,

          ),

          ...hilos.map((h) {

            final badge = _subtituloEstado(h.estado);

            if (h.idGrupoActor == null) {

              return _CardContinuarRompehielo(

                onTap: () => Navigator.pop(context, h),

                titulo: 'Mi perfil',

                subtitulo: ctx.miUsername,

                badge: badge,

                leading: AvatarSocial(url: ctx.miAvatar, size: 48),

              );

            }

            final s = _squadPorId(misSquads, h.idGrupoActor);

            return _CardContinuarRompehielo(

              onTap: () => Navigator.pop(context, h),

              titulo: s?.nombre ?? h.etiqueta,

              subtitulo: s != null ? _usernameSquad(s) : 'Como squad',

              badge: badge,

              miembrosAvatares: s?.avataresMiembros ?? const [],

              leading: _AvatarSquadModal(

                url: s?.portadaUrl?.trim() ?? '',

                size: 48,

              ),

            );

          }),

        ],

      ),

    );

  }

}


