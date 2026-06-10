# 🔐 Configuración de OAuth en Supabase (Google y Facebook)

Este documento explica paso a paso cómo configurar Google y Facebook OAuth en Supabase para que funcione en tu app Fernecito.

---

## 📋 Resumen

Para que los botones de "Continuar con Google" y "Continuar con Facebook" funcionen, necesitas:

1. **Habilitar los providers en Supabase**
2. **Crear aplicaciones OAuth en Google y Facebook**
3. **Configurar redirect URLs**
4. **Copiar credenciales (Client ID, Secret) en Supabase**

---

## 🔴 Google OAuth

### Paso 1: Crear proyecto en Google Cloud Console

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Nombre sugerido: "Fernecito MVP"

### Paso 2: Configurar OAuth Consent Screen

1. En el menú lateral, ve a **APIs & Services** → **OAuth consent screen**
2. Selecciona **External** (usuarios externos)
3. Completa la información:
   - **App name**: `Fernecito`
   - **User support email**: Tu email
   - **Developer contact information**: Tu email
4. Click en **Save and Continue**
5. En **Scopes**, deja los defaults (email, profile, openid)
6. Click en **Save and Continue**
7. En **Test users**, agrega tu email para testing
8. Click en **Save and Continue**

### Paso 3: Crear credenciales OAuth

1. Ve a **APIs & Services** → **Credentials**
2. Click en **Create Credentials** → **OAuth client ID**
3. Selecciona **Web application**
4. Nombre: `Fernecito Web Client`
5. En **Authorized JavaScript origins**, agrega:
   ```
   https://cuzphjyfidttkylfwkdg.supabase.co
   ```
6. En **Authorized redirect URIs**, agrega:
   ```
   https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback
   ```
7. Click en **Create**
8. **IMPORTANTE**: Copia el **Client ID** y **Client Secret** (los necesitarás en el siguiente paso)

### Paso 4: Configurar en Supabase Dashboard

