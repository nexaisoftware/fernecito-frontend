/// Pantalla dedicada para confirmar y ejecutar el borrado TOTAL del ecosistema
/// Fernecito (usuario + locales + staff + auth). Robusta: focus real,
/// verificación escribiendo "eliminar", estado de carga y errores visibles.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/supabase_client.dart';

class PantallaEliminarTodo extends StatefulWidget {
  const PantallaEliminarTodo({super.key});

  @override
  State<PantallaEliminarTodo> createState() => _PantallaEliminarTodoState();
}

class _PantallaEliminarTodoState extends State<PantallaEliminarTodo> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _eliminando = false;
  String? _error;

  bool get _habilitado =>
      _controller.text.trim().toLowerCase() == 'eliminar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    if (!_habilitado || _eliminando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      final sb = ServicioSupabase();
      final session = sb.cliente.auth.currentSession;
      if (session == null) {
        throw Exception('No hay sesión activa');
      }
      debugPrint('🗑️ [TODO] invocando eliminar_cuenta_usuario...');
      final res = await sb.cliente.functions
          .invoke(
            'eliminar_cuenta_usuario',
            body: {'modo': 'todo'},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 45));
      debugPrint('🗑️ [TODO] status=${res.status} data=${res.data}');
      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        throw Exception('Respuesta no OK (status ${res.status}): ${res.data}');
      }
      debugPrint('✅ [TODO] eliminado. Cerrando sesión...');
      await sb.cliente.auth.signOut();
      // No navegamos manual: AuthGate detecta signedOut → Login.
    } catch (e) {
      debugPrint('❌ [TODO] error: $e');
      if (!mounted) return;
      setState(() {
        _eliminando = false;
        _error = 'No se pudo eliminar la cuenta.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: ColoresApp.fondoPrincipal,
        middle: Text(
          'Eliminar todo Fernecito',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
        ),
        leading: _eliminando
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(CupertinoIcons.back, color: ColoresApp.principalMarca),
              ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, padding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  size: 56, color: ColoresApp.peligroMarca),
              const SizedBox(height: 16),
              Text(
                'Vas a eliminar PERMANENTEMENTE todo lo asociado a este email:',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: ColoresApp.peligroMarca.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '• Tu cuenta de usuario (amigos, squads, reservas, rompehielos)\n'
                  '• Tus locales y todos sus eventos y promos\n'
                  '• Tus roles de staff\n'
                  '• La cuenta de acceso (auth)\n\n'
                  'Esto NO se puede deshacer.',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Para confirmar, escribí "eliminar":',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !_eliminando,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                placeholder: 'eliminar',
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _eliminar(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                style: GoogleFonts.baloo2(
                    fontSize: 16, color: ColoresApp.textoPrincipal),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _habilitado
                        ? ColoresApp.peligroMarca
                        : Colors.white.withValues(alpha: 0.15),
                    width: _habilitado ? 1.5 : 1,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.peligroMarca,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 15),
                color: ColoresApp.peligroMarca,
                disabledColor:
                    ColoresApp.peligroMarca.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(50),
                onPressed: (_habilitado && !_eliminando) ? _eliminar : null,
                child: _eliminando
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        'Eliminar definitivamente',
                        style: GoogleFonts.baloo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              if (!_eliminando)
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textoSecundario,
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
