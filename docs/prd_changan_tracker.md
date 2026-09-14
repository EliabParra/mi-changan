# PRD: AutoTracker — Vehicle Mileage & Maintenance Tracker

> **Versión**: 1.0 — MVP  
> **Fecha**: 2026-04-04  
> **Autor**: AI Architect  
> **Basado en**: Análisis del prototipo web `changan-cs35-plus-tracker`

---

## 1. Visión del Producto

**AutoTracker** es una app móvil personal para gestionar el kilometraje, mantenimiento y servicios de un vehículo (inicialmente Changan CS35 Plus 2026). Reemplaza el prototipo web actual (React + SQLite + Express) con una solución mobile-first usando **Flutter** y **Supabase**.

### Objetivo del MVP

Una app Android funcional que el usuario pueda instalar desde un APK generado en las GitHub Releases, para uso personal diario. No se busca publicar en stores en esta etapa.

### Diferencias clave vs. el prototipo actual

| Aspecto | Prototipo Web | AutoTracker MVP |
|---------|--------------|-----------------|
| Plataforma | Web (React SPA) | Mobile (Flutter Android) |
| Base de datos | SQLite local | Supabase (PostgreSQL remoto) |
| Autenticación | Ninguna | Supabase Auth (email/magic link) |
| Desarrollo | Node.js local | Docker (Flutter SDK containerizado) |
| Distribución | AI Studio deploy | APK en GitHub Releases |
| Persistencia | Archivo .db local | Cloud + offline-first con cache local |

---

## 2. Usuarios y Contexto

### Persona Principal

- **Nombre**: Eliab (el developer/usuario)
- **Contexto**: Dueño de un Changan CS35 Plus 2026
- **Necesidad**: Registrar kilometraje diario, controlar mantenimientos, y proyectar uso futuro
- **Dispositivo**: Android (smartphone personal)
- **Uso**: Diario, brevemente al subir/bajar del auto

### Escenarios de Uso

1. **Al subir al auto**: Abrir la app, ver dashboard con km actual y alertas de mantenimiento
2. **Al estacionar**: Registrar lectura de odómetro manualmente (10 segundos)
3. **En un viaje largo**: Activar GPS tracker para registro automático
4. **Antes de ir al taller**: Consultar qué servicios están próximos/vencidos
5. **Después del taller**: Registrar el servicio realizado con costo y taller
6. **Fin de semana**: Revisar proyecciones y estadísticas de uso

---

## 3. Funcionalidades del MVP

### 3.1 Dashboard (Pantalla Principal)

**Propósito**: Vista rápida del estado del vehículo

- Kilometraje actual (valor máximo registrado)
- Promedio diario de km (histórico)
- Total de km recorridos desde la asignación
- Resumen semanal (km esta semana, promedio semanal vs histórico)
- Alertas de mantenimiento próximo (< 500 km restantes)

### 3.2 Registro de Kilometraje

**Propósito**: Registrar lecturas del odómetro

- **Modo Odómetro**: Ingresar lectura total actual
- **Modo Distancia**: Ingresar km recorridos (se suma al máximo actual)
- Campos: fecha, valor en km
- Historial de registros con opción de eliminar
- Validaciones: no vacío, número positivo, fecha válida

### 3.3 GPS Tracker

**Propósito**: Registro automático de distancia recorrida

- Mapa en tiempo real con posición actual (usar paquete Flutter de mapas)
- Iniciar/Detener rastreo
- Contador de distancia en el viaje actual
- Al detener: guarda log automáticamente con tipo "gps" y coordenadas
- Auto-guardado del progreso cada 60 segundos
- Reanudación de viaje si se cerró la app (últimas 2 horas)

> [!IMPORTANT]
> El GPS tracker requiere permisos de ubicación en Android. Evaluar si el MVP necesita background location o solo foreground.

### 3.4 Recordatorios de Mantenimiento

**Propósito**: Alertas basadas en km recorridos

- Crear recordatorio: mensaje, intervalo en km, último km de servicio
- Barra de progreso visual hacia el próximo servicio
- Estado: normal (> 500 km restantes), advertencia (≤ 500 km), vencido (≤ 0 km)
- Eliminar recordatorio

### 3.5 Registro de Servicios

**Propósito**: Historial de mantenimientos realizados

- Campos: fecha, tipo de servicio, costo, taller, km al momento del servicio
- Vincular opcionalmente a un recordatorio recurrente (actualiza el `last_service_km` del recordatorio)
- Historial ordenado por fecha
- Eliminar registro

### 3.6 Proyecciones

