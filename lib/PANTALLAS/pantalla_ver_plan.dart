library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/compartir_evento.dart' show origenCompartirDesdeContexto;
import '../core/compartir_plan.dart';
import '../core/constants.dart';
import '../core/lanzador_externo.dart';
import '../core/servicio_planes.dart';
import '../widgets/fernecito_loader.dart';
import 'pantalla_chat_plan.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_perfil_usuarios.dart';

class PantallaVerPlan extends StatefulWidget {
  const PantallaVerPlan({super.key, required this.idPlan, this.inicial});
  final String idPlan;
  final PlanComunidad? inicial;

  @override
  State<PantallaVerPlan> createState() => _PantallaVerPlanState();
}

class _PantallaVerPlanState extends State<PantallaVerPlan> {
  final _srv = ServicioPlanes();
  PlanDetalle? _detalle;
  bool _cargando = true;
  bool _uniendo = false;
  bool _pedidoOcupado = false;
  bool _changed = false;
  String? _error;

  PlanComunidad? get _plan => _detalle?.plan ?? widget.inicial;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final res = await _srv.detalle(widget.idPlan);
    if (!mounted) return;
    setState(() {
      _detalle = res.detalle;
      _error = res.detalle == null
          ? (res.error ?? 'Este plan ya no está disponible.')
          : null;
      _cargando = false;
    });
  }

  Future<void> _unirse() async {
    final plan = _plan;
    if (plan == null || !plan.puedeUnirse) return;
    String? idSquad;
    if (plan.permiteSquads) {
      idSquad = await _elegirIdentidadUnion(plan);
      if (idSquad == '__cancel__') return;
    }
    setState(() => _uniendo = true);
    try {
      final res = await _srv.solicitarUnirse(
        plan.id,
        idSquad: idSquad?.isEmpty == true ? null : idSquad,
      );
      _changed = true;
      if (!mounted) return;
      if (res == null) {
        _toast('No se pudo sumarte. Probá de nuevo.');
      } else {
        await _cargar();
        _toast(
          res.estado == 'aceptado'
              ? '¡Adentro! Ya podés chatear.'
              : 'Pedido enviado.',
        );
      }
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'sumarte'));
    } finally {
      if (mounted) setState(() => _uniendo = false);
    }
  }

  Future<String?> _elegirIdentidadUnion(PlanComunidad plan) async {
    final squads = await _srv.misSquads();
    if (!mounted) return '__cancel__';
    if (squads.isEmpty) return '';
    final accion = plan.modoLista == 'manual' ? 'solicitar' : 'unirte';
    final idSquad = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.paddingOf(ctx).bottom + 12,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                plan.modoLista == 'manual'
                    ? '¿Cómo querés solicitar unirte?'
                    : '¿Cómo te sumás?',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 10),
              _OpcionUnion(
                titulo: plan.modoLista == 'manual'
                    ? 'Solicitar solo'
                    : 'Voy solo',
                subtitulo: 'Vas a $accion con tu perfil.',
                icono: CupertinoIcons.person_fill,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final s in squads)
                _OpcionUnion(
                  titulo: plan.modoLista == 'manual'
                      ? 'Solicitar con ${s.nombre}'
                      : 'Ir con ${s.nombre}',
                  subtitulo:
                      '$accion con ${s.cantidadMiembros} miembros del squad',
                  icono: CupertinoIcons.person_3_fill,
                  onTap: () => Navigator.pop(ctx, s.idGrupo),
                ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(ctx, '__cancel__'),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (idSquad == null || idSquad == '__cancel__') return '__cancel__';
    final squad = squads.firstWhere(
      (s) => s.idGrupo == idSquad,
      orElse: () => squads.first,
    );
    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Ir con ${squad.nombre}'),
        content: Text(
          'Vas a sumar a ${squad.cantidadMiembros} '
          '${squad.cantidadMiembros == 1 ? 'persona' : 'personas'} '
          'al plan.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ir con squad'),
          ),
        ],
      ),
    );
    return confirmar == true ? idSquad : '__cancel__';
  }

  Future<bool> _gestionar(PlanMiembro miembro, String accion) async {
    final plan = _plan;
    if (plan == null) return false;
    try {
      final ok = await _srv.gestionarMiembro(
        idPlan: plan.id,
        idUsuario: miembro.idUsuario,
        accion: accion,
      );
      if (!mounted) return ok;
      if (!ok) {
        _toast('No se pudo actualizar la solicitud.');
        return false;
      }
      _changed = true;
      await _cargar();
      return true;
    } catch (e) {
      if (mounted) {
        _toast(_srv.mensajeError(e, accion: 'gestionar la solicitud'));
      }
      return false;
    }
  }

  Future<void> _abrirSolicitudes() async {
    final detalle = _detalle;
    if (detalle == null) return;
    final pendientes = detalle.miembros
        .where((m) => m.estado == 'pendiente')
        .toList(growable: false);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SolicitudesSheet(
        pendientes: pendientes,
        onAceptar: (m) => _gestionar(m, 'aceptar'),
        onRechazar: (m) => _gestionar(m, 'rechazar'),
      ),
    );
  }

  Future<void> _pedirAlLocal() async {
    final plan = _plan;
    if (plan == null) return;
    final ctrl = TextEditingController();
    final pedido = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Pedir beneficio al local'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            maxLength: 120,
            maxLines: 3,
            placeholder: 'Ej: 2x1 en tragos para el grupo',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pedido == null || pedido.trim().length < 3) return;
    setState(() => _pedidoOcupado = true);
    try {
      final ok = await _srv.pedidoLocal(plan.id, pedido.trim());
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo enviar el pedido.');
        return;
      }
      await _cargar();
      _toast('Pedido enviado al local.');
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'enviar el pedido'));
    } finally {
      if (mounted) setState(() => _pedidoOcupado = false);
    }
  }

  Future<void> _votarPedido() async {
    final plan = _plan;
    final detalle = _detalle;
    if (plan == null || detalle == null) return;
    setState(() => _pedidoOcupado = true);
    try {
      final res = await _srv.pedidoVotar(plan.id);
      if (!mounted) return;
      if (!res.ok) {
        _toast('No se pudo registrar tu voto.');
        return;
      }
      setState(() {
        _detalle = PlanDetalle(
          plan: plan.copyWith(pedidoVotos: res.votos),
          miembros: detalle.miembros,
          squads: detalle.squads,
          yaVotePedido: res.yaVote,
        );
      });
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'votar'));
    } finally {
      if (mounted) setState(() => _pedidoOcupado = false);
    }
  }

  Future<void> _salirDelPlan() async {
    final plan = _plan;
    if (plan == null || !plan.soyMiembro || plan.soyModerador) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Salir del plan?'),
        content: const Text(
          'Vas a dejar de ser parte de este plan y del chat del grupo.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _srv.salir(plan.id);
      if (!mounted) return;
      if (!res) {
        _toast('No se pudo salir del plan.');
        return;
      }
      _changed = true;
      await _cargar();
      _toast('Saliste del plan.');
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'salir del plan'));
    }
  }

  Future<void> _cancelar() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancelar plan'),
        content: const Text(
          'Se mostrará como cancelado y se avisará en el chat.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar plan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final plan = _plan;
    if (plan == null) return;
    try {
      final res = await _srv.cancelar(plan.id);
      if (res) {
        _changed = true;
        await _cargar();
      } else if (mounted) {
        _toast('No se pudo cancelar el plan. Probá de nuevo.');
      }
    } catch (e) {
      if (mounted) {
        _toast(_srv.mensajeError(e, accion: 'cancelar el plan'));
      }
    }
  }

  void _verPerfil(PlanMiembro m) {
    if (!m.perfilPublico) {
      _toast('Perfil privado · @${m.username ?? 'usuario'}');
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': m.idUsuario,
            'nombre': m.nombre,
            'username': m.username ?? '',
            'avatar': m.fotoUrl ?? '',
          },
          estadoRelacion: EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  Future<void> _compartir() async {
    final plan = _plan;
    if (plan == null) return;
    await compartirPlan(
      idPlan: plan.id,
      titulo: plan.titulo,
      nombreLocal: plan.nombreLocal,
      ciudad: plan.ciudad,
      fechaInicio: plan.fechaInicio,
      sharePositionOrigin: origenCompartirDesdeContexto(context),
      feedbackContext: context,
    );
  }

  Uri? _uriContacto(String texto) {
    final raw = texto.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    final pareceUrl =
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('wa.me/') ||
        lower.startsWith('www.wa.me/') ||
        lower.startsWith('instagram.com/') ||
        lower.startsWith('www.instagram.com/');
    if (!pareceUrl) return null;
    final normalizada =
        lower.startsWith('http://') || lower.startsWith('https://')
        ? raw
        : 'https://$raw';
    return Uri.tryParse(normalizada);
  }

  Future<void> _copiarContacto(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    _toast('Copiado al portapapeles');
  }

  Future<void> _abrirContacto(String texto) async {
    final uri = _uriContacto(texto);
    if (uri != null && await lanzarExternoConFallback(uri)) return;
    await _copiarContacto(texto);
  }

  Future<void> _localAceptarPedido() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _pedidoOcupado = true);
    try {
      final ok = await _srv.pedidoResponder(idPlan: plan.id, accion: 'aceptar');
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo aceptar.');
        return;
      }
      await _cargar();
      _toast('¡Se puso la 10!');
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'aceptar'));
    } finally {
      if (mounted) setState(() => _pedidoOcupado = false);
    }
  }

  Future<void> _localContraoferta() async {
    final plan = _plan;
    if (plan == null) return;
    final ctrl = TextEditingController();
    final texto = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Proponer otro beneficio'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            maxLength: 120,
            maxLines: 3,
            placeholder: 'Ej: 15% de descuento en birra',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (texto == null || texto.length < 3) return;
    setState(() => _pedidoOcupado = true);
    try {
      final ok = await _srv.pedidoResponder(
        idPlan: plan.id,
        accion: 'cambiar',
        contraoferta: texto,
      );
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo enviar la propuesta.');
        return;
      }
      await _cargar();
      _toast('Propuesta enviada.');
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'proponer'));
    } finally {
      if (mounted) setState(() => _pedidoOcupado = false);
    }
  }

  void _toast(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) {
      if (_cargando) {
        return const CupertinoPageScaffold(
          backgroundColor: ColoresApp.fondoPrincipal,
          child: Center(child: FernecitoLoader.inline(size: 28)),
        );
      }
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          leading: CupertinoNavigationBarBackButton(
            color: ColoresApp.principalMarca,
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'Este plan ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 14),
                CupertinoButton(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: _cargar,
                  child: Text(
                    'Reintentar',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (plan.estaFinalizado) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop(_changed);
        },
        child: CupertinoPageScaffold(
          backgroundColor: ColoresApp.fondoPrincipal,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: Colors.transparent,
            border: null,
            leading: CupertinoNavigationBarBackButton(
              color: ColoresApp.principalMarca,
              onPressed: () => Navigator.pop(context, _changed),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.archivebox,
                    size: 42,
                    color: ColoresApp.principalMarca,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Plan archivado',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Este plan ya finalizó y no tiene acciones disponibles.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 18),
                  CupertinoButton(
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => Navigator.pop(context, _changed),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.baloo2(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final portada = plan.portadaUrl;
    final color = _parseColor(plan.colorHex);
    final detalle = _detalle;
    final soloMiembros = (detalle?.miembros ?? const <PlanMiembro>[])
        .where((m) => m.estado == 'aceptado')
        .toList(growable: false);
    final pendientes =
        detalle?.miembros.where((m) => m.estado == 'pendiente').length ?? 0;
    final hayPedido = plan.hayPedidoActivo;
    final puedeVotar =
        plan.beneficioEstado == 'pedido' &&
        (plan.soyMiembro || plan.soyModerador) &&
        !(detalle?.yaVotePedido ?? false);
    final soyLocal = plan.miEstado == 'local';
    final localPuedeResponder = soyLocal && plan.beneficioEstado == 'pedido';
    final contactoValor = (plan.contactoAnfitrion ?? '').trim();
    final contactoTitulo = (plan.contactoTitulo ?? '').trim().isEmpty
        ? 'Contacto del organizador'
        : plan.contactoTitulo!.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: portada != null && portada.isNotEmpty
                        ? _FondoPlan(path: portada)
                        : ColoredBox(color: color),
                  ),
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.38),
                          Colors.black.withValues(alpha: 0.72),
                          ColoresApp.fondoPrincipal,
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context, _changed),
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                          const SizedBox(height: 114),
                          Row(
                            children: [
                              _Avatar(
                                url: plan.fotoOrganizadorUrl,
                                fallback: plan.nombreOrganizador,
                              ),
                              const SizedBox(width: 8),
                              _Avatar(
                                url: plan.fotoLocalUrl,
                                fallback: plan.nombreLocal,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  plan.esPlanLocal
                                      ? 'Plan del local · ${plan.nombreLocal}'
                                      : 'Plan de ${plan.primerNombreOrganizador} en ${plan.nombreLocal}',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 6,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plan.titulo,
                            style: GoogleFonts.baloo2(
                              fontSize: 34,
                              height: .92,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan.descripcion,
                            style: GoogleFonts.baloo2(
                              fontSize: 15.5,
                              height: 1.2,
                              color: Colors.white.withValues(alpha: 0.9),
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MetaPlanRow(
                    items: [
                      '${plan.personasAceptadas} personas',
                      'inicio ${_fmt(plan.fechaInicio)}',
                      if (plan.fechaFin != null) 'fin ${_fmt(plan.fechaFin!)}',
                      plan.modoLista == 'manual'
                          ? 'requiere aprobación'
                          : 'entrada libre',
                      if (plan.cupoMax != null)
                        '${plan.cupoUsados}/${plan.cupoMax} cupos',
                      if (plan.edadMinima != null) '+${plan.edadMinima}',
                      if (plan.soyModerador) 'Sos admin',
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (plan.chatDisponible)
                    _ActionButton(
                      texto: 'Chat del plan',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => PantallaChatPlan(plan: plan),
                            ),
                          ),
                    )
                  else if (plan.puedeUnirse)
                    _ActionButton(
                      texto: plan.modoLista == 'manual'
                          ? 'Solicitar unirme'
                          : 'Unirme al plan',
                      cargando: _uniendo,
                      onTap: _unirse,
                    )
                  else if (plan.soyMiembro)
                    _EresParteRow(
                      esAdmin: plan.soyModerador,
                      onSalir: plan.soyModerador ? null : _salirDelPlan,
                    )
                  else
                    _InfoBox(
                      titulo: plan.soyPendiente
                          ? 'Solicitud pendiente'
                          : plan.miEstado == 'expulsado'
                          ? 'Ya no podés entrar'
                          : plan.cupoLleno
                          ? 'Cupo completo'
                          : !plan.ingresoAbierto
                          ? 'Ingreso cerrado'
                          : 'No disponible',
                      texto: plan.soyPendiente
                          ? 'El admin tiene que aprobar tu solicitud.'
                          : plan.miEstado == 'expulsado'
                          ? 'Te expulsaron de este plan.'
                          : plan.cupoLleno
                          ? 'No quedan lugares disponibles.'
                          : !plan.ingresoAbierto
                          ? 'El admin cerró el ingreso de personas.'
                          : 'Este plan no acepta nuevas solicitudes.',
                    ),
                  if (hayPedido) ...[
                    const SizedBox(height: 14),
                    _PedidoBox(
                      plan: plan,
                      puedeVotar: puedeVotar,
                      yaVoto: detalle?.yaVotePedido ?? false,
                      votando: _pedidoOcupado,
                      onVotar: _votarPedido,
                      localPuedeResponder: localPuedeResponder,
                      onAceptarLocal: _localAceptarPedido,
                      onContraofertaLocal: _localContraoferta,
                    ),
                  ] else if (plan.puedePedirBeneficio) ...[
                    const SizedBox(height: 14),
                    _FilaPedirAlLocal(
                      ocupado: _pedidoOcupado,
                      onTap: _pedirAlLocal,
                    ),
                  ],
                  if (contactoValor.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ContactoCard(
                      titulo: contactoTitulo,
                      valor: contactoValor,
                      onTap: () => _abrirContacto(contactoValor),
                    ),
                  ],
                  if (plan.soyModerador && pendientes > 0) ...[
                    const SizedBox(height: 14),
                    _FilaSolicitudesPendientes(
                      cantidad: pendientes,
                      onTap: _abrirSolicitudes,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          texto: 'Ver local',
                          secundario: true,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => PantallaLocalPerfil(
                                avatarUrl: plan.fotoLocalUrl ?? '',
                                nombreLocal: plan.nombreLocal,
                                idLocal: plan.idLocal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TextActionButton(
                          icono: CupertinoIcons.share,
                          texto: 'Compartir',
                          onTap: _compartir,
                        ),
                      ),
                    ],
                  ),
                  if (plan.soyModerador) ...[
                    const SizedBox(height: 8),
                    _ActionButton(
                      texto: 'Cancelar plan',
                      secundario: true,
                      danger: true,
                      onTap: _cancelar,
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    'Participantes',
                    style: GoogleFonts.baloo2(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (soloMiembros.isEmpty)
                    _InfoBox(
                      titulo: 'Todavía no hay gente',
                      texto: 'Sé de los primeros en sumarte.',
                    )
                  else
                    _GridParticipantes(
                      personas: soloMiembros,
                      onTapPersona: _verPerfil,
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});
  final String? url;
  final String fallback;
  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return SizedBox(
      width: 50,
      height: 50,
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                memCacheWidth: 150,
                errorWidget: (_, _, _) => ColoredBox(
                  color: const Color(0xFF2B2B2B),
                  child: Center(
                    child: Text(
                      ini,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              )
            : ColoredBox(
                color: const Color(0xFF2B2B2B),
                child: Center(
                  child: Text(ini, style: const TextStyle(color: Colors.white)),
                ),
              ),
      ),
    );
  }
}

class _FondoPlan extends StatelessWidget {
  const _FondoPlan({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return CachedNetworkImage(imageUrl: path, fit: BoxFit.cover);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: GoogleFonts.baloo2(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: ColoresApp.textoSecundario,
      ),
    ),
  );
}

class _MetaPlanRow extends StatelessWidget {
  const _MetaPlanRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Text(
            items[i],
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoSecundario,
            ),
          ),
          if (i != items.length - 1)
            Text(
              '·',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
        ],
      ],
    ),
  );
}

class _ContactoCard extends StatelessWidget {
  const _ContactoCard({required this.titulo, required this.valor, this.onTap});
  final String titulo;
  final String valor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.link,
              size: 18,
              color: ColoresApp.principalMarca,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                CupertinoIcons.arrow_up_right,
                size: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
          ],
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.icono,
    required this.texto,
    required this.onTap,
  });
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 9),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 15, color: Colors.white.withValues(alpha: 0.72)),
        const SizedBox(width: 6),
        Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    ),
  );
}

