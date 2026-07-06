import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_soporte_usuario.dart';
import '../core/supabase_client.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/fernecito_loader.dart';

/// Ayuda y soporte del usuario. El usuario ABRE una solicitud (no la cierra):
/// se genera un código anti-estafa que queda visible hasta que el owner la
/// cierra. El owner se contacta al email del usuario.
class PantallaSoporte extends StatefulWidget {
  const PantallaSoporte({super.key});

  @override
  State<PantallaSoporte> createState() => _PantallaSoporteState();
}

class _PantallaSoporteState extends State<PantallaSoporte> {
  final _srv = ServicioSoporteUsuario();
  final _ctrlMensaje = TextEditingController();
  final _ctrlTelefono = TextEditingController();

  bool _cargando = true;
  bool _procesando = false;
  Map<String, dynamic>? _ticket; // ticket vigente (null = no tiene)
  String _email = '';

  @override
  void initState() {
    super.initState();
    _email = ServicioSupabase().cliente.auth.currentUser?.email ?? '';
    _cargar();
  }

  @override
  void dispose() {
    _ctrlMensaje.dispose();
    _ctrlTelefono.dispose();
    super.dispose();
  }

  bool get _abierta =>
      (_ticket?['estado_operacion']?.toString().toLowerCase()) == 'abierta';

  Future<void> _cargar() async {
    try {
      final t = await _srv.estado();
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final user = email.substring(0, at);
    final dom = email.substring(at);
    if (user.length <= 2) return '${user[0]}•••$dom';
    final ocultos = (user.length - 2).clamp(3, 6);
    return '${user.substring(0, 2)}${'•' * ocultos}$dom';
  }

  Future<void> _abrirConsulta() async {
    if (_procesando) return;
    final mensaje = _ctrlMensaje.text.trim();
    if (mensaje.length < 8) {
      _aviso('Contanos un poco más', 'Describí tu problema (mín. 8 caracteres).');
      return;
    }
    setState(() => _procesando = true);
    try {
      final res = await _srv.abrir(
        mensaje: mensaje,
        telefono: _ctrlTelefono.text.trim().isEmpty
            ? null
            : _ctrlTelefono.text.trim(),
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        final s = res['soporte'];
        setState(() {
          _ticket = s is Map ? Map<String, dynamic>.from(s) : _ticket;
        });
        HapticFeedback.mediumImpact();
        await _cargar();
      } else {
        _aviso(
          'No se pudo abrir',
          res['error']?.toString() ?? 'Intentá de nuevo en un momento.',
        );
      }
    } catch (e) {
      if (mounted) {
        final s = e.toString().toLowerCase();
        _aviso(
          'No se pudo abrir',
          s.contains('not_authenticated') || s.contains('401')
              ? 'Iniciá sesión para abrir una consulta.'
              : 'Revisá tu conexión e intentá de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }


  void _aviso(String titulo, String mensaje) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(mensaje),
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

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          bottom: false,
          child: _cargando
              ? const FernecitoLoaderCentro(size: 28)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 12, 20, padding.bottom + 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 18),
                      _heroEmail(),
                      const SizedBox(height: 16),
                      _infoAntiEstafa(),
                      const SizedBox(height: 18),
                      if (_abierta) _ticketAbierto() else _formularioConsulta(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Icon(CupertinoIcons.back, color: ColoresApp.principalMarca),
        ),
        const SizedBox(width: 6),
        Text(
          'Ayuda y soporte',
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ],
    );
  }

  Widget _heroEmail() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
              ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColoresApp.principalMarca.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.mail_solid,
              size: 22,
              color: ColoresApp.principalMarca,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Te contactamos a tu email',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email.isEmpty ? '—' : _maskEmail(_email),
                  style: GoogleFonts.baloo2(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoAntiEstafa() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.principalMarca.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.shield_lefthalf_fill,
                size: 20,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(width: 8),
              Text(
                'Tu código anti-estafas',
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Al abrir una consulta generamos un código único que solo vos y '
            'Fernecito conocen. Cuando te contactemos, lo PRIMERO que te vamos '
            'a decir es ese código.\n\n'
            'Si alguien dice ser de Fernecito y NO te dice tu código, es una '
            'estafa: cortá. Nunca te vamos a pedir tu contraseña.',
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: ColoresApp.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado: tiene una consulta abierta ──
  Widget _ticketAbierto() {
    final codigo = _ticket?['codigo_antiestafa']?.toString() ?? '------';
    final mensaje = _ticket?['mensaje']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Solicitud abierta',
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2E9E4F),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TU CÓDIGO ANTI-ESTAFAS',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: codigo));
              HapticFeedback.selectionClick();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  codigo,
                  style: GoogleFonts.baloo2(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: ColoresApp.principalMarca,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 18,
                  color: ColoresApp.principalMarca,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Advertencia de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresApp.peligroMarca.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
                          ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 17,
                  color: ColoresApp.peligroMarca,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No compartas este código con nadie. Cuando soporte te '
                    'contacte, comparalo con el que te diga: si NO coincide, '
                    'cortá la comunicación al instante.',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (mensaje.isNotEmpty) ...[
            Text(
              'Tu consulta',
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresApp.fondoPrincipal.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mensaje,
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  height: 1.35,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Estamos revisando tu caso. Te vamos a escribir a tu email; '
            'guardá este código para verificar que somos nosotros. Solo el '
            'equipo de Fernecito puede cerrar esta solicitud.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              height: 1.4,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado: sin consulta abierta → formulario ──
  Widget _formularioConsulta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contanos tu problema',
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
                      ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: CupertinoTextField(
            controller: _ctrlMensaje,
            minLines: 3,
            maxLines: 6,
            maxLength: 600,
            placeholder: 'Describí qué te pasó con el mayor detalle posible…',
            placeholderStyle: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.7),
            ),
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoPrincipal,
            ),
            decoration: null,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
                      ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CupertinoTextField(
            controller: _ctrlTelefono,
            keyboardType: TextInputType.phone,
            placeholder: 'WhatsApp (opcional)',
            placeholderStyle: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.7),
            ),
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoPrincipal,
            ),
            decoration: null,
            padding: const EdgeInsets.symmetric(vertical: 12),
            prefix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 16,
                color: Color(0xFF25D366),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dejá tu WhatsApp si querés que te escribamos por chat para '
          'consultas rápidas o que necesiten ida y vuelta. Si no, te '
          'respondemos por email.',
          style: GoogleFonts.baloo2(
            fontSize: 11.5,
            height: 1.35,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(50),
          onPressed: _procesando ? null : _abrirConsulta,
          child: _procesando
              ? const FernecitoLoader.inline(size: 16, color: CupertinoColors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.shield_fill,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Abrir consulta y generar código',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

}
