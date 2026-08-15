library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_planes.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/dialogo_fernecito.dart';
import 'pantalla_perfil_usuarios.dart';

class PantallaAdministrarPlanes extends StatefulWidget {
  const PantallaAdministrarPlanes({super.key});

  @override
  State<PantallaAdministrarPlanes> createState() =>
      _PantallaAdministrarPlanesState();
}

class _PantallaAdministrarPlanesState extends State<PantallaAdministrarPlanes> {
  final _srv = ServicioPlanes();
  List<PlanComunidad> _planes = const [];
  PlanDetalle? _detalle;
  bool _cargando = true;
  bool _guardando = false;
  String? _seleccionadoId;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final res = await _srv.hub(limit: 40, modo: 'mis');
    if (!mounted) return;
    final administrables = res.items.where((p) => p.soyModerador).toList();
    setState(() {
      _planes = administrables;
      _cargando = false;
    });
    if (_seleccionadoId != null) unawaited(_abrir(_seleccionadoId!));
  }

  Future<void> _abrir(String id) async {
    setState(() {
      _seleccionadoId = id;
      _detalle = null;
    });
    final res = await _srv.detalle(id);
    if (!mounted) return;
    setState(() => _detalle = res.detalle);
  }

  void _seleccionar(String id) {
    if (_seleccionadoId == id) {
      setState(() {
        _seleccionadoId = null;
        _detalle = null;
      });
      return;
    }
    unawaited(_abrir(id));
  }

  Future<void> _editarDescripcion(PlanComunidad p) async {
    final ctrl = TextEditingController(text: p.descripcion);
    final nuevo = await showFernecitoDialog<String>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Editar descripción'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            maxLength: 500,
            maxLines: 5,
            placeholder: 'Qué se hace en el plan…',
          ),
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevo == null || nuevo == p.descripcion || nuevo.length < 8) return;
    await _actualizar(p, descripcion: nuevo);
  }

  Future<void> _editarFecha(PlanComunidad p, {required bool inicio}) async {
    var valor = inicio
        ? p.fechaInicio
        : (p.fechaFin ?? p.fechaInicio.add(const Duration(hours: 3)));
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 310,
        color: const Color(0xFF1B1B1B),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Listo'),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: valor,
                minimumDate: DateTime.now().subtract(
                  const Duration(minutes: 10),
                ),
                maximumDate: DateTime.now().add(const Duration(days: 45)),
                use24hFormat: true,
                onDateTimeChanged: (v) => valor = v,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    await _actualizar(
      p,
      fechaInicio: inicio ? valor : null,
      fechaFin: inicio ? null : valor,
    );
  }

  Future<void> _editarCupo(PlanComunidad p) async {
    final ctrl = TextEditingController(text: p.cupoMax?.toString() ?? '');
    final res = await showFernecitoDialog<String>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Editar cupo'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            placeholder: 'Vacío = sin cupo',
          ),
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null) return;
    await _actualizar(
      p,
      cupoMax: int.tryParse(res),
      sinCupo: res.trim().isEmpty,
    );
  }

  Future<void> _actualizar(
    PlanComunidad p, {
    String? descripcion,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? cupoMax,
    bool sinCupo = false,
    bool? ingresoAbierto,
  }) async {
    setState(() => _guardando = true);
    try {
      final ok = await _srv.actualizarBasico(
        idPlan: p.id,
        descripcion: descripcion,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        cupoMax: cupoMax,
        sinCupo: sinCupo,
        ingresoAbierto: ingresoAbierto,
      );
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo actualizar el plan.');
        return;
      }
      _changed = true;
      await _cargar();
      if (_seleccionadoId != null) await _abrir(_seleccionadoId!);
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'actualizar el plan'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _gestionar(PlanMiembro m, String accion) async {
    final plan = _detalle?.plan;
    if (plan == null) return false;
    try {
      final ok = await _srv.gestionarMiembro(
        idPlan: plan.id,
        idUsuario: m.idUsuario,
        accion: accion,
      );
      if (!mounted) return ok;
      if (!ok) {
        _toast('No se pudo actualizar la solicitud.');
        return false;
      }
      _changed = true;
      unawaited(_abrir(plan.id));
      unawaited(_cargar());
      return true;
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'gestionar solicitud'));
      return false;
    }
  }

  Future<void> _pedirAlLocal(PlanComunidad p) async {
    final ctrl = TextEditingController();
    final pedido = await showFernecitoDialog<String>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Pedirle algo al local'),
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
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pedido == null || pedido.trim().length < 3) return;
    setState(() => _guardando = true);
    try {
      final ok = await _srv.pedidoLocal(p.id, pedido.trim());
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo enviar el pedido.');
        return;
      }
      await _abrir(p.id);
      _toast('Pedido enviado al local.');
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'enviar el pedido'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrarPlan(PlanComunidad p) async {
    final ok = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Borrar plan'),
        content: const Text(
          'Esta acción no se puede deshacer. El plan se elimina para todos.',
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          AccionDialogoFernecito(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _guardando = true);
    try {
      final borrado = await _srv.eliminar(p.id);
      if (!mounted) return;
      if (!borrado) {
        _toast('No se pudo borrar el plan.');
        return;
      }
      _changed = true;
      if (_seleccionadoId == p.id) {
        _seleccionadoId = null;
        _detalle = null;
      }
      await _cargar();
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'borrar el plan'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cancelarPlan(PlanComunidad p) async {
    final ok = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('Cancelar plan'),
        content: const Text(
          'Se va a mostrar como cancelado y se avisa en el chat.',
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          AccionDialogoFernecito(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar plan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _guardando = true);
    try {
      final cancelado = await _srv.cancelar(p.id);
      if (!mounted) return;
      if (!cancelado) {
        _toast('No se pudo cancelar el plan.');
        return;
      }
      _changed = true;
      await _cargar();
      if (_seleccionadoId != null) await _abrir(_seleccionadoId!);
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'cancelar el plan'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _expulsar(PlanMiembro m) async {
    final ok = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: Text('¿Expulsar a ${m.nombre}?'),
        content: const Text('Va a salir del plan y del chat del grupo.'),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          AccionDialogoFernecito(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _gestionar(m, 'expulsar');
  }

  Future<void> _editarContacto(PlanComunidad p) async {
    var modo = p.contactoModo == 'colaborar' ? 'colaborar' : 'contactar';
    final ctrl = TextEditingController(text: p.contactoAnfitrion ?? '');
    final guardado = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => DialogoFernecito(
          title: const Text('Contacto del organizador'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                CupertinoSegmentedControl<String>(
                  groupValue: modo,
                  children: const {
                    'contactar': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Contactar', style: TextStyle(fontSize: 12)),
                    ),
                    'colaborar': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Colaborar', style: TextStyle(fontSize: 12)),
                    ),
                  },
                  onValueChanged: (v) => setLocal(() => modo = v),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: ctrl,
                  maxLength: 80,
                  placeholder: modo == 'colaborar'
                      ? 'ej: link o alias'
                      : 'ej un whatsapp o instagram',
                ),
              ],
            ),
          ),
          actions: [
            AccionDialogoFernecito(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            AccionDialogoFernecito(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final texto = ctrl.text.trim();
    ctrl.dispose();
    if (guardado != true) return;
    setState(() => _guardando = true);
    try {
      final ok = await _srv.actualizarBasico(
        idPlan: p.id,
        contactoAnfitrion: texto.isEmpty ? null : texto,
        contactoModo: modo,
        limpiarContacto: texto.isEmpty,
      );
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo guardar el contacto.');
        return;
      }
      _changed = true;
      await _abrir(p.id);
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'guardar contacto'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _abrirSolicitudes(PlanDetalle detalle) async {
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

  void _toast(String msg) {
    showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        content: Text(msg),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = _detalle?.plan;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.pop(context, _changed),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        color: ColoresApp.principalMarca,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Administrar planes',
                        style: GoogleFonts.baloo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_guardando) const CupertinoActivityIndicator(radius: 9),
                  ],
                ),
              ),
              Expanded(
                child: _cargando
                    ? const Center(child: FernecitoLoader.inline(size: 26))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                        children: [
                          if (_planes.isEmpty)
                            const _InfoBox(
                              titulo: 'No tenés planes para administrar',
                              texto:
                                  'Cuando crees un plan, vas a poder editarlo y aceptar solicitudes desde acá.',
                            )
                          else
                            for (final p in _planes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AdminPlanCard(
                                  plan: p,
                                  selected: p.id == _seleccionadoId,
                                  onTap: () => _seleccionar(p.id),
                                ),
                              ),
                          if (_seleccionadoId != null) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 10,
                              ),
                              child: Text(
                                'Editar',
                                style: GoogleFonts.baloo2(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: ColoresApp.principalMarca,
                                ),
                              ),
                            ),
                            if (seleccionado == null)
                              const Center(
                                child: FernecitoLoader.inline(size: 22),
                              )
                            else
                              _PanelEditar(
                                plan: seleccionado,
                                detalle: _detalle!,
                                onDescripcion: () =>
                                    _editarDescripcion(seleccionado),
                                onInicio: () =>
                                    _editarFecha(seleccionado, inicio: true),
                                onFin: () =>
                                    _editarFecha(seleccionado, inicio: false),
                                onCupo: () => _editarCupo(seleccionado),
                                onIngreso: () => _actualizar(
                                  seleccionado,
                                  ingresoAbierto: !seleccionado.ingresoAbierto,
                                ),
                                onSolicitudes: () =>
                                    _abrirSolicitudes(_detalle!),
                                onContacto: () => _editarContacto(seleccionado),
                                onPedirAlLocal: () =>
                                    _pedirAlLocal(seleccionado),
                                onExpulsar: (m) => _expulsar(m),
                                onCancelar: () => _cancelarPlan(seleccionado),
                                onBorrar: () => _borrarPlan(seleccionado),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPlanCard extends StatelessWidget {
  const _AdminPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PlanComunidad plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected
            ? ColoresApp.principalMarca.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.nombreLocal} · ${plan.ciudad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EstadoDot(abierto: plan.ingresoAbierto),
        ],
      ),
    ),
  );
}

class _EstadoDot extends StatelessWidget {
  const _EstadoDot({required this.abierto});
  final bool abierto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: (abierto ? const Color(0xFF34D399) : const Color(0xFFF87171))
          .withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: abierto ? const Color(0xFF34D399) : const Color(0xFFF87171),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          abierto ? 'abierto' : 'cerrado',
          style: GoogleFonts.baloo2(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: abierto ? const Color(0xFF34D399) : const Color(0xFFF87171),
          ),
        ),
      ],
    ),
  );
}

