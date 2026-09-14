# Code Review Rules

## General
- Keep changes focused and minimal for each commit.
- Prefer clear naming and readable code over clever shortcuts.
- Add or update docs when behavior or setup changes.

## Flutter / Dart
- Follow feature-first structure and layer boundaries (presentation, domain, data).
- Avoid business logic inside widgets.
- Prefer immutable models and explicit dependency injection.
- Keep `flutter analyze` warnings at zero for touched code.

## Supabase / SQL
- Use migrations for every schema change.
- Enable RLS on user data tables from day one.
- Use least-privilege policies (`auth.uid() = user_id` pattern where applicable).
- Never store credentials in SQL files.

## Security
- Never commit real secrets or credentials.
- `.env.json` is local-only and must stay ignored.
- Use `.env.json.example` as template.

## Git
- Use Conventional Commits.
- One concern per commit whenever possible.