**Propósito**: Estimar km futuros basados en promedio de uso

- Gráfico de área: km históricos + proyección futura (1M, 6M, 1A)
- Líneas de referencia para los recordatorios de mantenimiento
- **Calculadora**: "¿Cuándo llegaré a X km?" y "¿Cuánto tendré el día Y?"
- Proyecciones rápidas: km estimados a 1, 3 y 6 meses

### 3.7 Configuración

**Propósito**: Datos base del vehículo y preferencias

- Km inicial del vehículo
- Fecha de compra y fecha de asignación
- Medida de neumáticos
- Modo claro/oscuro
- **Exportar/Importar** datos (JSON backup — mantener compatibilidad con el prototipo web)

---

## 4. Funcionalidades Excluidas del MVP

Estas features se considerarán para versiones futuras:

- [ ] Multi-vehículo (soporte para más de un auto)
- [ ] Fotos adjuntas a servicios
- [ ] Push notifications nativas para recordatorios
- [ ] Gastos de combustible y cálculo de consumo
- [ ] Integración OBD-II
- [ ] Compartir datos con otros usuarios
- [ ] Publicación en Google Play / App Store
- [ ] Versión iOS

---

## 5. Arquitectura Técnica

### 5.1 Stack

| Componente | Tecnología | Justificación |
|-----------|-----------|---------------|
| **Frontend** | Flutter 3.x (Dart) | Cross-platform, single codebase, material design nativo |
| **Backend** | Supabase (hosted) | PostgreSQL, Auth, Realtime, Row Level Security — zero backend code |
| **Mapas** | `flutter_map` + OpenStreetMap | Open source, sin API key requerida |
| **Gráficos** | `fl_chart` | Gráficos de alta calidad para Flutter |
| **State Management** | Riverpod | Escalable, testeable, type-safe |
| **Offline** | `drift` (SQLite local) + sync | Cache local para uso sin internet |
| **Dev Environment** | Docker (Flutter SDK) | Sin instalar Flutter/Android SDK localmente |
| **CI/CD** | GitHub Actions | Build APK → Release automática |

### 5.2 Diagrama de Arquitectura

```
┌──────────────────────────────┐
│       Flutter App (Dart)     │
│  ┌────────────────────────┐  │
│  │   Presentation Layer   │  │
│  │   (Screens + Widgets)  │  │
│  ├────────────────────────┤  │
│  │   Application Layer    │  │
│  │   (Riverpod Providers) │  │
│  ├────────────────────────┤  │
│  │    Domain Layer        │  │
│  │   (Models + Repos)     │  │
│  ├────────────────────────┤  │
│  │ Infrastructure Layer   │  │
│  │ (Supabase + drift)     │  │
│  └────────────────────────┘  │
└──────────────┬───────────────┘
               │ HTTPS
               ▼
┌──────────────────────────────┐
│        Supabase Cloud        │
│  ┌─────────┐ ┌────────────┐  │
│  │  Auth   │ │ PostgreSQL │  │
│  │ (Email) │ │  + RLS     │  │
│  └─────────┘ └────────────┘  │
│  ┌─────────┐ ┌────────────┐  │
│  │ Storage │ │  Realtime   │  │
│  │ (futuro)│ │  (futuro)   │  │
│  └─────────┘ └────────────┘  │
└──────────────────────────────┘
```

### 5.3 Modelo de Datos (Supabase PostgreSQL)

```sql
-- Tabla de perfiles (extiende auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Configuración del vehículo por usuario
CREATE TABLE vehicle_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, key)
);

-- Registros de kilometraje
CREATE TABLE mileage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  km_value DOUBLE PRECISION NOT NULL,
  type TEXT DEFAULT 'manual' CHECK (type IN ('manual', 'gps')),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recordatorios de mantenimiento
CREATE TABLE reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  interval_km DOUBLE PRECISION NOT NULL,
  last_service_km DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Registros de servicio
CREATE TABLE service_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  service_type TEXT NOT NULL,
  cost DOUBLE PRECISION NOT NULL,
  workshop TEXT NOT NULL,
  km_at_service DOUBLE PRECISION,
  reminder_id UUID REFERENCES reminders(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 5.4 Row Level Security (RLS)

Cada tabla tendrá políticas RLS para que un usuario solo vea y modifique sus propios datos:

```sql
-- Ejemplo para mileage_logs (aplicar mismo patrón a todas las tablas)
ALTER TABLE mileage_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own logs"
  ON mileage_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own logs"
  ON mileage_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own logs"
  ON mileage_logs FOR DELETE
  USING (auth.uid() = user_id);