class _PanelEditar extends StatelessWidget {
  const _PanelEditar({
    required this.plan,
    required this.detalle,
    required this.onDescripcion,
    required this.onInicio,
    required this.onFin,
    required this.onCupo,
    required this.onIngreso,
    required this.onSolicitudes,
    required this.onContacto,
    required this.onPedirAlLocal,
    required this.onExpulsar,
    required this.onCancelar,
    required this.onBorrar,
  });

  final PlanComunidad plan;
  final PlanDetalle detalle;
  final VoidCallback onDescripcion;
  final VoidCallback onInicio;
  final VoidCallback onFin;
  final VoidCallback onCupo;
  final VoidCallback onIngreso;
  final VoidCallback onSolicitudes;
  final VoidCallback onContacto;
  final VoidCallback onPedirAlLocal;
  final ValueChanged<PlanMiembro> onExpulsar;
  final VoidCallback onCancelar;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final pendientes = detalle.miembros
        .where((m) => m.estado == 'pendiente')
        .length;
    final miembros = detalle.miembros
        .where((m) => m.estado == 'aceptado' && m.rol != 'organizador')
        .toList(growable: false);
    final contactoLabel = plan.contactoModo == 'colaborar'
        ? 'Colaborar'
        : 'Contactar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditRow(
          icono: CupertinoIcons.textformat,
          label: 'Nombre',
          valor: '${plan.titulo} · fijo',
          onTap: () {},
          soloLectura: true,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: CupertinoIcons.doc_text,
          label: 'Descripción',
          valor: plan.descripcion.trim().isEmpty
              ? 'Sin descripción'
              : plan.descripcion.trim(),
          onTap: onDescripcion,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: CupertinoIcons.calendar,
          label: 'Fecha inicio',
          valor: _fmtFecha(plan.fechaInicio),
          onTap: onInicio,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: CupertinoIcons.calendar_badge_plus,
          label: 'Fecha fin',
          valor: plan.fechaFin != null
              ? _fmtFecha(plan.fechaFin!)
              : 'Sin definir',
          onTap: onFin,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: CupertinoIcons.person_2,
          label: 'Cupo',
          valor: plan.cupoMax != null
              ? '${plan.cupoUsados}/${plan.cupoMax} personas'
              : 'Sin límite',
          onTap: onCupo,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: plan.ingresoAbierto
              ? CupertinoIcons.lock_open
              : CupertinoIcons.lock,
          label: 'Ingreso',
          valor: plan.ingresoAbierto
              ? 'Abierto · tocá para cerrar'
              : 'Cerrado · tocá para abrir',
          onTap: onIngreso,
          destacado: plan.ingresoAbierto,
        ),
        const SizedBox(height: 8),
        _EditRow(
          icono: CupertinoIcons.chat_bubble_2,
          label: contactoLabel,
          valor: (plan.contactoAnfitrion ?? '').trim().isEmpty
              ? 'Sin dato · tocá para editar'
              : plan.contactoAnfitrion!,
          onTap: onContacto,
        ),
        const SizedBox(height: 14),
        _EditRow(
          icono: CupertinoIcons.tray_full,
          label: 'Solicitudes',
          valor: pendientes == 0
              ? 'Sin pendientes'
              : '$pendientes ${pendientes == 1 ? "pendiente" : "pendientes"}',
          onTap: onSolicitudes,
          destacado: pendientes > 0,
        ),
        const SizedBox(height: 14),
        if (plan.beneficioEstado == 'ninguno')
          _EditRow(
            icono: CupertinoIcons.gift,
            label: 'Pedirle al local',
            valor: 'Pedir un beneficio para el grupo',
            onTap: onPedirAlLocal,
          )
        else
          _PedidoBox(plan: plan),
        if (miembros.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Miembros',
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: ColoresApp.principalMarca,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in miembros)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if ((m.nombreSquad ?? '').isNotEmpty)
                            Text(
                              'via ${m.nombreSquad}',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onExpulsar(m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Expulsar',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _BotonAncho(
                texto: 'Cancelar plan',
                secundario: true,
                onTap: onCancelar,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotonAncho(
                texto: 'Borrar plan',
                danger: true,
                onTap: onBorrar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.icono,
    required this.label,
    required this.valor,
    required this.onTap,
    this.destacado = false,
    this.soloLectura = false,
  });

  final IconData icono;
  final String label;
  final String valor;
  final VoidCallback onTap;
  final bool destacado;
  final bool soloLectura;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: soloLectura ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: destacado
            ? ColoresApp.principalMarca.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            size: 18,
            color: destacado
                ? ColoresApp.principalMarca
                : Colors.white.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.baloo2(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (!soloLectura) ...[
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PedidoBox extends StatelessWidget {
  const _PedidoBox({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    final estado = plan.beneficioEstado;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
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
                  'Pedido al local',
                  style: GoogleFonts.baloo2(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              _BadgeEstadoPedido(estado: estado),
            ],
          ),
          if ((plan.pedidoBeneficio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.pedidoBeneficio!.trim(),
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (estado == 'contraoferta' &&
              (plan.beneficioContraoferta ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Contraoferta: ${plan.beneficioContraoferta!.trim()}',
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                CupertinoIcons.hand_thumbsup_fill,
                size: 13,
                color: ColoresApp.textoSecundario,
              ),
              const SizedBox(width: 5),
              Text(
                '${plan.pedidoVotos} ${plan.pedidoVotos == 1 ? "voto" : "votos"} del grupo',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
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
      'rechazado' => ('Rechazado', const Color(0xFFF87171)),
      'contraoferta' => ('Contraoferta', const Color(0xFF60A5FA)),
      _ => ('Pendiente', const Color(0xFFF5A623)),
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

class _BotonAncho extends StatelessWidget {
  const _BotonAncho({
    required this.texto,
    required this.onTap,
    this.secundario = false,
    this.danger = false,
  });

  final String texto;
  final VoidCallback onTap;
  final bool secundario;
  final bool danger;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFF87171).withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
          color: danger ? const Color(0xFFF87171) : Colors.white,
        ),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          texto,
          style: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
        ),
      ],
    ),
  );
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
      showFernecitoDialog<void>(
        context: context,
        builder: (ctx) => DialogoFernecito(
          content: Text('Perfil privado · @${m.username ?? 'usuario'}'),
          actions: [
            AccionDialogoFernecito(
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
            _MiniAvatar(url: miembro.fotoUrl, fallback: miembro.nombre),
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

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.url, required this.fallback});
  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2B2B2B),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _fallback(ini),
            )
          : _fallback(ini),
    );
  }

  Widget _fallback(String ini) => Center(
    child: Text(
      ini,
      style: GoogleFonts.baloo2(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}

String _fmtFecha(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$dd/$mm · $hh:$mi';
}
