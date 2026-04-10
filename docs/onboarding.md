# Guía de Onboarding — Mi Changan CS35 Plus Tracker

Esta guía cubre todo lo que necesitás para tener el proyecto corriendo localmente, desde cero, sin instalar Flutter ni el SDK de Android en tu máquina.

---

## Tabla de contenidos

1. [Prerequisitos](#1-prerequisitos)
2. [Clonar el repo y crear `.env.json`](#2-clonar-el-repo-y-crear-envjson)
3. [Comandos de desarrollo vía Docker](#3-comandos-de-desarrollo-vía-docker)
4. [Configurar Supabase (proyecto hosted)](#4-configurar-supabase-proyecto-hosted)
5. [Configurar GitHub Secrets](#5-configurar-github-secrets)
6. [Crear un release y obtener el APK](#6-crear-un-release-y-obtener-el-apk)
7. [Solución de problemas](#7-solución-de-problemas)

---

## 1. Prerequisitos

Antes de empezar, necesitás tener instalado:

| Herramienta | Versión mínima | Para qué se usa |
|-------------|---------------|-----------------|
| [Git](https://git-scm.com/) | 2.x | Clonar el repo y gestionar versiones |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) (o Docker Engine en Linux) | 24.x | Entorno de desarrollo Flutter reproducible |
| Cuenta en [GitHub](https://github.com/) | — | Repositorio, CI y releases |
| Cuenta en [Supabase](https://supabase.com/) | — | Base de datos y autenticación |

> **No necesitás instalar Flutter, Android Studio ni el SDK de Android en tu máquina.** Todo corre dentro del contenedor Docker.

### Verificar Docker

```bash
docker --version
# Docker version 24.x.x

docker compose version
# Docker Compose version v2.x.x
```

Si alguno de estos comandos falla, instalá Docker antes de continuar.

---

## 2. Clonar el repo y crear `.env.json`

### 2.1 Clonar

```bash
git clone https://github.com/<tu-usuario>/mi-changan.git
cd mi-changan
```

### 2.2 Crear `.env.json` a partir del ejemplo

```bash
cp .env.json.example .env.json
```

Abrí el archivo `.env.json` con cualquier editor de texto y completá con tus credenciales reales de Supabase:

```json
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "APP_NAME": "Mi Changan"
}
```

> ⚠️ **`.env.json` está en `.gitignore` y NUNCA debe ser commiteado.** Si hacés `git status` y aparece ese archivo, algo salió mal. Verificá que `.gitignore` lo lista correctamente antes de hacer cualquier commit.

---

## 3. Comandos de desarrollo vía Docker

El proyecto usa Docker como entorno canónico. Todos los comandos de Flutter corren dentro del contenedor — no se necesita nada instalado localmente.

### 3.1 Construir la imagen (primera vez)

```bash
docker compose build
```

Esto descarga la imagen base (~2 GB), instala el SDK de Android y pre-calienta el pub cache. Solo necesitás hacerlo la primera vez (o cuando cambie el `Dockerfile.dev`).

### 3.2 Instalar dependencias

```bash
docker compose run --rm flutter flutter pub get
```

### 3.3 Analizar el código

```bash
docker compose run --rm flutter flutter analyze
```

El análisis está configurado con `--fatal-infos`: cualquier warning o info se trata como error. El mismo check corre en CI en cada PR.

### 3.4 Correr los tests

```bash
docker compose run --rm flutter flutter test
```

### 3.5 Shell interactivo

Si necesitás correr múltiples comandos seguidos:

```bash
docker compose run --rm flutter bash
# Ya dentro del contenedor:
flutter pub get
flutter analyze
flutter test
```

### 3.6 Compilar APK de forma local

Solo para pruebas locales (requiere `.env.json` completo):

```bash
docker compose run --rm flutter flutter build apk --release --dart-define-from-file=.env.json
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. Configurar Supabase (proyecto hosted)

### 4.1 Crear un proyecto en Supabase

1. Ingresá a [supabase.com](https://supabase.com/) con tu cuenta.
2. Hacé clic en **New project**.
3. Completá: nombre del proyecto, contraseña para la base de datos (guardala segura), región.
4. Esperá ~2 minutos a que el proyecto quede activo.

### 4.2 Obtener la URL y la Anon Key

1. En el dashboard de tu proyecto, ir a **Project Settings → API**.
2. Copiar los valores de:
   - **Project URL** → `https://xxxxxxxxxxxx.supabase.co`
   - **anon / public** (bajo "Project API keys") → la clave larga que empieza con `eyJ...`

> **Nunca copies la `service_role` key** — esa tiene privilegios de administrador completos. Solo usá la `anon` key en el cliente Flutter.

### 4.3 Aplicar las migraciones

El proyecto incluye 5 migraciones SQL en `supabase/migrations/` que crean las tablas base con RLS habilitado. Para aplicarlas al proyecto hosted:

**Opción A — Supabase CLI (recomendado):**

```bash
# Instalar Supabase CLI (si no lo tenés)
npm install -g supabase

# Linkear con tu proyecto (necesitás el Project ID de la URL del dashboard)
supabase link --project-ref <project-ref>

# Aplicar migraciones
supabase db push
```

**Opción B — SQL Editor del dashboard:**

1. En el dashboard, ir a **SQL Editor**.
2. Abrir cada archivo de `supabase/migrations/` en orden (00001 → 00005).
3. Pegar el contenido y ejecutar cada uno.

### 4.4 Configurar autenticación

1. En el dashboard, ir a **Authentication → Settings**.
2. Activar el proveedor que quieras usar (Email/Password es el más simple para empezar).

---

## 5. Configurar GitHub Secrets

Los GitHub Secrets permiten que el workflow de release compile el APK con tus credenciales de Supabase **sin que esas credenciales estén en el código**.

### 5.1 Dónde configurar los secrets

1. En GitHub, ir a tu repositorio forkeado/creado.
2. **Settings → Secrets and variables → Actions**.
3. Hacer clic en **New repository secret** para cada uno.

### 5.2 Secrets requeridos

| Secret | Valor |
|--------|-------|
| `SUPABASE_URL` | La Project URL de Supabase (ej: `https://xxxxxxxxxxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | La anon/public key de Supabase (empieza con `eyJ...`) |

> Estos valores son exactamente los mismos que pusiste en tu `.env.json` local.

### 5.3 Verificar que los secrets están bien

Una vez configurados, podés crear un tag de prueba (ver sección siguiente) — si el workflow de release pasa sin errores, los secrets están correctamente configurados.

---

## 6. Crear un release y obtener el APK

El workflow `build-apk.yml` se dispara automáticamente cuando empujás un tag con formato `v*`.

### 6.1 Crear el tag y empujarlo

```bash
# Asegurarte de estar en main/master actualizado
git checkout master
git pull origin master

# Crear el tag con la versión semántica
git tag v0.1.0

# Empujar el tag a GitHub
git push origin v0.1.0
```

### 6.2 Seguir el progreso del workflow

1. En GitHub, ir a **Actions**.
2. Ver el workflow **Build APK** en ejecución.
3. El proceso tarda ~5-10 minutos (incluye pub get, tests y build).

### 6.3 Descargar el APK

Una vez que el workflow termina exitosamente:

1. Ir a **Releases** en tu repositorio de GitHub.
2. Encontrar el release `v0.1.0` (creado automáticamente).
3. Descargar `app-release.apk` desde los assets del release.
4. Instalarlo en tu dispositivo Android (necesitás habilitar instalación desde fuentes desconocidas en el teléfono).

---

## 7. Solución de problemas

### `docker compose build` falla con error de red

```
Error: failed to fetch packages
```

**Causa**: Sin conexión a internet durante el build.  
**Solución**: Verificar conexión y volver a intentar. Docker cachea capas, así que solo descarga lo que falta.

---

### `flutter pub get` falla dentro del contenedor

```
Running "flutter pub get" in app...
Because mi_changan requires SDK version >=3.x.x...
```

**Causa**: La imagen Docker usa Flutter stable, pero puede haber desfasaje con la versión declarada en `pubspec.yaml`.  
**Solución**: Actualizar la imagen con `docker compose pull` o ajustar la constraint de SDK en `pubspec.yaml`.

---

### `flutter analyze` reporta errores

```
error • ... • some_rule
```

**Causa**: El proyecto usa análisis estricto (`--fatal-infos`). Cualquier warning se trata como error.  
**Solución**: Leer el mensaje de error — generalmente es una importación innecesaria, una variable sin usar, o falta de tipado explícito. Corregirlo y volver a analizar.

---

### El workflow de CI falla en el PR

**Causa A — Tests fallando**: Correr `flutter test` localmente vía Docker para ver el error.  
**Causa B — Analyze fallando**: Correr `flutter analyze` localmente para ver qué regla se rompe.

El CI no usa secretos — si falla, es exclusivamente por código.

---

### El workflow de release falla con "secret not set"

```
Error: Input required and not supplied: files
```

**Causa**: Los GitHub Secrets `SUPABASE_URL` o `SUPABASE_ANON_KEY` no están configurados.  
**Solución**: Ver [sección 5](#5-configurar-github-secrets) y configurar ambos secrets antes de volver a crear el tag.

---

### El APK instalado muestra pantalla en blanco o crashea

**Causa más probable**: Las credenciales de Supabase en los GitHub Secrets son incorrectas o el proyecto Supabase no tiene las migraciones aplicadas.  
**Solución**:
1. Verificar que `SUPABASE_URL` y `SUPABASE_ANON_KEY` son correctos en GitHub Secrets.
2. Verificar que las 5 migraciones están aplicadas en el proyecto Supabase (ver [sección 4.3](#43-aplicar-las-migraciones)).

---

### `.env.json` aparece en `git status`

```
Untracked files:
    .env.json
```

> ⚠️ **¡PELIGRO!** Esto significa que `.env.json` NO está siendo ignorado por Git.

**Solución inmediata**:
1. Verificar que `.gitignore` contiene la línea `.env.json`.
2. Si la línea existe pero el archivo aparece igual, puede ser que esté trackeado por error. Ejecutar:
   ```bash
   git rm --cached .env.json
   ```
3. **Nunca hacer `git add .env.json` ni commitearlo.**

---

## Referencia rápida de comandos

| Acción | Comando |
|--------|---------|
| Instalar deps | `docker compose run --rm flutter flutter pub get` |
| Analizar código | `docker compose run --rm flutter flutter analyze` |
| Correr tests | `docker compose run --rm flutter flutter test` |
| Shell interactivo | `docker compose run --rm flutter bash` |
| Build APK local | `docker compose run --rm flutter flutter build apk --release --dart-define-from-file=.env.json` |
| Crear release | `git tag v0.1.0 && git push origin v0.1.0` |
