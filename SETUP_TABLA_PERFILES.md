# 🗄️ Setup Tabla Perfiles en Supabase

Este documento contiene el SQL necesario para crear la tabla `perfiles` y el bucket de Storage para las fotos.

---

## 📋 Paso 1: Crear Tabla `perfiles`

Ve a **Supabase Dashboard** → **SQL Editor** → **New query** y ejecuta:

```sql
-- Tabla de perfiles de usuarios
CREATE TABLE IF NOT EXISTS perfiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  nombre TEXT NOT NULL,
  edad INTEGER NOT NULL CHECK (edad >= 1 AND edad <= 100),
  foto_url TEXT,
  visible_en_pools BOOLEAN DEFAULT false,
  instagram TEXT,
  tiktok TEXT,
  profile_complete BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejorar performance
CREATE INDEX idx_perfiles_username ON perfiles(username);
CREATE INDEX idx_perfiles_profile_complete ON perfiles(profile_complete);

-- Habilitar Row Level Security (RLS)
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

-- Política: Todos pueden leer perfiles públicos
CREATE POLICY "Perfiles públicos son visibles para todos"
  ON perfiles
  FOR SELECT
  USING (visible_en_pools = true OR auth.uid() = id);

-- Política: Los usuarios solo pueden ver su propio perfil privado
CREATE POLICY "Usuarios pueden ver su propio perfil"
  ON perfiles
  FOR SELECT
  USING (auth.uid() = id);

-- Política: Los usuarios pueden crear su propio perfil
CREATE POLICY "Usuarios pueden crear su perfil"
  ON perfiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Política: Los usuarios solo pueden actualizar su propio perfil
CREATE POLICY "Usuarios pueden actualizar su perfil"
  ON perfiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_perfiles_updated_at
  BEFORE UPDATE ON perfiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

---

## 📦 Paso 2: Crear Bucket de Storage para Avatars

Ve a **Supabase Dashboard** → **Storage** → **Create bucket**

**Configuración**:
- **Name**: `avatars`
- **Public**: ✅ (marcar como público para que las URLs funcionen sin autenticación)
- **Allowed MIME types**: `image/jpeg, image/png, image/jpg, image/webp`
- **Max file size**: `5 MB`

### Configurar Políticas de Storage

Ve a **Storage** → **avatars** → **Policies** y crea estas políticas:

```sql
-- Política: Usuarios pueden subir sus propios avatars
CREATE POLICY "Usuarios pueden subir su avatar"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Usuarios pueden actualizar su propio avatar
CREATE POLICY "Usuarios pueden actualizar su avatar"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Todos pueden ver los avatars (bucket público)
CREATE POLICY "Avatars son públicos"
ON storage.objects
FOR SELECT
USING (bucket_id = 'avatars');
```

---

## 🔄 Paso 3: Verificar que Todo Funciona

### Test 1: Ver la tabla

```sql
SELECT * FROM perfiles;
```

Debería devolver vacío (sin errores).

### Test 2: Ver el bucket

Ve a **Storage** → Deberías ver el bucket `avatars` creado.

---

## 🎯 Estructura de la Tabla

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | ID del usuario (foreign key a auth.users) |
| `username` | TEXT | Username único (ej: @santi1) - ÚNICO |
| `nombre` | TEXT | Nombre o apodo (ej: "Santiago") |
| `edad` | INTEGER | Edad del usuario (1-100) |
| `foto_url` | TEXT | URL pública de la foto en Storage |
| `visible_en_pools` | BOOLEAN | Si el perfil es visible en pools públicos |
| `instagram` | TEXT | URL del perfil de Instagram (opcional) |
| `tiktok` | TEXT | URL del perfil de TikTok (opcional) |
| `profile_complete` | BOOLEAN | Si el usuario completó su perfil |
| `created_at` | TIMESTAMP | Fecha de creación |
| `updated_at` | TIMESTAMP | Última actualización (auto) |

---

## ✅ Checklist de Setup

- [ ] Ejecutar SQL para crear tabla `perfiles`
- [ ] Verificar que la tabla existe: `SELECT * FROM perfiles;`
- [ ] Crear bucket `avatars` en Storage
- [ ] Marcar bucket `avatars` como **público**
- [ ] Configurar políticas de Storage
- [ ] Ejecutar `flutter pub get` para instalar `image_picker`

---

## 🧪 Probar la Pantalla

1. Ejecuta `flutter pub get` para instalar dependencies
2. Corre la app: `flutter run`
3. Regístrate con un email nuevo o inicia sesión
4. Deberías ver la pantalla "Crea tu perfil en dos minutos!"
5. Prueba cada campo:
   - Username: ingresa uno, click "Validar"
   - Nombre: ingresa tu nombre
   - Edad: selecciona del picker
   - Foto: toca el círculo, elige cámara o galería
   - Switch: activa/desactiva perfil público
   - Si público: ingresa Instagram y TikTok
6. Click "Crear Perfil"
7. Debería guardarse en Supabase y navegar a Home

---

## 🐛 Si Algo Falla

### Error: "relation perfiles does not exist"
**Solución**: Ejecuta el SQL del Paso 1 en Supabase Dashboard

### Error: "bucket avatars does not exist"
**Solución**: Crea el bucket en Storage (Paso 2)

### Error: "permission denied for relation perfiles"
**Solución**: Verifica que las políticas RLS estén configuradas (Paso 1)

### Error al subir foto: "new row violates row-level security policy"
**Solución**: Verifica las políticas de Storage (Paso 2)

### Error: "Username ya existe" pero no es verdad
**Solución**: Los usernames se guardan en lowercase. Verifica en:
```sql
SELECT username FROM perfiles WHERE username = 'tuusername';
```

---

## 📝 Próximos Pasos

Una vez que funcione la creación de perfiles:

1. **Modificar app.dart** para verificar `profile_complete`:
   - Si `true` → Home
   - Si `false` → Crear Perfil

2. **Agregar validación de edad** (18+ para alcohol):
   - Mostrar warning si edad < 18
   - Restringir algunas features

3. **Optimizar subida de fotos**:
   - Comprimir antes de subir
   - Mostrar progress bar
   - Permitir editar/recortar

4. **Permitir editar perfil después**:
   - Pantalla "Editar Perfil" desde settings
   - Mantener mismo username (no editable)
   - Actualizar el resto de campos

---

**Estado**: ✅ SQL Listo para Ejecutar en Supabase

**Fernecito MVP** - Perfiles completos y funcionales 🥃