```

> [!TIP]
> Aunque es un MVP para un solo usuario, implementar RLS desde el día 1 prepara la app para multi-usuario sin refactoring.

---

## 6. Entorno de Desarrollo con Docker

### 6.1 Filosofía

Zero-install: El developer NO necesita instalar Flutter SDK, Android SDK, ni Dart localmente. Todo corre dentro de containers Docker.

### 6.2 Docker Setup

```dockerfile
# Dockerfile.dev
FROM ghcr.io/cirruslabs/flutter:latest

# Android SDK components
RUN yes | sdkmanager --licenses
RUN sdkmanager "platforms;android-34" "build-tools;34.0.0"

WORKDIR /app
COPY . .

RUN flutter pub get
```

```yaml
# docker-compose.yml
services:
  flutter:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/app
      - flutter-cache:/root/.pub-cache
    ports:
      - "8080:8080"  # Flutter web debug (para testing rápido)
    command: bash

volumes:
  flutter-cache:
```

### 6.3 Comandos de Desarrollo

```bash
# Entrar al container
docker compose run --rm flutter bash

# Dentro del container:
flutter pub get
flutter analyze
flutter test
flutter build apk --release  # Genera el APK
```

### 6.4 Build del APK

```bash
# Build release APK desde Docker
docker compose run --rm flutter flutter build apk --release

# El APK se genera en: build/app/outputs/flutter-apk/app-release.apk
```

> [!WARNING]
> Para firmar el APK se necesita un keystore. En el MVP se puede usar el debug keystore para uso personal. Para publicación futura se necesitará un release keystore.

---

## 7. Supabase — Guía de Configuración

### 7.1 Proyecto Supabase

1. Crear cuenta en [supabase.com](https://supabase.com)
2. Crear nuevo proyecto (free tier es suficiente para MVP)
3. Guardar la **Project URL** y la **anon key**

### 7.2 Configuración de Auth

- Habilitar **Email** como provider
- Opcionalmente habilitar **Magic Link** (login sin password)
- Configurar redirect URLs para la app Flutter

### 7.3 Migraciones de Base de Datos

Usar **Supabase CLI** para gestionar migraciones:

```bash
# Instalar Supabase CLI
npm install -g supabase

# Inicializar
supabase init

# Crear migración
supabase migration new create_initial_tables

# Aplicar migraciones
supabase db push
```

> [!TIP]
> Mantener las migraciones en el repo bajo `supabase/migrations/` para versionarlas con git. Esto es clave para escalabilidad.

### 7.4 Variables de Entorno

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Estas se configuran en Flutter como constantes de compilación o usando un archivo `.env` con `flutter_dotenv`.

---

## 8. Estructura del Proyecto Flutter

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp config, routing
├── core/
│   ├── constants/               # Colores, strings, dimensiones
│   ├── theme/                   # ThemeData (light + dark)
│   ├── router/                  # GoRouter config
│   └── providers/               # Core providers (supabase client, etc)
├── features/
│   ├── auth/
│   │   ├── data/                # Auth repository impl
│   │   ├── domain/              # Auth models
│   │   └── presentation/        # Login screen
│   ├── dashboard/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── mileage/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── tracker/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── maintenance/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── services/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── projections/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── settings/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/
    ├── widgets/                 # Widgets reutilizables
    ├── utils/                   # Helpers (haversine, formatters)
    └── models/                  # Modelos compartidos
```

---

## 9. CI/CD — GitHub Actions

### 9.1 Workflow de Build

```yaml
# .github/workflows/build-apk.yml
name: Build APK

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release
      - uses: softprops/action-gh-release@v2
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

### 9.2 Flujo de Release

1. Developer pushea tag `v0.1.0`
2. GitHub Actions corre tests + build
3. APK se sube como asset de la Release
4. Developer descarga APK e instala en su teléfono

---

## 10. Diseño UI/UX

### 10.1 Principios

- **Mobile-first**: Optimizado para uso con una mano
- **Rápido**: Máximo 2 taps para registrar km
- **Dark mode default**: Uso frecuente en el auto (baja luminosidad)
- **Branding Changan**: Mantener la paleta azul (#00529b) como color primario

### 10.2 Paleta de Colores

| Token | Valor | Uso |
|-------|-------|-----|
| `primary` | `#00529B` | Changan Blue — acciones principales |
| `surface-dark` | `#0A0A0A` | Fondo oscuro |
| `surface-light` | `#FAFAFA` | Fondo claro |
| `danger` | `#EF4444` | Alertas vencidas |
| `success` | `#10B981` | Estados OK |
| `silver` | `#A1A1AA` | Texto secundario |