class _FilaPedirAlLocal extends StatelessWidget {
  const _FilaPedirAlLocal({required this.ocupado, required this.onTap});
  final bool ocupado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: ocupado ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.gift, size: 17, color: ColoresApp.principalMarca),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pedir beneficio',
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
          if (ocupado)
            const CupertinoActivityIndicator(radius: 8)
          else
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: Colors.white.withValues(alpha: 0.4),
            ),
        ],
      ),
    ),
  );
}

class _PedidoBox extends StatelessWidget {
  const _PedidoBox({
    required this.plan,
    required this.puedeVotar,
    required this.yaVoto,
    required this.votando,
    required this.onVotar,
    this.localPuedeResponder = false,
    this.onAceptarLocal,
    this.onContraofertaLocal,
  });

  final PlanComunidad plan;
  final bool puedeVotar;
  final bool yaVoto;
  final bool votando;
  final VoidCallback onVotar;
  final bool localPuedeResponder;
  final VoidCallback? onAceptarLocal;
  final VoidCallback? onContraofertaLocal;

  @override
  Widget build(BuildContext context) {
    final estado = plan.beneficioEstado;
    final confirmado = estado == 'aceptado' || estado == 'contraoferta';
    final desc = () {
      if (confirmado) {
        final oferta = (plan.beneficioLocal ?? plan.beneficioContraoferta ?? '')
            .trim();
        final pedido = (plan.pedidoBeneficio ?? '').trim();
        final contra = (plan.beneficioContraoferta ?? '').trim();
        if (oferta.isNotEmpty) {
          if (pedido.isNotEmpty &&
              contra.isNotEmpty &&
              contra.toLowerCase() != pedido.toLowerCase()) {
            return '${plan.nombreLocal} ofreció otra cosa: "$oferta"';
          }
          if (pedido.isNotEmpty) {
            return '¡Se puso la 10! ${plan.nombreLocal} aceptó "$oferta"';
          }
          return 'Promo si te unís: "$oferta"';
        }
      }
      if (estado == 'pedido') {
        final p = (plan.pedidoBeneficio ?? '').trim();
        if (p.isEmpty) return 'El local todavía no respondió.';
        return 'Aún no aceptado: "$p"';
      }
      return (plan.pedidoBeneficio ?? '').trim();
    }();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.gift_fill,
                size: 16,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Pedir beneficio',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              _BadgeEstadoPedido(estado: estado),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                CupertinoIcons.hand_thumbsup_fill,
                size: 13,
                color: ColoresApp.textoSecundario,
              ),
              const SizedBox(width: 5),
              Text(
                '${plan.pedidoVotos} ${plan.pedidoVotos == 1 ? "voto" : "votos"}',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const Spacer(),
              if (puedeVotar)
                GestureDetector(
                  onTap: votando ? null : onVotar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.principalMarca,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: votando
                        ? const CupertinoActivityIndicator(
                            radius: 7,
                            color: Colors.white,
                          )
                        : Text(
                            'Me copa',
                            style: GoogleFonts.baloo2(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                )
              else if (yaVoto)
                Text(
                  'Ya votaste',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.principalMarca,
                  ),
                ),
            ],
          ),
          if (localPuedeResponder) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: votando ? null : onAceptarLocal,
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Aceptar beneficio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: votando ? null : onContraofertaLocal,
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Proponer otro beneficio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EresParteRow extends StatelessWidget {
  const _EresParteRow({required this.esAdmin, this.onSalir});
  final bool esAdmin;
  final VoidCallback? onSalir;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            esAdmin ? 'Eres parte · admin' : 'Eres parte',
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
        ),
        if (onSalir != null)
          GestureDetector(
            onTap: onSalir,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Salir',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeEstadoPedido extends StatelessWidget {
  const _BadgeEstadoPedido({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (estado) {
      'aceptado' => ('Aceptado', const Color(0xFF34D399)),
      'contraoferta' => ('Aceptado', const Color(0xFF34D399)),
      'pedido' => ('Aún no aceptado', const Color(0xFFF5A623)),
      _ => ('Sin pedido', Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _FilaSolicitudesPendientes extends StatelessWidget {
  const _FilaSolicitudesPendientes({
    required this.cantidad,
    required this.onTap,
  });
  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.principalMarca.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.tray_full,
            size: 17,
            color: ColoresApp.principalMarca,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$cantidad ${cantidad == 1 ? "solicitud pendiente" : "solicitudes pendientes"}',
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.titulo, required this.texto});
  final String titulo;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.texto,
    this.onTap,
    this.secundario = false,
    this.danger = false,
    this.cargando = false,
  });
  final String texto;
  final VoidCallback? onTap;
  final bool secundario;
  final bool danger;
  final bool cargando;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 9),
    color: secundario
        ? Colors.white.withValues(alpha: 0.08)
        : (danger ? CupertinoColors.systemRed : ColoresApp.principalMarca),
    borderRadius: BorderRadius.circular(14),
    onPressed: cargando ? null : onTap,
    child: cargando
        ? const CupertinoActivityIndicator(color: Colors.white)
        : Text(
            texto,
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
  );
}

/// Grid de participantes estilo pools: filas alternadas 3-2-3-2, celdas
/// compactas (avatar/portada + nombre), sin bordes duros.
const double _gridEspaciado = 12.0;

class _GridParticipantes extends StatelessWidget {
  const _GridParticipantes({
    required this.personas,
    required this.onTapPersona,
  });

