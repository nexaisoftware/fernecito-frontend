/// Modelo de datos para promociones exclusivas in-local.
/// 
/// Campos MVP:
/// - flyer (imagen stories/reels format)
/// - fecha inicio/fin, auto-expira +12hs
/// - tipos predefinidos (chips: 2x1, 3x2, % descuento, grupo 20%, entrada free, etc.)
/// - string libre para descripción adicional
/// - QR único por redemption (finito si local pone cupos, FOMO "quedan X")
/// - local_id (relación con perfil local)
/// - jerarquía (fila 1-3 pagada grande, resto free cronológico)
/// 
/// Uso: Serialización con Supabase, validación de fechas/cupos,
/// generación de QR codes, y lógica de expiración.
/// 
/// Stack: freezed/json_serializable para modelos inmutables
