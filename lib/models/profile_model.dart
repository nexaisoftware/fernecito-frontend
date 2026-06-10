/// Modelo de datos para perfiles de usuario y locales.
/// 
/// Perfil Usuario:
/// - foto, alias único (@santi1), IG/TikTok, estado corto (20-30 chars + emojis)
/// - switch "visible en pools"
/// 
/// Perfil Local:
/// - nombre, bio, 5 fotos, links (maps, WhatsApp, redes), verified badge
/// 
/// Uso: Serialización/deserialización con Supabase, validación de datos,
/// y type safety en toda la app.
/// 
/// Stack: freezed/json_serializable para modelos inmutables y serialización