  final List<PlanMiembro> personas;
  final ValueChanged<PlanMiembro> onTapPersona;

  List<List<int>> _filasAlternadas(int n) {
    final filas = <List<int>>[];
    var i = 0;
    var colCount = 3;
    while (i < n) {
      final fila = <int>[];
      for (var c = 0; c < colCount && i < n; c++) {
        fila.add(i++);
      }
      filas.add(fila);
      colCount = colCount == 3 ? 2 : 3;
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final total = personas.length;
    final ancho = MediaQuery.sizeOf(context).width - 32;
    final tamCelda = ((ancho - _gridEspaciado * 2) / 3).clamp(90.0, 110.0);
    final filas = _filasAlternadas(total);

    return Column(
      children: filas.map((indices) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: indices.map((idx) {
              return SizedBox(
                width: tamCelda,
                child: _CeldaPersona(
                  miembro: personas[idx],
                  tamCelda: tamCelda,
                  onTap: () => onTapPersona(personas[idx]),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _CeldaPersona extends StatelessWidget {
  const _CeldaPersona({
    required this.miembro,
    required this.tamCelda,
    required this.onTap,
  });
  final PlanMiembro miembro;
  final double tamCelda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = tamCelda * 0.62;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarRedondo(
            url: miembro.fotoUrl,
            fallback: miembro.nombre,
            size: avatarSize,
          ),
          const SizedBox(height: 6),
          Text(
            miembro.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (miembro.rol == 'organizador')
            Text(
              'admin',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColoresApp.principalMarca,
              ),
            )
          else if ((miembro.nombreSquad ?? '').trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'via ${miembro.nombreSquad}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarRedondo extends StatelessWidget {
  const _AvatarRedondo({
    required this.url,
    required this.fallback,
    required this.size,
  });
  final String? url;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                memCacheWidth: (size * 3).round(),
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    ini,
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : ColoredBox(
                color: const Color(0xFF2B2B2B),
                child: Center(
                  child: Text(
                    ini,
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SolicitudesSheet extends StatefulWidget {
  const _SolicitudesSheet({
    required this.pendientes,
    required this.onAceptar,
    required this.onRechazar,
  });

  final List<PlanMiembro> pendientes;
  final Future<bool> Function(PlanMiembro) onAceptar;
  final Future<bool> Function(PlanMiembro) onRechazar;

  @override
  State<_SolicitudesSheet> createState() => _SolicitudesSheetState();
}

class _SolicitudesSheetState extends State<_SolicitudesSheet> {
  late List<PlanMiembro> _items;
  String? _procesando;

  @override
  void initState() {
    super.initState();
    _items = [...widget.pendientes];
  }

  Future<void> _accion(
    PlanMiembro m,
    Future<bool> Function(PlanMiembro) fn,
  ) async {
    setState(() => _procesando = m.idUsuario);
    final ok = await fn(m);
    if (!mounted) return;
    setState(() {
      _procesando = null;
      if (ok) _items.removeWhere((x) => x.idUsuario == m.idUsuario);
    });
  }

  void _verPerfil(PlanMiembro m) {
    if (!m.perfilPublico) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text('Perfil privado · @${m.username ?? 'usuario'}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': m.idUsuario,
            'nombre': m.nombre,
            'username': m.username ?? '',
            'avatar': m.fotoUrl ?? '',
          },
          estadoRelacion: EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Solicitudes',
                      style: GoogleFonts.baloo2(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${_items.length}',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'No hay solicitudes pendientes.',
                        style: GoogleFonts.baloo2(
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        final procesando = _procesando == m.idUsuario;
                        return _FilaSolicitud(
                          miembro: m,
                          procesando: procesando,
                          onVerPerfil: () => _verPerfil(m),
                          onAceptar: () => _accion(m, widget.onAceptar),
                          onRechazar: () => _accion(m, widget.onRechazar),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaSolicitud extends StatelessWidget {
  const _FilaSolicitud({
    required this.miembro,
    required this.procesando,
    required this.onVerPerfil,
    required this.onAceptar,
    required this.onRechazar,
  });

  final PlanMiembro miembro;
  final bool procesando;
  final VoidCallback onVerPerfil;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AvatarRedondo(
              url: miembro.fotoUrl,
              fallback: miembro.nombre,
              size: 42,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    miembro.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: onVerPerfil,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Ver perfil',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.principalMarca,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (procesando) const CupertinoActivityIndicator(radius: 9),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BotonChico(
                texto: 'Aceptar',
                color: ColoresApp.principalMarca,
                onTap: procesando ? null : onAceptar,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BotonChico(
                texto: 'Rechazar',
                color: Colors.white.withValues(alpha: 0.09),
                textColor: Colors.white.withValues(alpha: 0.85),
                onTap: procesando ? null : onRechazar,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BotonChico extends StatelessWidget {
  const _BotonChico({
    required this.texto,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });

  final String texto;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    ),
  );
}

class _OpcionUnion extends StatelessWidget {
  const _OpcionUnion({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icono, color: ColoresApp.principalMarca),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                Text(
                  subtitulo,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: ColoresApp.textoSecundario,
          ),
        ],
      ),
    ),
  );
}

String _fmt(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm $hh:$mi';
}

Color _parseColor(String hex) {
  final clean = hex.replaceAll('#', '');
  return Color(int.tryParse('FF$clean', radix: 16) ?? 0xFFC084FC);
}
