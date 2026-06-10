/// Bandera global para indicar que el usuario está en el flujo de recuperación
/// de contraseña (paso 2 o 3: verificar OTP / nueva contraseña).
///
/// AuthGate debe ignorar eventos signedIn y passwordRecovery mientras esta
/// bandera sea true, para no reemplazar la pantalla y perder el paso 3.
library;

class RecoveryFlowFlag {
  RecoveryFlowFlag._();

  static bool _enFlujoRecuperacion = false;

  static bool get enFlujoRecuperacion => _enFlujoRecuperacion;

  static void activar() {
    _enFlujoRecuperacion = true;
  }

  static void desactivar() {
    _enFlujoRecuperacion = false;
  }
}
