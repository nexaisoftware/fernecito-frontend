import 'dart:html' as html;

/// Reemplaza la entrada actual del history del browser para que el "atrás"
/// de la PWA no vuelva a Google OAuth / login / redirects intermedios.
void limpiarHistorialAuthWeb() {
  try {
    final origin = html.window.location.origin;
    final search = html.window.location.search ?? '';
    final hash = html.window.location.hash;
    final path = html.window.location.pathname;
    final ensuciado = path != '/' || search.isNotEmpty || hash.isNotEmpty;
    if (ensuciado) {
      html.window.history.replaceState(null, '', '$origin/');
    }
  } catch (_) {
    // Best-effort: nunca romper el login.
  }
}
