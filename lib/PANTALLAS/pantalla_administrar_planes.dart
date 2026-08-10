library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_planes.dart';
import '../widgets/fernecito_loader.dart';

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

  Future<void> _editarTitulo(PlanComunidad p) async {
    final ctrl = TextEditingController(text: p.titulo);
    final nuevo = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Editar nombre'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: ctrl, maxLength: 80),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevo == null || nuevo == p.titulo || nuevo.length < 3) return;
    await _actualizar(p, titulo: nuevo);
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
    final res = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
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
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
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
    String? titulo,
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
        titulo: titulo,
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

  Future<void> _gestionar(PlanMiembro m, String accion) async {
    final plan = _detalle?.plan;
    if (plan == null) return;
    try {
      final ok = await _srv.gestionarMiembro(
        idPlan: plan.id,
        idUsuario: m.idUsuario,
        accion: accion,
      );
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo actualizar la solicitud.');
        return;
      }
      _changed = true;
      await _abrir(plan.id);
      await _cargar();
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'gestionar solicitud'));
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
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Administrar planes',
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_guardando) const CupertinoActivityIndicator(),
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
                            _InfoBox(
                              titulo: 'No tenés planes para administrar',
                              texto:
                                  'Cuando crees un plan, vas a poder editarlo y aceptar solicitudes desde acá.',
                            )
                          else
                            for (final p in _planes)
                              _AdminPlanCard(
                                plan: p,
                                selected: p.id == _seleccionadoId,
                                onTap: () => _abrir(p.id),
                                onTitulo: () => _editarTitulo(p),
                                onInicio: () => _editarFecha(p, inicio: true),
                                onFin: () => _editarFecha(p, inicio: false),
                                onCupo: () => _editarCupo(p),
                                onIngreso: () => _actualizar(
                                  p,
                                  ingresoAbierto: p.estado == 'cerrado',
                                ),
                              ),
                          if (_detalle != null) ...[
                            const SizedBox(height: 18),
                            _SolicitudesBox(
                              detalle: _detalle!,
                              onAceptar: (m) => _gestionar(m, 'aceptar'),
                              onRechazar: (m) => _gestionar(m, 'rechazar'),
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
    required this.onTitulo,
    required this.onInicio,
    required this.onFin,
    required this.onCupo,
    required this.onIngreso,
  });

  final PlanComunidad plan;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTitulo;
  final VoidCallback onInicio;
  final VoidCallback onFin;
  final VoidCallback onCupo;
  final VoidCallback onIngreso;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected
            ? ColoresApp.principalMarca.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              _Pill(plan.estado == 'cerrado' ? 'cerrado' : 'abierto'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.nombreLocal} · ${plan.ciudad}',
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MiniAction('Nombre', onTitulo),
              _MiniAction('Inicio', onInicio),
              _MiniAction('Fin', onFin),
              _MiniAction('Cupo', onCupo),
              _MiniAction(
                plan.estado == 'cerrado' ? 'Abrir ingreso' : 'Cerrar ingreso',
                onIngreso,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SolicitudesBox extends StatelessWidget {
  const _SolicitudesBox({
    required this.detalle,
    required this.onAceptar,
    required this.onRechazar,
  });

  final PlanDetalle detalle;
  final ValueChanged<PlanMiembro> onAceptar;
  final ValueChanged<PlanMiembro> onRechazar;

  @override
  Widget build(BuildContext context) {
    final pendientes = detalle.miembros
        .where((m) => m.estado == 'pendiente')
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solicitudes · ${detalle.plan.titulo}',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (pendientes.isEmpty)
            Text(
              'No hay solicitudes pendientes.',
              style: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
            )
          else
            for (final m in pendientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.nombre,
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _MiniAction('Aceptar', () => onAceptar(m), primary: true),
                    const SizedBox(width: 6),
                    _MiniAction('Rechazar', () => onRechazar(m)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontSize: 19,
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

class _MiniAction extends StatelessWidget {
  const _MiniAction(this.texto, this.onTap, {this.primary = false});
  final String texto;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary
            ? ColoresApp.principalMarca
            : const Color(0xFFE5E7EB).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: GoogleFonts.baloo2(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}
