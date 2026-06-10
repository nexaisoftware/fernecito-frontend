# 🔧 Configuración de Supabase para Fernecito

Este documento explica cómo está configurado Supabase en el proyecto y qué pasos seguir.

## ✅ Estado Actual

**Supabase está configurado y listo para usar** con las siguientes credenciales:

- **URL**: `https://cuzphjyfidttkylfwkdg.supabase.co`
- **Región**: Automática (Supabase asigna)
- **Anon Key**: Configurada en archivo `.env`

## 📁 Archivos Configurados

### 1. `.env` (Credenciales)
```
URL_SUPABASE=https://cuzphjyfidttkylfwkdg.supabase.co
CLAVE_PUBLICA_SUPABASE=eyJhbGciOi...
```
⚠️ **Este archivo NO debe subirse a Git** (está en `.gitignore`)

### 2. `main.dart` (Inicialización)
- Carga el archivo `.env` al inicio
- Inicializa la conexión con Supabase
- Muestra logs de éxito/error en consola

### 3. `supabase_client.dart` (Cliente Singleton)
- Proporciona acceso único al cliente de Supabase
- Patrón Singleton para evitar múltiples instancias

### 4. `pantalla_login.dart` (Autenticación)
- Implementa login con email/password
- Validaciones de campos
- Manejo de errores específicos
- Indicador de carga

## 🚀 Cómo Usar

### Ejecutar la app
```bash
flutter pub get
flutter run
```

Al iniciar, verás en la consola:
```
✅ Variables de entorno cargadas correctamente
✅ Supabase inicializado correctamente
📡 Conectado a: https://cuzphjyfidttkylfwkdg.supabase.co
```

### Probar el login

**IMPORTANTE**: Para que el login funcione, primero debes crear usuarios en Supabase.

#### Opción A: Crear usuario desde Dashboard (Recomendado para testing)
1. Ve a tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard)
2. Ve a **Authentication** → **Users**
3. Click en **Add user** → **Create new user**
4. Ingresa:
   - Email: `test@fernecito.com`
   - Password: `test123` (mínimo 6 caracteres)
   - Auto Confirm User: ✅ (para no tener que confirmar email)
5. Click en **Create user**

#### Opción B: Registro desde la app (Próximo paso)
Necesitamos crear la pantalla de registro (`pantalla_registro.dart`)

## 📊 Próximos Pasos

### 1. Crear tabla `perfiles` en Supabase
Ve a **SQL Editor** en Supabase Dashboard y ejecuta:

```sql
-- Tabla de perfiles de usuario
CREATE TABLE perfiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  alias TEXT UNIQUE NOT NULL,
  nombre_completo TEXT,
  foto_url TEXT,
  instagram TEXT,
  tiktok TEXT,
  estado TEXT,
  visible_en_pools BOOLEAN DEFAULT true,
  rol TEXT DEFAULT 'user' CHECK (rol IN ('user', 'local', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS (Row Level Security) - Los usuarios solo ven su propio perfil
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden leer todos los perfiles
CREATE POLICY "Perfiles públicos de lectura" ON perfiles
  FOR SELECT USING (true);

-- Política: Los usuarios solo pueden actualizar su propio perfil
CREATE POLICY "Usuarios pueden actualizar su perfil" ON perfiles
  FOR UPDATE USING (auth.uid() = id);

-- Política: Solo inserts propios
CREATE POLICY "Usuarios pueden crear su perfil" ON perfiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Trigger para crear perfil automáticamente al registrarse
CREATE OR REPLACE FUNCTION crear_perfil_usuario()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, alias)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'alias', 'usuario_' || substring(NEW.id::text, 1, 8))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION crear_perfil_usuario();
```

### 2. Crear pantalla de registro
Implementar `pantalla_registro.dart` con:
- Campos: email, contraseña, confirmar contraseña, alias
- Llamada a `supabase.auth.signUp()`
- Crear perfil automáticamente (via trigger de arriba)

### 3. Habilitar Email Auth en Supabase
1. Ve a **Authentication** → **Providers**
2. Habilita **Email**
3. En **Email Templates**, personaliza los mensajes en español

### 4. Configurar navegación después del login
En `pantalla_login.dart`, navegar a la pantalla principal después de login exitoso:
```dart
// TODO en línea ~259
Navigator.of(context).pushReplacement(
  CupertinoPageRoute(builder: (context) => const PantallaPrincipal()),
);
```

### 5. Persistencia de sesión
Supabase automáticamente persiste la sesión. Para verificar si hay usuario logueado:
```dart
final usuario = ServicioSupabase().usuarioActual;
if (usuario != null) {
  // Usuario ya está logueado, ir directo a home
}
```

## 🔐 Seguridad

### RLS (Row Level Security)
Siempre habilita RLS en todas las tablas:
```sql
ALTER TABLE nombre_tabla ENABLE ROW LEVEL SECURITY;
```

### Políticas Recomendadas
- **Lectura pública**: Promos, locales verificados
- **Lectura autenticada**: Perfiles de usuarios
- **Escritura propia**: Solo el dueño puede modificar sus datos
- **Escritura admin**: Solo rol admin puede ciertas operaciones

## 📝 Logs y Debug

Para ver qué está pasando con Supabase, revisa la consola:
```dart
print('Usuario actual: ${ServicioSupabase().usuarioActual}');
print(ConfiguracionSupabase.obtenerInfoDebug());
```

## 🆘 Solución de Problemas

### "Invalid login credentials"
- Verifica que el usuario exista en Supabase Dashboard
- Verifica que la contraseña tenga al menos 6 caracteres
- Verifica que el email esté confirmado (o usa Auto Confirm en dashboard)

### "No se pudo inicializar Supabase"
- Verifica que el archivo `.env` exista
- Verifica que las credenciales sean correctas
- Ejecuta `flutter pub get` para instalar `flutter_dotenv`

### Video de fondo no se ve
- Verifica que `fondologin.mp4` esté en `assets/videos/`
- Verifica que `pubspec.yaml` incluya `- assets/videos/`
- Ejecuta `flutter clean && flutter pub get`

## 🎯 Resumen

✅ Supabase configurado y conectado
✅ Login con email/password funcional
✅ Validaciones y manejo de errores
✅ Variables de entorno seguras
⏳ Pendiente: Crear tabla perfiles
⏳ Pendiente: Pantalla de registro
⏳ Pendiente: Navegación post-login

---

**Fernecito MVP** - Conectando Córdoba, una promo a la vez 🥃