1. Ve a tu [Supabase Dashboard](https://supabase.com/dashboard/project/cuzphjyfidttkylfwkdg)
2. Ve a **Authentication** → **Providers**
3. Busca **Google** en la lista
4. Habilita el toggle **Enable Sign in with Google**
5. Pega el **Client ID** de Google
6. Pega el **Client Secret** de Google
7. Click en **Save**

### Paso 5: Configurar para iOS (cuando hagas el build para App Store)

Para iOS necesitarás agregar estos redirect URIs adicionales en Google Cloud Console:

```
fernecito://callback
io.supabase.fernecito://callback
```

Y configurar el URL Scheme en `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fernecito</string>
    </array>
  </dict>
</array>
```

---

## 🔵 Facebook OAuth

### Paso 1: Crear aplicación en Facebook Developers

1. Ve a [Facebook Developers](https://developers.facebook.com/)
2. Click en **My Apps** → **Create App**
3. Selecciona **Consumer** como tipo de app
4. Completa la información:
   - **App name**: `Fernecito`
   - **App contact email**: Tu email
5. Click en **Create App**

### Paso 2: Agregar Facebook Login

1. En el dashboard de tu app, busca **Facebook Login** en productos
2. Click en **Set Up**
3. Selecciona **Web** como plataforma
4. En **Site URL**, ingresa:
   ```
   https://cuzphjyfidttkylfwkdg.supabase.co
   ```
5. Click en **Save** y luego en **Continue**

### Paso 3: Configurar OAuth Redirect URIs

1. En el menú lateral, ve a **Facebook Login** → **Settings**
2. En **Valid OAuth Redirect URIs**, agrega:
   ```
   https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback
   ```
3. Click en **Save Changes**

### Paso 4: Obtener credenciales

1. En el menú lateral, ve a **Settings** → **Basic**
2. Copia el **App ID** (esto es tu Client ID)
3. Click en **Show** en **App Secret** y copia el valor (esto es tu Client Secret)

### Paso 5: Configurar en Supabase Dashboard

1. Ve a tu [Supabase Dashboard](https://supabase.com/dashboard/project/cuzphjyfidttkylfwkdg)
2. Ve a **Authentication** → **Providers**
3. Busca **Facebook** en la lista
4. Habilita el toggle **Enable Sign in with Facebook**
5. Pega el **Client ID** (App ID de Facebook)
6. Pega el **Client Secret** (App Secret de Facebook)
7. Click en **Save**

### Paso 6: Publicar la app (importante para producción)

**Para testing**: Tu app funciona en modo "Development" solo con los emails que agregues como testers en Facebook Developers.

**Para producción**:
1. Ve a **App Review** en Facebook Developers
2. Completa la información requerida
3. Solicita permisos de `email` y `public_profile`
4. Envía tu app a revisión
5. Una vez aprobada, cambia el modo a **Live** en Settings → Basic

---

## 📱 Configuración para iOS/Android (Mobile Deep Links)

### Para iOS

En `ios/Runner/Info.plist`, agrega:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fernecito</string>
    </array>
  </dict>
</array>
```

### Para Android

En `android/app/src/main/AndroidManifest.xml`, dentro de `<activity>`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="fernecito"
    android:host="callback" />
</intent-filter>
```

---

## 🧪 Probar OAuth

### Desarrollo local (Web):

1. Ejecuta `flutter run -d chrome`
2. Click en "Continuar con Google" o "Continuar con Facebook"
3. Se abrirá una ventana de autorización
4. Autoriza la app
5. Deberías ser redirigido automáticamente

### Desarrollo mobile:

Para mobile, OAuth funciona mejor con:
- **Dispositivos físicos** (recomendado)
- O emuladores con Google Play Services instalados

### Testing con usuarios específicos:

1. **Google**: Agrega emails en Google Cloud Console → OAuth consent screen → Test users
2. **Facebook**: Agrega usuarios en Facebook Developers → Roles → Test Users

---

## ⚠️ Problemas Comunes

### "Error 400: redirect_uri_mismatch" (Google)

**Solución**: Verifica que el redirect URI en Google Cloud Console sea **exactamente**:
```
https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback
```

### "URL Blocked: This redirect failed" (Facebook)

**Solución**: Verifica que el redirect URI en Facebook Login Settings sea **exactamente**:
```
https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback
```

### OAuth funciona en web pero no en mobile

**Solución**:
1. Verifica que los deep links estén configurados en `Info.plist` (iOS) y `AndroidManifest.xml` (Android)
2. En Google Cloud Console, agrega el redirect URI para mobile: `fernecito://callback`
3. En Facebook, ve a Settings y asegúrate de que tu Bundle ID (iOS) o Package Name (Android) estén registrados

### "App not approved" (Facebook)

**Solución**: Mientras estés en modo Development, solo funcionará con usuarios agregados como testers. Para producción, debes enviar tu app a App Review de Facebook.

---

## 📝 Checklist de Configuración

### Google OAuth ✅
- [ ] Proyecto creado en Google Cloud Console
- [ ] OAuth consent screen configurado
- [ ] OAuth Client ID creado
- [ ] Redirect URI agregado: `https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback`
- [ ] Client ID y Secret copiados a Supabase
- [ ] Provider habilitado en Supabase Dashboard

### Facebook OAuth ✅
- [ ] App creada en Facebook Developers
- [ ] Facebook Login agregado
- [ ] Redirect URI agregado: `https://cuzphjyfidttkylfwkdg.supabase.co/auth/v1/callback`
- [ ] App ID y App Secret copiados a Supabase
- [ ] Provider habilitado en Supabase Dashboard

### Mobile (cuando hagas build) ✅
- [ ] Deep links configurados en iOS (`Info.plist`)
- [ ] Deep links configurados en Android (`AndroidManifest.xml`)
- [ ] Redirect URI mobile agregado en Google: `fernecito://callback`
- [ ] Bundle ID registrado en Facebook

---

## 🎯 Próximos Pasos

Una vez configurado OAuth:

1. **Probar en web** primero (más fácil de debugear)
2. **Agregar usuarios de prueba** en ambas plataformas
3. **Probar en dispositivo físico** para mobile
4. **Crear tabla `perfiles`** en Supabase (ver `CONFIGURACION_SUPABASE.md`)
5. **Implementar pantalla de crear perfil** después de OAuth login

---

## 📚 Referencias

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Google OAuth Setup](https://support.google.com/cloud/answer/6158849)
- [Facebook Login Docs](https://developers.facebook.com/docs/facebook-login)

---

**Fernecito MVP** - OAuth configurado y listo para escalar 🥃
