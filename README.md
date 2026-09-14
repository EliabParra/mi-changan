# Mi Changan — CS35 Plus Tracker

Tracker personal para el Changan CS35 Plus: registro de kilometraje, recordatorios, historial de servicio y más.

> **Repo público.** Nunca empujes credenciales reales. Ver [Política de secretos](#política-de-secretos) más abajo.

---

## Inicio rápido

¿Primera vez en el proyecto? Seguí la [guía de onboarding](docs/onboarding.md) — cubre desde clonar el repo hasta obtener tu primer APK.

**Comandos esenciales** (todos dentro de Docker, sin instalar Flutter localmente):

```bash
# Instalar dependencias
docker compose run --rm flutter flutter pub get

# Analizar código
docker compose run --rm flutter flutter analyze

# Correr tests
docker compose run --rm flutter flutter test

# Shell interactivo
docker compose run --rm flutter bash
```

---

## Política de secretos

> ⚠️ **Este es un repositorio público. Cualquier secreto commiteado queda expuesto de forma inmediata.**

### Reglas

1. **Nunca commitear credenciales reales.** Sin URLs de Supabase con refs de proyecto reales, sin anon keys, sin service role keys, sin tokens — jamás.
2. **`.env.json` es solo local.** Está listado en `.gitignore` y nunca debe aparecer en un commit ni en un diff de PR.
3. **Usar `.env.json.example` como plantilla.** Copiarlo y completar con valores reales:

   ```bash
   cp .env.json.example .env.json
   # Editar .env.json con las credenciales reales de Supabase
   ```

4. **CI/CD usa GitHub Secrets.** Los workflows inyectan credenciales en tiempo de build desde los secrets del repositorio — nunca desde archivos commiteados.

### Variables requeridas

| Variable | Descripción |
|----------|-------------|
| `SUPABASE_URL` | URL de tu proyecto Supabase (ej: `https://xxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Clave anon pública (nunca la service role key) |
| `APP_NAME` | Nombre de la app |

Se pasan a Flutter vía `--dart-define-from-file=.env.json` en tiempo de compilación.

---

## CI / Release

| Workflow | Trigger | Qué hace |
|----------|---------|----------|
| `ci.yml` | PR a `main`/`master` | `flutter analyze --fatal-infos` + `flutter test` (sin secretos) |
| `build-apk.yml` | Tag `v*` (ej: `v0.1.0`) | Tests + build APK release + sube a GitHub Releases |

Para publicar una nueva versión:

```bash
git tag v0.1.0
git push origin v0.1.0
# El APK aparece en https://github.com/<usuario>/mi-changan/releases
```

> Los GitHub Secrets `SUPABASE_URL` y `SUPABASE_ANON_KEY` deben estar configurados en el repositorio antes de hacer un release. Ver [docs/onboarding.md](docs/onboarding.md#configurar-github-secrets).

## Definiciones de tablas (actual)

El código de Wave 2 usa estas tablas en Supabase:

- `maintenance_reminders`
- `service_records`

Si todavía no existen en tu proyecto Supabase, agregá una migración antes de usar esas pantallas.

---

## Estructura del proyecto

```
lib/
├── core/          # Router, theme, providers, constantes
├── features/      # Módulos por feature (auth, dashboard, mileage, etc.)
│   └── <feature>/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/        # Widgets, utils y modelos compartidos

supabase/
└── migrations/    # Migraciones SQL versionadas (5 tablas MVP + RLS)

.github/workflows/ # CI (analyze+test) y release APK
docs/              # Documentación técnica y onboarding
```

---

## License

MIT
