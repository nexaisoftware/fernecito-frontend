/// Provider de autenticación usando Riverpod.
/// 
/// Responsabilidades:
/// - Gestionar estado de autenticación (logueado/deslogueado, usuario actual)
/// - Métodos de inicio de sesión, registro, cerrar sesión, magic link
/// - Validación de roles (usuario/local/admin)
/// - Manejo de errores y estados de carga
/// - Persistencia de sesión
/// 
/// Stack: Riverpod para state management reactivo
/// Backend: Supabase Auth
/// 
/// Uso:
/// ```dart
/// final proveedorAuth = ref.watch(proveedorAutenticacionProvider);
/// await ref.read(proveedorAutenticacionProvider.notifier).iniciarSesion(email, password);
/// ```