### 10.3 Navegación

Bottom Navigation Bar con las mismas secciones del prototipo:
1. **Dashboard** (Home)
2. **Logs** (Historial)
3. **GPS Tracker** (botón central elevado)
4. **Mantenimiento**
5. **Servicios**
6. **Proyecciones**
7. **Ajustes**

> [!NOTE]
> Considerar agrupar "Mantenimiento" y "Servicios" en una sola sección con tabs para simplificar la navegación en el MVP.

---

## 11. Estrategia Offline

### Fase 1 (MVP)

- **Online-first**: La app requiere internet para funcionar
- Cache local mínimo: guardar último estado del dashboard en SharedPreferences
- Si no hay internet: mostrar mensaje claro, permitir registrar offline con sync posterior

### Fase 2 (Post-MVP)

- **Offline-first** con `drift` (SQLite local)
- Sync bidireccional con Supabase cuando hay conexión
- Cola de operaciones pendientes

---

## 12. Testing Strategy

| Nivel | Herramienta | Cobertura |
|-------|------------|-----------|
| Unit | `flutter_test` | Models, providers, utils |
| Widget | `flutter_test` | Componentes individuales |
| Integration | `integration_test` | Flujos completos |

---

## 13. Métricas de Éxito del MVP

- [ ] El usuario puede registrar km manualmente en < 10 segundos
- [ ] El GPS tracker funciona en foreground sin crashes
- [ ] Los recordatorios alertan correctamente al acercarse al km de servicio
- [ ] Los datos persisten entre sesiones (Supabase)
- [ ] El APK se genera automáticamente en GitHub Releases
- [ ] La app funciona en Android 10+ (API 29+)

---

## 14. Plan de Migración de Datos

Para migrar datos del prototipo web actual:

1. Exportar JSON desde el prototipo web (feature ya existente)
2. Crear script/pantalla en la app Flutter para importar ese JSON
3. Mapear IDs (integer → UUID) durante la importación
4. Validar integridad después de importar

---

## 15. Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigación |
|--------|---------|-----------|
| Docker Flutter build lento | DX pobre | Usar cached volumes, layer caching |
| GPS drena batería | UX pobre | Solo foreground, usuario controla inicio/fin |
| Supabase free tier limits | Servicio caído | 500MB DB + 1GB storage es suficiente para MVP personal |
| Sin offline | No usable sin internet | Fase 1: mostrar estado claro. Fase 2: offline-first |
| APK sin firmar | No instala | Usar debug keystore, habilitar "instalar apps desconocidas" |

---

## 16. Hitos del MVP

| Hito | Descripción | Prioridad |
|------|-------------|-----------|
| H1 | Setup: Docker + Flutter project + Supabase config | 🔴 Crítico |
| H2 | Auth: Login con email/magic link | 🔴 Crítico |
| H3 | Dashboard + Registro de Kilometraje | 🔴 Crítico |
| H4 | Recordatorios de Mantenimiento | 🟡 Alto |
| H5 | Registro de Servicios | 🟡 Alto |
| H6 | Proyecciones y Gráficos | 🟢 Medio |
| H7 | GPS Tracker | 🟢 Medio |
| H8 | Settings + Export/Import | 🟡 Alto |
| H9 | CI/CD — APK en GitHub Releases | 🟡 Alto |
| H10 | Dark/Light mode | 🟢 Medio |

---

## 17. Preguntas Abiertas

> [!IMPORTANT]
> Necesito tu input en estos puntos antes de la implementación:

1. **¿Supabase hosted o self-hosted?** — Recomiendo hosted (supabase.com) para el MVP por simplicidad. ¿Estás de acuerdo?

2. **¿Auth method?** — ¿Email + password, magic link, o ambos? Magic link es más simple pero requiere email real.

3. **¿Moneda para costos de servicios?** — El prototipo actual usa `$`. ¿Es USD, pesos chilenos, o querés que sea configurable?

4. **¿GPS en background?** — ¿Necesitás que el tracker funcione con la app en segundo plano, o con foreground es suficiente para el MVP?

5. **¿Nombre de la app?** — Propuestas: "AutoTracker", "MiAuto", "DriveLog", "KmTracker". ¿O preferís otro?

6. **¿Agrupar Mantenimiento + Servicios?** — En mobile, 7 tabs en la barra inferior es mucho. ¿Te parece combinarlos en una sola sección con tabs internos?
