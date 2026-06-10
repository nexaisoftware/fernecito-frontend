/// Card compacta con contexto de la contraparte en rompehielo.
library;

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_squads.dart';
import '../core/squad_helpers.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../PANTALLAS/pantalla_perfil_squads.dart';
import '../PANTALLAS/pantalla_perfil_usuarios.dart';

class CardContextoRompehielo extends StatelessWidget {
  const CardContextoRompehielo({
    super.key,
    required this.estado,
    required this.esSquad,
    required this.contraparte,
    this.miembrosSquad = const [],
  });

  final RompehieloEstado? estado;
  final bool esSquad;
  final Map<String, dynamic> contraparte;
  final List<MiembroSquad> miembrosSquad;

  @override
  Widget build(BuildContext context) {
    final ctx = _ContextoRompehieloUi.fromEstado(estado);
    if (!ctx.mostrarCard && miembrosSquad.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ctx.mostrarOrigen) ...[
                  _fila('${ctx.etiquetaOrigen}:', ctx.valorOrigen),
                  if (ctx.ciudad != null && ctx.ciudad!.isNotEmpty)
                    _fila('Ciudad:', ctx.ciudad!),
                ],
                if (esSquad && miembrosSquad.isNotEmpty) ...[
                  if (ctx.mostrarOrigen) const SizedBox(height: 6),
                  _filaMiembros(context),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            color: ColoresApp.principalMarca.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            onPressed: () => _abrirPerfil(context),
            child: Text(
              'Ver perfil',
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColoresApp.principalMarca,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoSecundario,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$etiqueta ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: valor,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaMiembros(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Miembros: ',
          style: GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        ),
        ...miembrosSquad.asMap().entries.expand((e) {
          final i = e.key;
          final m = e.value;
          final user =
              m.username.startsWith('@') ? m.username : '@${m.username}';
          return [
            if (i > 0)
              Text(
                ', ',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            GestureDetector(
              onTap: () => _abrirPerfilUsuario(context, m),
              child: Text(
                user,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.principalMarca,
                  decoration: TextDecoration.underline,
                  decorationColor:
                      ColoresApp.principalMarca.withValues(alpha: 0.55),
                ),
              ),
            ),
          ];
        }),
      ],
    );
  }

  Future<void> _abrirPerfil(BuildContext context) async {
    if (!esSquad) {
      final id = contraparte['id_usuario']?.toString() ?? '';
      if (id.isEmpty) return;
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilUsuarios(
            usuario: {
              'id_usuario': id,
              'username': contraparte['username'] ?? '@usuario',
              'avatar': contraparte['avatar'] ?? '',
            },
            estadoRelacion: EstadoRelacionUsuario.ninguno,
          ),
        ),
      );
      return;
    }
    final id = contraparte['id_grupo']?.toString() ??
        contraparte['id_squad']?.toString() ??
        '';
    if (id.isEmpty) return;
    final det = await ServicioSquads().detalle(id);
    if (!context.mounted || det == null) return;
    final map = mapNavegacionDesdeDetalle(det);
    final estado = det.miEstado == 'pendiente'
        ? EstadoRelacionSquad.solicitudPendiente
        : (det.miEstado == 'aceptado'
            ? EstadoRelacionSquad.miembro
            : EstadoRelacionSquad.ninguno);
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilSquads(
          squad: map,
          estadoRelacion: estado,
        ),
      ),
    );
  }

  void _abrirPerfilUsuario(BuildContext context, MiembroSquad m) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': m.idUsuario,
            'username':
                m.username.startsWith('@') ? m.username : '@${m.username}',
            'avatar': m.avatarUrl ?? '',
          },
          estadoRelacion: EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }
}

class _ContextoRompehieloUi {
  final String etiquetaOrigen;
  final String valorOrigen;
  final String? ciudad;
  final bool mostrarOrigen;

  bool get mostrarCard =>
      mostrarOrigen || (ciudad != null && ciudad!.isNotEmpty);

  const _ContextoRompehieloUi({
    required this.etiquetaOrigen,
    required this.valorOrigen,
    this.ciudad,
    required this.mostrarOrigen,
  });

  factory _ContextoRompehieloUi.fromEstado(RompehieloEstado? e) {
    if (e == null || !e.existe) {
      return const _ContextoRompehieloUi(
        etiquetaOrigen: '',
        valorOrigen: '',
        mostrarOrigen: false,
      );
    }

    final yoInicie = e.yoInicie;
    final etiqueta = yoInicie ? 'Lo viste en' : 'Te vio en';

    final valor = switch (e.origen) {
      RompehieloOrigen.explorar => 'Explorar',
      RompehieloOrigen.pool => e.nombreEvento?.trim().isNotEmpty == true
          ? e.nombreEvento!.trim()
          : 'Evento',
      RompehieloOrigen.perfil || null => yoInicie ? 'Su perfil' : 'Te buscó',
    };

    return _ContextoRompehieloUi(
      etiquetaOrigen: etiqueta,
      valorOrigen: valor,
      ciudad: e.ciudadSnapshot,
      mostrarOrigen: true,
    );
  }
}
